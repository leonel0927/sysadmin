$ip=(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet 2").IPAddress
echo "DESDE SERVIDOR DE WINDOWS"
echo "NOMBRE DEL EQUIPO: $env:COMPUTERNAME"
echo "IP ACTUAL:$ip "
echo "ESPACIO EN EL DISCO:$([Math]::Round((Get-Volume -DriveLetter C).SizeRemaining / 1GB, 2)) GB"