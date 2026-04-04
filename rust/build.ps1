$env:PATH = "C:\Users\jmsan\.strawberry-perl\perl\bin;C:\Users\jmsan\.cargo\bin;" + $env:PATH
Set-Location $PSScriptRoot
cargo build 2>&1
Write-Host "---"
Write-Host "DLL size:" ((Get-Item "target\debug\xmtp_plugin_native.dll" -ErrorAction SilentlyContinue).Length / 1MB) "MB"
