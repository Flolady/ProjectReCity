# VIctory on NVIDIA: the fxceless base and our changes

A patch for [fxceless/victory-gta6](https://github.com/fxceless/victory-gta6) (a fork of
[Marvisak/VIctory](https://github.com/Marvisak/VIctory) tuned on an RTX 4070) at commit `ca8829f`, with the shader
and memory fixes we carried from other forks. It is how the Xbox Series build runs best on an NVIDIA card here
today. Nothing of the game is in this folder: the patch is Rust source, and the launcher reads your own copy.

| File | What it is |
|---|---|
| [`victory-nvidia.patch`](victory-nvidia.patch) | `git diff ca8829f` of our branch: 15 files of `crates/victory-gpu`, `victory-loader` and `victory-shader` |
| [`Launch.ps1`](Launch.ps1) | Starts the game with the settings measured below; paths are parameters |

The patch is GPL-3.0-or-later like VIctory and keeps every file's notices. It builds a separate program: nothing
here is linked into ReCity's `gta6rt`.

## Build

```powershell
git clone https://github.com/fxceless/victory-gta6.git victory-nv
cd victory-nv
git checkout ca8829f
git apply ..\ProjectReCity\ports\victory-nvidia\victory-nvidia.patch
# put your own crates/victory-formats/src/bcpack-tables.bin in place (never commit it)
cargo build --profile diag -p victory --features diagnostics
```

`--features diagnostics` adds the render-target dumps and crash-report peeks; a plain `cargo build --release -p
victory` builds the same fixes without them.

## What the patch changes

From [Zettrox/ztrx](https://github.com/Zettrox/ztrx) and our own work (NVIDIA, 32-lane waves):

- **Wave64 programs on 32-lane hosts.** The host's wave width is read from `D3D12_FEATURE_D3D12_OPTIONS1` and the
  translator lowers console wave64 code to it (lane exchanges across the two halves, the first-half rule of
  `v_fma_mix*` and interpolation). `VICTORY_WAVE_WIDE_ONLY=<hash>,...` gives a chosen program the "wave-wide" form
  (branches taken by the whole wave with group barriers); a guard refuses that form for a branch inside a loop.
  The shader cache key includes the host width and these switches.
- **Physical page aliases.** The title maps the same pages at two addresses; writes seen at one now invalidate the
  host copies made from the other.
- **Diagnostics** (feature `diagnostics` only): per-frame draw traces and render-target dumps
  (`VICTORY_CAPTURE_FRAMES`, `VICTORY_DUMP_TARGETS`), slow-frame breakdowns, and what the registers point at in a
  crash report.

From [DexNom/VIctory](https://github.com/DexNom/VIctory) `921d8d3` ("Repair pixel quad sampling") and upstream
`4015a18`:

- **Cube-map LOD.** DXIL `Log` (op 23) already returns log2; the result was multiplied by 1/ln 2 again, so cube maps
  were sampled 1.44 times too coarse. The `_cl` minimum LOD is applied too.
- **Quad reads in pixel shaders.** A DPP8 or swizzle that stays inside its quad becomes a quad read
  (`QuadReadLaneAt` / `QuadOp`), so helper lanes give the derivatives' neighbours their values. Broadcasts and the
  three swaps take the direct operations.

## Measured (RTX 3060 Ti, driver 616.92, Windows 11, 16 GB)

Runs from a cold or warm shader cache to the open world of the first mission, 7 to 9 minutes each, with the
settings in `Launch.ps1`:

| | ztrx (before) | this patch |
|---|---|---|
| Frame rate in the world | 0.7-2 fps | **~5 fps steady** (188-210 ms per frame, ~4,900 draws) |
| Device lost / crash | none in 8 min | none in three runs of 7, 8 and 9 min, nor in a fourth run with dumps |

Most of the frame-rate gain comes from the fxceless base and its five scheduling switches (`VICTORY_ASYNC_SUBMIT`,
`VICTORY_QUEUE2`, `VICTORY_INDIRECT_WINDOW`, `VICTORY_TEXTURE_NO_WAIT`, `VICTORY_INDIRECT_GATHER`; see its README),
not from the shader fixes.

Translation of the whole shader pack (`victory translate --list --validate --pipelines`, 32-lane host):

| Programs | ztrx | this patch |
|---|---|---|
| Vertex / pixel: emitted / validated by `dxil.dll` | 14,164 / 14,053 | 14,199 / 14,088 |
| Compute: pipelines created / emitted | 2,646 / 2,672 | 2,674 / 2,674 |
| Mesh: emitted / validated | 8,762 / 8,657 | 8,762 / 8,657 |

Seen on screen: hair drawn in strands instead of blocks (quad reads), characters in colour, sky and haze right.

## Still wrong

- **Horizontal stripes on lit clothing.** Render-target dumps put them in the normals target of the G-buffer
  (albedo and depth are clean), written by the deferred character material shaders, which use only
  implicit-derivative sampling. Cause not found; a wrong vertical derivative is the leading hypothesis, unproven.
- **Grainy courtyard** in some runs, not tied to a cause.
- **`VICTORY_WAVE_WIDE_ONLY`**: the two compute programs it names (a reflection tiling pass and a particle
  visibility pass) now run instead of being refused, but a visual effect is not shown: the scene differs from run to
  run at the same second. `VICTORY_WAVE_WIDE=1` for every program degrades the picture; do not use it.
- Ray-traced effects stay off (the acceleration-structure builder writes past the windows it names).

## Credits

VIctory by Marvisak and contributors; the NVIDIA fork by fxceless; ztrx by Zettrox; the quad and cube fixes by
DexNom. AI-assisted (Claude), tested on the machine above.
