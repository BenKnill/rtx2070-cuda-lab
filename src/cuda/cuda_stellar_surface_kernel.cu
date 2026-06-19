#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#include <cuda_runtime.h>

struct Pixel {
    unsigned char r;
    unsigned char g;
    unsigned char b;
};

__device__ float hash21(float x, float y) {
    float h = sinf(x * 127.1f + y * 311.7f) * 43758.5453f;
    return h - floorf(h);
}

__device__ float value_noise(float x, float y) {
    float ix = floorf(x);
    float iy = floorf(y);
    float fx = x - ix;
    float fy = y - iy;
    float ux = fx * fx * (3.0f - 2.0f * fx);
    float uy = fy * fy * (3.0f - 2.0f * fy);

    float a = hash21(ix, iy);
    float b = hash21(ix + 1.0f, iy);
    float c = hash21(ix, iy + 1.0f);
    float d = hash21(ix + 1.0f, iy + 1.0f);
    return (a + (b - a) * ux) + ((c + (d - c) * ux) - (a + (b - a) * ux)) * uy;
}

__device__ float fbm(float x, float y) {
    float sum = 0.0f;
    float amp = 0.5f;
    float freq = 1.0f;
    for (int i = 0; i < 6; ++i) {
        sum += amp * value_noise(x * freq, y * freq);
        freq *= 2.07f;
        amp *= 0.52f;
        x += 13.1f;
        y -= 7.7f;
    }
    return sum;
}

__device__ float ridge(float x) {
    return 1.0f - fabsf(2.0f * x - 1.0f);
}

__device__ Pixel ramp(float heat, float filament, float flare) {
    heat = fminf(fmaxf(heat, 0.0f), 1.0f);
    filament = fminf(fmaxf(filament, 0.0f), 1.0f);
    flare = fminf(fmaxf(flare, 0.0f), 1.0f);

    float r = 0.08f + heat * 1.25f + filament * 0.42f + flare * 0.7f;
    float g = 0.015f + heat * heat * 0.75f + filament * 0.26f + flare * 0.62f;
    float b = 0.004f + powf(heat, 4.0f) * 0.18f + filament * 0.045f + flare * 0.18f;

    float white = fmaxf(heat - 0.82f, 0.0f) * 2.8f + flare * 0.55f;
    r += white;
    g += white * 0.82f;
    b += white * 0.48f;

    Pixel p;
    p.r = static_cast<unsigned char>(fminf(r, 1.0f) * 255.0f);
    p.g = static_cast<unsigned char>(fminf(g, 1.0f) * 255.0f);
    p.b = static_cast<unsigned char>(fminf(b, 1.0f) * 255.0f);
    return p;
}

__global__ void render_kernel(Pixel* pixels, int width, int height, float time) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height) {
        return;
    }

    float u = (static_cast<float>(x) + 0.5f) / static_cast<float>(width);
    float v = (static_cast<float>(y) + 0.5f) / static_cast<float>(height);
    float px = (u - 0.5f) * 2.0f;
    float py = (v - 0.5f) * 2.0f;

    float swirl_x = px * cosf(time * 0.22f) - py * sinf(time * 0.17f);
    float swirl_y = px * sinf(time * 0.13f) + py * cosf(time * 0.2f);
    float granules = fbm(swirl_x * 8.0f + time * 0.9f, swirl_y * 8.0f - time * 0.35f);
    float small = fbm(swirl_x * 29.0f - time * 1.7f, swirl_y * 25.0f + time * 0.8f);
    float cells = ridge(granules);

    float filament = 0.0f;
    for (int i = 0; i < 5; ++i) {
        float fi = static_cast<float>(i);
        float stripe = sinf((px * (7.5f + fi * 2.1f) + py * (3.2f + fi)) + time * (0.9f + fi * 0.21f) + fi * 1.7f);
        float vein = expf(-stripe * stripe * (8.0f + fi * 1.5f));
        filament += vein * (0.13f + 0.04f * fi);
    }

    float flare_core = fbm(px * 3.0f + 11.0f + time * 0.28f, py * 2.4f - 3.0f - time * 0.16f);
    float flare = powf(fmaxf(flare_core - 0.57f, 0.0f) * 2.35f, 2.0f);
    float dark_pores = powf(fmaxf(0.35f - small, 0.0f) * 2.2f, 1.6f);

    float heat = 0.22f + granules * 0.58f + cells * 0.24f + small * 0.23f + filament * 0.38f + flare * 0.45f;
    heat -= dark_pores * 0.34f;
    heat += 0.08f * sinf(time + px * 5.0f + py * 4.0f);

    pixels[y * width + x] = ramp(heat, filament, flare);
}

static void check(cudaError_t err, const char* label) {
    if (err != cudaSuccess) {
        std::cerr << label << ": " << cudaGetErrorString(err) << "\n";
        std::exit(1);
    }
}

static void write_ppm(const std::filesystem::path& path, const std::vector<Pixel>& pixels, int width, int height) {
    std::ofstream out(path, std::ios::binary);
    out << "P6\n" << width << " " << height << "\n255\n";
    out.write(reinterpret_cast<const char*>(pixels.data()), static_cast<std::streamsize>(pixels.size() * sizeof(Pixel)));
}

int main(int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "usage: stellar_surface <output_dir> [frames=72] [width=1280] [height=720]\n";
        return 2;
    }

    std::filesystem::path out_dir = argv[1];
    int frames = argc > 2 ? std::atoi(argv[2]) : 72;
    int width = argc > 3 ? std::atoi(argv[3]) : 1280;
    int height = argc > 4 ? std::atoi(argv[4]) : 720;

    std::filesystem::create_directories(out_dir);

    Pixel* device_pixels = nullptr;
    std::vector<Pixel> host_pixels(static_cast<size_t>(width) * static_cast<size_t>(height));
    check(cudaMalloc(&device_pixels, host_pixels.size() * sizeof(Pixel)), "cudaMalloc");

    dim3 block(16, 16);
    dim3 grid((width + block.x - 1) / block.x, (height + block.y - 1) / block.y);

    for (int frame = 0; frame < frames; ++frame) {
        float time = static_cast<float>(frame) / 12.0f;
        render_kernel<<<grid, block>>>(device_pixels, width, height, time);
        check(cudaGetLastError(), "render_kernel");
        check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
        check(cudaMemcpy(host_pixels.data(), device_pixels, host_pixels.size() * sizeof(Pixel), cudaMemcpyDeviceToHost), "cudaMemcpy");

        char name[128];
        std::snprintf(name, sizeof(name), "stellar_surface_%03d.ppm", frame);
        write_ppm(out_dir / name, host_pixels, width, height);
    }

    check(cudaFree(device_pixels), "cudaFree");
    std::cout << "wrote " << frames << " stellar CUDA frames to " << out_dir << "\n";
    return 0;
}
