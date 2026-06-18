$ErrorActionPreference = "Stop"

$Root = "C:\Users\18572\blender-wsl-render"
$Samples = Join-Path $Root "cuda_samples_v12_5"
$SampleDir = Join-Path $Samples "Samples\5_Domain_Specific\fluidsGL"
$LogDir = Join-Path $Root "cuda_care_logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogPath = Join-Path $LogDir "windows-cuda126-fluidsgl-$Stamp.txt"

function Log($Message) {
    $Message | Tee-Object -FilePath $LogPath -Append
}

$MsBuild = "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
$CudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6"
$env:CUDA_PATH = $CudaPath
$env:CUDA_PATH_V12_6 = $CudaPath
$env:PATH = "$CudaPath\bin;$Samples\bin\win64\Release;$env:PATH"

Log "CUDA 12.6 fluidsGL build/run $Stamp"
Log "SampleDir: $SampleDir"

if (!(Test-Path $MsBuild)) { throw "MSBuild not found at $MsBuild" }
if (!(Test-Path "$CudaPath\bin\nvcc.exe")) { throw "CUDA 12.6 nvcc not found" }

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

Log ""
Log "== Run fluidsGL reference autotest =="
$StdoutPath = Join-Path $LogDir "windows-cuda126-fluidsgl-$Stamp.stdout.txt"
$StderrPath = Join-Path $LogDir "windows-cuda126-fluidsgl-$Stamp.stderr.txt"
if (Test-Path (Join-Path $SampleDir "fluidsGL.ppm")) {
    Remove-Item (Join-Path $SampleDir "fluidsGL.ppm") -Force
}
$Process = Start-Process -FilePath $Exe `
    -ArgumentList @("-file=data/ref_fluidsGL.ppm") `
    -WorkingDirectory $SampleDir `
    -RedirectStandardOutput $StdoutPath `
    -RedirectStandardError $StderrPath `
    -Wait `
    -PassThru
$RunCode = $Process.ExitCode
if (Test-Path $StdoutPath) {
    Get-Content $StdoutPath | Tee-Object -FilePath $LogPath -Append
}
if (Test-Path $StderrPath) {
    Get-Content $StderrPath | Tee-Object -FilePath $LogPath -Append
}
Log "fluidsGL exit code: $RunCode"

if (Test-Path (Join-Path $SampleDir "fluidsGL.ppm")) {
    Log "Output PPM: $(Join-Path $SampleDir 'fluidsGL.ppm')"
}

if ($RunCode -ne 0) {
    throw "fluidsGL reference autotest failed"
}

Log ""
Log "Done. Log: $LogPath"
