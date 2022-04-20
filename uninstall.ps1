#Requires -RunAsAdministrator

#region variables

$script:rancherDesktopUninstallExe = "C:\Users\$env:UserName\AppData\Local\Programs\Rancher Desktop\Uninstall Rancher Desktop.exe"
$script:dockerFilesPath = "C:\Users\$env:UserName\AppData\Local\Programs\Rancher Desktop\resources\resources\win32\bin"
$script:bashProfilePath = "C:\Users\$env:UserName\.bash_profile"

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
    Write-Host "Restoring PowerShell Profile from your computer..." -ForegroundColor Green

    Set-Content -Path $PROFILE -Value (get-content -Path $PROFILE | Select-String -Pattern 'docker' -NotMatch)
    Set-Content -Path $PROFILE -Value (get-content -Path $PROFILE | Select-String -Pattern 'nerdctl' -NotMatch)
    Set-Content -Path $PROFILE -Value (get-content -Path $PROFILE | Select-String -Pattern 'Rancher-Desktop' -NotMatch)
    Set-Content -Path $PROFILE -Value (get-content -Path $PROFILE -Raw | Select-String -Pattern '{*\n.*}' -NotMatch)
    Set-Content -Path $PROFILE -Value (get-content -Path $PROFILE | Select-String -Pattern 'VPN' -NotMatch)
    Set-Content -Path $PROFILE -Value (get-content -Path $PROFILE | Select-String -Pattern 'wsl' -NotMatch)

    Write-Host "PowerShell Profile restored successfully." -ForegroundColor Green
}

function RestoreGitBashProfile
{
    Write-Host "Restoring GitBash Profile from your computer..." -ForegroundColor Green

    Set-Content -Path $script:bashProfilePath -Value (get-content -Path $script:bashProfilePath | Select-String -Pattern 'Rancher-Desktop' -NotMatch)
    Set-Content -Path $script:bashProfilePath -Value (get-content -Path $script:bashProfilePath | Select-String -Pattern 'docker' -NotMatch)
    Set-Content -Path $script:bashProfilePath -Value (get-content -Path $script:bashProfilePath | Select-String -Pattern 'VPN' -NotMatch)
    Set-Content -Path $script:bashProfilePath -Value (get-content -Path $script:bashProfilePath | Select-String -Pattern 'wsl' -NotMatch)
    
    Write-Host "GitBash Profile restored successfully." -ForegroundColor Green
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
RestoreGitBashProfile
DeleteStartScript
RemoveWslVpnKit
UninstallRancherDesktop

Write-Host "Uninstall finished." -ForegroundColor Green
Write-Host -NoNewLine "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
Stop-Process -Force -Id $PID

#endregion
