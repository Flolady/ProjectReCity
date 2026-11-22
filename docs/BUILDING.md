# Building Project ReCity in depth

The [README](../README.md#-quick-start) gets you from zero to a build with `Build.bat`. This page is for when you want
more control, a different OS, or need to know what each stage does.

## Your game folder

Point ReCity at the folder that contains `MicrosoftGame.Config` next to the `.rpf` archives, all as ordinary files.
Only version **1.0.2.1** of the Xbox Series package is recognised today; `game/xbox-1.0.2.1.json` lists every file
with its size and SHA-256. Detection only looks at a few file sizes, so it is instant even on a slow drive.

## The stages

`make_game.py` runs five stages, in this order. Each one can be resumed and each one can be run on its own.

| Stage | Does | Typical cost |
|---|---|---|
| `check` | finds and verifies your copy, checks tools and free space | seconds |
| `shaders` | carves, unpacks, disassembles and translates all 26,503 GPU programs to SPIR-V | the long one; uses `--jobs` processes |
| `assets` | exports models, textures and audio banks | long, disk-heavy |
| `runtime` | compiles `gta6rt.exe` and its TLS host DLL (Windows) | minutes |
| `pipelines` | creates every translated shader on your GPU driver and saves a pipeline cache | minutes; saves stutter at first boot |

## Command line

```powershell
python -I make_game.py --find                                  # which copies are on this PC?
python -I make_game.py --check                                 # verify only, build nothing
python -I make_game.py --game "D:\GTA6-XBS" --out "D:\Games\ReCity" --work "E:\recity-work"
python -I make_game.py --stages shaders,assets                 # pick stages
python -I make_game.py --jobs 8                                # parallel shader translation
python -I make_game.py --wav                                   # also write 16-bit WAV (large)
python -I make_game.py --wave64-emulate auto|on|off            # see below
```

- `--work` holds the ~350 GB of intermediate files; put it on your biggest drive.
- `--out` is the finished port (default `Documents\ReCity`).
- `--wav` is off by default: PCM WAV is several times the size of the lossless Ogg Opus already produced.

## Wave64 and your GPU

Most of the game's shaders were written for 64-wide AMD waves. AMD cards run them as they are. NVIDIA and Intel
cards run 32-wide subgroups, so ReCity can translate compute and mesh shaders with an exact wave64 emulation.

- `auto` (default) asks `vulkaninfo` and turns emulation on unless every GPU can run 64-wide, or when it can't tell.
  A work folder that once used emulation keeps it.
- `on` / `off` force it. Changing the mode re-translates the shaders; the mode is stored next to them.
- Cross-half wave operations in vertex, pixel and geometry shaders are still approximate on 32-wide GPUs.

The build also remembers which translator sources produced the shaders, so editing the translator re-runs only the
translation from the saved disassembly.

## LLVM with the AMDGPU target

The official Windows LLVM installer leaves out the AMDGPU target that the disassembler needs. Pick one:

- **Windows, native:** `scripts\build_llvm_mc.ps1` builds `llvm-mc.exe` into `%LOCALAPPDATA%\ReCity\llvm-mc` and
  sets `LLVM_MC` (needs git and the Visual Studio C++ tools).
- **Windows, through WSL:** install `llvm-21` in Ubuntu and set
  `LLVM_MC="wsl -d Ubuntu -e /usr/lib/llvm-21/bin/llvm-mc"`.
- **Linux:** `llvm-mc` on `PATH` is enough.

LLVM 21 translates every shader; LLVM 23 still rejects 1,471 of them (see [design.md](design.md#disassembling-shaders)).

## Building the runtime by hand

With Ninja:

```powershell
cmake -S runtime -B runtime/build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build runtime/build
```

Without Ninja, the Visual Studio generator does the same (from Git Bash, export `MSYS_NO_PATHCONV=1` first):

```powershell
cmake -S runtime -B runtime/build -G "Visual Studio 17 2022" -A x64
cmake --build runtime/build --config RelWithDebInfo --parallel
ctest --test-dir runtime/build -C RelWithDebInfo --output-on-failure
```

The runtime uses version 1.2 root signatures, so it needs Windows SDK **10.0.26100** or newer.

## Linux

`make_game.py` runs on Linux for every stage except compiling the runtime, which is Windows-only.

**Vulkan pipeline checks** (CMake 3.24+, a C++20 compiler, Vulkan headers and loader):

```sh
cmake -S runtime -B runtime/build/linux
cmake --build runtime/build/linux --parallel
./runtime/build/linux/vk_pipeline_check /path/to/work/shaders/spirv   # the folder with index.json
```

The `pipelines` stage finds that binary in `runtime/build/linux` or `runtime/build` by itself.

**Running the loader under Wine or Proton:** grab the `runtime-windows` artifact from the *Runtime* workflow's
`windows` job (or build it on Windows), unzip it, and pass it in:

```sh
python3 -I make_game.py --runtime-build ~/Downloads/runtime-windows
```

This copies `gta6rt.exe` and `gta6rt_tls_host.dll` into `--out` and writes a `gta6rt.sh` launcher that uses `wine`,
or whatever `WINE` points to (for Proton, its `files/bin/wine`). The same flag also skips the runtime build on
Windows. CI runs the loader's tests under Wine on every runtime change.

## Troubleshooting

| Symptom | Fix |
|---|---|
| the build says `third_party/rpf9-explorer` is missing | you downloaded a ZIP; use `git clone --recursive`, or run `git submodule update --init` |
| `llvm-mc` has no AMDGPU target | see [LLVM with the AMDGPU target](#llvm-with-the-amdgpu-target) |
| runtime stage fails on root signatures | update the Windows SDK to 10.0.26100+ |
| build stopped halfway | run the same command again; finished work is kept |
| `/flags` turned into paths in Git Bash | `export MSYS_NO_PATHCONV=1` |
