$CudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6"
$env:CUDA_PATH = $CudaPath
$env:CUDA_PATH_V12_6 = $CudaPath
$env:PATH = "$CudaPath\bin;$CudaPath\libnvvp;$env:PATH"

Write-Host "CUDA_PATH=$env:CUDA_PATH"
& "$CudaPath\bin\nvcc.exe" --version
