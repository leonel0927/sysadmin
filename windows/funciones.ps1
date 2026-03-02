function instalarFTP {

    Install-WindowsFeature Web-Server -IncludeAllSubFeature
    Install-WindowsFeature Web-FTP-Service -IncludeAllSubFeature
    Install-WindowsFeature Web-FTP-Server -IncludeAllSubFeature
    Install-WindowsFeature Web-Basic-Auth

    New-NetFirewallRule -DisplayName "FTP" -Direction Inbound -Protocol TCP -LocalPort 21 -Action Allow
Import-Module WebAdministration


    if (-not (Test-Path "C:\FTP")) {

    mkdir C:\FTP
    mkdir C:\FTP\LocalUser
    mkdir C:\FTP\LocalUser\Public

    # General ahora va DENTRO de Public
    mkdir C:\FTP\LocalUser\Public\General
}
    
#PERMISOS NTFS SEGUROS PARA PUBLIC
icacls "C:\FTP\LocalUser\Public" /inheritance:r
icacls "C:\FTP\LocalUser\Public" /remove "BUILTIN\Usuarios"
icacls "C:\FTP\LocalUser\Public" /grant "IUSR:(OI)(CI)RX"
icacls "C:\FTP\LocalUser\Public" /grant "SYSTEM:(OI)(CI)F"
icacls "C:\FTP\LocalUser\Public" /grant "Administrators:(OI)(CI)F"

# General hereda de Public (no necesita quitar herencia)
icacls "C:\FTP\LocalUser\Public\General" /grant "IUSR:(OI)(CI)RX"
    if (-not (Get-WebSite -Name "FTP" -ErrorAction SilentlyContinue)) {
    New-WebFtpSite -Name "FTP" -Port 21 -PhysicalPath "C:\FTP"
    Write-Host "Sitio FTP creado."
}
else {
    Write-Host "El sitio FTP ya existe."
}

    #CONFIGURACION IIS (SOLO UNA VEZ)
    
    Set-ItemProperty "IIS:\Sites\FTP" `
        -Name ftpServer.security.authentication.basicAuthentication.enabled `
        -Value $true

    Set-ItemProperty "IIS:\Sites\FTP" `
        -Name ftpServer.security.authentication.anonymousAuthentication.enabled `
        -Value $true

    Set-ItemProperty "IIS:\Sites\FTP" `
        -Name ftpServer.security.authentication.anonymousAuthentication.username `
        -Value "IUSR"

 Clear-WebConfiguration `
    -Filter "/system.ftpServer/security/authorization" `
    -PSPath IIS:\ `
    -Location "FTP"

# Permitir lectura a anonymous
Add-WebConfiguration "/system.ftpServer/security/authorization" `
    -Value @{accessType="Allow";users="?";permissions=1} `
    -PSPath IIS:\ -Location "FTP"

# Permitir lectura y escritura a autenticados
Add-WebConfiguration "/system.ftpServer/security/authorization" `
    -Value @{accessType="Allow";users="*";permissions=3} `
    -PSPath IIS:\ -Location "FTP"

}


function CrearGrupos {
    
    if(-not($ADSI.Children | Where-Object { $_.SchemaClassName -eq "Group" -and $_.Name -eq "Reprobados"})){
         if(-not (Test-Path "C:\FTP\Reprobados")) {
         New-Item -Path "C:\FTP\Reprobados" -ItemType Directory | Out-Null
        }
        #Creacion de grupos FTP
        #METER EL NOMBRE DE LA MAQUINA
        $FTPUserGroup = $ADSI.Create("Group", "Reprobados")
        #Actualizar las credenciales/servidor
        $FTPUserGroup.SetInfo()
    
        $FTPUserGroup.Description = "Los miembros de este grupo estan Reprobados"
        $FTPUserGroup.SetInfo()
            
    }
    
    if(-not($ADSI.Children | Where-Object { $_.SchemaClassName -eq "Group" -and $_.Name -eq "Recursadores"})){
        if(-not (Test-Path "C:\FTP\Recursadores")) {
         New-Item -Path "C:\FTP\Recursadores" -ItemType Directory | Out-Null
        } 
        #METER EL NOMBRE DE LA MAQUINA
        $FTPUserGroup = $ADSI.Create("Group", "Recursadores")
        $FTPUserGroup.SetInfo()
    
        $FTPUserGroup.Description = "Los miembros de este grupo estan Recursando"
        $FTPUserGroup.SetInfo()
        
    }
    
}

function CrearUsuario {

    do{
        $global:FTPUserName=read-Host "Ingrese el nombre de usuario"
        
        if((Get-LocalUser -Name $global:FTPUserName -ErrorAction SilentlyContinue)){
            Write-Host "Usuario ya Existente ($global:FTPUserName)"
        }
    }while((Get-LocalUser -Name $global:FTPUserName -ErrorAction SilentlyContinue))
    
    $regex="^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9]).{8,}$"
    
    
    do{
    $global:FTPPassword=read-Host "Ingresar una contraseña"
    
        if($global:FTPPassword -notmatch $regex){
            Write-Host "Contraseña no valida, que contenga Mayuscula,minuscula y minimo de 8 caracteres"
        }else{
            break
        }
    }while($global:FTPPassword -notmatch $regex)


    Write-Host "INGRESE A CUAL GRUPO PERTENECERA"
    $grupo=Read-Host "1-Reprobados  2-Recursadores"

    if($grupo -eq 1){
        $global:FTPUserGroupName = "Reprobados"
    }elseif($grupo -eq 2){
        $global:FTPUserGroupName = "Recursadores"
    }

    $CreateUserFTPUser=$global:ADSI.create("User",$global:FTPUserName)
    $CreateUserFTPUser.SetInfo()    
    $CreateUserFTPUser.SetPassword($global:FTPPassword)    
    $CreateUserFTPUser.SetInfo()    




    if(-not(Test-Path "C:\FTP\LocalUser\$global:FTPUserName")){
        mkdir "C:\FTP\LocalUser\$global:FTPUserName"
        mkdir "C:\FTP\LocalUser\$global:FTPUserName\$global:FTPUserName"
    New-Item -ItemType SymbolicLink `
    -Path "C:\FTP\LocalUser\$global:FTPUserName\General" `
    -Target "C:\FTP\LocalUser\Public\General"
    New-Item -ItemType SymbolicLink -Path "C:\FTP\LocalUser\$global:FTPUserName\$global:FTPUserGroupName" -Target "C:\FTP\$global:FTPUserGroupName"
    }       
    
}


function Permisos {

    # Agregar usuario al grupo
    if (-not (Get-LocalGroupMember $global:FTPUserGroupName |
              Where-Object { $_.Name -like "*$global:FTPUserName" })) {

        Add-LocalGroupMember -Group $global:FTPUserGroupName -Member $global:FTPUserName
    }

    # Permisos en carpetas de grupo
    icacls "C:\FTP\Reprobados" /grant "Reprobados:(OI)(CI)M"
    icacls "C:\FTP\Recursadores" /grant "Recursadores:(OI)(CI)M"

    # Permisos en General
     icacls "C:\FTP\LocalUser\Public\General" /grant "Reprobados:(OI)(CI)M"
    icacls "C:\FTP\LocalUser\Public\General" /grant "Recursadores:(OI)(CI)M"
    icacls "C:\FTP\LocalUser\Public\General" /grant "IUSR:(OI)(CI)RX"

    # Permisos carpeta personal
    icacls "C:\FTP\LocalUser\$global:FTPUserName"
$permiso = "$($global:FTPUserName):(OI)(CI)M"

icacls "C:\FTP\LocalUser\$global:FTPUserName" /grant:r $permiso
}
function CambiarGrupoUsuario {

    param(
        [string]$NombreUsuario
    )

    # Verificar que el usuario exista
    if (-not (Get-LocalUser -Name $NombreUsuario -ErrorAction SilentlyContinue)) {
        Write-Host "El usuario no existe."
        return
    }

    $grupoActual = $null
    $grupoNuevo  = $null

    # Detectar grupo actual
    if (Get-LocalGroupMember -Group "Reprobados" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*$NombreUsuario" }) {

        $grupoActual = "Reprobados"
        $grupoNuevo  = "Recursadores"
    }
    elseif (Get-LocalGroupMember -Group "Recursadores" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*$NombreUsuario" }) {

        $grupoActual = "Recursadores"
        $grupoNuevo  = "Reprobados"
    }
    else {
        Write-Host "El usuario no pertenece a ningún grupo válido."
        return
    }

    # Quitar del grupo actual
    Remove-LocalGroupMember -Group $grupoActual -Member $NombreUsuario

    # Agregar al nuevo grupo
    Add-LocalGroupMember -Group $grupoNuevo -Member $NombreUsuario

    Write-Host "Usuario $NombreUsuario cambiado de $grupoActual a $grupoNuevo correctamente."

    # 🔥 ACTUALIZAR LINK SIMBÓLICO
    $rutaLink = "C:\FTP\LocalUser\$NombreUsuario\$grupoActual"

    if (Test-Path $rutaLink) {
        cmd /c rmdir "$rutaLink"
    }

    $nuevoLink = "C:\FTP\LocalUser\$NombreUsuario\$grupoNuevo"

# Si ya existe, eliminarlo
if (Test-Path $nuevoLink) {
    cmd /c rmdir "$nuevoLink"
}

New-Item -ItemType SymbolicLink `
    -Path $nuevoLink `
    -Target "C:\FTP\$grupoNuevo"

    Write-Host "Acceso a carpeta actualizado."
}