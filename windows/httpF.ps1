
function Validar-Puerto {
    param ([int]$Puerto)
    $Reservados = @(21, 22, 23, 25, 53, 110, 143, 443, 445, 3306, 3389, 5432)

    if ($Puerto -lt 1 -or $Puerto -gt 65535) {
        Write-Host "ERROR: Puerto fuera de rango valido (1-65535)." -ForegroundColor Red
        return $false
    }
    if ($Reservados -contains $Puerto) {
        Write-Host "ALERTA: El puerto $Puerto es critico/reservado. Elija otro (ej. 8000, 8080, 9000)." -ForegroundColor Red
        return $false
    }
    if (Get-NetTCPConnection -LocalPort $Puerto -ErrorAction SilentlyContinue) {
        Write-Host "ERROR: El puerto $Puerto ya esta siendo usado por otro proceso." -ForegroundColor Red
        return $false
    }
    return $true
}
function Obtener-Versiones-Choco {
    param ([string]$Paquete)

    Write-Host "Consultando versiones disponibles de $Paquete en Chocolatey..." -ForegroundColor Cyan
    $resultado = & choco search $Paquete --exact 2>$null

    $lineas = @()
    foreach ($linea in $resultado) {
        $linea = $linea.Trim()
        $partes = $linea -split "\s+"
        if ($partes.Count -ge 2) {
            $nombre = $partes[0]
            $ver    = $partes[1]
            if ($nombre -eq $Paquete -and $ver -match "^\d+\.\d+[\d\.]*$") {
                $lineas += $ver
            }
        }
    }

    if ($lineas.Count -eq 0) {
        Write-Host "No se encontraron versiones para '$Paquete'." -ForegroundColor Red
        return $null
    }

    return $lineas
}

function Seleccionar-Version {
    param ([string]$Paquete)

    $versiones = Obtener-Versiones-Choco -Paquete $Paquete
    if (-not $versiones) { return $null }

    Write-Host ""
    Write-Host "Versiones disponibles para $Paquete`:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $versiones.Count; $i++) {
        $etiqueta = ""
        if ($i -eq 0)                        { $etiqueta = " [Latest/Development]" }
        if ($i -eq ($versiones.Count - 1))   { $etiqueta = " [LTS/Estable]" }
        Write-Host "  $($i+1). $($versiones[$i])$etiqueta"
    }

    do {
        $sel = Read-Host "Seleccione numero de version"
        $sel = $sel -replace '[^0-9]', ''   # Solo digitos
    } while ([string]::IsNullOrWhiteSpace($sel) -or [int]$sel -lt 1 -or [int]$sel -gt $versiones.Count)

    $versionElegida = $versiones[[int]$sel - 1]
    Write-Host ""
    Write-Host ">>> Version seleccionada: $versionElegida <<<" -ForegroundColor Green
    Write-Host ""
    return $versionElegida
}
function Crear-Pagina-Prueba {
    param (
        [string]$Ruta,
        [string]$Servicio,
        [string]$Version,
        [int]$Puerto
    )

    $Contenido = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>$Servicio</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 80px; background: #f0f4f8; }
        .card { display: inline-block; padding: 40px 60px; background: white;
                border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; } span.ok { color: #27ae60; font-weight: bold; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Servidor</h1>
        <h2>Servidor: <span class="ok">$Servicio</span></h2>
        <h3>Version: $Version</h3>
        <h3>Puerto: $Puerto</h3>
    </div>
</body>
</html>
"@

    if (!(Test-Path $Ruta)) {
        New-Item -ItemType Directory -Path $Ruta -Force | Out-Null
    }
    $Contenido | Set-Content -Path "$Ruta\index.html" -Encoding UTF8
    Write-Host "Pagina index.html creada en: $Ruta" -ForegroundColor Green
}

function Aplicar-Seguridad-IIS {
    param ([string]$SitioNombre = "Default Web Site")

    Write-Host "Aplicando configuracion de seguridad en IIS..." -ForegroundColor Cyan

    try {
        Remove-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST" `
            -Filter "system.webServer/httpProtocol/customHeaders" `
            -Name "." -AtElement @{name="X-Powered-By"} -ErrorAction SilentlyContinue
    } catch {}

    $headers = @(
        @{ name = "X-Frame-Options";        value = "SAMEORIGIN" },
        @{ name = "X-Content-Type-Options"; value = "nosniff" }
    )
    foreach ($h in $headers) {
        try {
            Add-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST" `
                -Filter "system.webServer/httpProtocol/customHeaders" `
                -Name "." -Value $h -ErrorAction SilentlyContinue
        } catch {}
    }

    try {
        Add-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST/$SitioNombre" `
            -Filter "system.webServer/security/requestFiltering/verbs" `
            -Name "." -Value @{ verb = "TRACE"; allowed = "false" } -ErrorAction SilentlyContinue
        Add-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST/$SitioNombre" `
            -Filter "system.webServer/security/requestFiltering/verbs" `
            -Name "." -Value @{ verb = "TRACK"; allowed = "false" } -ErrorAction SilentlyContinue
        Add-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST/$SitioNombre" `
            -Filter "system.webServer/security/requestFiltering/verbs" `
            -Name "." -Value @{ verb = "DELETE"; allowed = "false" } -ErrorAction SilentlyContinue
    } catch {}

    Write-Host "Seguridad IIS aplicada (X-Powered-By eliminado, headers de seguridad, metodos bloqueados)." -ForegroundColor Green
}

function Configurar-Firewall {
    param ([int]$Puerto, [string]$Servicio)

    Write-Host "Configurando firewall para puerto $Puerto..." -ForegroundColor Cyan

    Get-NetFirewallRule -DisplayName "HTTP-$Servicio-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule

    New-NetFirewallRule -DisplayName "HTTP-$Servicio-$Puerto" `
        -Direction Inbound -LocalPort $Puerto -Protocol TCP `
        -Action Allow -ErrorAction SilentlyContinue | Out-Null

    if ($Puerto -ne 80) {
        if (-not (Get-NetTCPConnection -LocalPort 80 -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName "HTTP-Block-80" `
                -Direction Inbound -LocalPort 80 -Protocol TCP `
                -Action Block -ErrorAction SilentlyContinue | Out-Null
            Write-Host "Puerto 80 bloqueado (no esta en uso)." -ForegroundColor Yellow
        }
    }

    Write-Host "Firewall configurado: puerto $Puerto abierto." -ForegroundColor Green
}

function Crear-Usuario-Dedicado {
    param ([string]$NombreUsuario, [string]$Directorio)

    Write-Host "Configurando usuario dedicado: $NombreUsuario..." -ForegroundColor Cyan

    if (-not (Get-LocalUser -Name $NombreUsuario -ErrorAction SilentlyContinue)) {
        $Password = ConvertTo-SecureString "Srv!2024$NombreUsuario" -AsPlainText -Force
        New-LocalUser -Name $NombreUsuario -Password $Password `
            -FullName "Dedicated $NombreUsuario Service Account" `
            -Description "Usuario dedicado para servicio web" `
            -PasswordNeverExpires -UserMayNotChangePassword | Out-Null
        Write-Host "Usuario '$NombreUsuario' creado." -ForegroundColor Green
    }

    if (Test-Path $Directorio) {
        $acl = Get-Acl $Directorio
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $NombreUsuario, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow"
        )
        $acl.AddAccessRule($rule)
        Set-Acl -Path $Directorio -AclObject $acl
        Write-Host "Permisos NTFS aplicados para '$NombreUsuario' en '$Directorio'." -ForegroundColor Green
    }
}

function Instalar-IIS {
    param ([int]$Puerto)

    $Version = "10.0 (Windows Server 2019)"
    Write-Host "`n[IIS] Verificando instalacion..." -ForegroundColor Cyan

    $feature = Get-WindowsFeature Web-Server -ErrorAction SilentlyContinue
    if (-not $feature) {
        Write-Host "ERROR: No se puede verificar caracteristicas de Windows. Asegurese de ejecutar como Administrador." -ForegroundColor Red
        Pause; return
    }
    if (-not $feature.Installed) {
        Write-Host "IIS no encontrado. Instalando IIS y herramientas..." -ForegroundColor Yellow
        $result = Install-WindowsFeature -Name Web-Server -IncludeManagementTools
        Install-WindowsFeature -Name Web-Security | Out-Null
        if ($result.Success) {
            Write-Host "IIS instalado correctamente." -ForegroundColor Green
        } else {
            Write-Host "ERROR: Fallo la instalacion de IIS." -ForegroundColor Red
            Pause; return
        }
    } else {
        Write-Host "IIS ya esta instalado." -ForegroundColor Green
    }

    Import-Module WebAdministration -ErrorAction SilentlyContinue

    Stop-Service W3SVC -ErrorAction SilentlyContinue

    Write-Host "Configurando puerto $Puerto en IIS..." -ForegroundColor Yellow
    Get-WebBinding -Name "Default Web Site" -ErrorAction SilentlyContinue | Remove-WebBinding
    New-WebBinding -Name "Default Web Site" -Protocol "http" -Port $Puerto -IPAddress "*"

    Crear-Pagina-Prueba -Ruta "C:\inetpub\wwwroot" -Servicio "IIS (Internet Information Services)" -Version $Version -Puerto $Puerto
    Aplicar-Seguridad-IIS
    Configurar-Firewall -Puerto $Puerto -Servicio "IIS"

    Start-Service W3SVC -ErrorAction SilentlyContinue
    Write-Host "[IIS] Desplegado correctamente en puerto $Puerto." -ForegroundColor Green
    Pause
}

function Instalar-Apache {
    param (
        [int]$PuertoGeneral 
    )

    $Version = Seleccionar-Version -Paquete "apache-httpd"
    if (-not $Version) {
        Write-Host "No se pudo obtener version de Apache. Abortando." -ForegroundColor Red
        Pause; return
    }

    Write-Host "`n[Apache] Version seleccionada: $Version" -ForegroundColor Cyan

    $apacheRoot = Get-ChildItem "C:\tools" -Directory -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -match "(?i)^apache" -and (Test-Path "$($_.FullName)\bin\httpd.exe") } |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 1 -ExpandProperty FullName

    if (-not $apacheRoot) {
        Write-Host "Apache no encontrado. Instalando via Chocolatey..." -ForegroundColor Yellow
        choco install apache-httpd -y --force
        Start-Sleep -Seconds 3

        $zipPath = "C:\ProgramData\chocolatey\lib\apache-httpd\tools\httpd-2.4.55-o111s-x64-vs17.zip"
        if (Test-Path $zipPath) {
            Write-Host "Extrayendo Apache desde ZIP..." -ForegroundColor Yellow
            Expand-Archive -Path $zipPath -DestinationPath "C:\tools" -Force
            Start-Sleep -Seconds 3
        } else {
            $zipAlt = Get-ChildItem "C:\ProgramData\chocolatey\lib\apache-httpd\tools" -Filter "*x64*.zip" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($zipAlt) {
                Write-Host "Extrayendo Apache desde: $($zipAlt.FullName)" -ForegroundColor Yellow
                Expand-Archive -Path $zipAlt.FullName -DestinationPath "C:\tools" -Force
                Start-Sleep -Seconds 3
            }
        }

        $apacheRoot = Get-ChildItem "C:\tools" -Directory -ErrorAction SilentlyContinue |
                      Where-Object { $_.Name -match "(?i)^apache" -and (Test-Path "$($_.FullName)\bin\httpd.exe") } |
                      Sort-Object LastWriteTime -Descending |
                      Select-Object -First 1 -ExpandProperty FullName

        if (-not $apacheRoot) {
            Write-Host "ERROR: No se encontro Apache tras la instalacion." -ForegroundColor Red
            Pause; return
        }
    } else {
        Write-Host "Apache ya instalado en: $apacheRoot" -ForegroundColor Green
    }

    $apacheRootEscaped = $apacheRoot -replace '\\', '/'
    Stop-Service Apache2.4 -ErrorAction SilentlyContinue

    Write-Host "Generando certificados SSL autofirmados..." -ForegroundColor Cyan
    $binPath = "$apacheRoot\bin"
    if (Test-Path "$binPath\openssl.exe") {
        $subject = "/C=MX/ST=Sinaloa/L=Mochis/O=UAS/OU=FIM/CN=localhost"
        Start-Process "$binPath\openssl.exe" -ArgumentList "req -config ..\conf\openssl.cnf -new -out ..\conf\server.csr -keyout ..\conf\server.key -nodes -x509 -days 365 -subj `"$subject`" -out ..\conf\server.crt" -WorkingDirectory $binPath -Wait
        Write-Host "Certificados creados exitosamente." -ForegroundColor Green
    }

    $confPath = "$apacheRoot\conf\httpd.conf"
    if (Test-Path $confPath) {
        $conf = Get-Content $confPath
        $conf = $conf -replace '#LoadModule ssl_module', 'LoadModule ssl_module'
        $conf = $conf -replace '#LoadModule socache_shmcb_module', 'LoadModule socache_shmcb_module'
        $conf = $conf -replace '#Include conf/extra/httpd-ssl.conf', 'Include conf/extra/httpd-ssl.conf'
        $conf = $conf -replace 'Include conf/extra/httpd-ahssl.conf', '#Include conf/extra/httpd-ahssl.conf'

        $conf = $conf -replace '^ServerRoot.*', "ServerRoot `"$apacheRootEscaped`""
        $conf = $conf -replace 'Listen\s+\d+', "#Listen $PuertoGeneral"
        $conf = $conf -replace '^ServerName.*', "ServerName localhost:$PuertoGeneral"

        $conf | Set-Content $confPath
    }

    $sslConfPath = "$apacheRoot\conf\extra\httpd-ssl.conf"
    if (Test-Path $sslConfPath) {
        $sslConf = Get-Content $sslConfPath
        $sslConf = $sslConf -replace 'Listen\s+\d+', "Listen $PuertoGeneral"
        $sslConf = $sslConf -replace '<VirtualHost _default_:\d+>', "<VirtualHost _default_:$PuertoGeneral>"
        $sslConf = $sslConf -replace 'ServerName.*', "ServerName localhost:$PuertoGeneral"
        
        $sslConf = $sslConf -replace 'SSLCertificateFile.*', "SSLCertificateFile `"$apacheRootEscaped/conf/server.crt`""
        $sslConf = $sslConf -replace 'SSLCertificateKeyFile.*', "SSLCertificateKeyFile `"$apacheRootEscaped/conf/server.key`""
        $sslConf = $sslConf -replace 'DocumentRoot.*', "DocumentRoot `"$apacheRootEscaped/htdocs`""
        
        $sslConf | Set-Content $sslConfPath
        Write-Host "Archivo SSL configurado en puerto $PuertoGeneral." -ForegroundColor Green
    }

    $htdocsDir = "$apacheRoot\htdocs"
    if (-not (Test-Path $htdocsDir)) {
        New-Item -ItemType Directory -Path $htdocsDir -Force | Out-Null
    }

    Crear-Usuario-Dedicado -NombreUsuario "svc_apache" -Directorio $htdocsDir
    Crear-Pagina-Prueba -Ruta $htdocsDir -Servicio "Apache HTTP Server" -Version $Version -Puerto $PuertoGeneral
    Configurar-Firewall -Puerto $PuertoGeneral -Servicio "Apache SSL"

    $httpdExe = "$apacheRoot\bin\httpd.exe"
    $apacheSvc = Get-Service Apache2.4 -ErrorAction SilentlyContinue
    if ($apacheSvc) {
        Start-Service Apache2.4 -ErrorAction SilentlyContinue
        Write-Host "Servicio Apache2.4 iniciado." -ForegroundColor Green
    } elseif (Test-Path $httpdExe) {
        Start-Process $httpdExe -WorkingDirectory "$apacheRoot\bin" -ErrorAction SilentlyContinue
        Write-Host "Apache iniciado desde bin." -ForegroundColor Green
    }

    Write-Host "[Apache] Desplegado con SSL en el puerto $PuertoGeneral." -ForegroundColor Green
    Pause
}
function Instalar-Nginx {
    param ([int]$Puerto)
    $Version = Seleccionar-Version -Paquete "nginx"
    if (-not $Version) {
        Write-Host "No se pudo obtener version de Nginx. Abortando." -ForegroundColor Red
        Pause; return
    }

    Write-Host "`n[Nginx] Instalando version $Version..." -ForegroundColor Cyan

    Stop-Process -Name nginx -Force -ErrorAction SilentlyContinue

    $nginxYaInstalado = Get-ChildItem "C:\tools" -Directory -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -match "^nginx" -and (Test-Path "$($_.FullName)\nginx.exe") } |
                        Select-Object -First 1

    if (-not $nginxYaInstalado) {
        Write-Host "Instalando Nginx $Version via Chocolatey..." -ForegroundColor Yellow
        choco install nginx -y
    } else {
        Write-Host "Nginx ya instalado en: $($nginxYaInstalado.FullName)" -ForegroundColor Yellow
    }

    $nginxRoot = Get-ChildItem "C:\tools" -Directory -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -match "^nginx" } |
                 Where-Object { Test-Path "$($_.FullName)\nginx.exe" } |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 1 -ExpandProperty FullName

    if (-not $nginxRoot) {
        $nginxRoot = Get-ChildItem "C:\tools" -Directory -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -match "^nginx" } |
                     Sort-Object LastWriteTime -Descending |
                     Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $nginxRoot) {
        $nginxRoot = "C:\tools\nginx"
        Write-Host "ADVERTENCIA: No se encontro carpeta nginx en C:\tools." -ForegroundColor Yellow
    }

    Write-Host "Directorio nginx detectado: $nginxRoot" -ForegroundColor Cyan

    $confPath = "$nginxRoot\conf\nginx.conf"
    if (Test-Path $confPath) {
        (Get-Content $confPath) -replace 'listen\s+\d+;', "listen $Puerto;" | Set-Content $confPath
        Write-Host "Puerto $Puerto configurado en: $confPath" -ForegroundColor Green
    } else {
        Write-Host "ADVERTENCIA: No se encontro nginx.conf en $confPath" -ForegroundColor Yellow
    }

    $htmlDir = "$nginxRoot\html"
    if (-not (Test-Path $htmlDir)) {
        New-Item -ItemType Directory -Path $htmlDir -Force | Out-Null
    }

    Crear-Usuario-Dedicado -NombreUsuario "svc_nginx" -Directorio $htmlDir

    Crear-Pagina-Prueba -Ruta $htmlDir -Servicio "Nginx Open Source" -Version $Version -Puerto $Puerto
    Configurar-Firewall -Puerto $Puerto -Servicio "Nginx"

    $nginxExe = "$nginxRoot\nginx.exe"
    if (Test-Path $nginxExe) {
        Start-Process $nginxExe -WorkingDirectory $nginxRoot -ErrorAction SilentlyContinue
        Write-Host "Nginx iniciado desde: $nginxExe" -ForegroundColor Green
    } else {
        Write-Host "ADVERTENCIA: No se encontro nginx.exe en $nginxRoot" -ForegroundColor Yellow
    }
    Write-Host "[Nginx] Desplegado en puerto $Puerto con version $Version." -ForegroundColor Green
    Pause
}