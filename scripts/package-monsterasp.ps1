param([string]$Dotnet = 'dotnet')
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$publishRoot = Join-Path $projectRoot 'artifacts/monsterasp'
& $Dotnet publish (Join-Path $projectRoot 'backendMAIN/backend.csproj') -c Release -o $publishRoot
if ($LASTEXITCODE -ne 0) { throw 'Backend publish failed.' }

# This public deployment has no database, login, SMTP credentials or admin UI.
$webConfigPath = Join-Path $publishRoot 'web.config'
[xml]$webConfig = Get-Content -LiteralPath $webConfigPath -Raw
$appNode = $webConfig.configuration.location.'system.webServer'.aspNetCore
$variables = $webConfig.CreateElement('environmentVariables')
foreach ($entry in @{
    PublicWebsite__Enabled = 'true'
    ASPNETCORE_ENVIRONMENT = 'Production'
    Logging__LogLevel__System_Net_Http_HttpClient = 'Warning'
}.GetEnumerator()) {
    $variable = $webConfig.CreateElement('environmentVariable')
    $variable.SetAttribute('name', $entry.Key)
    $variable.SetAttribute('value', $entry.Value)
    [void]$variables.AppendChild($variable)
}
[void]$appNode.AppendChild($variables)
$webConfig.Save($webConfigPath)

Add-Type -AssemblyName System.IO.Compression
$zipPath = Join-Path $projectRoot 'artifacts/technocare-public-api.zip'
$stream = [IO.File]::Open($zipPath, [IO.FileMode]::Create)
$archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $publishRoot -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($publishRoot, $file.FullName).Replace('\', '/')
        if ($file.Name -like 'appsettings*.json' -or $file.Extension -eq '.pdb' -or $relative.StartsWith('wwwroot/') -or $relative.StartsWith('photos/')) { continue }
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $relative, [IO.Compression.CompressionLevel]::Optimal)
    }
} finally { $archive.Dispose(); $stream.Dispose() }
Write-Output "Public API deployment package: $zipPath"
