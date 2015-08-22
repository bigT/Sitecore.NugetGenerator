$modulepath = Join-Path $env:HOMEDRIVE $env:HOMEPATH "SitecoreNugetGenerator"

$webClient = New-Object System.Net.WebClient
Write-Host "Downloading Sitecore Nuget generator module to $modulepath"
$webClient.DownloadFile('https://raw.githubusercontent.com/bigt/Home/dev/dnvm.ps1', $modulepath)
