function verificador_ip {
    param($ip)
    # Regex igual al de Linux
    if ($ip -match '^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$') {
        $partes = $matches[1], $matches[2], $matches[3], $matches[4]
        foreach ($p in $partes) {
            if ([int]$p -gt 255) { return $false }
        }
        $v = [double]$partes[0] * 16777216 + [double]$partes[1] * 65536 + [double]$partes[2] * 256 + [double]$partes[3]
        $min = 16777217    # 1.0.0.1
        $max = 4294967294  # 255.255.255.254
        if ($v -lt $min -or $v -gt $max) { return $false }
        return $true
    }
    return $false
}

function validador_rango {
    param($ip)
    $p = $ip.Split('.')
    return [double]$p[0] * 16777216 + [double]$p[1] * 65536 + [double]$p[2] * 256 + [double]$p[3]
}
function instalacion {
    Write-Host "VERIFICANDO ROL DHCP..."
    $aux = Get-WindowsFeature DHCP -ErrorAction SilentlyContinue
    if ($aux.Installed) {
        Write-Host "ESTADO: INSTALADO"
    } else {
        Write-Host "INSTALANDO ROL DHCP..."
        Install-WindowsFeature DHCP -IncludeManagementTools | Out-Null
        Write-Host "INSTALACIÓN COMPLETADA."
    }
}

function configurar_dhcp {
    Write-Host "--- NUEVA CONFIGURACIÓN DE ÁMBITO ---"
    $scopeName = Read-Host "NOMBRE DEL ÁMBITO"
    while ($true) { 
        $rinicial = Read-Host "IP INICIAL DEL RANGO"
        $rfinal   = Read-Host "IP FINAL DEL RANGO"
        if ((verificador_ip $rinicial) -and (verificador_ip $rfinal)) {
            if ((validador_rango $rinicial) -le (validador_rango $rfinal)) { break } 
            else { Write-Host "ERROR: La IP inicial debe ser menor a la final." }
        } else { Write-Host "ERROR: Formato de IP inválido o fuera de rango (1.0.0.1 - 255.255.255.254)." }
    }
    $tiempoInput = Read-Host "TIEMPO DE CONCESIÓN (HH:mm:ss, ej: 08:00:00)"
    while ($true) {
        $dns = Read-Host "IP DEL SERVIDOR DNS"
        if (verificador_ip $dns) { break } else { Write-Host "IP DNS INVÁLIDA" }
    }
    while ($true) {
        $ptenlace = Read-Host "PUERTA DE ENLACE (GATEWAY)"
        if (verificador_ip $ptenlace) { break } else { Write-Host "IP GATEWAY INVÁLIDA" }
    }
    $red = $rinicial.Substring(0, $rinicial.LastIndexOf('.')) + ".0"
    $ip_servidor = ($rinicial.Substring(0, $rinicial.LastIndexOf('.')) + ".1")
    Write-Host "CONFIGURANDO INTERFAZ ETHERNET 2..."
    $adapter = Get-NetAdapter -Name "Ethernet 2" -ErrorAction Stop
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
    Pause
}
function monitoreo {
    Write-Host "===================================================="
    Write-Host "             MONITOREO Y VALIDACIÓN"
    Write-Host "===================================================="
    $status = Get-Service DHCPServer -ErrorAction SilentlyContinue
    if ($status.Status -eq "Running") {
        Write-Host "SERVICIO:  EN EJECUCIÓN "
    } else {
        Write-Host "SERVICIO:  DETENIDO "
    }
    Write-Host "CONCESIONES (LEASES) ACTIVAS:"
    $scopes = Get-DhcpServerv4Scope
    foreach ($s in $scopes) {
        Write-Host "Ámbito: $($s.ScopeId)"
        $leases = Get-DhcpServerv4Lease -ScopeId $s.ScopeId -ErrorAction SilentlyContinue
        if ($leases) {
            $leases | Select-Object IPAddress, ClientId, HostName, LeaseExpiryTime | Format-Table -AutoSize
        } else {
            Write-Host "   Esperando conexión de clientes..."
        }
    }
    Write-Host "===================================================="
}
instalacion
while ($true) {
    Write-Host "      ******************************************"
    Write-Host "      * PANEL DE CONTROL DHCP (WINDOWS SERVER) *"
    Write-Host "      ******************************************"
    Write-Host "      1. Configurar nuevo ámbito (Scope)"
    Write-Host "      2. Monitorear clientes conectados"
    Write-Host "      3. Salir"
    Write-Host "      ******************************************"
    $opcion = Read-Host "Seleccione una opción [1-3]"
    switch ($opcion) {
        "1" { configurar_dhcp }
        "2" { monitoreo }
        "3" { Write-Host "Saliendo..."; exit }
        default { Write-Host "Opción no válida."; }
    }
}