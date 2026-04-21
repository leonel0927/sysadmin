$usuariosConMFA = @("admin_identidad","admin_storage","admin_politicas","admin_auditoria")
$multiOTPExe = "C:\Program Files\multiOTP\windows\multiotp.exe"
$usuario = $env:USERNAME.ToLower() -replace "practica\\",""

if ($usuariosConMFA -contains $usuario) {
    $intentos = 0
    $acceso = $false
    while ($intentos -lt 3) {
        $codigo = Read-Host "Codigo Google Authenticator"
        $resultado = & $multiOTPExe $usuario $codigo 2>&1
        if ($LASTEXITCODE -eq 0) {
            $acceso = $true
            break
        }
        $intentos++
        Write-Host "Codigo invalido. Intentos restantes: $(3 - $intentos)"
    }
    if (-not $acceso) {
        Write-Host "Demasiados intentos. Acceso denegado."
        exit 1
    }
}

& "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"