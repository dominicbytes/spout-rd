param(
    [string]$Version = "0.2.0-alpha.1"
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
$addonRoot = Join-Path $buildRoot "addons\spout-gd"
# Drop gitignored leftovers such as ~*.dll renamed aside while Redot held the DLL locked.
Get-ChildItem -LiteralPath $addonRoot -Recurse -File -Filter "~*" | Remove-Item -Force
foreach ($name in @("LICENSE", "THIRD_PARTY.md", "README.md")) {
    $destination = Join-Path $addonRoot $name
    if (-not (Test-Path -LiteralPath $destination)) {
        Copy-Item -LiteralPath (Join-Path $root $name) -Destination $destination
    }
}

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($archivePath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $addonRoot -Recurse -File) {
        $entryName = $file.FullName.Substring($buildRoot.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive, $file.FullName, $entryName, [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
}
finally {
    $archive.Dispose()
}
$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath
"$($hash.Hash.ToLowerInvariant())  $([System.IO.Path]::GetFileName($archivePath))" | Set-Content -LiteralPath $checksumPath -Encoding ASCII

[pscustomobject]@{
    version = $Version
    archive = $archivePath
    sha256 = $hash.Hash.ToLowerInvariant()
    checksum_file = $checksumPath
} | ConvertTo-Json
