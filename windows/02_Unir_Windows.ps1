$dominioFQDN = "practica.local"
$servidorDNS = "192.168.117.11"
$interfaz = "Ethernet 3"

Write-Host "Configurando DNS..."
Set-DnsClientServerAddress -InterfaceAlias $interfaz -ServerAddresses $servidorDNS
Write-Host "DNS configurado: $servidorDNS"

Write-Host "Verificando conectividad con el servidor..."
if (-not (Test-Connection -ComputerName $servidorDNS -Count 2 -Quiet)) {
    Write-Host "No se puede alcanzar el servidor $servidorDNS. Verifica la red."
    exit
}

Write-Host "Conectividad OK."
Write-Host "Uniendo al dominio $dominioFQDN..."

Add-Computer -DomainName $dominioFQDN `
    -Credential (Get-Credential -Message "Credenciales de Administrador del dominio practica.local") `
    -Restart -Force