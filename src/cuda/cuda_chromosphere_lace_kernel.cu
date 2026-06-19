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

__device__ float clamp01(float x) {
    return fminf(fmaxf(x, 0.0f), 1.0f);
}

__device__ float smooth01(float a, float b, float x) {
    float t = clamp01((x - a) / (b - a));
    return t * t * (3.0f - 2.0f * t);
}

__device__ float hash21(float x, float y) {
    float h = sinf(x * 127.1f + y * 311.7f) * 43758.5453123f;
    return h - floorf(h);
}

__device__ float noise(float x, float y) {
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
    float x0 = a + (b - a) * ux;
    float x1 = c + (d - c) * ux;
    return x0 + (x1 - x0) * uy;
}

__device__ float fbm(float x, float y) {
    float sum = 0.0f;
    float amp = 0.52f;
    for (int i = 0; i < 7; ++i) {
        sum += amp * noise(x, y);
        float nx = x * 1.83f - y * 0.57f + 19.3f;
        float ny = x * 0.57f + y * 1.83f - 11.7f;
        x = nx;
        y = ny;
        amp *= 0.52f;
    }
    return sum;
}

__device__ float ridge(float x) {
    return 1.0f - fabsf(x * 2.0f - 1.0f);
}

__device__ float line_kernel(float x, float sharpness) {
    return expf(-x * x * sharpness);
}

__device__ void add_color(float& r, float& g, float& b, float weight, float cr, float cg, float cb) {
    r += weight * cr;
    g += weight * cg;
    b += weight * cb;
}

__device__ Pixel tone_map(float r, float g, float b) {
    // Stable display curve: enough punch through star apertures without the
    // whole plate flashing frame-to-frame.
    r = 1.0f - expf(-r * 1.08f);
    g = 1.0f - expf(-g * 1.08f);
    b = 1.0f - expf(-b * 1.08f);
    float luma = r * 0.2126f + g * 0.7152f + b * 0.0722f;
    float sat = 1.18f;
    r = luma + (r - luma) * sat;
    g = luma + (g - luma) * sat;
    b = luma + (b - luma) * sat;
    Pixel p;
    p.r = static_cast<unsigned char>(clamp01(r) * 255.0f);
    p.g = static_cast<unsigned char>(clamp01(g) * 255.0f);
    p.b = static_cast<unsigned char>(clamp01(b) * 255.0f);
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
    float aspect = static_cast<float>(width) / static_cast<float>(height);
    float px = (u - 0.5f) * aspect * 2.0f;
    float py = (v - 0.5f) * 2.0f;

    float slow = time * 0.055f;
    float drift = time * 0.18f;

    float w1 = fbm(px * 1.45f + slow * 0.7f, py * 1.32f - slow * 0.5f) - 0.5f;
    float w2 = fbm(px * 2.10f - slow * 0.9f + 8.0f, py * 1.88f + slow * 0.6f - 3.0f) - 0.5f;
    float w3 = fbm(px * 4.20f + drift * 0.32f, py * 3.90f - drift * 0.25f) - 0.5f;

    float ax = px + w1 * 0.31f + sinf(py * 2.1f + w2 * 4.0f + slow) * 0.055f + w3 * 0.04f;
    float ay = py + w2 * 0.27f + cosf(px * 2.4f - w1 * 3.0f - slow) * 0.05f - w3 * 0.035f;

    float gran = fbm(ax * 17.5f + drift * 0.25f, ay * 16.0f - drift * 0.20f);
    float micro = fbm(ax * 72.0f - drift * 0.72f, ay * 66.0f + drift * 0.54f);
    float hair = fbm(ax * 150.0f + drift * 1.1f, ay * 132.0f - drift * 0.92f);
    float cells = powf(ridge(gran), 2.8f);
    float dark_pores = powf(smooth01(0.60f, 0.22f, micro), 1.9f);

    float filament = 0.0f;
    float hot_lace = 0.0f;
    const float angles[10] = {0.04f, 0.36f, 0.79f, 1.11f, 1.53f, 2.02f, 2.49f, -0.31f, -0.87f, -1.28f};
    for (int i = 0; i < 10; ++i) {
        float fi = static_cast<float>(i);
        float ca = cosf(angles[i]);
        float sa = sinf(angles[i]);
        float along = ax * ca + ay * sa;
        float across = -ax * sa + ay * ca;
        float local = fbm(along * 4.5f + fi * 17.0f + slow, across * 6.2f - fi * 13.0f - slow);
        float waviness = (local - 0.5f) * 5.8f + (fbm(along * 14.0f - drift * 0.17f, across * 11.0f + drift * 0.13f) - 0.5f) * 2.4f;
        float phase = along * (24.0f + fi * 4.1f) + waviness + time * (0.28f + fi * 0.018f);
        float stripe = sinf(phase);
        float thin = line_kernel(stripe, 42.0f + fi * 8.0f);
        float broken = smooth01(0.18f, 0.78f, local);
        filament += thin * broken * (0.085f + fi * 0.006f);
        hot_lace += line_kernel(stripe, 120.0f + fi * 12.0f) * broken * 0.055f;
    }

    float knots = smooth01(0.73f, 0.96f, fbm(ax * 28.0f + drift * 0.13f + 12.0f, ay * 24.0f - drift * 0.11f - 8.0f));
    float sparks = smooth01(0.77f, 0.97f, fbm(ax * 93.0f - drift * 1.8f, ay * 88.0f + drift * 1.3f));
    float blue_shear = smooth01(0.63f, 0.93f, fbm(ax * 9.0f - 22.0f, ay * 10.5f + 31.0f + slow * 1.6f));
    float violet_shear = smooth01(0.72f, 0.98f, fbm(ax * 12.0f + 43.0f - slow, ay * 13.0f - 4.0f + slow * 1.4f));

    float base = 0.12f + cells * 0.34f + gran * 0.22f + micro * 0.12f + hair * 0.055f;
    base -= dark_pores * 0.18f;
    base += filament * 0.55f + knots * 0.22f + sparks * 0.08f;
    base = clamp01(base);

    float r = 0.035f;
    float g = 0.008f;
    float b = 0.004f;

    add_color(r, g, b, base * 0.85f, 1.0f, 0.24f, 0.035f);
    add_color(r, g, b, cells * 0.24f, 1.0f, 0.62f, 0.12f);
    add_color(r, g, b, filament * 1.25f, 1.0f, 0.83f, 0.28f);
    add_color(r, g, b, hot_lace * 1.65f, 1.0f, 0.97f, 0.67f);
    add_color(r, g, b, knots * knots * 0.54f, 1.0f, 0.72f, 0.21f);
    add_color(r, g, b, sparks * sparks * 0.28f, 1.0f, 0.95f, 0.55f);

    // Small cool traces keep the shader from becoming one-note orange once it
    // is sampled through many white star masks.
    add_color(r, g, b, blue_shear * filament * 0.28f, 0.18f, 0.62f, 1.0f);
    add_color(r, g, b, violet_shear * hot_lace * 0.24f, 0.62f, 0.18f, 1.0f);

    pixels[y * width + x] = tone_map(r, g, b);
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
        std::cerr << "usage: chromosphere_lace <output_dir> [frames=72] [width=1280] [height=720]\n";
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
        std::snprintf(name, sizeof(name), "chromosphere_lace_%03d.ppm", frame);
        write_ppm(out_dir / name, host_pixels, width, height);
    }

    check(cudaFree(device_pixels), "cudaFree");
    std::cout << "wrote " << frames << " chromosphere lace CUDA frames to " << out_dir << "\n";
    return 0;
}
