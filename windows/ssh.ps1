  . "Z:\Funciones\instalacion.ps1"
  . "Z:\Funciones\status.ps1"
function Activador {
    Clear-Host
    Write-Host "       ACTIVANDO SSH       "
    Write-Host "Configurando servicio"
    Set-Service sshd -StartupType Automatic -ErrorAction SilentlyContinue
    Restart-Service sshd -ErrorAction SilentlyContinue
    if (!(Get-NetFirewallRule -Name "OpenSSH-Port-22" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name "OpenSSH-Port-22" -DisplayName "OpenSSH-Server-In-TCP" -Enabled True -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow | Out-Null
    }
    $ipMostrar = Get-NetIPAddress -InterfaceAlias "Ethernet 3" -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
                 Select-Object -ExpandProperty IPAddress -First 1

    Write-Host "------------------------------------------------"
    if ((Get-Service sshd).Status -eq "Running") {
        Write-Host " SERVIDOR ACTIVO"
        Write-Host " IP FIJA DETECTADA: $ipMostrar"
    } else {
        Write-Host " ERROR AL INICIAR SERVICIO"
    }
    Write-Host "------------------------------------------------"
    
    Pause
}
while ($true) {
    Clear-Host
    Write-Host "*********** SERVIDOR SSH  ***********"
    Write-Host "1) Instalar"
    Write-Host "2) Estado"
    Write-Host "3) Activar"
    Write-Host "4) Salir"
    
    $opc = Read-Host "Opcion"

    switch ($opc) {
        "1" { instalar "OpenSSH.Server" }
        "2" { status "sshd" }
        "3" { Activador }
        "4" { 
            Write-Host "Cerrando script..."
            exit 
        }
        Default { Write-Host "Opción inválida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}