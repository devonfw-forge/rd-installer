if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $($args)" -Verb RunAs; exit }

Start-Service docker

Add-AccountToDockerAccess "$env:UserDomain\$env:UserDomain"
