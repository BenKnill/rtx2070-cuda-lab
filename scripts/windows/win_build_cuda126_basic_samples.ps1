$ErrorActionPreference = "Stop"

$Root = "C:\Users\18572\blender-wsl-render"
$Samples = Join-Path $Root "cuda_samples_v12_5"
$LogDir = Join-Path $Root "cuda_care_logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogPath = Join-Path $LogDir "windows-cuda126-basic-samples-$Stamp.txt"

function Log($Message) {
    $Message | Tee-Object -FilePath $LogPath -Append
}

$MsBuild = "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
$CudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6"

Log "CUDA 12.6 basic sample build $Stamp"
Log "MSBuild: $MsBuild"
Log "CUDA: $CudaPath"

if (!(Test-Path $MsBuild)) { throw "MSBuild not found at $MsBuild" }
if (!(Test-Path "$CudaPath\bin\nvcc.exe")) { throw "CUDA 12.6 nvcc not found" }
$env:CUDA_PATH = $CudaPath
$env:CUDA_PATH_V12_6 = $CudaPath

$Solutions = @(
    "Samples\1_Utilities\deviceQuery\deviceQuery_vs2022.sln",
    "Samples\1_Utilities\bandwidthTest\bandwidthTest_vs2022.sln"
)

foreach ($Rel in $Solutions) {
    $Sln = Join-Path $Samples $Rel
    Log ""
    Log "== Build $Rel =="
    & $MsBuild $Sln /m /t:Build /p:Configuration=Release /p:Platform=x64 2>&1 |
        Tee-Object -FilePath $LogPath -Append
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed: $Rel"
    }
}

Log ""
Log "== Built executables =="
Get-ChildItem $Samples -Recurse -Filter deviceQuery.exe -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName |
    Tee-Object -FilePath $LogPath -Append
Get-ChildItem $Samples -Recurse -Filter bandwidthTest.exe -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName |
    Tee-Object -FilePath $LogPath -Append

Log ""
Log "== Run deviceQuery =="
$DeviceQuery = Get-ChildItem $Samples -Recurse -Filter deviceQuery.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (!$DeviceQuery) { throw "deviceQuery.exe not found after build" }
& $DeviceQuery 2>&1 | Tee-Object -FilePath $LogPath -Append
if ($LASTEXITCODE -ne 0) {
    throw "deviceQuery failed"
}

Log ""
Log "== Run bandwidthTest =="
$BandwidthTest = Get-ChildItem $Samples -Recurse -Filter bandwidthTest.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (!$BandwidthTest) { throw "bandwidthTest.exe not found after build" }
& $BandwidthTest --mode=quick 2>&1 | Tee-Object -FilePath $LogPath -Append
if ($LASTEXITCODE -ne 0) {
    throw "bandwidthTest failed"
}

Log ""
Log "Done. Log: $LogPath"
