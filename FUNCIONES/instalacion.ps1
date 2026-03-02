function verificar_instalacion {
    param ([string]$pak)
    $chequeo = Get-WindowsFeature -Name $pak -ErrorAction SilentlyContinue
    if ($chequeo -and $chequeo.Installed) {
        Write-Host "SERVICIO $pak YA INSTALADO" 
    } else {
        Write-Host "INSTALANDO SERVICIO $pak..." 
        try {
            Install-WindowsFeature -Name $pak -IncludeManagementTools -ErrorAction Stop
        }
        catch {
            $cap = Get-WindowsCapability -Online | Where-Object Name -like "$pak*"
            Add-WindowsCapability -Online -Name $cap.Name -ErrorAction SilentlyContinue
        }
    }
}