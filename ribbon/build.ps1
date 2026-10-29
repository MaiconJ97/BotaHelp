param(
    [string]$AutoCADDir = 'C:\Program Files\Autodesk\AutoCAD 2026',
    [string]$DotNet = '',
    [ValidatePattern('^[A-Za-z0-9._-]+\.dll$')]
    [string]$OutputName = 'BotaHelp.dll',
    [switch]$SkipChecks
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $DotNet) {
    $localSdk = Join-Path $env:LOCALAPPDATA 'BotaHelp\BuildTools\dotnet8\dotnet.exe'
    $DotNet = if (Test-Path -LiteralPath $localSdk) { $localSdk } else { 'dotnet' }
}
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'
& $DotNet build (Join-Path $PSScriptRoot 'BotaHelp.csproj') -c Release "-p:AutoCADDir=$AutoCADDir"
if ($LASTEXITCODE -ne 0) { throw 'Fallo la compilacion de BotaHelp.dll.' }

$compiledDll = Join-Path $PSScriptRoot 'bin\Release\net8.0-windows\BotaHelp.dll'
if (-not $SkipChecks) {
    $testCases = Join-Path $env:TEMP ('botahelp-invocations-' + [guid]::NewGuid().ToString('N') + '.json')
    & $DotNet run --project (Join-Path $projectRoot 'tests\ribbon\BotaHelp.Ribbon.Tests.csproj') -c Release -- $compiledDll (Join-Path $projectRoot 'bota_help.lsp') $testCases
    if ($LASTEXITCODE -ne 0) { throw 'Fallaron las comprobaciones de empaquetado.' }
    $previousCases = $env:BOTAHELP_INVOCATION_CASES
    try {
        $env:BOTAHELP_INVOCATION_CASES = $testCases
        & node --test (Join-Path $projectRoot 'tests\bota2.test.cjs') (Join-Path $projectRoot 'tests\bota3.test.cjs') (Join-Path $projectRoot 'tests\bota3-direction.test.cjs') (Join-Path $projectRoot 'tests\bota3-densify.test.cjs') (Join-Path $projectRoot 'tests\bota3-spacing.test.cjs') (Join-Path $projectRoot 'tests\settings-sync.test.cjs') (Join-Path $projectRoot 'tests\ribbon-invocation.test.cjs')
        if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas de AutoLISP o de carga desde la DLL.' }
    }
    finally { $env:BOTAHELP_INVOCATION_CASES = $previousCases }
}
$destination = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Copy-Item -LiteralPath $compiledDll -Destination (Join-Path $destination $OutputName) -Force
Get-FileHash -LiteralPath (Join-Path $destination $OutputName) -Algorithm SHA256
Write-Output ('DLL lista para distribuir: ' + (Join-Path $destination $OutputName))
