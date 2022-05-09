#region variables

$script:rancherDesktopExe = "$env:LOCALAPPDATA\Programs\Rancher Desktop\Rancher Desktop.exe"
$script:rancherDesktopExeHash = "CF7E00240316A3654AB66802A8AAA281478824650C4032C1862123C317CF0885"
$script:rancherDesktopVersion = "1.1.1"
$script:windowsBinariesPath = "$env:LOCALAPPDATA\Programs\Rancher Desktop\resources\resources\win32\bin"
$script:linuxBinariesPath = "C:\Users\$env:UserName\AppData\Local\Programs\Rancher Desktop\resources\resources\linux\bin"
$script:rancherDesktopTargetVersion = "1.3.0"
$script:rancherDesktopInstallerName = "Rancher.Desktop.Setup.$script:rancherDesktopTargetVersion"
$script:rancherDesktopUrl = "https://github.com/rancher-sandbox/rancher-desktop/releases/download/v$script:rancherDesktopTargetVersion/$script:rancherDesktopInstallerName.exe"
$script:rancherDesktopInstallerHash = "92108CBBD8C98F99B00A608D8F7D21E12FAECA76F16890585EF212CC5BF1C779"
$script:StaticWindowsDockerdHash = "B63E2B20D66F086C05D85E7E23A61762148F23FABD5D81B20AE3B0CAB797669A"
$script:appDataSettingsPath = "C:\Users\$env:UserName\AppData\Roaming\rancher-desktop\settings.json"

#endregion

#region functions

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

function UpdateRancherDesktop
{

    Write-Host "Updating Rancher Desktop to version $script:rancherDesktopTargetVersion..." -ForegroundColor Blue
    
    if(!(Test-Path -Path $script:rancherDesktopExe))
    {
        Write-Host "Rancher Desktop was not found in the system." -ForegroundColor Red
        exit 1
    }
    elseif ((Get-FileHash -Algorithm SHA256 "$script:rancherDesktopExe").Hash -ne "$script:rancherDesktopExeHash")
    {
        Write-Host "Wrong Rancher Desktop version detected. Please make sure that the version installed is: $script:rancherDesktopVersion" -ForegroundColor Red
        exit 2      
    }
    else # All update preconditions passed
    {
        $WindowsContainers = $false
        $TempFile = New-TemporaryFile
        
        if ((Get-FileHash -Algorithm SHA256 "$script:windowsBinariesPath\dockerd.exe").Hash -eq $script:StaticWindowsDockerdHash)
        {
            # Create backup of dockerd
            Copy-Item "$script:windowsBinariesPath\dockerd.exe" $TempFile -Force
            $WindowsContainers = $true
        }

        $BinariesRenamed = Test-Path -Path "$script:linuxBinariesPath\docker.old"
        
        if(!(Test-Path -Path "$script:rancherDesktopInstallerName.exe") -or (Get-FileHash -Algorithm SHA256 "$script:rancherDesktopInstallerName.exe").Hash -ne "$script:rancherDesktopInstallerHash")
        {
            Invoke-WebRequest $script:rancherDesktopUrl -OutFile "$script:rancherDesktopInstallerName.exe"
            if((Get-FileHash -Algorithm SHA256 "$script:rancherDesktopInstallerName.exe").Hash -ne "$script:rancherDesktopInstallerHash")
            {
                Write-Host "Checksum validation of Rancher Desktop installer failed." -ForegroundColor Red
                exit 3
            }
        }

        #Set default value of "experimentalHostResolver" to "true" in settings.json
        $settingsContent = Get-Content $script:appDataSettingsPath -raw | ConvertFrom-Json
        $settingsContent.kubernetes | Add-Member -NotePropertyName experimentalHostResolver -NotePropertyValue $true
        $settingsContent | ConvertTo-Json | set-content $script:appDataSettingsPath

        Invoke-Expression ".\$script:rancherDesktopInstallerName.exe"

        $setupId = (Get-Process $script:rancherDesktopInstallerName).id 2> $null

        Wait-Process -Id $setupId

        Write-Host "Rancher Desktop successfully updated to version $script:rancherDesktopTargetVersion." -ForegroundColor Green

        if ($WindowsContainers)
        {
            # Restore and remove backup of dockerd
            Stop-Service -Name "docker"
            Copy-Item $TempFile "$script:windowsBinariesPath\dockerd.exe"  -Recurse -Force
            Start-Service -Name "docker"
        }

        Remove-Item $TempFile
        
        if ($BinariesRenamed)
        {
            RenameBinariesFunction
        }
    }
}

#endregion

#region main

# Elevate script if needed.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $($script:parameters)" -Verb RunAs; exit }

UpdateRancherDesktop

Write-Host "Update process finished." -ForegroundColor Green
Write-Host -NoNewLine "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
Stop-Process -Force -Id $PID

#endregion
