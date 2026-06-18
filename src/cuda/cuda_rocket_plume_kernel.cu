#include <cuda_runtime.h>

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <string>

struct Rgb {
  unsigned char r;
  unsigned char g;
  unsigned char b;
};

__device__ float clamp01(float x) { return fminf(1.0f, fmaxf(0.0f, x)); }

__device__ float smoothstepf(float a, float b, float x) {
  float t = clamp01((x - a) / (b - a));
  return t * t * (3.0f - 2.0f * t);
}

__device__ float hash21(float x, float y) {
  float n = sinf(x * 127.1f + y * 311.7f) * 43758.5453f;
  return n - floorf(n);
}

__device__ float noise2(float x, float y) {
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
  float v = 0.0f;
  float amp = 0.55f;
  float freq = 1.0f;

  for (int i = 0; i < 5; ++i) {
    v += amp * noise2(x * freq, y * freq);
    freq *= 2.07f;
    amp *= 0.52f;
  }

  return v;
}

__global__ void plume_kernel(Rgb *out, int width, int height, int frame) {
  int px = blockIdx.x * blockDim.x + threadIdx.x;
  int py = blockIdx.y * blockDim.y + threadIdx.y;

  if (px >= width || py >= height) {
    return;
  }

  float u = px / float(width - 1);
  float v = (py / float(height - 1) - 0.5f) * 2.0f;
  float t = frame * 0.055f;

  float center = 0.045f * sinf(9.0f * u - 1.8f * t) +
                 0.025f * sinf(23.0f * u + 0.9f * t);
  float r = 0.035f + 0.62f * powf(u, 0.82f);
  float core_r = 0.026f + 0.13f * powf(u, 0.55f);
  float y = v - center;
  float ay = fabsf(y);

  float start = smoothstepf(0.0f, 0.035f, u);
  float end = 1.0f - smoothstepf(0.86f, 1.0f, u);
  float envelope = start * end * expf(-powf(ay / r, 2.15f));

  float axial = 9.25f * u - 1.55f * t;
  float shock_phase = cosf(axial * 6.2831853f);
  float shock = powf(clamp01(0.5f + 0.5f * shock_phase), 3.2f);
  shock *= expf(-powf(ay / (0.29f * r + 0.018f), 2.0f));
  shock *= expf(-1.65f * u) * start;

  float core = expf(-powf(ay / core_r, 2.35f)) * expf(-3.0f * u) * start;

  float turb = fbm(u * 5.0f - 0.55f * t, v * 3.2f + 0.7f * t);
  float filament = fbm(u * 17.0f + 0.7f * t, v * 11.0f - 1.1f * t);
  float ragged = smoothstepf(0.18f, 0.82f, filament);

  float density = envelope * (0.56f + 0.68f * turb) + 0.92f * shock +
                  1.35f * core;
  density *= 0.72f + 0.48f * ragged;
  density = clamp01(density);

  float hot = clamp01(core * 1.45f + shock * 0.85f);
  float cool = smoothstepf(0.18f, 0.92f, u) * envelope;

  float rr = density * (0.78f + 1.85f * hot + 0.32f * cool);
  float gg = density * (0.34f + 1.52f * hot + 0.58f * cool);
  float bb = density * (0.12f + 0.66f * hot + 1.18f * cool);

  float alpha_edge = smoothstepf(0.0f, 0.04f, density);
  rr *= alpha_edge;
  gg *= alpha_edge;
  bb *= alpha_edge;

  int idx = py * width + px;
  out[idx].r = (unsigned char)(255.0f * clamp01(rr));
  out[idx].g = (unsigned char)(255.0f * clamp01(gg));
  out[idx].b = (unsigned char)(255.0f * clamp01(bb));
}

void check(cudaError_t err, const char *where) {
  if (err != cudaSuccess) {
    fprintf(stderr, "CUDA error at %s: %s\n", where, cudaGetErrorString(err));
    exit(1);
  }
}

void write_ppm(const std::string &path, const Rgb *pixels, int width,
               int height) {
  FILE *fp = fopen(path.c_str(), "wb");

  if (!fp) {
    fprintf(stderr, "Failed to open %s\n", path.c_str());
    exit(1);
  }

  fprintf(fp, "P6\n%d %d\n255\n", width, height);
  fwrite(pixels, sizeof(Rgb), width * height, fp);
  fclose(fp);
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: %s <out_dir> [frames] [width] [height]\n", argv[0]);
    return 1;
  }

  std::string out_dir = argv[1];
  int frames = argc > 2 ? atoi(argv[2]) : 96;
  int width = argc > 3 ? atoi(argv[3]) : 1024;
  int height = argc > 4 ? atoi(argv[4]) : 512;

  Rgb *device_pixels = nullptr;
  Rgb *host_pixels = (Rgb *)malloc(sizeof(Rgb) * width * height);

  if (!host_pixels) {
    fprintf(stderr, "Failed to allocate host pixels\n");
    return 1;
  }

  check(cudaMalloc(&device_pixels, sizeof(Rgb) * width * height), "cudaMalloc");

  dim3 block(16, 16);
  dim3 grid((width + block.x - 1) / block.x,
            (height + block.y - 1) / block.y);

  for (int frame = 0; frame < frames; ++frame) {
    plume_kernel<<<grid, block>>>(device_pixels, width, height, frame);
    check(cudaGetLastError(), "plume_kernel");
    check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    check(cudaMemcpy(host_pixels, device_pixels, sizeof(Rgb) * width * height,
                     cudaMemcpyDeviceToHost),
          "cudaMemcpy");

    char filename[1024];
    snprintf(filename, sizeof(filename), "%s/plume_frame_%03d.ppm",
             out_dir.c_str(), frame);
    write_ppm(filename, host_pixels, width, height);
  }

  cudaFree(device_pixels);
  free(host_pixels);
  return 0;
}
