. "Z:\FUNCIONES\instalacion.ps1"
verificar_instalacion -pak "RSAT-AD-PowerShell"
verificar_instalacion -pak "GPMC"
Import-Module ActiveDirectory
Import-Module GroupPolicy

# --- CONFIGURACION ---
$dominio = "DC=practica,DC=local"
$gpoName = "Politicas-Acceso-FIM"

function Configurar-Todo {
    # 1. Crear GPO si no existe
    if (-not (Get-GPO -Name $gpoName -ErrorAction SilentlyContinue)) {
        New-GPO -Name $gpoName | Out-Null
        Write-Host "[+] GPO creada" -ForegroundColor Green
    }

    # 2. CIERRE DE SESION FORZADO (System ForceLogoff)
    Set-GPRegistryValue -Name $gpoName `
        -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
        -ValueName "ForceLogoff" -Type DWord -Value 1

    # 3. BLOQUEO NOTEPAD (DisallowRun para Win10 Pro)
    Set-GPRegistryValue -Name $gpoName `
        -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
        -ValueName "DisallowRun" -Type DWord -Value 1
        
    Set-GPRegistryValue -Name $gpoName `
        -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun" `
        -ValueName "1" -Type String -Value "notepad.exe"

    Write-Host "[+] Registro configurado en GPO" -ForegroundColor Cyan

    # 4. VINCULACION FORZADA
    foreach ($uo in @("Cuates", "NoCuates")) {
        $pathOU = "OU=$uo,$dominio"
        try {
            New-GPLink -Name $gpoName -Target $pathOU -Enforced Yes -ErrorAction Stop | Out-Null
            Write-Host "[+] Vinculo forzado en OU: $uo" -ForegroundColor Green
        } catch {
            Set-GPLink -Name $gpoName -Target $pathOU -Enforced Yes | Out-Null
            Write-Host "[!] Vinculo ya existia en: $uo" -ForegroundColor Yellow
        }
    }
}

function Ver-Estado-Actual {
    $gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
    if ($gpo) {
        Write-Host "--- Estado de GPO ---"
        foreach ($uo in @("Cuates", "NoCuates")) {
            $link = Get-GPInheritance -Target "OU=$uo,$dominio" | 
                    Select-Object -ExpandProperty GpoLinks | 
                    Where-Object { $_.DisplayName -eq $gpoName }
            $status = if ($link) { "OK" } else { "ERROR" }
            Write-Host "OU: $uo -> $status"
        }
    } else {
        Write-Host "La GPO no existe" -ForegroundColor Red
    }
}

# --- MENU PRINCIPAL ---
do {
    Clear-Host
    Write-Host "============================="
    Write-Host "   CONTROL DE ACCESO GPO"
    Write-Host "============================="
    Write-Host "[1] Aplicar Politicas"
    Write-Host "[2] Ver Estado"
    Write-Host "[0] Salir"
    $op = Read-Host "Opcion"

    switch ($op) {
        "1" { Configurar-Todo }
        "2" { Ver-Estado-Actual }
        "0" { Write-Host "Saliendo..." }
    }
    if ($op -ne "0") { Read-Host "Presione Enter" }
} while ($op -ne "0")