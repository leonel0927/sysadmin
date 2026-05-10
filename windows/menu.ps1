do {
    Clear-Host
    Write-Host "*************BIENVENIDO AL MENU DEL SERVIDOR WINDOWS *********"
    Write-Host "-DIGITE UNA OPCION"
    Write-Host "1) DHCP"
    Write-Host "2) DNS"
    Write-Host "3) SSH"
    Write-Host "4) FTP"
    Write-Host "5)HTTP"
    Write-Host "6)HTTPS"
    Write-Host "7)Active Directory"
    Write-Host "8)Active Directory 2"
    Write-Host "9) Salir"
    $OPC = Read-Host "Opcion"

    switch ($OPC) {
        "1" { ./dhcp.ps1 }
        "2" { ./dns.ps1 }
        "3" {./ssh.ps1 }
        "4" {./ftp2.ps1}
        "5" {./http.ps1}
        "6" {./practica7.ps1}
        "7" {./practica8M.ps1}
        "8" {./Menu_Practica9.ps1}
        "9" { Write-Host "Cerrando script..."; exit }
        default { Write-Host "Opción inválida." ; Start-Sleep -Seconds 1 }
    }
} while ($true)