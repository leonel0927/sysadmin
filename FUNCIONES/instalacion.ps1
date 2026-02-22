function instalar {
    param ([string]$pak)
    $chequeo = Get-WindowsFeature -Name $pak
    if ($chequeo.Installed) {
        Write-Host "SERVICIO $pak YA INSTALADO" 
    } else {
        Write-Host "INSTALANDO SERVICIO $pak..." 
        Install-WindowsFeature -Name $pak -IncludeManagementTools
    }
}