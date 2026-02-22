  . "Z:\Funciones\instalacion.ps1"
  . "Z:\Funciones\status.ps1"
function Activador {
    Clear-Host
    Write-Host "ACTIVANDO SERVIDOR Y CONFIGURANDO RED..."
    Stop-Service sshd -ErrorAction SilentlyContinue
    $interfaz = "Ethernet 2" 
    $ip = "192.168.1.1"
    $mask = 24
    Remove-NetIPAddress -InterfaceAlias $interfaz -Confirm:$false -ErrorAction SilentlyContinue
    New-NetIPAddress -InterfaceAlias $interfaz -IPAddress $ip -PrefixLength $mask -ErrorAction SilentlyContinue
    Start-Service sshd
    Set-Service sshd -StartupType Automatic
     if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (TCP-In)" -Enabled True -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow
    }

    Write-Host "SERVIDOR ACTIVADO CON LA IP: $ip"
    Pause
}
function Desactivador {
    Clear-Host
    Write-Host "DESACTIVANDO SERVIDOR..."
    Stop-Service sshd
    Set-Service sshd -StartupType Disabled
    Write-Host "SERVIDOR DESACTIVADO"
    Pause
}
while ($true) {
    Clear-Host
    Write-Host "*********** SERVIDOR SSH  ***********"
    Write-Host "1) Instalar"
    Write-Host "2) Estado"
    Write-Host "3) Activar"
    Write-Host "4) Desactivar"
    Write-Host "5) Salir"
    
    $opc = Read-Host "Opcion"

    switch ($opc) {
        "1" { instalar "OpenSSH.Server" }
        "2" { status "sshd" }
        "3" { Activador }
        "4" { Desactivador }
        "5" { 
            Write-Host "Cerrando script..."
            exit 
        }
        Default { Write-Host "Opción inválida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}