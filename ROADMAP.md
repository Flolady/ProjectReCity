# Project ReCity roadmap

Last updated: 2026-11-22. Each item is ticked only when it is verified (a test, a measurement or a run), never on
estimate. The detailed evidence for every line is in [docs/](docs/README.md); what changed recently is in
[CHANGELOG.md](CHANGELOG.md). Claim an item in [the coordination issue](https://github.com/pixl27/ProjectReCity/issues/1)
before starting it.

Legend: ✅ done and verified · ⚠️ partly done or unverified on hardware · ⬜ not started

## Phase 0 — Groundwork without the executable

Everything the build can do from the package alone.

| Item | State | Evidence |
|---|---|---|
| Find and check a copy of the Xbox Series package 1.0.2.1 | ✅ | `game/xbox-1.0.2.1.json`, `make_game.py --check` |
| Carve, unpack and disassemble every shader (26,503) | ✅ | `tools/shader_carve.py`, `fssm_unpack.py`, `shader_disasm.py` |
| Translate every shader RDNA2 → SPIR-V, all passing `spirv-val` (LLVM 21) | ✅ | `tools/rdna2spirv.py`, [docs/design.md](docs/design.md) |
| Same with LLVM 23 (1,471 still rejected) | ⚠️ | [docs/design.md](docs/design.md#disassembling-shaders) |
| Wave64 exact on 32-wide subgroups for compute and mesh | ✅ | `--wave64-emulate`, GPU tests |
| Wave64 cross-half ops in VS / PS / GS on 32-wide subgroups | ⚠️ | approximate today |
| Export models (OBJ, names, UVs, materials) | ⚠️ | some layouts still rejected ([docs/models.md](docs/models.md)) |
| Export texture dictionaries and world pools (DDS) | ⚠️ | BCPack entries skipped; `tools/bcpack.py` not wired into `rpf9dump` ([docs/textures.md](docs/textures.md)) |
| Export audio banks (Opus lossless, PCM, XMA2 via ffmpeg) | ✅ | [docs/audio.md](docs/audio.md) |
| Music / radio configuration | ⚠️ | durations and stream ids measured, no per-track start offsets ([docs/audio_config.md](docs/audio_config.md)) |
| Pipeline cache built on the player's driver before first boot | ✅ | `pipelines` stage, `vk_pipeline_check` |

## Phase 1 — Runtime and loader

| Item | State | Evidence |
|---|---|---|
| PE loader: map, relocate, bind imports, static TLS | ✅ | `runtime/src/pe_loader.*`, `pe_loader_test`, `loader_tls_test` |
| Run a stand-in executable end to end (`gta6rt --run`) | ✅ | `run_tiny_game` ctest |
| GDK, XMem and `xgameruntime` shims (offline) | ⚠️ | covered by unit tests, untested against the real executable |
| GameInput shim (Xbox pads, DualSense through SDL3) | ⚠️ | `gameinput_test`; DualSense features need SDL3 |
| Loader under Wine / Proton on Linux | ✅ | `wine` CI job |
| First dry run of the real executable (`gta6rt --dry-run`) | ⬜ | needs the executable ([docs/design.md](docs/design.md#day-one-when-the-exe-is-here)) |

## Phase 2 — Xbox D3D12 → Vulkan

The milestones below come from [docs/d3d12_vulkan.md §6](docs/d3d12_vulkan.md#6-boot-milestones). M0–M2 need no
game executable.

| Milestone | Scope | State |
|---|---|---|
| Device objects | queues, command lists, fences, descriptor heaps, committed and reserved resources, RTV/DSV, texture views, samplers, query heaps | ✅ on one GPU |
| Commands | barriers, clears, uploads, copies (BC included), colour resolves, occlusion / timestamp / pipeline-statistics queries | ✅ on one GPU |
| **M0** | `D3D12XboxCreateDevice`, frame events + `PresentX`, a stable clear colour for 60 frames | ⬜ no swapchain yet |
| **M1** | root signature → `s0..s31`, one translated VS+PS, PSO, vertex buffer, draw | ⬜ no root signatures, pipelines or draws yet |
| **M2** | descriptor heap → bindless sampling, matching a known texture with error 0 | ⬜ |
| **M3** | depth / MRT / render passes / frames in flight; the game's first frame | ⬜ needs the executable |
| **M4** | compute PSOs, UAVs, indirect dispatch, copy queues, streaming | ⬜ |
| **M5** | mesh shaders, `ExecuteIndirect`, multi-threaded command lists — a stable open-world frame | ⬜ |
| **M6** | ray tracing / XDXR (standard builds or the shipped BVH builder) | ⬜ |
| **M7** | HDR, VRS, `PresentX` planes, resize, suspend / resume, frame pacing | ⬜ |

Open questions that block these milestones are listed in
[docs/d3d12_vulkan.md §8.2](docs/d3d12_vulkan.md#82-unknown--open-questions).

## Phase 3 — Playable

| Item | State |
|---|---|
| Boot to the first rendered frame | ⬜ |
| Story mode start, input, audio, saves | ⬜ |
| Open world at a stable frame rate | ⬜ |
| PC extras: uncapped frame rate, ultrawide, remappable controls, mod-friendly asset overrides | ⬜ |

## ReCity quality track

Work that makes the project easier to build, test and contribute to. This is where ReCity's own changes start.

| Item | State |
|---|---|
| One identity everywhere: name, logo, `RECITY_*` variables, output folder `Documents\ReCity` | ✅ 2026-11-22 |
| `gta6rt` rejects two mode flags at once (`--dry-run --run` used to run the game) | ✅ 2026-11-22, ctest |
| `save_keys.py` warnings name the file they are about | ✅ 2026-11-22, unit test |
| Coordination and GPU-results issues on this repository | see [#1](https://github.com/pixl27/ProjectReCity/issues/1), [#2](https://github.com/pixl27/ProjectReCity/issues/2) |
| Ninja-free Windows runtime build documented (Visual Studio generator) | ✅ 2026-11-22 |
| Wire `tools/bcpack.py` into the texture export | ⬜ |
| Release a prebuilt `gta6rt` from CI for players without Visual Studio | ⬜ |
