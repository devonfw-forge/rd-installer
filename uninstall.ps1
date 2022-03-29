#Requires -RunAsAdministrator

#region variables

$script:rancherDesktopUninstallExe = "C:\Users\$env:UserName\AppData\Local\Programs\Rancher Desktop\Uninstall Rancher Desktop.exe"
$script:dockerFilesPath = "C:\Users\$env:UserName\AppData\Local\Programs\Rancher Desktop\resources\resources\win32\bin"
$script:profilePath = "C:\Users\$env:UserName\Documents\WindowsPowerShell\old-profile.ps1"

#endregion

#region functions

function RemoveDockerD
{
    Write-Host "Uninstalling dockerd..." -ForegroundColor Blue
    dockerw context rm win -f

    Stop-Service docker
    dockerd --unregister-service

    $path = [System.Environment]::GetEnvironmentVariable(
        'PATH',
        'Machine'
    )

    $path = ($path.Split(';') | Where-Object { $_ -ne "$script:dockerFilesPath" }) -join ';'

    [System.Environment]::SetEnvironmentVariable(
        'PATH',
        $path,
        'Machine'
    )

    Remove-Item -Path "${script:dockerFilesPath}\dockerd.exe" -Force

    Write-Host "dockerd uninstalled successfully." -ForegroundColor Green
}

function UninstallDockerAccessHelper
{
    Write-Host "Uninstalling dockeraccesshelper..." -ForegroundColor Blue
    Uninstall-Module -Name dockeraccesshelper -Force
    Write-Host "dockeraccesshelper uninstalled successfully." -ForegroundColor Green
}

function RestorePowershellProfile
{
    Write-Host "Removing the alias from your computer..." -ForegroundColor Green

    New-Item -Type File -Path $PROFILE -Force
    Get-Content "${script:profilePath}" >> $PROFILE
    Remove-Item -Path "${script:profilePath}" -Force

    Write-Host "Profile restored successfully." -ForegroundColor Green
}

function DeleteStartScript
{
    Remove-Item "${script:dockerFilesPath}\start.ps1" -Force
}

function UninstallRancherDesktop
{
    Write-Host "Uninstalling Rancher Desktop..." -ForegroundColor Blue
    & $script:rancherDesktopUninstallExe

    Start-Sleep -s 5

    $uninstallid = (Get-Process Un_A).id 2> $null

    Wait-Process -Id $uninstallId

    wsl --unregister rancher-desktop
    wsl --unregister rancher-desktop-data

    Write-Host "Rancher Desktop successfully uninstalled." -ForegroundColor Green
}

function RemoveWslVpnKit
{
    Write-Host "Removing the VPN tool..." -ForegroundColor Blue
    wsl --unregister wsl-vpnkit

    Write-Host "VPN tool removed successfully." -ForegroundColor Green
}

#endregion

#region main

RemoveDockerD
UninstallDockerAccessHelper
RestorePowershellProfile
DeleteStartScript
RemoveWslVpnKit
UninstallRancherDesktop

#endregion
