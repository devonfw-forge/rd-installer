#Requires -RunAsAdministrator

#region variables

param(
    [switch]$Help = $false,
    [switch]$VPN = $false,
    [switch]$WindowsContainers = $false,
    [switch]$Alias = $false
)

$script:rancherDesktopExe = "C:\Users\$env:UserName\AppData\Local\Programs\Rancher Desktop\Rancher Desktop.exe"
$script:dockerFilesPath = "C:\Users\$env:UserName\AppData\Local\Programs\Rancher Desktop\resources\resources\win32\bin"
$script:profilePath = "C:\Users\$env:UserName\Documents\WindowsPowerShell\old-profile.ps1"
$script:dockerPackageUrl = "https://download.docker.com/win/static/stable/x86_64/docker-20.10.8.zip"
$script:rancherDesktopUrl = "https://github.com/rancher-sandbox/rancher-desktop/releases/download/v1.2.1/Rancher.Desktop.Setup.1.2.1.exe"
$script:wslVpnKitUrl = "https://github.com/sakai135/wsl-vpnkit/releases/download/v0.3.0/wsl-vpnkit.tar.gz"
$script:restartRequired = $false

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
    Write-Host "  -Alias                Creates alias for usual Docker commands in Powershell."
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
        $wslExists = $true
    }
}

function DownloadDockerD
{
    Write-Host "Installing dockerd..." -ForegroundColor Blue
    Invoke-WebRequest $script:dockerPackageUrl -OutFile "docker.zip"
    Expand-Archive docker.zip -DestinationPath "C:\"
    Copy-Item "C:\docker\dockerd.exe" $script:dockerFilesPath -Recurse -Force
    Remove-Item docker.zip
    Remove-Item "C:\docker"

    [Environment]::SetEnvironmentVariable("Path", "$($env:path);$script:dockerFilesPath", [System.EnvironmentVariableTarget]::Machine)
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

    Copy-Item $PROFILE "$script:profilePath"

    Write-Host "" >> $PROFILE
    Get-Content "profile.ps1" >> "$PROFILE"

    . $PROFILE
}

function FinishInstallation
{
    if($script:restartRequired) {
        Write-Host "Installation finished." -ForegroundColor Green
        Write-Warning "A restart is required to enable the windows features. Please restart your machine."
        $user_input = Read-Host -Prompt "Would you like to restart now? (Type 'Y' for 'Yes' or 'N' for 'No')."
        if($user_input -eq 'Y')
        {
            Restart-computer
        }
    } else {
        Write-Host "Installation finished." -ForegroundColor Green
    }
}

function CopyStartScript
{
    Copy-Item "start.ps1" "$script:dockerFilesPath" -Force
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
    Invoke-WebRequest $script:rancherDesktopUrl -OutFile "Rancher.Desktop.Setup.1.2.1.exe"
    .\Rancher.Desktop.Setup.1.2.1.exe /silent

    $setupId = (Get-Process Rancher.Desktop.Setup.1.2.1).id 2> $null

    Wait-Process -Id $setupId

    Write-Host "Rancher Desktop successfully installed." -ForegroundColor Green
}

function ActivateWslVpnkit
{
    Write-Host "Activating the tool for the VPN..." -ForegroundColor Blue
    Invoke-WebRequest $script:wslVpnKitUrl -OutFile "wsl-vpnkit.tar.gz"

    wsl --import wsl-vpnkit $env:USERPROFILE\wsl-vpnkit wsl-vpnkit.tar.gz --version 2
    wsl -d wsl-vpnkit service wsl-vpnkit start 2> $null

    Remove-Item wsl-vpnkit.tar.gz -Force

    Write-Host "VPN tool activated." -ForegroundColor Green
}

#endregion

#region main

if($Help)
{
    Help
    exit 1
}

IsDockerDesktopInstalled
EnableWslFeature
InstallRancherDesktop

if($VPN)
{
    ActivateWslVpnkit
}

if($WindowsContainers)
{
    EnableContainerFeature
    InstallDockerAccessHelperModule
    DownloadDockerD
    CreateWindowsContext
    CopyStartScript
    Start-Service docker
    Add-AccountToDockerAccess "$env:UserDomain\$env:UserName"
}

if($Alias)
{
    CreatePowershellProfile
}

FinishInstallation

#endregion
