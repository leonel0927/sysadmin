function status(){
    param([string] $pak)
    $status= Get-Service -Name $pak
     Write-Host "--- ESTADO DEL SERVICIO ---"
    Write-Host "SERVICIO: $($Status.Status)"
    Read-Host "ENTER PARA SALIR"
}
#hola desde linux
