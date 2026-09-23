param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfg = Join-Path $HOME '.config/agy-nvidia'
$yaml = Join-Path $cfg 'litellm.yaml'
$envFile = Join-Path $cfg '.env'
function Usage {
  Write-Host 'Usage: switch-model.bat [list|key nvapi-...|3.7 MODEL|3.8 MODEL|3.6 MODEL|pro MODEL]'
}
function Normalize([string]$id) {
  if ([string]::IsNullOrWhiteSpace($id) -or $id -notmatch '^[A-Za-z0-9._/-]+$') { throw "Invalid model ID: $id" }
  $id -replace '^openai/', ''
}
function Restart-Router {
  & systemctl --user restart agy-nvidia-proxy.service 2>$null
  for ($i=0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 1
    try { Invoke-WebRequest 'http://127.0.0.1:4000/health/liveliness' -UseBasicParsing -TimeoutSec 2 | Out-Null; Write-Host 'proxy: UP'; return } catch {}
  }
  throw 'Proxy did not become ready on port 4000.'
}
function List-Models {
  $text = Get-Content $yaml -Raw
  $anchors = @{}
  [regex]::Matches($text, '&(\w+)\s*\r?\n\s*model:\s*openai/(\S+)') | ForEach-Object { $anchors[$_.Groups[1].Value]=$_.Groups[2].Value }
  [regex]::Matches($text, 'model_name:\s*(\S+)\s*\r?\n\s*litellm_params:\s*(?:&(\w+)|\*(\w+))') | ForEach-Object {
    $key = if ($_.Groups[2].Value) {$_.Groups[2].Value} else {$_.Groups[3].Value}
    '{0,-35} -> {1}' -f $_.Groups[1].Value, $anchors[$key]
  }
  if (Test-Path $envFile) { 'KEY: set' } else { 'KEY: not set' }
  try { Invoke-WebRequest 'http://127.0.0.1:4000/health/liveliness' -UseBasicParsing -TimeoutSec 2 | Out-Null; 'proxy: UP (router :4000 -> LiteLLM :4001)' } catch { 'proxy: DOWN' }
}
function Set-Group([string]$group, [string]$id) {
  $id = Normalize $id
  $anchor = switch ($group) { '3.7' {'super'} '3.8' {'ultra'} '3.6' {'free'} 'pro' {'pro'} default { throw "Unknown group: $group" } }
  $text = Get-Content $yaml -Raw
  $pattern = "(&$anchor\s*\r?\n\s*model:\s*)openai/\S+"
  $next = [regex]::Replace($text, $pattern, "`$1openai/$id", 1)
  if ($next -eq $text) { throw "Could not find YAML anchor &$anchor" }
  [IO.File]::WriteAllText($yaml, $next)
  Copy-Item $yaml (Join-Path $repo 'litellm.yaml') -Force
  Write-Host "$group -> $id"
  Restart-Router
}

try {
  if (-not $Args -or $Args.Count -eq 0) {
    Copy-Item (Join-Path $repo 'litellm.yaml') $yaml -Force
    Restart-Router; Write-Host 'preset applied'; List-Models
  } elseif ($Args[0] -ieq 'list') { List-Models
  } elseif ($Args[0] -ieq 'key') {
    if (-not $Args[1] -or $Args[1] -notmatch '^nvapi-') { throw 'key must start with nvapi-' }
    New-Item -ItemType Directory -Force $cfg | Out-Null
    [IO.File]::WriteAllText($envFile, "NVIDIA_API_KEY=$($Args[1])`n")
    Write-Host "key updated in $envFile"; Restart-Router
  } elseif ($Args[0] -in @('3.7','3.8','3.6','pro')) { Set-Group $Args[0] $Args[1]
  } else { Usage; exit 1 }
} catch { Write-Error $_; exit 1 }
