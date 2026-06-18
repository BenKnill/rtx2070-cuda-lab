# RTX 2070 CUDA Care Notes

Date: 2026-06-18

## Current State

- GPU: NVIDIA GeForce RTX 2070, compute capability 7.5, 8 GB VRAM.
- Windows driver: 566.36, reporting CUDA driver capability 12.7.
- Windows toolkit: CUDA 12.6 installed at `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6`.
- Older Windows toolkit still present: CUDA 11.2.
- WSL distro: Ubuntu 20.04.6 LTS.
- WSL toolkit: CUDA 12.6 installed at `/usr/local/cuda-12.6`.
- Older WSL toolkit still present: CUDA 11.0.
- WSL `/usr/local/cuda` now points to CUDA 12.6 through alternatives.
- Blender still present in WSL: 4.4.3.

## Validation

Windows CUDA 12.6:

- Built NVIDIA cuda-samples `v12.5` `deviceQuery` and `bandwidthTest` with VS2022 after changing local sample project imports from `CUDA 12.5` to `CUDA 12.6`.
- `deviceQuery`: PASS, CUDA driver/runtime 12.7 / 12.6.
- `bandwidthTest --mode=quick`: PASS.
- Built native Windows `fluidsGL` and ran the reference path successfully.
- `fluidsGL` generated deterministic frames and passed image comparison with 0 failures.

WSL CUDA 12.6:

- Built `deviceQuery` and `bandwidthTest` using `/usr/local/cuda-12.6/bin/nvcc`.
- `deviceQuery`: PASS, CUDA driver/runtime 12.7 / 12.6.
- `bandwidthTest --mode=quick`: PASS.

## Important Lanes

- Blender/OptiX renders: keep using the existing Blender path. The CUDA upgrade did not require a driver change.
- CUDA compute without graphics interop: WSL is good now and easier to automate.
- CUDA/OpenGL interactive samples: use native Windows. NVIDIA WSL still does not support the CUDA/OpenGL interop path that `fluidsGL` needs.
- Game engine / real-time preview renders: prefer native Windows on this box.
- AI keyframe/guide rendering: Blender still wins for physically grounded lighting and shadow passes; game engines may win for real-time iteration once assets are staged.

## Helper Scripts

- `win_cuda126_env.ps1`: sets CUDA 12.6 environment variables for the current PowerShell process and prints `nvcc --version`.
- `wsl_cuda126_env.sh`: exports CUDA 12.6 environment variables in WSL and prints `nvcc --version`.
- `win_build_cuda126_basic_samples.ps1`: rebuilds/runs Windows `deviceQuery` and `bandwidthTest`.
- `wsl_build_cuda126_basic_samples.sh`: rebuilds/runs WSL `deviceQuery` and `bandwidthTest`.
- `win_build_run_cuda126_fluidsgl.ps1`: rebuilds/runs native Windows `fluidsGL` reference mode.

## Logs

Logs are under `cuda_care_logs/`. The key successful receipts are:

- `windows-cuda126-install-20260618-163256.txt`
- `wsl-cuda126-install-20260618-164332.txt`
- `windows-cuda126-basic-samples-20260618-170417.txt`
- `wsl-cuda126-basic-samples-20260618-170453.txt`
- `windows-cuda126-fluidsgl-20260618-172434.txt`
- `wsl-fluidsgl-gallery-animation-20260618-172529.txt`
