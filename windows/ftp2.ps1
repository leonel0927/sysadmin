$FTP_IP   = "192.168.117.11"
$FTP_REPO = "servidores"

function Preparar-ServidorFTP {
    Write-Host "--- Iniciando configuracion del Servidor FTP ---"

    if (Test-Path "C:\FTP") {
        cmd /c "takeown /f C:\FTP /r /d s >nul 2>nul"
        cmd /c "icacls C:\FTP /grant Administradores:(OI)(CI)F /T /Q >nul 2>nul"
        icacls "C:\FTP" /reset /t /c /l | Out-Null
    }

    Install-WindowsFeature Web-Server, Web-FTP-Service, Web-FTP-Server, Web-Basic-Auth -IncludeAllSubFeature -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "Acceso_FTP" -Direction Inbound -Protocol TCP -LocalPort 21 -Action Allow -ErrorAction SilentlyContinue
    Import-Module WebAdministration

    secedit /export /cfg C:\secpol.cfg | Out-Null
    (Get-Content C:\secpol.cfg) -replace 'PasswordComplexity = 1', 'PasswordComplexity = 0' | Out-File C:\secpol.cfg
    secedit /configure /db C:\Windows\security\local.sdb /cfg C:\secpol.cfg /areas SECURITYPOLICY | Out-Null
    Remove-Item C:\secpol.cfg -Force -ErrorAction SilentlyContinue

    if (-not (Test-Path "C:\FTP\LocalUser\Public\General")) {
        New-Item -Path "C:\FTP\LocalUser\Public\General" -ItemType Directory -Force | Out-Null
    }

    foreach ($svc in @("IIS", "Apache", "Nginx")) {
        $dir = "C:\FTP\servidores\Windows\$svc"
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-Host "  Creada: $dir"
        }
    }

    icacls "C:\FTP\LocalUser\Public" /inheritance:r | Out-Null
    icacls "C:\FTP\LocalUser\Public" /grant "IUSR:(OI)(CI)RX" | Out-Null
    icacls "C:\FTP\LocalUser\Public" /grant "SYSTEM:(OI)(CI)F" | Out-Null
    icacls "C:\FTP\LocalUser\Public" /grant "Administrators:(OI)(CI)F" | Out-Null

    if (-not (Get-WebSite -Name "FTP" -ErrorAction SilentlyContinue)) {
        New-WebFtpSite -Name "FTP" -Port 21 -PhysicalPath "C:\FTP"
    }

    Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.userIsolation.mode -Value "IsolateAllDirectories"
    Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.ssl.controlChannelPolicy -Value 0
    Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.ssl.dataChannelPolicy -Value 0

    Clear-WebConfiguration -Filter "/system.ftpServer/security/authorization" -PSPath IIS:\ -Location "FTP"
    Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";users="?";permissions=1} -PSPath IIS:\ -Location "FTP"
    Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";users="*";permissions=3} -PSPath IIS:\ -Location "FTP"

    Restart-WebItem "IIS:\Sites\FTP"
    Write-Host "--- Servidor FTP listo ---"
}

function Generar-GruposClase {
    if (-not $global:ADSI) { $global:ADSI = [ADSI]"WinNT://$env:ComputerName" }
    $grupos = @("Reprobados", "Recursadores")
    foreach ($g in $grupos) {
        if (-not ($global:ADSI.Children | Where-Object { $_.SchemaClassName -eq "Group" -and $_.Name -eq $g })) {
            New-Item -Path "C:\FTP\$g" -ItemType Directory -Force | Out-Null
            $nuevoGrupo = $global:ADSI.Create("Group", $g)
            $nuevoGrupo.SetInfo()
            Write-Host "Grupo $g creado."
        }
    }
}

function Alta-NuevoUsuario {
    if ($null -eq $global:ADSI) { $global:ADSI = [ADSI]"WinNT://$env:COMPUTERNAME" }

    do {
        $global:NombreUserFTP = Read-Host "Nombre del nuevo alumno"
        if (Get-LocalUser -Name $global:NombreUserFTP -ErrorAction SilentlyContinue) {
            Write-Host "Error: El usuario ya existe."
        }
    } while (Get-LocalUser -Name $global:NombreUserFTP -ErrorAction SilentlyContinue)

    $global:ClaveFTP = Read-Host "Contrasena"
    $opcion = Read-Host "Grupo: 1=Reprobados | 2=Recursadores"
    $global:AsignacionGrupo = if ($opcion -eq "1") { "Reprobados" } else { "Recursadores" }

    $accRepo = Read-Host "Acceso al repositorio de servidores? [S/N]"
    $global:AccesoRepo = ($accRepo -eq "S" -or $accRepo -eq "s")

    $cuentaFTP = $global:ADSI.create("User", $global:NombreUserFTP)
    $cuentaFTP.SetInfo()
    $cuentaFTP.SetPassword($global:ClaveFTP)
    $cuentaFTP.SetInfo()

    $rutaBase = "C:\FTP\LocalUser\$global:NombreUserFTP"
    if (-not (Test-Path $rutaBase)) {
        New-Item -Path "$rutaBase\$global:NombreUserFTP" -ItemType Directory -Force | Out-Null
        cmd /c mklink /D "$rutaBase\General" "C:\FTP\LocalUser\Public\General"
        cmd /c mklink /D "$rutaBase\$global:AsignacionGrupo" "C:\FTP\$global:AsignacionGrupo"
        if ($global:AccesoRepo) {
            if (-not (Test-Path "C:\FTP\servidores\Windows")) {
                New-Item -Path "C:\FTP\servidores\Windows" -ItemType Directory -Force | Out-Null
            }
            cmd /c mklink /D "$rutaBase\servidores" "C:\FTP\servidores\Windows"
            Write-Host "  Acceso al repositorio habilitado para $global:NombreUserFTP"
        }
    }
}

function Aplicar-SeguridadNTFS {
    Add-LocalGroupMember -Group $global:AsignacionGrupo -Member $global:NombreUserFTP -ErrorAction SilentlyContinue
    icacls "C:\FTP\Reprobados"   /grant "Reprobados:(OI)(CI)M"   /Q | Out-Null
    icacls "C:\FTP\Recursadores" /grant "Recursadores:(OI)(CI)M" /Q | Out-Null
    icacls "C:\FTP\LocalUser\Public\General" /grant "Usuarios:(OI)(CI)M" /Q | Out-Null
    icacls "C:\FTP\LocalUser\Public" /grant "$($global:AsignacionGrupo):(RX)" /Q | Out-Null
    icacls "C:\FTP\LocalUser\$global:NombreUserFTP" /grant:r "$($global:NombreUserFTP):(OI)(CI)M" /T /C /Q | Out-Null
    if ($global:AccesoRepo) {
        icacls "C:\FTP\servidores" /grant "$($global:NombreUserFTP):(OI)(CI)RX" /T /Q | Out-Null
    }
}

function Mover-UsuarioDeGrupo {
    param([string]$TargetUser)
    if (-not (Get-LocalUser -Name $TargetUser -ErrorAction SilentlyContinue)) {
        Write-Host "Usuario no encontrado."; return
    }
    $grupoOrigen  = if (Get-LocalGroupMember "Reprobados" | Where-Object { $_.Name -like "*$TargetUser" }) { "Reprobados" } else { "Recursadores" }
    $grupoDestino = if ($grupoOrigen -eq "Reprobados") { "Recursadores" } else { "Reprobados" }
    Remove-LocalGroupMember -Group $grupoOrigen  -Member $TargetUser
    Add-LocalGroupMember    -Group $grupoDestino -Member $TargetUser
    cmd /c rmdir "C:\FTP\LocalUser\$TargetUser\$grupoOrigen" 2>$null
    cmd /c mklink /D "C:\FTP\LocalUser\$TargetUser\$grupoDestino" "C:\FTP\$grupoDestino"
    Write-Host "$TargetUser movido a $grupoDestino."
}

function Preparar-Repositorio {
    Write-Host ""
    Write-Host "============================================"
    Write-Host "   PREPARANDO REPOSITORIO DE SERVIDORES"
    Write-Host "============================================"

    $servicios = @{
        "Apache" = "https://www.apachelounge.com/download/VS17/binaries/httpd-2.4.62-240820-win64-VS17.zip"
        "Nginx"  = "https://nginx.org/download/nginx-1.26.2.zip"
    }

    foreach ($svc in $servicios.Keys) {
        $dir     = "C:\FTP\servidores\Windows\$svc"
        $url     = $servicios[$svc]
        $archivo = Split-Path $url -Leaf
        $destino = "$dir\$archivo"
        $sha256  = "$destino.sha256"

        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }

        if ((Test-Path $destino) -and (Test-Path $sha256)) {
            Write-Host "  [OMITIDO] $svc ya existe en repositorio"
            continue
        }

        Write-Host "  Descargando $svc..."
        try {
            Invoke-WebRequest -Uri $url -OutFile $destino -UseBasicParsing
            $hash = (Get-FileHash $destino -Algorithm SHA256).Hash
            "$hash  $archivo" | Set-Content $sha256
            Write-Host "  [OK] $svc -> $archivo"
        } catch {
            Write-Host "  [ERR] No se pudo descargar $svc"
        }
    }

    $dirIIS    = "C:\FTP\servidores\Windows\IIS"
    $markerIIS = "$dirIIS\iis_windows_feature.txt"
    if (-not (Test-Path $dirIIS)) { New-Item -Path $dirIIS -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path $markerIIS)) {
        "IIS se instala con: Install-WindowsFeature Web-Server" | Set-Content $markerIIS
        $hash = (Get-FileHash $markerIIS -Algorithm SHA256).Hash
        "$hash  iis_windows_feature.txt" | Set-Content "$markerIIS.sha256"
        Write-Host "  [OK] IIS -> marcador creado"
    }

    icacls "C:\FTP\servidores" /grant "Usuarios:(OI)(CI)RX" /T /Q | Out-Null
    Write-Host ""
    Write-Host "Repositorio listo."
    Pause
}

function Split-FtpListing {
    param([string]$raw)
    $result = [System.Collections.ArrayList]::new()
    $current = ""
    $rawbytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
    foreach ($byt in $rawbytes) {
        if ($byt -eq 13 -or $byt -eq 10) {
            if ($current.Trim() -ne "") {
                [void]$result.Add($current.Trim())
            }
            $current = ""
        } else {
            $current += [char]$byt
        }
    }
    if ($current.Trim() -ne "") { [void]$result.Add($current.Trim()) }
    return $result.ToArray()
}

function Instalar-Desde-FTP {
    $FTP_IP   = "192.168.117.11"
    $FTP_REPO = "servidores"

    Write-Host ""
    Write-Host "============================================"
    Write-Host "   INSTALAR SERVIDOR DESDE FTP"
    Write-Host "============================================"

    $ftpUser = Read-Host "Usuario FTP"
    $ftpPass = Read-Host "Contrasena FTP"
    $cred    = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)

    Write-Host ""
    Write-Host "Servidores disponibles en el repositorio:"

    try {
        $req1 = [System.Net.FtpWebRequest]::Create("ftp://$FTP_IP/$FTP_REPO/")
        $req1.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
        $req1.Credentials = $cred
        $req1.EnableSsl = $false
        $req1.UsePassive = $true
        $resp1 = $req1.GetResponse()
        $reader1 = New-Object System.IO.StreamReader($resp1.GetResponseStream())
        $rawCarpetas = $reader1.ReadToEnd()
        $reader1.Close()
        $resp1.Close()
        $carpetas = @(Split-FtpListing -raw $rawCarpetas)
    } catch {
        Write-Host "ERROR: No se pudo conectar al FTP: $_"
        $prep = Read-Host "Desea preparar el repositorio ahora? [S/N]"
        if ($prep -eq "S" -or $prep -eq "s") { Preparar-Repositorio }
        Pause
        return
    }

    if ($carpetas.Count -eq 0) {
        Write-Host "No se encontraron servidores en el repositorio."
        Pause
        return
    }

    for ($i = 0; $i -lt $carpetas.Count; $i++) {
        Write-Host "  $($i+1)) $($carpetas[$i])"
    }

    do {
        $selSvc = Read-Host "Seleccione el servidor [1-$($carpetas.Count)]"
        $selSvc = [int]($selSvc -replace '[^0-9]', '')
    } while ($selSvc -lt 1 -or $selSvc -gt $carpetas.Count)

    $svcDir  = $carpetas[$selSvc - 1]
    $rutaSvc = "$FTP_REPO/$svcDir"

    # Buscar el archivo zip en la carpeta local del repositorio
    $localDir = "C:\FTP\servidores\Windows\$svcDir"
    $archivoLocal = Get-ChildItem $localDir -Filter "*.zip" -ErrorAction SilentlyContinue |
                    Select-Object -First 1
    if (-not $archivoLocal) {
        $archivoLocal = Get-ChildItem $localDir -Filter "*.txt" -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -notmatch "sha256" } |
                        Select-Object -First 1
    }
    if (-not $archivoLocal) {
        Write-Host "No hay instaladores en $localDir"
        Pause
        return
    }
    $archivo = $archivoLocal.Name
    Write-Host "Instalador encontrado: $archivo"
    $urlArchivo = "ftp://$FTP_IP/$rutaSvc/$archivo"
    $urlHash    = "ftp://$FTP_IP/$rutaSvc/$archivo.sha256"
    $destLocal  = "C:\Temp\$archivo"
    $destHash   = "C:\Temp\$archivo.sha256"

    if (-not (Test-Path "C:\Temp")) { New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null }

    Write-Host ""
    Write-Host "Descargando $archivo..."
    try {
        $reqD = [System.Net.FtpWebRequest]::Create($urlArchivo)
        $reqD.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
        $reqD.Credentials = $cred
        $reqD.EnableSsl = $false
        $reqD.UsePassive = $true
        $respD = $reqD.GetResponse()
        $streamD = $respD.GetResponseStream()
        $fsD = [System.IO.File]::Create($destLocal)
        $streamD.CopyTo($fsD)
        $fsD.Close()
        $streamD.Close()
        $respD.Close()
    } catch {
        Write-Host "ERROR descargando archivo: $_"
        Pause
        return
    }

    Write-Host "Verificando integridad SHA256..."
    try {
        $reqH = [System.Net.FtpWebRequest]::Create($urlHash)
        $reqH.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
        $reqH.Credentials = $cred
        $reqH.EnableSsl = $false
        $reqH.UsePassive = $true
        $respH = $reqH.GetResponse()
        $streamH = $respH.GetResponseStream()
        $fsH = [System.IO.File]::Create($destHash)
        $streamH.CopyTo($fsH)
        $fsH.Close()
        $streamH.Close()
        $respH.Close()
    } catch {
        Write-Host "ERROR: No se encontro el archivo .sha256. Abortando."
        Pause
        return
    }

    $hashEsperado = (Get-Content $destHash).Split(" ")[0].Trim().ToUpper()
    $hashReal     = (Get-FileHash $destLocal -Algorithm SHA256).Hash.ToUpper()

    if ($hashReal -ne $hashEsperado) {
        Write-Host "INTEGRIDAD FALLIDA - Archivo CORRUPTO. Se elimina."
        Remove-Item $destLocal -Force -ErrorAction SilentlyContinue
        Remove-Item $destHash  -Force -ErrorAction SilentlyContinue
        Pause
        return
    }
    Write-Host "[OK] Hash verificado correctamente."

    switch ($svcDir) {
        "IIS" {
            $puerto = Leer-Puerto
            Instalar-IIS -Puerto $puerto
        }
        "Apache" {
            Write-Host "Extrayendo Apache..."
            if (-not (Test-Path "C:\tools")) { New-Item -Path "C:\tools" -ItemType Directory -Force | Out-Null }
            Expand-Archive -Path $destLocal -DestinationPath "C:\tools" -Force
            $puerto = Leer-Puerto
            Instalar-Apache -PuertoGeneral $puerto
        }
        "Nginx" {
            Write-Host "Extrayendo Nginx..."
            if (-not (Test-Path "C:\tools")) { New-Item -Path "C:\tools" -ItemType Directory -Force | Out-Null }
            Expand-Archive -Path $destLocal -DestinationPath "C:\tools" -Force
            $puerto = Leer-Puerto
            Instalar-Nginx -Puerto $puerto
        }
    }

    $activarSSL = Read-Host "Desea activar SSL/TLS en $svcDir? [S/N]"
    if ($activarSSL -eq "S" -or $activarSSL -eq "s") {
        switch ($svcDir) {
            "IIS"    { Configurar-SSL-IIS }
            "Apache" { Configurar-SSL-Apache }
            "Nginx"  { Configurar-SSL-Nginx }
        }
    }
    Pause
}

function Leer-Puerto {
    do {
        $input = Read-Host "Ingrese el puerto de escucha"
        $input = $input -replace '[^0-9]', ''
        if ([string]::IsNullOrWhiteSpace($input)) { continue }
        $puerto = [int]$input
        $valido = Validar-Puerto -Puerto $puerto
    } while (-not $valido)
    return $puerto
}

$global:ADSI = [ADSI]"WinNT://$env:ComputerName"

$httpFPath = Join-Path $PSScriptRoot "httpF.ps1"
if (Test-Path $httpFPath) { . $httpFPath }

do {
    Clear-Host
    Write-Host "============================================"
    Write-Host "       PANEL ADMINISTRATIVO FTP"
    Write-Host "============================================"
    Write-Host "1) Configurar servidor FTP (Instalacion)"
    Write-Host "2) Alta masiva de usuarios"
    Write-Host "3) Cambiar alumno de grupo"
    Write-Host "4) Preparar repositorio de servidores"
    Write-Host "5) Instalar servidor desde FTP"
    Write-Host "6) Salir"
    Write-Host "--------------------------------------------"
    $seleccion = Read-Host "Elija una opcion"

    switch ($seleccion) {
        "1" {
            Preparar-ServidorFTP
            Generar-GruposClase
            Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.ssl.controlChannelPolicy -Value 0
            Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.ssl.dataChannelPolicy -Value 0
            Restart-WebItem "IIS:\Sites\FTP"
            Write-Host "Instalacion finalizada."
            Pause
        }
        "2" {
            $cantidad = Read-Host "Cuantos usuarios desea crear?"
            if ($cantidad -as [int] -and [int]$cantidad -gt 0) {
                for ($i = 1; $i -le [int]$cantidad; $i++) {
                    Write-Host ""
                    Write-Host "--- Creando usuario $i de $cantidad ---"
                    Alta-NuevoUsuario
                    Aplicar-SeguridadNTFS
                    Write-Host "Usuario guardado."
                }
            } else {
                Write-Host "Cantidad no valida."
            }
            Pause
        }
        "3" {
            $nomAlumno = Read-Host "Login del usuario a reubicar"
            Mover-UsuarioDeGrupo -TargetUser $nomAlumno
            Pause
        }
        "4" { Preparar-Repositorio }
        "5" { Instalar-Desde-FTP }
        "6" { Write-Host "Saliendo..." }
        default {
            Write-Host "Opcion no valida."
            Pause
        }
    }
} while ($seleccion -ne "6")