#!/bin/bash
verificador_ip(){
    local ip=$1
    if [[ $ip =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then 
        OIFS=$IFS
        IFS='.'
        partes=($ip)
        IFS=$OIFS
        for i in {0..3}; do
            if [[ ${partes[$i]} -gt 255 ]]; then return 1; fi
        done
        local valor_host=$(( (127 << 24) + 0 ))
        local valor_ip=$(( (${partes[0]} << 24) + (${partes[1]} << 16) + (${partes[2]} << 8) + ${partes[3]} ))
        local valor_minimo=$(( (1 << 24) + (0 << 16) + (0 << 8) + 1 ))
        local valor_maximo=$(( (255 << 24) + (255 << 16) + (255 << 8) + 254 )) 
       if [[ $valor_ip -lt $valor_minimo || $valor_ip -gt $valor_maximo || $valor_ip -eq $valor_host ||  $valor_ip -eq $(($valor_host + 1 )) ]]; then
            return 1
        fi
        return 0
    fi
    return 1
}
comparar_red(){
    local ip1=$1
    local ip2=$2
    local red1=$(echo $ip1 | cut -d. -f1-3)
    local red2=$(echo $ip2 | cut -d. -f1-3)

    if [[ "$red1" == "$red2" ]]; then
        return 0
    else
        return 1 
    fi
}
validador_rango(){
    local ip=$1
    local p1 p2 p3 p4
    IFS=. read -r p1 p2 p3 p4 <<< "$ip"
    echo $(( (p1 << 24) + (p2 << 16) + (p3 << 8) + p4 ))
}
instalacion(){
    echo "VERIFICANDO SERVIDOR..."
    if dpkg -l | grep -q isc-dhcp-server; then
        echo "ESTADO: INSTALADO"
    else
        echo "INSTALANDO SERVIDOR..."
        sudo apt-get update && sudo apt-get install -y isc-dhcp-server
    fi
}
configurar_dhcp(){
    echo "--- NUEVA CONFIGURACIÓN DE ÁMBITO ---"
    read -p "NOMBRE DEL AMBITO: " scope
    
    while true; do
        read -p "IP INICIAL: " rinicial
        read -p "IP FINAL: " rfinal
          if verificador_ip "$rinicial" && verificador_ip "$rfinal"; then
            if comparar_red "$rinicial" "$rfinal"; then
                numinicial=$(validador_rango "$rinicial")
                numfinal=$(validador_rango "$rfinal")
                if [[ $numinicial -le $numfinal ]]; then
                    break
                else
                    echo "LA IP INICIAL DEBE SER MENOR A LA FINAL"
                fi
            else
                echo "LAS IPS NO PERTENECEN A LA MISMA RED"
            fi
        else
            echo "FORMATO DE IP INVÁLIDO"
        fi
    done
   while true; do
    read -p "TIEMPO DE CONCESIÓN (segundos): " tiempo
      if [[ ! $tiempo =~ ^[0-9]+$ ]]; then
           echo "El tiempo debe de ser numero entero"
         elif (( $tiempo <= 0 )); then
             echo "El tiempo debe de ser mayor a 0"
         else
           break
       fi
    done
        read -p "IP DNS: " dns
        read -p "IP PUERTA DE ENLACE: " ptenlace
    red=$(echo $rinicial | cut -d. -f1-3).0
    ip_servidor=$rinicial
    echo "CONFIGURANDO INTERFAZ enp0s8..."
    sudo ip addr flush dev enp0s8
    sudo ip addr add $ip_servidor/24 dev enp0s8
    sudo ip link set enp0s8 up
    echo "GENERANDO dhcpd.conf..."
   CONF= "authoritative;"
  CONF="${CONF}"$'\n'"subnet $red netmask 255.255.255.0 {"
  CONF="${CONF}"$'\n'" range $rinicial $rfinal;"

 if [[ -n "$ptenlace" ]]; then
       CONF="${CONF}"'\n'" option routers $ptenlace;"
fi

if [[ -n "$dns" ]]; then
    CONF="{$CONF}"$'\n'" option domain-name-servers $dns;"
fi
 CONF="${CONF}"$'\n'" default-lease-time $tiempo;"
  CONF="${CONF}"$'\n'" max-lease-time 7200;"
CONF="${CONF}"$'\n'"}"
echo "$CONF" | sudo tee /etc/dhcp/dhcpd.conf > /dev/null
sudo sed -i "s/INTERFACESv4=.*/INTERFACESv4=enp0s8/" /etc/default/isc-dhcp-server
  sudo dhcpd -t -cf /etc/dhcp/dhcpd.conf && sudo systemctl restart isc-dhcp-server
    echo "CONFIGURACIÓN APLICADA CON ÉXITO."
    read -p "Presione Enter para continuar..."
}
monitoreo(){
    echo "========================================================="
    echo "                 MONITOREO DEL SERVIDOR"
    echo "========================================================="
    echo "Estado del servicio: "
    sudo systemctl is-active --quiet isc-dhcp-server && echo "FUNCIONANDO" || echo "ERROR / DETENIDO"   
    echo "Equipos conectados (Concesiones):"
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
        echo "No hay concesiones activas actualmente."
    fi
    echo "========================================================="
    read -p "Presione Enter para volver al menú..."
}
instalacion
while true; do
    echo "      ******************************************"
    echo "      * PANEL DE CONTROL DHCP SERVER     *"
    echo "      ******************************************"
    echo "      1. Configurar nuevo ambito (Scope)"
    echo "      2. Monitorear clientes conectados"
    echo "      3. Salir"
    echo "      ******************************************"
    read -p "Seleccione una opcion [1-3]: " opcion
    case $opcion in
        1) configurar_dhcp ;;
        2) monitoreo ;;
        3) 
            echo "Saliendo..."
            exit 0
            ;;
        *) 
            echo "Opcion no válida."
            sleep 1
            ;;
    esac
done
