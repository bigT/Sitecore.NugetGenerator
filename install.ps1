$homepath = Join-Path $env:HOMEDRIVE $env:HOMEPATH
$modulepath = Join-Path $homepath "\Documents\WindowsPowerShell\Modules\SitecoreNugetGenerator\SitecoreNugetGenerator.psm1"

$webClient = New-Object System.Net.WebClient
Write-Host "Downloading Sitecore Nuget generator module to $modulepath"
New-Item -ItemType Directory -Force -Path (split-path $modulepath) > $null
$webClient.DownloadFile('https://rawgit.com/bigT/Sitecore.NugetGenerator/master/SitecoreNugetGenerator/SitecoreNugetGenerator.psm1', $modulepath)
