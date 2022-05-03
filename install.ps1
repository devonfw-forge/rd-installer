#region variables

param(
    [switch]$Help = $false,
    [switch]$VPN = $false,
    [switch]$WindowsContainers = $false,
    [switch]$Alias = $false,
    [switch]$RenameBinaries = $false
)

$script:parameters = ""

foreach ($boundParam in $PSBoundParameters.GetEnumerator())
{
  $script:parameters += '-{0} ' -f $boundParam.Key
}

$script:rancherDesktopExe = "C:\Users\$env:UserName\AppData\Local\Programs\Rancher Desktop\Rancher Desktop.exe"
$script:windowsBinariesPath = "C:\Users\$env:UserName\AppData\Local\Programs\Rancher Desktop\resources\resources\win32\bin"
$script:linuxBinariesPath = "C:\Users\$env:UserName\AppData\Local\Programs\Rancher Desktop\resources\resources\linux\bin"
$script:profilePath = "C:\Users\$env:UserName\Documents\WindowsPowerShell\old-profile.ps1"
$script:panicFilePath = "C:\ProgramData\docker\panic.log"
$script:dockerPackageUrl = "https://download.docker.com/win/static/stable/x86_64/docker-20.10.8.zip"
$script:rancherDesktopUrl = "https://github.com/rancher-sandbox/rancher-desktop/releases/download/v1.1.1/Rancher.Desktop.Setup.1.1.1.exe"
$script:wslVpnKitUrl = "https://github.com/sakai135/wsl-vpnkit/releases/download/v0.3.1/wsl-vpnkit.tar.gz"
$script:restartRequired = $false
$script:bashProfilePath = "C:\Users\$env:UserName\.bash_profile"
$script:appDataSettingsPath = "C:\Users\$env:UserName\AppData\Roaming\rancher-desktop\settings.json"

#endregion

#region functions

function Help
{
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\install.ps1 [flags]"
    Write-Host ""
    Write-Host "Flags:"
    Write-Host "  -VPN                  Enables support for enterprise VPNs."
    Write-Host "  -WindowsContainers    Enables support for Windows Containers using Docker binary."
    Write-Host "  -Alias                Creates alias for usual Docker commands in Powershell and Bash."
    Write-Host ""
    Write-Host "Advanced Flags:"
    Write-Host "  -RenameBinaries       Renames binaries to provide universal docker command support in cases where shell profiles are of no use, but comes with some caveats (e.g. requires using docker compose instead of docker-compose). Incompatible with -Alias flag."
    Write-Host ""
}

function EnableContainerFeature
{
    $containerExists = Get-WindowsOptionalFeature -Online -FeatureName Containers

    if($containerExists.State -eq 'Enabled')
    {
        Write-Host "Containers feature is already installed. Skipping the install." -ForegroundColor Green
        return
    } else {
        Write-Host "Installing Containers feature..." -ForegroundColor Blue
        Enable-WindowsOptionalFeature -NoRestart -Online -FeatureName Containers -All
        $script:restartRequired = $true
    }

    Write-Host "Containers feature enabled." -ForegroundColor Green
}

function EnableWslFeature
{
    $wslExists = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

    if($wslExists.State -eq 'Enabled')
    {
        Write-Host "WSL feature is already installed. Skipping the install." -ForegroundColor Green
        return
    } else {
        Write-Host "Installing WSL feature..." -ForegroundColor Blue
        Enable-WindowsOptionalFeature -NoRestart -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All
        $script:restartRequired = $true
    }
}

function EnableVirtualMachinePlatformFeature
{
    $vmpExists = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

    if($vmpExists.State -eq 'Enabled')
    {
        Write-Host "Virtual Machine Platform feature is already installed. Skipping the install." -ForegroundColor Green
        return
    } else {
        Write-Host "Installing Virtual Machine Platform feature..." -ForegroundColor Blue
        Enable-WindowsOptionalFeature -NoRestart -Online -FeatureName VirtualMachinePlatform -All
        $script:restartRequired = $true
    }
}

function DownloadDockerD
{
    Write-Host "Installing dockerd..." -ForegroundColor Blue
    Invoke-WebRequest $script:dockerPackageUrl -OutFile "docker.zip"
    Expand-Archive docker.zip -DestinationPath "C:\"
    Copy-Item "C:\docker\dockerd.exe" $script:windowsBinariesPath -Recurse -Force
    Remove-Item docker.zip
    Remove-Item "C:\docker" -Recurse -Force

    [Environment]::SetEnvironmentVariable("Path", "$($env:path);$script:windowsBinariesPath", [System.EnvironmentVariableTarget]::Machine)
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    dockerd --register-service

    Write-Host "dockerd successfully installed." -ForegroundColor Green
}

function InstallDockerAccessHelperModule
{
    Write-Host "Installing dockeraccesshelper module..." -Foregroundcolor Blue
    if (Get-Module -ListAvailable -Name dockeraccesshelper) {
        Write-Host "Module already exists. Skipping the install." -ForegroundColor Green
        Import-Module dockeraccesshelper
    } else {
        Install-Module -Name dockeraccesshelper -Force
        Import-Module dockeraccesshelper
        Write-Host "dockeraccesshelper module successfully installed." -ForegroundColor Green
    }
}

function CreateWindowsContext
{
    $winContextExists = $false
    $contextList = docker context ls | ConvertFrom-String

    Write-Host "Checking if the windows context already exists..." -ForegroundColor Blue
    for($i=1; $i -le $contextList.Count; $i++)
    {
        if($contextList[$i].P1 -eq 'win')
        {
            Write-Host "Windows context already exists. Skipping the install." -ForegroundColor Green
            $winContextExists = $true
            return
        }
    }

    if(-Not($winContextExists))
    {
        docker context create win --docker host=npipe:////./pipe/docker_engine
    }

    Write-Host "Windows context successfully installed." -ForegroundColor Green
}

function CreatePowershellProfile
{
    if(!(Test-Path -Path $PROFILE))
    {
        New-Item -Type File -Path $PROFILE -Force
    }
    
    Write-Host "" >> $PROFILE
    Add-Content $PROFILE (Get-Content "profile.ps1")

    . $PROFILE
}

function UpdateGitBashProfile
{
    $search = (Get-Content $script:bashProfilePath | Select-String -Pattern '#region generated by rd-installer for Alias support in Git Bash').Matches.Success
    if( -Not $search){
        Add-Content $script:bashProfilePath "#region generated by rd-installer for Alias support in Git Bash"
        Add-Content $script:bashProfilePath "alias docker=""nerdctl"""
        Add-Content $script:bashProfilePath "alias docker-compose=""nerdctl compose"""
        Add-Content $script:bashProfilePath "alias dockerw=""/c/Users/$env:UserName/AppData/Local/Programs/Rancher\ Desktop/resources/resources/win32/bin/docker.exe --context win"""
        Add-Content $script:bashProfilePath "alias dockerw-compose=""/c/Users/$env:UserName/AppData/Local/Programs/Rancher\ Desktop/resources/resources/win32/bin/docker-compose.exe --context win"""
        Add-Content $script:bashProfilePath "#endregion"
    }
}

function RestartRequired
{
    if($script:restartRequired) {
        Write-Warning "Before proceeding, a restart is required to enable some Windows features. Please execute the installer again after reboot."
        $user_input = Read-Host -Prompt "Would you like to restart now? (Type 'Y' for 'Yes' or 'N' for 'No')."
        if($user_input -eq 'Y')
        {
            Restart-computer
        } elseif ($user_input -eq 'N') {
            Stop-Process -Force -Name powershell
        }
    }
}

function CopyStartScript
{
    Copy-Item "start.ps1" "$script:windowsBinariesPath" -Force
}

function IsDockerDesktopInstalled
{
    $dockerDesktopExists = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where { $_.DisplayName -eq "Docker Desktop" }) -ne $null

    if($dockerDesktopExists)
    {
        Write-Host "Please make sure Docker Desktop is uninstalled before installing Rancher Desktop." -ForegroundColor Red
        exit 1
    }
}

function InstallRancherDesktop
{
    Write-Host "Installing Rancher Desktop..." -ForegroundColor Blue
    Invoke-WebRequest $script:rancherDesktopUrl -OutFile "Rancher.Desktop.Setup.1.1.1.exe"
    .\Rancher.Desktop.Setup.1.1.1.exe

    $setupId = (Get-Process Rancher.Desktop.Setup.1.1.1).id 2> $null

    Wait-Process -Id $setupId

    Write-Host "Rancher Desktop successfully installed." -ForegroundColor Green
}

function ActivateWslVpnkit
{
    Write-Host "Activating the tool for the VPN..." -ForegroundColor Blue
    Invoke-WebRequest $script:wslVpnKitUrl -OutFile "wsl-vpnkit.tar.gz"

    wsl --import wsl-vpnkit $env:USERPROFILE\wsl-vpnkit wsl-vpnkit.tar.gz --version 2

    Remove-Item wsl-vpnkit.tar.gz -Force

    $search = (Get-Content $PROFILE | Select-String -Pattern '#region generated by rd-installer for VPN support in Powershell').Matches.Success
    if( -Not $search){
        Add-Content $PROFILE "#region generated by rd-installer for VPN support in Powershell"
        Add-Content $PROFILE "# Start the VPN support"
        Add-Content $PROFILE "wsl -d wsl-vpnkit service wsl-vpnkit start 2> `$null"
        Add-Content $PROFILE "#endregion"
        Add-Content $PROFILE ""

    }
    $search = (Get-Content $script:bashProfilePath | Select-String -Pattern '#region generated by rd-installer for VPN support in Git Bash').Matches.Success
    if( -Not $search){
        Add-Content $script:bashProfilePath "#region generated by rd-installer for VPN support in Git Bash"
        Add-Content $script:bashProfilePath "# Start the VPN support"
        Add-Content $script:bashProfilePath "wsl -d wsl-vpnkit service wsl-vpnkit start 2> /dev/null"
        Add-Content $script:bashProfilePath "#endregion"
        Add-Content $script:bashProfilePath ""
    }

    Write-Host "VPN tool activated." -ForegroundColor Green
}


function ChangeFilePermissions
{
    $isReadOnly = Get-ItemProperty -Path $script:panicFilePath 2> $null | Select-Object IsReadOnly
    if($isReadOnly -match "True")
    {
        Set-ItemProperty -Path $script:panicFilePath -Name IsReadOnly -Value $false
    }
}

function RenameBinariesFunction
{
    Write-Host "Renaming the Rancher Desktop binaries..." -ForegroundColor Blue
    Rename-Item -Path "$script:windowsBinariesPath\docker.exe" -NewName dockerw.exe
    Rename-Item -Path "$script:windowsBinariesPath\docker-compose.exe" -NewName dockerw-compose.exe
    Copy-Item "$script:windowsBinariesPath\nerdctl.exe" "$script:windowsBinariesPath\docker.exe" -Force

    Rename-Item -Path "$script:linuxBinariesPath\docker" -NewName docker.old
    Copy-Item "$script:linuxBinariesPath\nerdctl" "$script:linuxBinariesPath\docker" -Force
    Write-Host "Renaming done." -ForegroundColor Green
}

function SetAppDataSettings
{
    if(!(Test-Path -Path $script:appDataSettingsPath))
    {
        New-Item -Type File -Path $script:appDataSettingsPath -Force
        Add-Content $script:appDataSettingsPath (Get-Content "settings.json")
    }
    else
    {
        $settingsContent = Get-Content $script:appDataSettingsPath -raw | ConvertFrom-Json
        $settingsContent.kubernetes.enabled=$false
        $settingsContent.kubernetes.containerEngine="containerd"
        $settingsContent.updater=$false
        $settingsContent | ConvertTo-Json | set-content $script:appDataSettingsPath
    }
}

#endregion

#region main

if($Alias -and $RenameBinaries)
{
    Write-Host "The flags -Alias and -RenameBinaries cannot be activated together." -ForegroundColor Red
    Write-Host "Please choose only one of them." -ForegroundColor Red
    exit 1
}

if($Help)
{
    Help
    exit 0
}

# Elevate script if needed.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $($script:parameters)" -Verb RunAs; exit }

IsDockerDesktopInstalled

if($WindowsContainers)
{
    EnableContainerFeature
}
EnableWslFeature
EnableVirtualMachinePlatformFeature
RestartRequired

SetAppDataSettings

InstallRancherDesktop

if($VPN)
{
    ActivateWslVpnkit
}

if($WindowsContainers)
{
    InstallDockerAccessHelperModule
    DownloadDockerD
    ChangeFilePermissions
    CreateWindowsContext
    CopyStartScript
    Start-Service docker
    Add-AccountToDockerAccess "$env:UserDomain\$env:UserName"
}

if($Alias -and -Not($RenameBinaries))
{
    CreatePowershellProfile
    UpdateGitBashProfile
}

if($RenameBinaries -and -Not($Alias))
{
    RenameBinariesFunction
}

Write-Host "Installation finished." -ForegroundColor Green
Write-Host -NoNewLine "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
Stop-Process -Force -Id $PID

#endregion
