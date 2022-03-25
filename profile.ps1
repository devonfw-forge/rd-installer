# Path to the docker binaries
$dockerBinaries = "C:\Users\$env:UserName\AppData\Local\Programs\Rancher Desktop\resources\resources\win32\bin"

# Set 'docker' as an alias for nerdctl
Set-Alias docker nerdctl

# Set 'docker-compose as an alias for nerdctl compose
function docker-compose
{
    nerdctl compose $args
}

# Set 'dockerw' as an alias for docker --context win
function dockerw
{
    & $dockerBinaries\docker.exe --context win $args
}


# Set 'dockerw-compose' as an alias for docker-compose --context win
function dockerw-compose
{
    & $dockerBinaries\docker-compose.exe --context win $args
}

# Set 'dockerw-start' as an alias for the start.ps1 script
function dockerw-start
{
    & $dockerBinaries\start.ps1
}

# Start the VPN support
wsl -d wsl-vpnkit service wsl-vpnkit start