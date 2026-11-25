# Changelog

What Project ReCity has changed, newest first. The state of every subsystem is in [ROADMAP.md](ROADMAP.md).

## 2026-11-25 — VIctory on NVIDIA: ~5 fps in the open world

- New [ports/victory-nvidia/](ports/victory-nvidia/README.md): a patch for fxceless's NVIDIA fork of VIctory
  (`ca8829f`) with wave64 lowering for 32-lane hosts and physical-page alias tracking (from ztrx), DexNom's cube-map
  LOD and pixel quad-read fixes, and diagnostics, plus a launcher with the measured settings.
- On an RTX 3060 Ti (driver 616.92): the open world of the first mission at ~5 fps steady (0.7-2 with ztrx), no
  device loss in 7-9 minute runs; whole-pack translation +35 vertex/pixel programs and every compute pipeline
  created. Still wrong: stripes in the G-buffer normals of lit clothing.

## 2026-11-22 — New README and build guide

- The README is rewritten from scratch: a short pitch, a pipeline diagram, a progress table, a three-line quick
  start, a map of the repository, a FAQ and how to join in. CI badges show the state of `main`.
- The detailed build instructions moved to a new guide, [docs/BUILDING.md](docs/BUILDING.md): the five stages, every
  option, wave64, getting an `llvm-mc` with AMDGPU, the runtime build with or without Ninja, Linux and Wine, and
  troubleshooting.

## 2026-11-22 — Project ReCity

### Identity

- New name, Project ReCity, and a new logo (`assets/logo.svg`).
- Environment variables are now `RECITY_*` (for example `RECITY_GAME_DIR`, `RECITY_W64_EMULATE`,
  `RECITY_VK_VALIDATION`), the C++ namespace is `recity::`, and CMake options are `RECITY_SDL3`,
  `RECITY_SDL3_FETCH` and `RECITY_D3D12_SHIM_TESTS`.
- The build output defaults to `Documents\ReCity`; the saves and `llvm-mc` helper folders moved to
  `%LOCALAPPDATA%\ReCity`.
- README, contributing guide, agent guide and issue templates point to this repository, with a roadmap
  ([ROADMAP.md](ROADMAP.md)) and this changelog.

### Fixes

- `gta6rt` accepted several mode flags together: `--dry-run --run <exe>` initialised the modules and called the
  entry point, the opposite of a dry run. It now requires exactly one of `--dry-run`, `--init` and `--run` and
  prints the usage otherwise. New ctests: `gta6rt_rejects_two_modes`, `gta6rt_rejects_init_and_run`.
- `tools/save_keys.py`: the warnings for a truncated or lying JSAV header did not say which file they were about,
  so a batch over a saves folder could not tell the broken save apart. Each warning now starts with the file path.
  New tests in `tests/test_save_keys.py`.

### Documentation

- The Windows runtime build works without Ninja, using the Visual Studio generator (see [AGENTS.md](AGENTS.md)).
