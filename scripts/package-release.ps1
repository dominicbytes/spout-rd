param(
    [string]$Version = "0.1.0-alpha.1"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$buildRoot = Join-Path $root ".build\release"
$distRoot = Join-Path $root "dist"
$archivePath = Join-Path $distRoot "redot-spout-gd-$Version-windows-x86_64.zip"
$checksumPath = Join-Path $distRoot "SHA256SUMS.txt"

if (-not $buildRoot.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Release staging path escaped the repository root: $buildRoot"
}

if (Test-Path -LiteralPath $buildRoot) {
    Remove-Item -LiteralPath $buildRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path (Join-Path $buildRoot "addons") | Out-Null
New-Item -ItemType Directory -Force -Path $distRoot | Out-Null

Copy-Item -LiteralPath (Join-Path $root "addons\spout-gd") -Destination (Join-Path $buildRoot "addons") -Recurse
Copy-Item -LiteralPath (Join-Path $root "docs") -Destination $buildRoot -Recurse
Copy-Item -LiteralPath (Join-Path $root "patches") -Destination $buildRoot -Recurse
Copy-Item -LiteralPath (Join-Path $root "README.md") -Destination $buildRoot
Copy-Item -LiteralPath (Join-Path $root "LICENSE") -Destination $buildRoot
Copy-Item -LiteralPath (Join-Path $root "THIRD_PARTY.md") -Destination $buildRoot
Copy-Item -LiteralPath (Join-Path $root "CHANGELOG.md") -Destination $buildRoot

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}

Compress-Archive -Path (Join-Path $buildRoot "*") -DestinationPath $archivePath -CompressionLevel Optimal
$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath
"$($hash.Hash.ToLowerInvariant())  $([System.IO.Path]::GetFileName($archivePath))" | Set-Content -LiteralPath $checksumPath -Encoding ASCII

[pscustomobject]@{
    version = $Version
    archive = $archivePath
    sha256 = $hash.Hash.ToLowerInvariant()
    checksum_file = $checksumPath
} | ConvertTo-Json
