    . "Z:\Funciones\verificador_ip.ps1"
    . "Z:\Funciones\instalacion.ps1"
    . "Z:\Funciones\status.ps1"
function comparar_red {
    param($ip1, $ip2)
    $red1 = $ip1.Substring(0, $ip1.LastIndexOf('.'))
    $red2 = $ip2.Substring(0, $ip2.LastIndexOf('.'))
    
    if ($red1 -eq $red2) { return $true }
    return $false
}

function validador_rango {
    param($ip)
    $p = $ip.Split('.')
    return [double]$p[0] * 16777216 + [double]$p[1] * 65536 + [double]$p[2] * 256 + [double]$p[3]
}

function instalacion {
  verificar_instalacion "DHCP"
  Read-Host "ENTER PARA SALIR"
}

function configurar_dhcp {
    Write-Host "--- NUEVA CONFIGURACIÓN DE ÁMBITO ---"
    $scopeName = Read-Host "NOMBRE DEL ÁMBITO"
    while ($true) { 
        $rinicial = Read-Host "IP INICIAL DEL RANGO"
        $rfinal   = Read-Host "IP FINAL DEL RANGO"
        if ((verificador_ip "$rinicial") -and ("verificador_ip $rfinal")) {
            if (comparar_red $rinicial $rfinal) {
                if ((validador_rango $rinicial) -le (validador_rango $rfinal)) { break } 
                else { Write-Host "ERROR: La IP inicial debe ser menor a la final." }
            } else { Write-Host "ERROR: La IP inicial y final deben pertenecer a la misma red." }
        } else { Write-Host "ERROR: Formato de IP inválido o fuera de rango." }
    }
while ($true) { 
    $tiempoInput = Read-Host "TIEMPO DE CONCESIÓN: "
    if ($tiempoInput -match "^\d+$" -and [int]$tiempoInput -gt 0){
	$tiempoInput = [int]$tiempoInput
	break
    }else{
	Write-Host "ERROR: El numero debe ser mayor a 0 y entero"
	}
}
    while ($true) {
        $dns = Read-Host "IP DEL SERVIDOR DNS"
        if ( [string]::IsNullOrWhiteSpace($dns) -or (verificador_ip "$dns")) {
               break  
        } else { Write-Host "IP DNS INVÁLIDA" }
    }

    while ($true) {
        $ptenlace = Read-Host "PUERTA DE ENLACE (GATEWAY)"
        if ( [string]::IsNullOrWhiteSpace($ptenalce) -or (verificador_ip "$ptenlace")) {
            break
        } else { Write-Host "IP GATEWAY INVÁLIDA" }
    }
    $red = $rinicial.Substring(0, $rinicial.LastIndexOf('.')) + ".0"
    $ip_servidor = $rinicial.Trim()
    Write-Host "CONFIGURANDO INTERFAZ ETHERNET 2..."
    $adapter = Get-NetAdapter -Name "Ethernet 2" -ErrorAction Stop
    Remove-NetIPAddress -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
    New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $ip_servidor -PrefixLength 24 -Confirm:$false | Out-Null
    $octetos = $rinicial.Split('.')
    $ultimo = [int]$octetos[3] + 1
    $rcliente = "$($octetos[0]).$($octetos[1]).$($octetos[2]).$ultimo"	
    try {
	
        Add-DhcpServerv4Scope -Name $scopeName -StartRange $rcliente -EndRange $rfinal -SubnetMask 255.255.255.0 -State Active
        if (-not [string]::IsNullOrWhiteSpace($ptenlace)) {
		Set-DhcpServerv4OptionValue -OptionId 3 -Value $ptenlace
	}
        if (-not [string]::IsNullOrWhiteSpace($dns)) {
		Set-DhcpServerv4OptionValue -OptionId 6 -Value $dns
	}
        Set-DhcpServerv4Scope -ScopeId $red -LeaseDuration ([timespan]::FromSeconds($tiempoInput))
        Restart-Service DHCPServer
        Write-Host "DHCP CONFIGURADO Y ACTIVO EN ETHERNET 2."
    } catch {
        Write-Host "ERROR CRÍTICO: $($_.Exception.Message)"
    }
    Pause
}

function monitoreo {
    Write-Host "===================================================="
    Write-Host "              MONITOREO Y VALIDACIÓN"
    Write-Host "===================================================="
    status "DHCP"
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
    Write-Host "      1. Configurar nuevo ambito (Scope)"
    Write-Host "      2. Monitorear clientes conectados"
    Write-Host "      3. Salir"
    Write-Host "      ******************************************"
    $opcion = Read-Host "Seleccione una opción [1-3]"
    switch ($opcion) {
        "1" { configurar_dhcp }
        "2" { monitoreo }
        "3" { Write-Host "Saliendo..."; exit }
        default { Write-Host "Opcion no valida."; }
    }
}
