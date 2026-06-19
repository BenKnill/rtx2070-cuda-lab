Page: [RTX 2070 CUDA Lab gallery](https://htmlpreview.github.io/?https://github.com/BenKnill/rtx2070-cuda-lab/blob/main/docs/index.html)

# RTX 2070 CUDA Lab

Standalone CUDA demo gallery and care notes for the RTX 2070 remote render/offload box.

The practical page lives in `docs/index.html`. GitHub's raw-file preview is available immediately through HTMLPreview above. If GitHub Pages is enabled successfully, the cleaner URL should be:

[https://benknill.github.io/rtx2070-cuda-lab/](https://benknill.github.io/rtx2070-cuda-lab/)

## Blender Bridge

- `docs/media/gateway_plasma_keyframe.png` - Cycles/OptiX keyframe using downloaded NASA Gateway, ESAS crew module, NASA Earth texture, and ESO Milky Way skybox assets with procedural plasma/atmosphere shaders.
- `assets/blender/gateway_plasma_keyframe.blend` - packed Blender scene for the NASA asset shader keyframe.
- `scripts/blender/render_asset_shader_keyframe.py` - generator for the local asset-library render; expects the local `asset_library` cache outside this repo.
- `docs/media/cuda_rocket_plume_zaware_scene.gif` / `.mp4` - z-aware Blender/Cycles rocket animation with CUDA plume cards rendered inside the scene.
- `docs/media/cuda_rocket_plume_scene.gif` / `.mp4` - faster flat-composite full-scene rocket animation retained as a scratch/reference artifact.
- `docs/media/cuda_rocket_plume_blender_preview.png` - Cycles render of a procedural rocket with a CUDA-generated exhaust plume attached to the nozzle.
- `docs/media/cuda_rocket_plume.gif` / `.mp4` - raw 96-frame CUDA plume field generated under WSL.
- `assets/blender/cuda_rocket_plume_scene.blend` - packed Blender scene containing the rocket and derived plume-card textures.
- `assets/blender/rocket_plume_cards/` - selected CUDA plume frames prepared as Blender emission cards.
- `docs/media/cuda_smoke_blender_bridge_preview.png` - Cycles render using CUDA smokeParticles frames as layered cloud cards.
- `assets/blender/cuda_smoke_cards_scene.blend` - packed Blender scene containing the generated smoke-card textures.
- `assets/blender/smoke_cards/` - derived PNG cards from the CUDA smokeParticles frame capture.

## What Is Here

- `docs/index.html` - the gallery page.
- `docs/media/fluidsGL_native_run.gif` / `.mp4` - native Windows CUDA/OpenGL fluidsGL animation.
- `docs/media/oceanFFT_native_run.gif` / `.mp4` - native Windows CUDA/CUFFT/OpenGL ocean surface animation.
- `docs/media/smokeParticles_native_run.gif` / `.mp4` - native Windows CUDA/OpenGL volumetric smoke particle animation.
- `docs/media/simpleGL_native_run.gif` / `.mp4` - native Windows CUDA/OpenGL VBO sine-wave animation.
- `src/cuda/cuda_rocket_plume_kernel.cu` - WSL CUDA kernel that synthesizes rocket plume frames for Blender.
- `scripts/wsl/wsl_make_cuda_rocket_plume_scene_animation.sh` - renders a clean Blender plate and composites the animated plume into the full rocket shot.
- `scripts/wsl/wsl_render_cuda_rocket_plume_zaware_animation.sh` - renders lower-sample Cycles frames with animated CUDA plume cards inside Blender for real scene depth.
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
