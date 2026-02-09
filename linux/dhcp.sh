#!/bin/bash
verificador_ip(){
    local ip=$1
    if [[ $ip =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then 
        OIFS=$IFS
        IFS='.'
        partes=($ip)
        IFS=$OIFS
        if [[ ${partes[0]} -le 255 && ${partes[1]} -le 255 && ${partes[2]} -le 255 && ${partes[3]} -le 255 ]]; then
            return 0
        fi 
    fi
    return 1
}

instalacion(){
    echo "VERIFICANDO SI YA EXISTE EL SERVIDOR..."
    if dpkg -l | grep -q isc-dhcp-server; then
        echo "EL SERVIDOR YA EXISTE"
    else
        echo "INSTALANDO SERVIDOR DE FORMA DESATENDIDA..."
        sudo apt-get update && sudo apt-get install -y isc-dhcp-server
    fi
}

validador_rango(){
    local ip=$1
    local p1 p2 p3 p4
    IFS=. read -r p1 p2 p3 p4 <<< "$ip"
    echo $(( (p1 << 24) + (p2 << 16) + (p3 << 8) + p4 ))
}
echo "            CONFIGURACION DE SERVIDOR DHCP"
instalacion

read -p "NOMBRE DEL AMBITO: " scope
while true; do
    read -p "IP INICIAL: " rinicial
    read -p "IP FINAL: " rfinal
    if verificador_ip "$rinicial" && verificador_ip "$rfinal"; then
        numinicial=$(validador_rango "$rinicial")
        numfinal=$(validador_rango "$rfinal")
        if [[ $numinicial -le $numfinal ]]; then
            break
        else
            echo "LA IP INICIAL DEBE DE SER MENOR A LA FINAL"
        fi
    else
        echo "FORMATO DE IP INVALIDO"
    fi
done
read -p "TIEMPO DE CONCESION (segundos): " tiempo
while true; do
    read -p "IP DNS: " dns
    verificador_ip "$dns" && break || echo "DNS INVALIDO"
done
while true; do
    read -p "IP PUERTA DE ENLACE: " ptenlace
    verificador_ip "$ptenlace" && break || echo "PUERTA DE ENLACE INVALIDA"
done
red=$(echo $rinicial | cut -d. -f1-3).0
ip_servidor=$rinicial
export red rinicial rfinal ptenlace dns tiempo
red=$(echo $rinicial | cut -d. -f1-3).0
sudo ip addr flush dev enp0s8
sudo ip addr add $ip_servidor/24 dev enp0s8
sudo ip link set enp0s8 up
echo "GENERANDO ARCHIVO DE CONFIGURACION..."
sudo -E bash -c "cat > /etc/dhcp/dhcpd.conf <<EOF
authoritative;
subnet $red netmask 255.255.255.0 {
  range $rinicial $rfinal;
  option routers $ptenlace;
  option domain-name-servers $dns;
  default-lease-time $tiempo;
  max-lease-time 7200;
}
EOF"
sudo dhcpd -t -cf /etc/dhcp/dhcpd.conf && sudo systemctl restart isc-dhcp-server

echo -e "\n========================================================="
echo "                     MONITOREO"
echo "=========================================================="
echo "1) Estado del servicio:"
sudo systemctl is-active --quiet isc-dhcp-server && echo "Servicio: FUNCIONANDO" || echo "Servicio: ERROR"
echo "2) Equipos conectados:"
LEASES_FILE="/var/lib/dhcp/dhcpd.leases" 
if [ -f "$LEASES_FILE" ]; then
    echo -e "IP ASIGNADA\tMAC ADDRESS\t\tNOMBRE EQUIPO"
    awk '
    /^lease/ { ip=$2 }
    /hardware ethernet/ { mac=$3; gsub(/;/,"",mac) }
    /client-hostname/ { name=$2; gsub(/;/,"",name); gsub(/"/,"",name) }
    /^}/ { printf "%s\t%s\t%s\n", ip, mac, (name==""?"(N/A)":name); ip=mac=name="" }
    ' "$LEASES_FILE" | sort | uniq
else
    echo "No hay concesiones activas actualmente"
fi
