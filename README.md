Page: [RTX 2070 CUDA Lab gallery](https://htmlpreview.github.io/?https://github.com/BenKnill/rtx2070-cuda-lab/blob/main/docs/index.html)

# RTX 2070 CUDA Lab

Standalone CUDA demo gallery and care notes for the RTX 2070 remote render/offload box.

The practical page lives in `docs/index.html`. GitHub's raw-file preview is available immediately through HTMLPreview above. If GitHub Pages is enabled successfully, the cleaner URL should be:

[https://benknill.github.io/rtx2070-cuda-lab/](https://benknill.github.io/rtx2070-cuda-lab/)

## Blender Bridge

- `docs/media/cuda_smoke_blender_bridge_preview.png` - Cycles render using CUDA smokeParticles frames as layered cloud cards.
- `assets/blender/cuda_smoke_cards_scene.blend` - packed Blender scene containing the generated smoke-card textures.
- `assets/blender/smoke_cards/` - derived PNG cards from the CUDA smokeParticles frame capture.

## What Is Here

- `docs/index.html` - the gallery page.
- `docs/media/fluidsGL_native_run.gif` / `.mp4` - native Windows CUDA/OpenGL fluidsGL animation.
- `docs/media/oceanFFT_native_run.gif` / `.mp4` - native Windows CUDA/CUFFT/OpenGL ocean surface animation.
- `docs/media/smokeParticles_native_run.gif` / `.mp4` - native Windows CUDA/OpenGL volumetric smoke particle animation.
- `docs/media/simpleGL_native_run.gif` / `.mp4` - native Windows CUDA/OpenGL VBO sine-wave animation.
- `docs/media/cuda_sim_contact.png` - contact sheet of non-windowed CUDA QA outputs.
- `notes/cuda_care_notes.md` - RTX 2070 and CUDA 12.6 setup notes.
- `scripts/wsl/` - WSL-first install, probe, conversion, and validation scripts.
- `scripts/windows/` - Windows-only native CUDA/OpenGL build/capture scripts for demos that need real Windows graphics interop.

## Box State

- GPU: NVIDIA RTX 2070, compute capability 7.5.
- Windows display driver observed during setup: 566.36, CUDA driver capability 12.7.
- CUDA Toolkit 12.6 installed on Windows and WSL.
- WSL GitHub CLI is the repo/publishing path.

## Policy

Use WSL for repo, GitHub, conversion, probing, and general scripting whenever possible. Use Windows scripts only for native CUDA/OpenGL demos where WSLg cannot provide CUDA/OpenGL interop.
