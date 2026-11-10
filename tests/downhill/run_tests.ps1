param([string]$Godot = $env:GODOT, [string]$OutputDirectory = '')
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if (-not $Godot) {
    $candidates = @(
        (Join-Path $projectPath '.local/Godot-4.7/Godot_v4.7-stable_win64_console.exe'),
        (Join-Path $projectPath '../SheepGame/.local/Godot-4.7/Godot_v4.7-stable_win64_console.exe')
    )
    $Godot = $candidates | Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1
    if (-not $Godot) {
        $command = Get-Command godot -ErrorAction SilentlyContinue
        if ($command) { $Godot = $command.Source }
    }
    if (-not $Godot) { throw 'Pass -Godot <Godot 4.7 executable> or set GODOT.' }
}
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'hermes/cache/scratch/downhill-tests'
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$env:DOWNHILL_OUTPUT_DIR = $OutputDirectory
$testNames = @('movement', 'lifecycle', 'edge', 'course', 'timing', 'regression', 'guidance', 'effects', 'airborne', 'camera', 'scenery', 'presentation', 'polish', 'contact', 'interface', 'release', 'farewell', 'classic_pen', 'menu_quit')
foreach ($testName in $testNames) {
    $testLog = Join-Path $OutputDirectory "downhill-$testName-engine.log"
    # These suites assert actual captured input or GPU-uploaded transforms.
    $displayArgs = @('--headless')
    if ($testName -in @('camera', 'interface', 'release', 'farewell')) { $displayArgs = @() }
    $output = & $Godot @displayArgs --rendering-method gl_compatibility --audio-driver Dummy --log-file $testLog --add-dir $OutputDirectory --path $projectPath --script "res://tests/downhill/${testName}_test.gd" 2>&1
    $exitCode = $LASTEXITCODE
    $output | Tee-Object -FilePath (Join-Path $OutputDirectory "downhill-$testName.log")
    if ($exitCode -ne 0 -or (($output | Out-String) -match '(?m)^(ERROR:|SCRIPT ERROR:|FAIL:)')) {
        throw "$testName failed (exit $exitCode); inspect $testLog"
    }
}
Write-Output "DOWNHILL: all $($testNames.Count) suites passed"
