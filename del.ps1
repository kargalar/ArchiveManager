$path1 = "$env:USERPROFILE\Documents\Archive Manager"
if (Test-Path $path1) { Remove-Item -Recurse -Force $path1; Write-Host "Deleted $path1" }

$path2 = "$env:USERPROFILE\OneDrive\Documents\Archive Manager"
if (Test-Path $path2) { Remove-Item -Recurse -Force $path2; Write-Host "Deleted $path2" }

$path3 = "$env:APPDATA\Documents\Archive Manager"
if (Test-Path $path3) { Remove-Item -Recurse -Force $path3; Write-Host "Deleted $path3" }

Write-Host "Done"
