[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$InstallerPath,

    [string]$ExpectedVersion,

    [Parameter(Mandatory)]
    [string]$ExpectedExecutablePath,

    [switch]$AllowLocalInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:CI -ne 'true' -and -not $AllowLocalInstall) {
    throw 'Refusing to run installer verification outside CI. This script performs a real install/uninstall; pass -AllowLocalInstall only when you intentionally want that.'
}

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Wait-Until {
    param(
        [Parameter(Mandatory)][scriptblock]$Condition,
        [Parameter(Mandatory)][string]$FailureMessage,
        [int]$TimeoutSeconds = 30
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (& $Condition) {
            return
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)

    throw $FailureMessage
}

function Assert-NoSpreadsheetAssociations {
    $extensions = @('.csv', '.tsv', '.xls', '.xlsm', '.xlsx')
    foreach ($extension in $extensions) {
        foreach ($applicationName in @('Codex.exe', 'ChatGPT.exe')) {
            $openWithList = "HKLM:\Software\Classes\$extension\OpenWithList\$applicationName"
            Assert-True (-not (Test-Path -LiteralPath $openWithList)) "Unexpected $applicationName OpenWithList registration for $extension"
        }

        foreach ($shellName in @('OpenWithCodex', 'OpenWithChatGPT')) {
            $applicationShell = "HKLM:\Software\Classes\$extension\shell\$shellName"
            Assert-True (-not (Test-Path -LiteralPath $applicationShell)) "Unexpected $shellName shell registration for $extension"
        }

        $openWithProgids = "HKLM:\Software\Classes\$extension\OpenWithProgids"
        if (Test-Path -LiteralPath $openWithProgids) {
            $item = Get-Item -LiteralPath $openWithProgids
            foreach ($name in $item.GetValueNames()) {
                Assert-True ($name -notmatch 'Codex|ChatGPT') "Unexpected application OpenWithProgids value '$name' for $extension"
            }
        }
    }
}

$resolvedInstaller = (Resolve-Path -LiteralPath $InstallerPath).ProviderPath
$normalizedExecutablePath = $ExpectedExecutablePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
if (
    [string]::IsNullOrWhiteSpace($normalizedExecutablePath) -or
    [System.IO.Path]::IsPathRooted($normalizedExecutablePath) -or
    $normalizedExecutablePath.Split([System.IO.Path]::DirectorySeparatorChar) -contains '..'
) {
    throw "ExpectedExecutablePath must be a safe relative path: $ExpectedExecutablePath"
}
$expectedExecutableName = [System.IO.Path]::GetFileName($normalizedExecutablePath)
$principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
Assert-True ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'Installer verification requires an elevated Windows runner.'

$installDir = Join-Path $env:ProgramFiles 'ChatGPT'
$applicationExe = Join-Path $installDir $normalizedExecutablePath
$uninstaller = Join-Path $installDir 'Uninstall.exe'
$commonPrograms = [Environment]::GetFolderPath('CommonPrograms')
$startMenuShortcut = Join-Path $commonPrograms 'ChatGPT\ChatGPT.lnk'
$commonDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
$desktopShortcut = Join-Path $commonDesktop 'ChatGPT.lnk'
$uninstallKey = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ChatGPT'
$protocolKey = 'HKLM:\Software\Classes\codex'
$protocolCommandKey = 'HKLM:\Software\Classes\codex\shell\open\command'
$skillExtensionKey = 'HKLM:\Software\Classes\.skill'
$skillOpenWithProgidsKey = 'HKLM:\Software\Classes\.skill\OpenWithProgids'
$skillProgIdKey = 'HKLM:\Software\Classes\ChatGPT.skill'
$skillCommandKey = 'HKLM:\Software\Classes\ChatGPT.skill\shell\open\command'
$applicationRegistrationKey = "HKLM:\Software\Classes\Applications\$expectedExecutableName"
$applicationCommandKey = "$applicationRegistrationKey\shell\open\command"
$legacyInstallDir = Join-Path $env:ProgramFiles 'Codex'
$legacyDirExisted = Test-Path -LiteralPath $legacyInstallDir
$legacySentinel = Join-Path $legacyInstallDir "ci-legacy-sentinel-$([Guid]::NewGuid().ToString('N')).txt"

$skillDefaultBefore = $null
if (Test-Path -LiteralPath $skillExtensionKey) {
    $skillDefaultBefore = (Get-Item -LiteralPath $skillExtensionKey).GetValue('')
}

New-Item -ItemType Directory -Path $legacyInstallDir -Force | Out-Null
Set-Content -LiteralPath $legacySentinel -Value 'legacy Codex installation sentinel' -Encoding ASCII

try {
$installed = $false
try {
    $installProcess = Start-Process -FilePath $resolvedInstaller -ArgumentList '/S' -Wait -PassThru
    Assert-True ($installProcess.ExitCode -eq 0) "Silent install failed with exit code $($installProcess.ExitCode)."
    $installed = $true

    Assert-True (Test-Path -LiteralPath $applicationExe) "Manifest application executable was not installed at $applicationExe"
    Assert-True (Test-Path -LiteralPath $startMenuShortcut) "Start Menu shortcut was not created at $startMenuShortcut"
    Assert-True (Test-Path -LiteralPath $desktopShortcut) "Desktop shortcut was not created at $desktopShortcut"
    Assert-True (Test-Path -LiteralPath $uninstallKey) "Uninstall registry key was not created: $uninstallKey"
    Assert-True (Test-Path -LiteralPath $protocolKey) "codex: protocol registry key was not created: $protocolKey"
    Assert-True (Test-Path -LiteralPath $protocolCommandKey) "codex: protocol open command was not created: $protocolCommandKey"
    Assert-True (Test-Path -LiteralPath $skillProgIdKey) ".skill ProgID was not created: $skillProgIdKey"
    Assert-True (Test-Path -LiteralPath $skillCommandKey) ".skill open command was not created: $skillCommandKey"
    Assert-True (Test-Path -LiteralPath $applicationRegistrationKey) "Open With application registration was not created: $applicationRegistrationKey"
    Assert-True (Test-Path -LiteralPath $applicationCommandKey) "Open With application command was not created: $applicationCommandKey"
    Assert-True (Test-Path -LiteralPath $skillOpenWithProgidsKey) ".skill OpenWithProgids key was not created"
    Assert-True ((Get-Item -LiteralPath $skillOpenWithProgidsKey).GetValueNames() -contains 'ChatGPT.skill') '.skill OpenWithProgids does not contain ChatGPT.skill'
    Assert-True (Test-Path -LiteralPath $legacySentinel) 'The legacy Codex install directory was modified or removed'

    $skillDefaultAfter = (Get-Item -LiteralPath $skillExtensionKey).GetValue('')
    Assert-True ($skillDefaultAfter -eq $skillDefaultBefore) '.skill default handler was changed by the installer'

    $uninstallProperties = Get-ItemProperty -LiteralPath $uninstallKey
    Assert-True (-not [string]::IsNullOrWhiteSpace($uninstallProperties.UninstallString)) 'UninstallString is missing from uninstall registry key.'
    if (-not [string]::IsNullOrWhiteSpace($ExpectedVersion)) {
        Assert-True ($uninstallProperties.DisplayVersion -eq $ExpectedVersion) "DisplayVersion '$($uninstallProperties.DisplayVersion)' did not match expected '$ExpectedVersion'."
    }

    $protocolCommand = (Get-Item -LiteralPath $protocolCommandKey).GetValue('')
    Assert-True ($protocolCommand -like "*$applicationExe*") "codex: protocol command does not point to the manifest application executable: $protocolCommand"

    $skillCommand = (Get-Item -LiteralPath $skillCommandKey).GetValue('')
    Assert-True ($skillCommand -like "*$applicationExe*") ".skill command does not point to the manifest application executable: $skillCommand"

    $applicationCommand = (Get-Item -LiteralPath $applicationCommandKey).GetValue('')
    Assert-True ($applicationCommand -like "*$applicationExe*") "Open With command does not point to the manifest application executable: $applicationCommand"

    Assert-NoSpreadsheetAssociations
} finally {
    if ($installed -and (Test-Path -LiteralPath $uninstaller)) {
        $uninstallProcess = Start-Process -FilePath $uninstaller -ArgumentList '/S' -Wait -PassThru
        if ($uninstallProcess.ExitCode -ne 0) {
            throw "Silent uninstall failed with exit code $($uninstallProcess.ExitCode)."
        }

        Wait-Until -Condition { -not (Test-Path -LiteralPath $installDir) } -FailureMessage "Install directory still exists after uninstall: $installDir"
        Wait-Until -Condition { -not (Test-Path -LiteralPath $desktopShortcut) } -FailureMessage "Desktop shortcut still exists after uninstall: $desktopShortcut"
        Wait-Until -Condition { -not (Test-Path -LiteralPath $uninstallKey) } -FailureMessage "Uninstall registry key still exists after uninstall: $uninstallKey"
        Wait-Until -Condition { -not (Test-Path -LiteralPath $protocolKey) } -FailureMessage "codex: protocol registry key still exists after uninstall: $protocolKey"
        Wait-Until -Condition { -not (Test-Path -LiteralPath $skillProgIdKey) } -FailureMessage ".skill ProgID still exists after uninstall: $skillProgIdKey"
        Wait-Until -Condition { -not (Test-Path -LiteralPath $applicationRegistrationKey) } -FailureMessage "Open With application registration still exists after uninstall: $applicationRegistrationKey"
        Assert-True (Test-Path -LiteralPath $legacySentinel) 'The legacy Codex install directory was removed during uninstall'
    }
}
} finally {
    if (Test-Path -LiteralPath $legacySentinel) {
        Remove-Item -LiteralPath $legacySentinel -Force
    }
    if (-not $legacyDirExisted -and (Test-Path -LiteralPath $legacyInstallDir)) {
        Remove-Item -LiteralPath $legacyInstallDir -Force -ErrorAction SilentlyContinue
    }
}

Write-Host 'CI installer install/uninstall verification passed.'
