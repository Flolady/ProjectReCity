<h1 align="center">
  <img src="assets/logo.svg" alt="Project ReCity" width="180">
  <br>
  Project ReCity
</h1>

<h4 align="center">Grand Theft Auto VI (Xbox Series) recompiled to run natively on Windows, built on your PC from your own copy.</h4>

<p align="center">
  <a href="#project-status">Status</a> ·
  <a href="ROADMAP.md">Roadmap</a> ·
  <a href="CHANGELOG.md">What's new</a> ·
  <a href="#how-to-build">How to build</a> ·
  <a href="#how-it-works">How it works</a> ·
  <a href="#want-to-help">Want to help?</a> ·
  <a href="#license-and-credits">License</a>
</p>

Project ReCity is a static recompilation project. The Xbox Series CPU is x86-64 like a PC, so the game's code is
loaded and run natively, and the console's system software is reimplemented. The console's precompiled RDNA2 GPU
programs are translated to SPIR-V for Vulkan. The game's models, textures and audio are read from your package. All
of this happens **on your PC, from your own copy of the game**.

> [!IMPORTANT]
> This repository **does not contain the game, keys or an executable**, and it does not explain how to get them. You
> need your own copy, with its files already readable on disk. Nothing here decrypts or works around any protection.
> Everything the build creates (the generated shaders, extracted assets, the runtime folder and your saves) comes
> from your game and stays on your PC. Never share those files.

## Project status

**Early. The game does not boot yet.** Everything that can be done without the game's executable is in place, so
work on booting can start as soon as one is available to a developer. The plan to get there is in
[ROADMAP.md](ROADMAP.md); what changed recently is in [CHANGELOG.md](CHANGELOG.md).

| What | Status |
|---|---|
| Finding and checking your copy (Xbox Series 1.0.2.1) | ✅ Works |
| Shaders: carve, unpack native RDNA2 code, disassemble | ✅ All 26,503 |
| Shaders: RDNA2 → SPIR-V translation | ✅ **All 26,503** with LLVM 21 (LLVM 23 still rejects 1,471): 2,236 VS, 12,101 PS, 2,689 CS, 9,282 mesh, 195 geometry. All pass `spirv-val`, with a per-shader metadata index for pipeline creation. ⚠️ 21,545 are wave64: exact on 64-wide subgroups (AMD). On 32-wide subgroups (NVIDIA, Intel), compute and mesh shaders are exact with wave64 emulation (`--wave64-emulate`, on by default there); cross-half wave ops in vertex, pixel and geometry shaders are still approximate |
| Shader translator checked on a real GPU | ⚠️ The hand-written GPU tests (vertex fetch, texture sampling, exports, ALU ops, partial-register ops, barycentrics, wave-uniform branches, compute LDS/barriers/buffer stores, wave64 masks) have been run on more than 30 GPU and driver combinations: NVIDIA Turing, Ampere, Ada and Blackwell (Windows and Linux); AMD GCN3, RDNA1, RDNA2, RDNA3 and RDNA4 (Windows driver and RADV); Intel Gen9 (ANV); Apple M1 (MoltenVK, no geometry or mesh stages); and Mesa llvmpipe. Wave64 tests need 64-wide subgroups (AMD) or `RECITY_W64_EMULATE=1`. These are small test shaders: the game's own shaders are checked by `spirv-val` and by driver pipeline creation (`vk_pipeline_check`), not by their output. New results go in [the GPU results issue](https://github.com/pixl27/ProjectReCity/issues/2) |
| Models (OBJ with real names, UVs, material references) | ✅ Exported. Not all layouts are decoded yet |
| Texture dictionaries and world texture pools (DDS) | ✅ Exported. Pool entries stored as BCPack are still skipped by the export; a clean-room decoder (`tools/bcpack.py`) rebuilds BC1, BC3, BC4 and BC5, and is not wired into `rpf9dump` yet ([notes](docs/textures.md)) |
| Audio banks (AWC: Opus, XMA2) | ✅ Exported whole. Opus repackaged **losslessly** as Ogg Opus; PCM (codec 0/2) as WAV; XMA2 decoded with ffmpeg. `--wav` adds 16-bit PCM WAV ([notes](docs/audio.md)) |
| Music/radio config | 🔎 Measured. **1,589** audio-config records with exact durations and AWC stream ids; station grouping and content-id lists; no per-track start offsets ([notes](docs/audio_config.md)) |
| PE loader and import shims | ⚠️ Runs a stand-in executable end to end (`gta6rt --run`: CRT startup, statics, heap, files, threads, GDK imports through the shims, exit code back). Untested against the real executable |
| Xbox D3D12 → Vulkan | ⚠️ In progress. A Vulkan-backed device behind the Xbox-ABI proxy creates queues, command lists, fences, descriptor heaps, committed and reserved resources, render-target and depth views, texture views and samplers (which go into the bindless set), and query heaps. Barriers, clears, uploads, copies (BC included), colour resolves and occlusion, timestamp and pipeline-statistics queries run on Vulkan, checked on one GPU. No buffer views, root signatures, pipelines, draws or swapchain yet ([plan](docs/d3d12_vulkan.md)) |
| Booting, story mode, anything playable | ❌ No |

## How to build

The port isn't downloaded ready-made. It's built on your PC from your own copy.

**The easy way:**

1. Install the prerequisites below.
2. Download this project **with its submodule**: `git clone --recursive https://github.com/pixl27/ProjectReCity`.
   A "Download ZIP" from GitHub leaves out `third_party/rpf9-explorer`. The build fetches it if `git` is installed,
   and otherwise tells you what to do.
3. Double-click **`Build.bat`**.

It finds your copy of the game by itself: it looks in Downloads, Desktop, Documents, Games, your home folder and
the top of every drive, two folders deep. It recognises the version from a few file sizes, without reading
anything large. If you have more than one copy it asks which one, and if it finds none it asks you to paste the
folder. Before starting it checks that everything below is installed and that there is enough free space, and it
lists anything missing in one go. The result goes to `Documents\ReCity`. A stopped build continues where it left
off.

Your game folder is the one that holds `MicrosoftGame.Config` and the `.rpf` archives, as plain files.

**Prerequisites:**

- **Your own copy** of the Xbox Series package, version 1.0.2.1.
- **Windows 10/11 x64**, with about **350 GB** free for work files. They can go on another drive with `--work`.
- [Python 3.12+](https://www.python.org/downloads/) (tick "Add python.exe to PATH").
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0).
- [Vulkan SDK](https://vulkan.lunarg.com/), for `spirv-as` / `spirv-val`.
- [LLVM 21+](https://github.com/llvm/llvm-project/releases) with the **AMDGPU target** for `llvm-mc`. The official
  Windows build has no AMDGPU target. On Windows, `scripts\build_llvm_mc.ps1` builds a native `llvm-mc.exe` with it
  (no WSL; needs git and the Visual Studio C++ tools below) and sets `LLVM_MC`. Or install `llvm-21` in WSL and set
  `LLVM_MC` to the whole command, `LLVM_MC="wsl -d Ubuntu -e /usr/lib/llvm-21/bin/llvm-mc"` (see
  [docs/design.md](docs/design.md#disassembling-shaders)). On Linux, `llvm-mc` on PATH is enough.
- Visual Studio 2022 with **Desktop development with C++** and the **Windows SDK 10.0.26100 or newer**, for the
  runtime stage (the runtime uses version 1.2 root signatures, which older SDKs don't declare).
- [ffmpeg](https://ffmpeg.org/download.html) on PATH (optional: decodes the XMA2 streams, and required for `--wav`).

**From a terminal**, with the same behaviour and more control:

```powershell
python -I make_game.py --find                          # list the copies found on this PC
python -I make_game.py --check                         # check your copy, build nothing
python -I make_game.py --game "D:\path\to\your\package" --out "D:\Games\ReCity" --work "E:\recity-work"
python -I make_game.py --stages shaders,assets         # only some stages
python -I make_game.py --game "D:\path\to\your\package" --wav   # also decode Opus to PCM WAV (large)
python -I make_game.py --wave64-emulate off            # auto (default), on or off; see below
```

`--wave64-emulate` decides whether wave64 compute and mesh shaders are translated to be exact on any subgroup size
(see "Wave64 emulation" in [docs/design.md](docs/design.md)). NVIDIA and Intel GPUs have 32-wide subgroups and need
it. The default, `auto`, asks `vulkaninfo` (part of the Vulkan SDK) and turns it on unless every GPU reports 64-wide
subgroups, or when it can't tell; it also turns it on when the GPU the runtime would use can't be made to run
compute and mesh shaders 64-wide. The mode is saved next to the translated shaders, and changing it translates them
again. With `auto`, a work folder that previously used emulation keeps it for later translations and retries, even if
the current GPU supports native wave64. Use `--wave64-emulate off` to translate it natively.

The build records which translator sources produced the shaders. A change to those files reruns translation using the
saved disassembly. Older work folders need one translation after upgrading to record this information.

Stages run in order: `check`, `shaders`, `assets`, `runtime`, `pipelines` (creates every translated shader on your
GPU driver and saves a pipeline cache, so the first boot doesn't compile them). The shader translation is the longest
step: it runs on `--jobs` processes (half the CPU threads by default).

`--wav` is off by default because 16-bit PCM WAV is several times larger than Ogg Opus. It decodes the repackaged Ogg
Opus streams to `work\assets\audio\wav` after the audio bank step; existing WAV files are skipped when a build resumes.

### Vulkan diagnostics on Linux

With CMake 3.24+, a C++20 compiler, and Vulkan development headers and loader installed:

```sh
cmake -S runtime -B runtime/build/linux
cmake --build runtime/build/linux --parallel
./runtime/build/linux/vk_pipeline_check /path/to/spirv
```

Pass the directory containing `index.json` and the translated SPIR-V files to `vk_pipeline_check`.

`make_game.py` runs on Linux too. The `pipelines` stage uses the `vk_pipeline_check` built above
(`runtime/build/linux`, or `runtime/build`). The `runtime` stage builds on Windows only, so on Linux it needs a
Windows build of `runtime/`; without one it is left out of the default stages, and asking for it fails before any
work starts.

### Running the loader on Linux

The loader is a Windows program and runs under Wine or Proton; CI runs its tests under Wine on every change to
`runtime/` (the `wine` job of the Runtime workflow). Give the `runtime` stage a folder with `gta6rt.exe` and
`gta6rt_tls_host.dll`, such as the `runtime-windows` artifact of that workflow's `windows` job, unzipped:

```sh
python3 -I make_game.py --runtime-build ~/Downloads/runtime-windows
```

It copies both files into `--out` and writes `gta6rt.sh` next to them, which starts `gta6rt.exe` with `wine`, or
with the Wine named by `WINE` (for Proton, its `files/bin/wine`). The same option skips the build on Windows.

## How it works

| Piece | What it does | Where |
|---|---|---|
| Version check | Every package file's name, size and SHA-256 for each supported version | `game/`, `make_game.py` |
| Shader pipeline | Carves DXBC containers from `shaders.rpf` without its encrypted table of contents. Unpacks the `XBCH` → `FSSM` native RDNA2 program, disassembles it with LLVM (`gfx1013`) and translates it to SPIR-V | `tools/shader_carve.py`, `fssm_unpack.py`, `shader_disasm.py`, `rdna2spirv.py` |
| Asset export | Finds validated resources inside RPF9 archives and the loose `.ttpf` texture pools | `tools/rpf9dump` (on rpf9-explorer's Core) |
| Runtime | Maps the PE image, resolves imports to shims (GDK, XMem, `d3d12_xs`) | `runtime/` |
| Research tools | PE/RTTI inspection, raw carving, texture tiling probes, GPU test harnesses | `tools/`, `runtime/test/` |

The translator's runtime contract (user SGPRs, push constants, memory model, bindless images, vertex fetch,
system values) and all the format notes are in [docs/design.md](docs/design.md); the format, asset, runtime
and validation notes are indexed in [docs/README.md](docs/README.md). The Xbox D3D12 plan is in
[docs/d3d12_vulkan.md](docs/d3d12_vulkan.md). Audio bank formats and the export tools are in
[docs/audio.md](docs/audio.md); [docs/related_projects.md](docs/related_projects.md) records the prior art we may
read and the licence limits on it.

## Want to help?

The biggest open pieces (full list in [ROADMAP.md](ROADMAP.md)):

- **Shader translator on hardware**: the vertex-shader input layout (`v0` = `VertexIndex` is unverified if the
  console runs VS as NGG) and wave64 cross-half code in VS/PS/GS on 32-wide subgroups.
- **Xbox D3D12 → Vulkan**: root signatures, pipelines, draws and the swapchain.
- **Model layouts** the decoder rejects today.

Claim work in [the coordination issue](https://github.com/pixl27/ProjectReCity/issues/1) and read
[CONTRIBUTING.md](CONTRIBUTING.md) first. Never attach game files, extracted assets or generated shaders to issues
or pull requests.

---

## License and credits

Project ReCity is free software under the **GNU General Public License v3.0 or later**; see [LICENSE](LICENSE).
Third-party code keeps its own license.

- Project ReCity is derived from Leonida by ItsNotRexed and contributors (GPL-3.0-or-later), and has been modified
  since 2026-11-22; [CHANGELOG.md](CHANGELOG.md) lists the changes. The full authorship is in the git history.
- [rpf9-explorer](https://github.com/breadbbbb/rpf9-explorer) by breadbbbb: the RPF9 model, texture-pool and AWC
  decoders used by `tools/rpf9dump` (git submodule).
- [Mesa](https://gitlab.freedesktop.org/mesa/mesa) (MIT): GFX10 resource-descriptor layout
  (`tools/gfx10_formats.json`), and the ACO/RADV rules used as reference for 16-bit results and shader system
  registers.
- [libHttpClient](https://github.com/microsoft/libHttpClient) (MIT) by Microsoft: the XTaskQueue/XAsync
  implementation in `third_party/xtaskqueue`, used by the offline `xgameruntime` shim.
- [LLVM](https://llvm.org/): AMDGPU disassembler. [SPIRV-Tools](https://github.com/KhronosGroup/SPIRV-Tools):
  assembly and validation.

Grand Theft Auto and all related names are trademarks of their owners. This project is not affiliated with or
endorsed by them.
