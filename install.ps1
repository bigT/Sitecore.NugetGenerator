$homepath = Join-Path $env:HOMEDRIVE $env:HOMEPATH
$modulepath = Join-Path $homepath "\Documents\WindowsPowerShell\ModulesSitecoreNugetGenerator\SitecoreNugetGenerator.psm1"

$webClient = New-Object System.Net.WebClient
Write-Host "Downloading Sitecore Nuget generator module to $modulepath"
$webClient.DownloadFile('https://rawgit.com/bigT/Sitecore.NugetGenerator/master/SitecoreNugetGenerator/SitecoreNugetGenerator.psm1', $modulepath)
