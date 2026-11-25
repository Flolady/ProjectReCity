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

## Where the frame goes, and levers tried (2026-11-25)

Same machine, warm cache, frames of 3,000 draws or more after the first ten in the world, medians.

| Run | Switches on top of `Launch.ps1` | fps | ms/frame | ms per 1,000 draws | GPU part | waits under shader writes |
|---|---|---|---|---|---|---|
| z50 | none | 5.2 | 193 | 39.5 | 67 ms | 58 ms |
| z53 | `VICTORY_INPLACE=2` | 3.1 | 320 | 64.8 | 215 ms | 114 ms |
| z54 | `VICTORY_CARD_WINDOWS_MB=1024` | stopped at 184 s by the memory guard (1.1 GB of commit left); while loading: GPU part 7-37 ms, copies 400-850 ms | | | | |
| z55 | `VICTORY_COPY_PLAIN=1 VICTORY_MERGE_GAP=64 VICTORY_MERGE_RUNS=4096` | 4.8 | 207 | 42.7 | 4 ms | 0 ms |

Run-to-run spread is large (a cold-cache run of the same build gave 53.4 ms per 1,000 draws), so z55 against z50
is no gain and no loss.

- **The critical path is the one thread that submits.** In z50 it spends 50-60 ms user and ~60 ms kernel time a
  frame inside its 28 submissions, plus ~14 ms waiting for the submission lock; the kernel time is write-watch
  queries (about 3,000 a frame over 8.6 GB, 8.5 GB of it unchanged, 32 ms) and page guards (26 ms). The title takes
  ~50 ms from a present to its first list. In z55 the waits under shader writes are gone and the title's part
  halves, but the submitting thread then works ~95 ms user + ~75 ms kernel + ~30 ms lock a frame: the work moved,
  the frame did not get shorter.
- **Title memory in place (`VICTORY_INPLACE=2`) is slower on this card**: the GPU part triples. Shadow copies of
  small buffers are already in the PC's memory (`shared_buffer`, pool L0), so why it triples is not known. A census
  (`VICTORY_INPLACE_PROBE=1`) found ~470 MB more that a committed page-pool section would cover; that level was
  written and not run.
- **Windows on the card (`VICTORY_CARD_WINDOWS_MB`)** shortens the GPU part a lot but multiplies the copies, and the
  extra card copies ran an 8 GB card and 16 GB of RAM out of commit.
- **What would move the frame**: less work per submission on that one thread (fewer or cheaper write-watch and
  guard calls, or the work spread over more threads). Not done yet.

## Still wrong

- **Horizontal stripes on lit clothing.** Render-target dumps put them in the normals target of the G-buffer
  (albedo and depth are clean), written by the deferred character material shaders, which use only
  implicit-derivative sampling. Cause not found. Ruled out: derivatives taken under divergent control flow (in
  the emitted DXIL of one of them, all 34 implicit-derivative operations sit in code every lane runs, with no
  branch at all).
- **Grainy courtyard** in some runs, not tied to a cause.
- **`VICTORY_WAVE_WIDE_ONLY`**: the two compute programs it names (a reflection tiling pass and a particle
  visibility pass) now run instead of being refused, but a visual effect is not shown: the scene differs from run to
  run at the same second. `VICTORY_WAVE_WIDE=1` for every program degrades the picture; do not use it.
- Ray-traced effects stay off (the acceleration-structure builder writes past the windows it names).

## Credits

VIctory by Marvisak and contributors; the NVIDIA fork by fxceless; ztrx by Zettrox; the quad and cube fixes by
DexNom. AI-assisted (Claude), tested on the machine above.
