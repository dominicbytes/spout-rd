param(
    [ValidateSet('d3d12', 'vulkan')][string[]]$Drivers = @('d3d12', 'vulkan'),
    [string]$WorkRoot = (Join-Path $env:TEMP 'spout-rd-tests'),
    [int]$TimeoutSeconds = 45,
    [string]$CaseFilter = '*',
    [switch]$SkipGpu
)
$ErrorActionPreference = 'Stop'
if (-not $env:REDOT_BIN -or -not (Test-Path -LiteralPath $env:REDOT_BIN)) {
    throw 'Set REDOT_BIN to the Redot console executable.'
}
$repo = Split-Path $PSScriptRoot -Parent
# Keep editor imports out of the dependency submodules.
foreach ($submodule in @('Spout2', 'godot-cpp')) {
    $ignore = Join-Path $repo "$submodule/.gdignore"
    if (-not (Test-Path -LiteralPath $ignore)) {
        New-Item -ItemType File -Path $ignore | Out-Null
    }
}
New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null
$cases = @(
    @('smoke_spout_bridge', 'smoke'), @('test_api', 'api'),
    @('test_lifecycle', 'lifecycle'), @('test_receive_bytes', 'bytes'),
    @('test_guard', 'separate_config'), @('test_guard', 'gl'),
    @('test_sender_stability', 'empty'), @('test_sender_stability', 'duplicate'), @('test_sender_stability', 'unicode'),
    @('test_sender_stability', 'long_ascii'), @('test_sender_stability', 'long_unicode'), @('test_sender_stability', 'long_project'),
    @('test_loopback', 'rgba'), @('test_loopback', 'opaque'), @('test_loopback', 'hdr'), @('test_loopback', 'hdr_opaque'),
    @('test_loopback', 'hdr_alpha'),
    @('test_receive_bounds', 'small'), @('test_receive_bounds', 'empty'), @('test_receive_bounds', 'format'),
    @('test_invert_default', 'gradient')
)
$results = @()
foreach ($driver in $Drivers) {
    foreach ($case in $cases) {
        $name = "$($case[0])-$($case[1])"
        if ($name -notlike $CaseFilter) { continue }
        $gpu = $case[0] -notin @('smoke_spout_bridge', 'test_api')
        if ($SkipGpu -and $gpu) { continue }
        $project = Join-Path $WorkRoot "$driver-$name"
        New-Item -ItemType Directory -Force -Path "$project/.godot", "$project/addons" | Out-Null
        Copy-Item -LiteralPath "$repo/addons/spout-gd" -Destination "$project/addons" -Recurse -Force
        Copy-Item -LiteralPath $PSScriptRoot -Destination $project -Recurse -Force
        @'
config_version=5
[application]
config/name="SpoutRegression"
[rendering]
renderer/rendering_method="forward_plus"
'@ | Set-Content -LiteralPath "$project/project.godot" -Encoding UTF8
        # Avoid an editor import and the unrelated 26.3 import shutdown crash.
        'res://addons/spout-gd/spout_gd.gdextension' | Set-Content -LiteralPath "$project/.godot/extension_list.cfg" -Encoding ASCII
        $stdout = Join-Path $project 'stdout.log'
        $stderr = Join-Path $project 'stderr.log'
        $arguments = @('--audio-driver', 'Dummy', '--path', ('"{0}"' -f $project), '--rendering-method', 'forward_plus', '--rendering-driver', $driver, '--quit-after', '600', '--script', "res://tests/$($case[0]).gd")
        if ($gpu) {
            $arguments += @('--display-driver', 'windows', '--resolution', '128x128', '--position', '-32000,-32000')
        } else {
            $arguments += '--headless'
        }
        if ($case[1] -eq 'separate') { $arguments += @('--render-thread', 'separate') }
        if ($case[1] -eq 'gl') { $arguments += @('--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3') }
        $arguments += @('--', $case[1])
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo.FileName = $env:REDOT_BIN
        $process.StartInfo.Arguments = $arguments -join ' '
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.EnvironmentVariables['APPDATA'] = "$project/user"
        $process.StartInfo.EnvironmentVariables['LOCALAPPDATA'] = "$project/local"
        $process.StartInfo.EnvironmentVariables['TEMP'] = $project
        $process.StartInfo.EnvironmentVariables['TMP'] = $project
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        [void]$process.Start()
        $outTask = $process.StandardOutput.ReadToEndAsync()
        $errTask = $process.StandardError.ReadToEndAsync()
        $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
        if ($timedOut) {
            # The console executable launches the engine as a child: stop that
            # specific process tree so redirected pipe reads cannot hang.
            & taskkill.exe /PID $process.Id /T /F | Out-Null
        }
        $process.WaitForExit()
        $outText = $outTask.Result
        $errText = $errTask.Result
        $outText | Set-Content -LiteralPath $stdout -Encoding UTF8
        $errText | Set-Content -LiteralPath $stderr -Encoding UTF8
        $output = $outText + $errText
        $warnings = @($output -split "`n" | Where-Object { $_ -match '^WARNING:' })
        $unexpectedWarnings = @($warnings | Where-Object { $_ -notmatch 'PSO caching is not implemented yet in the Direct3D 12 driver' })
        $guardWarning = $null
        if ($case[1] -in @('separate', 'separate_config')) { $guardWarning = 'SpoutViewport does not support a separate render thread' }
        if ($case[1] -eq 'gl') { $guardWarning = 'SpoutViewport is inactive under GL Compatibility' }
        if ($case[0] -eq 'test_sender_stability' -and $case[1] -like 'long_*') { $guardWarning = 'Spout names are limited to 240 UTF-8 bytes' }
        $guardPassed = $true
        if ($case[1] -eq 'separate') {
            $unexpectedWarnings = @($unexpectedWarnings | Where-Object { $_ -notmatch 'The separate rendering thread feature is experimental' })
        }
        if ($guardWarning) {
            $guardPassed = @($unexpectedWarnings | Where-Object { $_.Contains($guardWarning) }).Count -eq 1
            $unexpectedWarnings = @($unexpectedWarnings | Where-Object { -not $_.Contains($guardWarning) })
        }
        $passed = $guardPassed -and $unexpectedWarnings.Count -eq 0 -and -not $timedOut -and $process.ExitCode -eq 0 -and $output -notmatch 'ERROR:|SCRIPT ERROR' -and $output -match '\[(SPOUT_TEST|SPOUT_SMOKE)\] PASS'
        $results += [pscustomobject]@{ Driver = $driver; Test = $name; Pass = $passed; Exit = $process.ExitCode; Timeout = $timedOut }
        Write-Host "$driver $name : $(if ($passed) {'PASS'} else {'FAIL'}) (exit $($process.ExitCode))"
        if (-not $passed) {
            Write-Host (($output -split "`n" | Where-Object { $_ -match 'ERROR|WARNING|\[STABILITY\]|\[LOOPBACK\]|\[INVERT\]|crashed|\[SPOUT_TEST\]' }) -join "`n")
            Write-Host "Full logs: $project"
        }
    }
}
$results | Format-Table -AutoSize
$results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $WorkRoot 'results.json') -Encoding UTF8
if ($results.Count -eq 0 -or @($results | Where-Object { -not $_.Pass }).Count -gt 0) { exit 1 }
