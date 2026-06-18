$ErrorActionPreference = "Stop"

$Root = "C:\Users\18572\blender-wsl-render"
$Samples = Join-Path $Root "cuda_samples_v12_5"
$SampleDir = Join-Path $Samples "Samples\5_Domain_Specific\simpleGL"
$OutDir = Join-Path $Root "cuda_demo_output\simplegl_frames"
$LogDir = Join-Path $Root "cuda_care_logs"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogPath = Join-Path $LogDir "windows-simplegl-animation-capture-$Stamp.txt"

function Log($Message) {
    $Message | Tee-Object -FilePath $LogPath -Append
}

$MsBuild = "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
$CudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6"
$env:CUDA_PATH = $CudaPath
$env:CUDA_PATH_V12_6 = $CudaPath
$env:PATH = "$CudaPath\bin;$Samples\bin\win64\Release;$env:PATH"

Log "Capture simpleGL animation frames $Stamp"
Log "OutDir: $OutDir"

if (!(Test-Path $MsBuild)) { throw "MSBuild not found at $MsBuild" }
if (!(Test-Path "$CudaPath\bin\nvcc.exe")) { throw "CUDA 12.6 nvcc not found" }

Get-ChildItem $OutDir -Filter "frame_*.ppm" -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem $SampleDir -Filter "simpleGL_frame_*.ppm" -ErrorAction SilentlyContinue | Remove-Item -Force

$Sln = Join-Path $SampleDir "simpleGL_vs2022.sln"
Log ""
Log "== Build simpleGL =="
& $MsBuild $Sln /m /t:Build /p:Configuration=Release /p:Platform=x64 2>&1 |
    Tee-Object -FilePath $LogPath -Append
if ($LASTEXITCODE -ne 0) {
    throw "simpleGL build failed"
}

$Exe = Join-Path $Samples "bin\win64\Release\simpleGL.exe"
if (!(Test-Path $Exe)) { throw "simpleGL.exe not found at $Exe" }

Log ""
Log "== Capture frames =="
$StdoutPath = Join-Path $LogDir "simplegl-capture-$Stamp.stdout.txt"
$StderrPath = Join-Path $LogDir "simplegl-capture-$Stamp.stderr.txt"
$Process = Start-Process -FilePath $Exe `
    -ArgumentList @("-captureframes=72") `
    -WorkingDirectory $SampleDir `
    -RedirectStandardOutput $StdoutPath `
    -RedirectStandardError $StderrPath `
    -Wait `
    -PassThru

if (Test-Path $StdoutPath) {
    Get-Content $StdoutPath | Tee-Object -FilePath $LogPath -Append
}
if (Test-Path $StderrPath) {
    Get-Content $StderrPath | Tee-Object -FilePath $LogPath -Append
}
Log "exit code: $($Process.ExitCode)"
if ($Process.ExitCode -ne 0) {
    throw "simpleGL capture failed"
}

$Index = 0
Get-ChildItem $SampleDir -Filter "simpleGL_frame_*.ppm" | Sort-Object Name | ForEach-Object {
    $OutName = "frame_{0:D3}.ppm" -f $Index
    Copy-Item $_.FullName (Join-Path $OutDir $OutName) -Force
    $Index += 1
}

if ($Index -lt 2) {
    throw "Expected multiple simpleGL frames, captured $Index"
}

Log "Captured $Index frames"
Log "Done. Log: $LogPath"
