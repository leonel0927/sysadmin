Remove-Item -Force Z:\windows\vim.exe
# Obtener el PATH actual
$oldPath = [Environment]::GetEnvironmentVariable("Path", "Machine")

# Filtrar y quitar las rutas que contengan 'Vim' o 'Z:\windows' o 'C:\editor'
$newPath = ($oldPath -split ';' | Where-Object { $_ -notmatch "Vim" -and $_ -notmatch "Z:\\windows" -and $_ -notmatch "C:\\editor" }) -join ';'

# Guardar el PATH limpio
[Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")