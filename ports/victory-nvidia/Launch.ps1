# Starts the Xbox Series build under VIctory built with victory-nvidia.patch (see README.md), offline, Series X
# profile. Paths are parameters: nothing here points at a particular machine.
#   .\Launch.ps1 -Game 'D:\GTA VI' -Exe 'D:\victory-nv\target\diag\victory.exe' -Work 'D:\victory-work'
param(
  [Parameter(Mandatory = $true)][string]$Game,
  [Parameter(Mandatory = $true)][string]$Exe,
  [Parameter(Mandatory = $true)][string]$Work
)
$ErrorActionPreference = 'Stop'
foreach ($d in 'cache', 'data') { New-Item -ItemType Directory -Force (Join-Path $Work $d) | Out-Null }
# Diagnostics stay off unless set on purpose.
foreach ($v in 'VICTORY_CAPTURE', 'VICTORY_CAPTURE_FRAMES', 'VICTORY_DUMP_TARGETS', 'VICTORY_WAVE_WIDE') {
  Remove-Item "Env:$v" -ErrorAction SilentlyContinue
}
# Two wave64 compute programs the driver refuses as 64-lane waves (particle visibility, reflection tiling) run in
# the wave-wide form with '2cc4c197,369cbe90' here, at ~45 ms more GPU time a frame and with larger stripes on lit
# clothing (run z68): left empty. Never VICTORY_WAVE_WIDE=1 (every program): it degrades the picture.
$env:VICTORY_WAVE_WIDE_ONLY = ''
# fxceless's scheduling switches (its README): submission on its own thread, a second copy queue, indirect-draw
# windows, textures without waiting, gathered indirect records.
$env:VICTORY_ASYNC_SUBMIT = '1'
$env:VICTORY_QUEUE2 = '1'
$env:VICTORY_INDIRECT_WINDOW = '1'
$env:VICTORY_TEXTURE_NO_WAIT = '1'
$env:VICTORY_INDIRECT_GATHER = '1'
# Measured by fxceless (its README) and checked here (runs z57, z58: 35.4 ms per 1,000 draws against 39.5 without
# the four): parts of a submission joined, shader writes put back through a view of our own, card hash passes
# joined, and a submission's refreshes spread over several threads.
$env:VICTORY_JOIN_PARTS = '1'
$env:VICTORY_BACK_OWN_VIEW = '1'
$env:VICTORY_CARD_REHASH_RUNS = '1'
$env:VICTORY_WIDE_REFRESH = '1'
$env:VICTORY_GAME_DIR = $Game
$env:VICTORY_CACHE_DIR = Join-Path $Work 'cache'
$env:VICTORY_DATA_DIR = Join-Path $Work 'data'
& $Exe run (Join-Path $Game 'game_scarlett_master.exe') --execute --console series-x `
  2> (Join-Path $Work 'victory.log.err') > (Join-Path $Work 'victory.log')
"Exit code $LASTEXITCODE. Log: $(Join-Path $Work 'victory.log.err')"
