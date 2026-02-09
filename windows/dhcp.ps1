function verificador_ip {
    param($ip)
    if ($ip -match '^(\d{1,3}\.){3}\d{1,3}$') {
        $partes = $ip.Split('.')
        if ([int]$partes[0] -le 255 -and [int]$partes[1] -le 255 -and [int]$partes[2] -le 255 -and [int]$partes[3] -le 255) {
            return $true
        }
    }
    return $false
}

function validador_rango {
    param($ip)
    $p = $ip.Split('.')
    return [double]$p[0] * 16777216 + [double]$p[1] * 65536 + [double]$p[2] * 256 + [double]$p[3]
}

function instalacion {
    Write-Host "` VERIFICANDO SI EL SERVIDOR YA EXISTE"
    $aux = Get-WindowsFeature DHCP -ErrorAction SilentlyContinue
    if ($aux.Installed) {
        Write-Host "EL SERVIDOR YA ESTÁ INSTALADO."
    } else {
        Write-Host "INSTALANDO SERVIDOR DE FORMA DESATENDIDA..."
        Install-WindowsFeature DHCP -IncludeManagementTools | Out-Null
        Write-Host "INSTALACIÓN COMPLETADA."
    }
}
Write-Host "===================================================="
Write-Host "         CONFIGURACION DE SERVIDOR DHCP"
Write-Host "===================================================="
instalacion
Write-Host " ORQUESTACIÓN DE CONFIGURACIÓN"
$scopeName = Read-Host "INGRESE NOMBRE DEL ÁMBITO"

while ($true) { 
    $rinicial = Read-Host "IP INICIAL DEL RANGO: "
    $rfinal   = Read-Host "IP FINAL DEL RANGO: "
    
    if ((verificador_ip $rinicial) -and (verificador_ip $rfinal)) {
        if ((validador_rango $rinicial) -le (validador_rango $rfinal)) { break } 
        else { Write-Host "ERROR: La IP inicial debe ser menor a la final." }
    } else { Write-Host "ERROR: Formato de IP inválido." }
}

$tiempoInput = Read-Host "TIEMPO DE CONCESIÓN (Formato HH:mm:ss, ej: 08:00:00)"

while ($true) {
    $dns = Read-Host "IP DEL SERVIDOR DNS"
    if (verificador_ip $dns) { break } else { Write-Host "IP DNS INVÁLIDA" }
}

while ($true) {
    $ptenlace = Read-Host "PUERTA DE ENLACE (GATEWAY)"
    if (verificador_ip $ptenlace) { break } else { Write-Host "IP GATEWAY INVÁLIDA"  }
}
$red = $rinicial.Substring(0, $rinicial.LastIndexOf('.')) + ".0"
Write-Host "CONFIGURANDO INTERFAZ ETHERNET 2..."
$adapter = Get-NetAdapter -Name "Ethernet 2"
$ip_servidor = ($rinicial.Substring(0, $rinicial.LastIndexOf('.')) + ".1")
Remove-NetIPAddress -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $ip_servidor -PrefixLength 24 -Confirm:$false | Out-Null

try {
    Add-DhcpServerv4Scope -Name $scopeName -StartRange $rinicial -EndRange $rfinal -SubnetMask 255.255.255.0 -State Active
    Set-DhcpServerv4OptionValue -OptionId 3 -Value $ptenlace
    Set-DhcpServerv4OptionValue -OptionId 6 -Value $dns
    Set-DhcpServerv4Scope -ScopeId $red -LeaseDuration ([timespan]$tiempoInput)
    Restart-Service DHCPServer
    Write-Host "DHCP CONFIGURADO Y ACTIVO EN ETHERNET 2."
} catch {
    Write-Host "ERROR CRÍTICO: $($_.Exception.Message)"
}
Write-Host "===================================================="
Write-Host "              MONITOREO Y VALIDACIÓN"
Write-Host "===================================================="
Write-Host "1) ESTADO DEL SERVICIO:"
$status = Get-Service DHCPServer
if ($status.Status -eq "Running") {
    Write-Host "   SERVICIO:  EN EJECUCIÓN "
} else {
    Write-Host "   SERVICIO:  DETENIDO "
}

Write-Host "`n2) CONCESIONES (LEASES) ACTIVAS EN $red :"
$leases = Get-DhcpServerv4Lease -ScopeId $red -ErrorAction SilentlyContinue
if ($leases) {
    $leases | Select-Object IPAddress, ClientId, HostName, LeaseExpiryTime | Format-Table -AutoSize
} else {
    Write-Host "   ESPERANDO CONEXIÓN DE CLIENTES..."
}