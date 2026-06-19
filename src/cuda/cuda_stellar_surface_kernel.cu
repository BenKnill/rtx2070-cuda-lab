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

__device__ float clamp01(float x) {
    return fminf(fmaxf(x, 0.0f), 1.0f);
}

__device__ float smooth01(float edge0, float edge1, float x) {
    float t = clamp01((x - edge0) / (edge1 - edge0));
    return t * t * (3.0f - 2.0f * t);
}

__device__ float filament_band(float x, float sharpness) {
    return expf(-x * x * sharpness);
}

__device__ Pixel ramp(float heat, float filament, float flare) {
    heat = clamp01(heat);
    filament = clamp01(filament);
    flare = clamp01(flare);

    float r = 0.06f + heat * 1.18f + filament * 0.62f + flare * 0.46f;
    float g = 0.012f + powf(heat, 1.55f) * 0.66f + filament * 0.34f + flare * 0.38f;
    float b = 0.002f + powf(heat, 4.4f) * 0.1f + filament * 0.032f + flare * 0.08f;

    float white = fmaxf(heat - 0.84f, 0.0f) * 2.45f + flare * 0.34f;
    r += white;
    g += white * 0.78f;
    b += white * 0.38f;

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

    float flow_a = fbm(px * 2.2f + 17.0f + time * 0.045f, py * 2.0f - 8.0f - time * 0.032f) - 0.5f;
    float flow_b = fbm(px * 2.4f - 5.0f - time * 0.036f, py * 2.1f + 13.0f + time * 0.041f) - 0.5f;
    float flow_c = fbm(px * 4.7f + time * 0.11f, py * 4.1f - time * 0.075f) - 0.5f;

    float ax = px + flow_a * 0.23f + flow_c * 0.06f + sinf(py * 3.1f + flow_b * 2.7f) * 0.025f;
    float ay = py + flow_b * 0.23f - flow_c * 0.05f + cosf(px * 2.8f + flow_a * 2.4f) * 0.025f;

    float granule = fbm(ax * 16.0f + time * 0.18f, ay * 15.0f - time * 0.13f);
    float micro = fbm(ax * 58.0f - time * 0.42f, ay * 54.0f + time * 0.31f);
    float hair = fbm(ax * 112.0f + time * 0.74f, ay * 96.0f - time * 0.58f);

    float network = powf(ridge(granule), 3.15f);
    float bright_cells = smooth01(0.46f, 0.86f, granule) * 0.62f + network * 0.34f;
    float dark_pores = powf(smooth01(0.38f, 0.08f, micro), 1.55f);

    float warp = (fbm(ax * 7.0f + 31.0f, ay * 7.5f - 19.0f) - 0.5f) * 5.5f;
    warp += (fbm(ax * 18.0f - time * 0.19f, ay * 16.0f + time * 0.16f) - 0.5f) * 2.7f;

    float filament = 0.0f;
    const float angles[7] = {0.15f, 0.72f, 1.34f, 2.03f, 2.63f, -0.42f, -1.08f};
    for (int i = 0; i < 7; ++i) {
        float fi = static_cast<float>(i);
        float ca = cosf(angles[i]);
        float sa = sinf(angles[i]);
        float coord = ax * ca + ay * sa;
        float cross = -ax * sa + ay * ca;
        float local = fbm(coord * 5.0f + fi * 13.0f, cross * 5.8f - fi * 7.0f);
        float phase = coord * (18.0f + fi * 4.7f) + warp + local * 4.0f + time * (0.32f + fi * 0.035f);
        float stripe = sinf(phase);
        float vein = filament_band(stripe, 28.0f + fi * 7.0f);
        filament += vein * (0.065f + 0.012f * fi);
    }

    float knots = smooth01(0.71f, 0.94f, fbm(ax * 22.0f + 4.0f + time * 0.12f, ay * 20.0f - 2.0f - time * 0.09f));
    float flare = knots * knots * (0.36f + 0.24f * fbm(ax * 61.0f, ay * 57.0f));
    float local_flicker = (fbm(ax * 10.0f + time * 0.28f, ay * 9.0f - time * 0.21f) - 0.5f) * 0.045f;

    float heat = 0.16f + bright_cells * 0.54f + micro * 0.18f + hair * 0.085f + filament * 0.72f + flare * 0.34f;
    heat -= dark_pores * 0.22f;
    heat += local_flicker;

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
