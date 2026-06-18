$ErrorActionPreference = "Stop"

$Root = "C:\Users\18572\blender-wsl-render"
$Samples = Join-Path $Root "cuda_samples_v12_5"
$SampleDir = Join-Path $Samples "Samples\5_Domain_Specific\fluidsGL"
$OutDir = Join-Path $Root "cuda_demo_output\fluidsgl_frames"
$LogDir = Join-Path $Root "cuda_care_logs"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogPath = Join-Path $LogDir "windows-fluidsgl-animation-capture-$Stamp.txt"

function Log($Message) {
    $Message | Tee-Object -FilePath $LogPath -Append
}

$MsBuild = "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
$CudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6"
$env:CUDA_PATH = $CudaPath
$env:CUDA_PATH_V12_6 = $CudaPath
$env:PATH = "$CudaPath\bin;$Samples\bin\win64\Release;$env:PATH"

Log "Capture fluidsGL animation frames $Stamp"
Log "OutDir: $OutDir"

Get-ChildItem $OutDir -Filter "frame_*.ppm" -ErrorAction SilentlyContinue | Remove-Item -Force

$Sln = Join-Path $SampleDir "fluidsGL_vs2022.sln"
Log ""
Log "== Build fluidsGL =="
& $MsBuild $Sln /m /t:Build /p:Configuration=Release /p:Platform=x64 2>&1 |
    Tee-Object -FilePath $LogPath -Append
if ($LASTEXITCODE -ne 0) {
    throw "fluidsGL build failed"
}

$Exe = Join-Path $Samples "bin\win64\Release\fluidsGL.exe"
if (!(Test-Path $Exe)) { throw "fluidsGL.exe not found at $Exe" }

$FrameValues = @(4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60, 64, 68, 72, 76, 80, 84, 88, 92, 96, 100)
$Index = 0
foreach ($Frame in $FrameValues) {
    Log ""
    Log "== Capture simulation frame $Frame =="
    $StdoutPath = Join-Path $LogDir "fluidsgl-frame-$Frame-$Stamp.stdout.txt"
    $StderrPath = Join-Path $LogDir "fluidsgl-frame-$Frame-$Stamp.stderr.txt"
    $Ppm = Join-Path $SampleDir "fluidsGL.ppm"
    if (Test-Path $Ppm) { Remove-Item $Ppm -Force }

    $Process = Start-Process -FilePath $Exe `
        -ArgumentList @("-file=data/ref_fluidsGL.ppm", "-frames=$Frame", "-skipcompare") `
        -WorkingDirectory $SampleDir `
        -RedirectStandardOutput $StdoutPath `
        -RedirectStandardError $StderrPath `
        -Wait `
        -PassThru

    Get-Content $StdoutPath | Tee-Object -FilePath $LogPath -Append
    Get-Content $StderrPath | Tee-Object -FilePath $LogPath -Append
    Log "exit code: $($Process.ExitCode)"
    if ($Process.ExitCode -ne 0) {
        throw "fluidsGL frame capture failed at frame $Frame"
    }
    if (!(Test-Path $Ppm)) {
        throw "fluidsGL.ppm missing after frame $Frame"
    }

    $OutName = "frame_{0:D3}.ppm" -f $Index
    Copy-Item $Ppm (Join-Path $OutDir $OutName) -Force
    $Index += 1
}

Log ""
Log "Captured $Index frames"
Log "Done. Log: $LogPath"
