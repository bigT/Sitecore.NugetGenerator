
# Core assemblies
$Assemblies = @(
    'Sitecore.Kernel.dll',
    'Sitecore.ContentSearch.dll',
    'Sitecore.ContentSearch.Linq.dll',
    'Sitecore.Logging.dll',
    'Sitecore.Update.dll',
    'Sitecore.Zip.dll',
    'Sitecore.Client.dll',
    'Sitecore.Mvc.dll'
)

<# 
 .Synopsis
  Extract Sitecore core assemblies from an official Sitecore release archive.

 .Description
  Displays a visual representation of a calendar. This function supports multiple months
  and lets you highlight specific date ranges or days.

 .Parameter SitecoreZip
  Path to Sitecore official zip file (E.g. '.\Sitecore 8.0 rev. 150621.zip' ).

 .ExtractTo
  Path to the folder the will hold extracted assemblies. The folder must already exist.

 .Example
   # TODO

#>
function Get-SitecoreAssemblies {
    param (
        [Parameter(Mandatory=$true, HelpMessage="Path to Sitecore official zip file (E.g. '.\Sitecore 8.0 rev. 150621.zip' ).")]
        [string]$SitecoreZip,

        [Parameter(Mandatory = $true, HelpMessage="The folder where assemblies should be extracted to.")]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [string]$ExtractTo
    )

    # Extract core assemblies
    [Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" ) > $null
    $Zip = [System.IO.Compression.ZipFile]::OpenRead((Convert-Path $SitecoreZip))
    Try 
    {
        # Find assemblies in the archive
        $ZipAssemblies = $Zip.Entries | where { $Assemblies -contains $_.Name }
        if ($ZipAssemblies.Length -ne $Assemblies.Length) {
            $ZipAssemblyName = $ZipAssemblies | % { $_.Name }
            Throw "Could not find '$($Assemblies | where { $ZipAssemblyName -notcontains $_ })' assemblies in '$SitecoreZip'."
        }
 
        # Extract assemblies to the lib folder
        $ZipAssemblies | % { [System.IO.Compression.ZipFileExtensions]::ExtractToFile( $_, "$ExtractTo\$($_.Name)", $true) }

    }
    Finally
    {
        $Zip.Dispose();
    }
}

<# 
 .Synopsis
  Generates a Sitecore nuget file specification, by expanding provided template.

 .Description
  Generates a Sitecore nuget file specification, by expanding provided template.
  By expanding the variable inside template file using information derived retrieved
  from Sitecore assemblies and passed in parameters.

 .Parameter LibPath
  The path to the folder that contains Sitecore assemblies that should be added to the
  package.

 .Parameter NuspecTempalte
  The path to the nuget specification template file that should be e

 .Parameter PackageMinorVersion
  A minor version to append to the Sitecore release version when generating a nuget
  specification from the specified template.

 .Example
   TO DO
#>
function New-SitecoreNugetSpec {
    param (

        [Parameter(Mandatory = $true, HelpMessage="The folder that contains Sitecore assemblies.")]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [System.IO.DirectoryInfo]$LibPath,

        [Parameter(Mandatory=$true, HelpMessage="Nuspec template path (E.g. 'CompanyName.Sc.Loibs.Core.nuspec.template' ).")]
        [ValidateScript({ Test-Path $_ })]
        [System.IO.FileInfo]$NuspecTempalte,

        [Parameter(Mandatory=$true, HelpMessage="NuGet package Id prefix.")]
        [System.IO.FileInfo]$PackageIdPrexif,

        $PackageMinorVersion = 0,
        $VersionInfoAssembly = "Sitecore.Kernel.dll"
    )

    # Get product version and derived version
    $MainAssembly = Get-Item "$LibPath\$VersionInfoAssembly" -ErrorAction Stop
    $ProductVersion = $MainAssembly.VersionInfo.ProductVersion

    # Set up nuget generation context.
    $TemplateVariables = @{ 
        IdPrefix = $PackageIdPrexif; 
        Version = ($ProductVersion -replace "[^0-9\.]", "");
        VersionMinor = $PackageMinorVersion;
        LibFolder = "$LibPath";
        ProductVersion = $ProductVersion;
        MainAssemblyName = $MainAssembly.BaseName;
    }

    # Expand Nuspec template into an nuspec and package a NuGet
    # The variables below can be expanded using [[VARIABLE_NAME]] syntax (E.g. [[Version]] )
    $Template = Get-Content $NuspecTempalte -Raw
    $Nuspec = "";

    while ($Template -match "(?smi)(?<pre>.*?)\[\[(?<exp>.*?)\]\](?<post>.*)") { 
      $Template = $matches.post 
      $Nuspec += $matches.pre 
      $Nuspec += $TemplateVariables[($matches.exp)]
    } 
    $Nuspec += $Template

    # Write our expanded nuspec into a spec file named after the template file name.
    $NuspecFile = (Get-Item $NuspecTempalte).BaseName
    $Nuspec | Set-Content $NuspecFile

    # Pass the library path down the pipeline, useful for chaining
    # transforms using the same libraries.
    $LibPath
}

function Get-SitecoreSampleNuspecTempaltes {
    param (
        [Parameter(Mandatory = $true, HelpMessage="Destination folder for the templates.")]
        [ValidateScript({Test-Path (Resolve-Path -Path $_) -PathType Container})]
        [string] $DownloadTo
    )

    # Template names
    $TemplateNames = @('Sc.Libs.Core.nuspec.template', 'Sc.Libs.MVC.nuspec.template', 'Sc.Module.nuspec.template')

    # Normalise path information, ensures we're dealing with full paths
    $DownloadTo = Resolve-Path $DownloadTo;

    # Download templates from GitHub
    $webClient = New-Object System.Net.WebClient
    New-Item -ItemType Directory -Force -Path $DownloadTo > $null
    $TemplateNames | % { $webClient.DownloadFile("https://rawgit.com/bigT/Sitecore.NugetGenerator/master/Tempaltes/$_", "$DownloadTo\$_") }
}

function Get-SitecorePackageContent {
    param (
        [Parameter(Mandatory=$true, HelpMessage="A path to a zip package.")]
        [ValidateScript({Test-Path (Resolve-Path $_) -PathType Leaf})]
        [string]$PackageZip,

        [Parameter(Mandatory = $true, HelpMessage="The folder where assemblies should be extracted to.")]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [string]$ExtractTo
    )

    # Normalise path to the zip
    $PackagePathInfo = Resolve-Path $PackageZip
    $ExtractToPath = Resolve-Path $ExtractTo

    # Create a temp location for the package
    $TempPackageFiles = "$PWD\" + [System.IO.Path]::GetRandomFileName()

    # Extract package to a temp location
    [Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" ) > $null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($PackagePathInfo.Path, $TempPackageFiles)

    if (!(Test-Path "$TempPackageFiles\package.zip" -PathType Leaf)) {
        Remove-Item $TempPackageFiles -Force
        Throw "Could not find 'package.zip' inside '$PackageZip', now a valid Sitecore package."
    }

    # Extract actual package
    [System.IO.Compression.ZipFile]::ExtractToDirectory("$TempPackageFiles\package.zip", "$TempPackageFiles\package")

    Copy-Item -Recurse "$TempPackageFiles\package\files\*" -Destination $ExtractToPath
    Remove-Item $TempPackageFiles -Force

    Get-Item $ExtractToPath
}

Export-ModuleMember -Function New-SitecoreNugetSpec
Export-ModuleMember -Function Get-SitecoreAssemblies
Export-ModuleMember -Function Get-SitecoreSampleNuspecTempaltes
Export-ModuleMember -Function Get-SitecorePackageContent
