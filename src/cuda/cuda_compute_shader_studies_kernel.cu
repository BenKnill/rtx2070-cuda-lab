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

__device__ float smooth01(float edge0, float edge1, float x) {
    float t = clamp01((x - edge0) / (edge1 - edge0));
    return t * t * (3.0f - 2.0f * t);
}

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
    float ab = a + (b - a) * ux;
    float cd = c + (d - c) * ux;
    return ab + (cd - ab) * uy;
}

__device__ float fbm(float x, float y) {
    float sum = 0.0f;
    float amp = 0.52f;
    float freq = 1.0f;
    for (int i = 0; i < 6; ++i) {
        sum += amp * value_noise(x * freq, y * freq);
        x = x * 1.11f + 17.4f;
        y = y * 0.93f - 9.2f;
        freq *= 2.08f;
        amp *= 0.5f;
    }
    return sum;
}

__device__ Pixel make_pixel(float r, float g, float b) {
    Pixel p;
    p.r = static_cast<unsigned char>(clamp01(r) * 255.0f);
    p.g = static_cast<unsigned char>(clamp01(g) * 255.0f);
    p.b = static_cast<unsigned char>(clamp01(b) * 255.0f);
    return p;
}

__device__ Pixel accretion_disk(float x, float y, float t) {
    float r = sqrtf(x * x + y * y);
    float a = atan2f(y, x);
    float swirl = a + 4.2f / (r + 0.18f) + t * 0.52f;
    float disk = expf(-fabsf(y + sinf(swirl * 2.0f) * 0.05f) * 8.0f) * smooth01(1.08f, 0.2f, r);
    float ring = expf(-powf((r - 0.48f) * 5.2f, 2.0f));
    float lanes = powf(0.5f + 0.5f * sinf(swirl * 18.0f + fbm(x * 8.0f, y * 8.0f) * 5.0f), 5.0f);
    float core = expf(-r * r * 38.0f);
    float lens = 0.12f / (r + 0.12f);
    float heat = disk * (0.36f + lanes * 0.8f) + ring * 0.42f + core * 1.7f + lens * 0.24f;
    return make_pixel(heat * 1.35f, heat * 0.66f + core * 0.34f, heat * 0.24f + ring * 0.12f);
}

__device__ Pixel aurora_sheet(float x, float y, float t) {
    float sweep = x * 2.1f + sinf(y * 4.5f + t * 0.6f) * 0.22f;
    float curtains = 0.0f;
    for (int i = 0; i < 6; ++i) {
        float fi = static_cast<float>(i);
        float center = -0.8f + fi * 0.32f + sinf(t * 0.35f + fi) * 0.08f;
        float strand = expf(-powf((sweep - center) * (9.5f + fi), 2.0f));
        strand *= 0.45f + 0.55f * fbm(x * 5.0f + fi * 3.1f, y * 15.0f - t * 0.8f);
        curtains += strand;
    }
    float vertical = smooth01(-1.0f, 0.22f, y) * smooth01(1.0f, -0.42f, y);
    float sparkle = powf(fbm(x * 42.0f + t, y * 34.0f - t * 0.4f), 7.0f);
    float glow = curtains * vertical + sparkle * 0.18f;
    return make_pixel(glow * 0.20f + sparkle * 0.15f, glow * 1.20f, glow * 0.95f + curtains * 0.35f);
}

__device__ Pixel caustic_lattice(float x, float y, float t) {
    float warp = fbm(x * 3.2f + t * 0.18f, y * 3.4f - t * 0.21f) - 0.5f;
    float u = x * 8.5f + warp * 2.4f + sinf(y * 5.0f + t * 0.7f);
    float v = y * 8.5f - warp * 2.1f + cosf(x * 5.5f - t * 0.5f);
    float line_a = expf(-powf(sinf(u) * 5.5f, 2.0f));
    float line_b = expf(-powf(sinf(v + u * 0.28f) * 5.8f, 2.0f));
    float line_c = expf(-powf(sinf((u - v) * 0.72f + t) * 6.6f, 2.0f));
    float radial = smooth01(1.42f, 0.18f, sqrtf(x * x + y * y));
    float heat = (line_a + line_b + line_c) * 0.42f * radial;
    return make_pixel(heat * 0.35f, heat * 0.82f + radial * 0.05f, heat * 1.35f + line_c * 0.12f);
}

__device__ Pixel ion_turbulence(float x, float y, float t) {
    float r = sqrtf(x * x + y * y);
    float a = atan2f(y, x);
    float flow = fbm(x * 2.8f + t * 0.22f, y * 2.8f - t * 0.19f);
    float twist = a * 3.0f + r * 8.0f - t * 0.9f + flow * 4.0f;
    float arms = powf(0.5f + 0.5f * sinf(twist), 4.0f);
    float knots = powf(fbm(x * 12.0f + t * 0.7f, y * 12.0f - t * 0.45f), 4.0f);
    float field = smooth01(1.18f, 0.06f, r) * (arms * 0.76f + knots * 0.42f);
    float core = expf(-r * r * 16.0f);
    return make_pixel(field * 0.95f + core * 0.48f, field * 0.26f + knots * 0.18f, field * 1.15f + core * 0.72f);
}

__global__ void study_kernel(Pixel* pixels, int width, int height, float time) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height) {
        return;
    }

    int half_w = width / 2;
    int half_h = height / 2;
    int tile_x = x >= half_w ? 1 : 0;
    int tile_y = y >= half_h ? 1 : 0;
    int mode = tile_y * 2 + tile_x;

    int local_x = tile_x ? x - half_w : x;
    int local_y = tile_y ? y - half_h : y;
    float u = (static_cast<float>(local_x) + 0.5f) / static_cast<float>(half_w);
    float v = (static_cast<float>(local_y) + 0.5f) / static_cast<float>(half_h);
    float aspect = static_cast<float>(half_w) / static_cast<float>(half_h);
    float px = (u - 0.5f) * 2.0f * aspect;
    float py = (v - 0.5f) * 2.0f;

    Pixel color;
    if (mode == 0) {
        color = accretion_disk(px, py, time);
    } else if (mode == 1) {
        color = aurora_sheet(px, py, time);
    } else if (mode == 2) {
        color = caustic_lattice(px, py, time);
    } else {
        color = ion_turbulence(px, py, time);
    }

    bool divider = abs(x - half_w) <= 1 || abs(y - half_h) <= 1;
    if (divider) {
        color = make_pixel(0.02f, 0.025f, 0.035f);
    }
    pixels[y * width + x] = color;
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
        std::cerr << "usage: compute_shader_studies <output_dir> [frames=72] [width=1280] [height=720]\n";
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
        study_kernel<<<grid, block>>>(device_pixels, width, height, time);
        check(cudaGetLastError(), "study_kernel");
        check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
        check(cudaMemcpy(host_pixels.data(), device_pixels, host_pixels.size() * sizeof(Pixel), cudaMemcpyDeviceToHost), "cudaMemcpy");

        char name[128];
        std::snprintf(name, sizeof(name), "compute_shader_studies_%03d.ppm", frame);
        write_ppm(out_dir / name, host_pixels, width, height);
    }

    check(cudaFree(device_pixels), "cudaFree");
    std::cout << "wrote " << frames << " CUDA compute shader study frames to " << out_dir << "\n";
    return 0;
}
