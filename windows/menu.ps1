do {
    Clear-Host
    Write-Host "*************BIENVENIDO AL MENU DEL SERVIDOR WINDOWS *********"
    Write-Host "-DIGITE UNA OPCION"
    Write-Host "1) DHCP"
    Write-Host "2) DNS"
    Write-Host "3) SALIR"
    $OPC = Read-Host "Opcion"

    switch ($OPC) {
        "1" { ./dhcp.ps1 }
        "2" { ./dns.ps1 }
        "3" { Write-Host "Cerrando script..."; exit }
        default { Write-Host "Opción inválida." ; Start-Sleep -Seconds 1 }
    }
} while ($true)