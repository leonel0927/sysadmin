$interfaz = "Ethernet 2"
function Verificador-Dominio {
    param([string]$Dominio)
    $regex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$"
    if ($Dominio -match $regex) {
        return $true
    } else {
        return $false
    }
}

function Instalar-DNS {
    $check = Get-WindowsFeature -Name DNS
    if ($check.Installed) {
        Write-Host "SERVICIO YA INSTALADO"
    } else {
        Write-Host "SERVICIO NO INSTALADO, INSTALACION AUTOMATICA..."
        Install-WindowsFeature DNS -IncludeManagementTools
        if ((Get-WindowsFeature -Name DNS).Installed) {
            Write-Host "INSTALACION EXITOSA"
        } else {
            Write-Host "ERROR AL INSTALAR"
            exit
        }
    }
}

function Listar-Dominios {
    Write-Host "`nDOMINIO`t`t`tIP ASIGNADA"
    Write-Host "------------------------------------------"
    $Zonas = Get-DnsServerZone | Where-Object { $_.ZoneType -eq "Primary" -and $_.ZoneName -notlike "*in-addr.arpa" -and $_.ZoneName -notmatch "TrustAnchors" }
    
    foreach ($Zona in $Zonas) {
        $Registro = Get-DnsServerResourceRecord -ZoneName $Zona.ZoneName | Where-Object { $_.HostName -eq "@" -and $_.RecordType -eq "A" } | Select-Object -First 1
        $IP = if ($Registro) { $Registro.RecordData.IPv4Address.IPAddressToString } else { "IP no encontrada" }
        Write-Host ("{0,-20} `t {1}" -f $Zona.ZoneName, $IP)
    }
    Write-Host "------------------------------------------"
    Read-Host "ENTER PARA SALIR"
}

function Eliminar-Dominio {
    $DelDom = Read-Host "INGRESE EL NOMBRE DEL DOMINIO A ELIMINAR"
    $Existe = Get-DnsServerZone -Name $DelDom -ErrorAction SilentlyContinue
    
    if ($Existe) {
        $Registro = Get-DnsServerResourceRecord -ZoneName $DelDom | Where-Object { $_.HostName -eq "@" -and $_.RecordType -eq "A" } | Select-Object -First 1
        
        if ($Registro) {
            $IPString = $Registro.RecordData.IPv4Address.IPAddressToString
            $Oct = $IPString.Split('.')
            $ReverseZone = "$($Oct[2]).$($Oct[1]).$($Oct[0]).in-addr.arpa"
            Remove-DnsServerZone -Name $ReverseZone -Force -ErrorAction SilentlyContinue
        }
        
        Remove-DnsServerZone -Name $DelDom -Force
        Write-Host "DOMINIO $DelDom ELIMINADO"
    } else {
        Write-Host "EL DOMINIO '$DelDom' NO EXISTE"
    }
    Read-Host "ENTER PARA SALIR"
}

function Agregar-Dominio {
    while ($true){
    $Dominio = Read-Host "NOMBRE"
        if (-not (Verificador-Dominio $Dominio)) {
        Write-Host "NOMBRE DEL DOMINIO INVALIDO"
        }else{
        break
        }
    }
    . "Z:\FUNCIONES\verificador_ip.ps1"
    $ServerIP = (Get-NetIPAddress -InterfaceAlias $interfaz -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
    while ($true){
    $IP = Read-Host "IP"
    if ([string]::IsNullOrWhiteSpace($IP)){
        $IP=$ServerIP
    }
    if (-not (verificador_ip $IP)){
     Write-Host "IP INVALIDA"
     }else{
        break
     }
    }
    if (-not $ServerIP) {
        Write-Host "SERVIDOR SIN IP, EJECUTANDO DHCP..."
        if (Test-Path ".\dhcp.ps1") {
            .\dhcp.ps1
        } else {
            Write-Host "Error: No se encuentra el archivo dhcp.ps1"
        }
        return
    }

    $Oct = $IP.Split('.')
    $ReverseZone = "$($Oct[2]).$($Oct[1]).$($Oct[0]).in-addr.arpa"

    if (Get-DnsServerZone -Name $Dominio -ErrorAction SilentlyContinue) {
        Write-Host "EL DOMINIO YA EXISTE"
    } else {
        Add-DnsServerPrimaryZone -Name $Dominio -ZoneFile "$Dominio.dns"
        
        Add-DnsServerResourceRecordA -Name "@" -IPv4Address $IP -ZoneName $Dominio
        Add-DnsServerResourceRecordA -Name "www" -IPv4Address $IP -ZoneName $Dominio
        Add-DnsServerResourceRecordA -Name "ns1" -IPv4Address $ServerIP -ZoneName $Dominio
        
        $NetworkID = "$($Oct[0]).$($Oct[1]).$($Oct[2]).0/24"
        if (-not (Get-DnsServerZone -Name $ReverseZone -ErrorAction SilentlyContinue)) {
            Add-DnsServerPrimaryZone -NetworkID $NetworkID -ZoneFile "$ReverseZone.dns"
        }
        
        Add-DnsServerResourceRecordPtr -Name $Oct[3] -ZoneName $ReverseZone -PtrDomainName "$Dominio."
        Add-DnsServerResourceRecordPtr -Name $Oct[3] -ZoneName $ReverseZone -PtrDomainName "www.$Dominio."
        
        Write-Host "DOMINIO CREADO EXITOSAMENTE : $Dominio <-> $IP"
    }
    Read-Host "ENTER PARA SALIR"
}

function Comprobar-Estado {
    $Status = Get-Service -Name DNS
    Write-Host "--- ESTADO DEL SERVICIO ---"
    Write-Host "SERVICIO: $($Status.Status)"
    Read-Host "ENTER PARA SALIR"
}

Instalar-DNS

do {
    Clear-Host
    Write-Host "--- MENU DNS ---"
    Write-Host "1. ESTADO"
    Write-Host "2. AGREGAR DOMINIOS"
    Write-Host "3. LISTAR DOMINIOS"
    Write-Host "4. ELIMINAR DOMINIOS"
    Write-Host "5. DHCP"
    Write-Host "6. SALIR"
    $OPC = Read-Host "Opcion"

    switch ($OPC) {
        "1" { Comprobar-Estado }
        "2" { Agregar-Dominio }
        "3" { Listar-Dominios }
        "4" { Eliminar-Dominio }
        "5" { .\dhcp.ps1 }
        "6" { Write-Host "Cerrando script..."; exit }
        default { Write-Host "Opción inválida." ; Start-Sleep -Seconds 1 }
    }
} while ($true)