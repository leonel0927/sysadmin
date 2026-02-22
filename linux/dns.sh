#!/bin/bash
INTERFAZ="enp0s8"
 source /home/srv-linux-server/SCRIPS2/FUNCIONES/verificador_ip.sh
 source /home/srv-linux-server/SCRIPS2/FUNCIONES/status.sh
instalar() {
    if dpkg -l | grep -E "^ii\s+bind9\s" > /dev/null; then
        echo "SERVICIO YA INSTALADO"
    else
        echo "SERVICIO NO INSTALADO,INSTALACION AUTOMATICA"
        sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock
        sudo apt update -y && sudo apt install -y bind9 bind9utils bind9-doc >/dev/null 2>&1
        if [ -d "/etc/bind" ]; then
            echo "INSTALACION EXITOSA"
        else
            echo "ERROR AL INSTALAR"
            exit 1
        fi
    fi
    clear
}

listar(){
    echo -e "\nDOMINIO\t\t\tIP ASIGNADA"
    echo "------------------------------------------"
    zonas=$(grep "^zone" /etc/bind/named.conf.local | cut -d'"' -f2 | grep -Ev "localhost|127|255|0|broadcast|in-addr.arpa")
    for zone in $zonas; do
        IP_ZONE=$(grep -E "^($zon|@)[[:space:]]+IN[[:space:]]+A" /var/cache/bind/db.$zone 2>/dev/null | awk '{print $NF}' | head -n1)
        if [ -z "$IP_ZONE" ]; then
            IP_ZONE="IP no encontrada"
        fi
        printf "%-25s %s\n" "$zone" "$IP_ZONE"
    done
    echo "------------------------------------------"
    read -p "Presiona ENTER para volver al menú..."
}

eliminar(){
    read -p "INGRESE EL NOMBRE DEL DOMINIO A ELIMINAR: " DEL_DOM
    if grep -q "zone \"$DEL_DOM\"" /etc/bind/named.conf.local; then
        IP_DEL=$(grep -P "\tIN\tA\t" /var/cache/bind/db.$DEL_DOM | tail -n1 | awk '{print $NF}')
        OCTETOS=$(echo $IP_DEL | cut -d. -f1-3)
        REVERSE_ZONE=$(echo $OCTETOS | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')
        
        sudo sed -i "/zone \"$DEL_DOM\"/,/};/d" /etc/bind/named.conf.local
        sudo sed -i "/zone \"$REVERSE_ZONE\"/,/};/d" /etc/bind/named.conf.local
        sudo rm -f /var/cache/bind/db.$DEL_DOM
        sudo rm -f /var/cache/bind/db.$REVERSE_ZONE
        sudo systemctl restart bind9
        echo "DOMINIO $DEL_DOM ELIMINADO"
    else
        echo "EL DOMINIO '$DEL_DOM' NO EXISTE"
    fi
    read -p "ENTER PARA SALIR"
}

configurar() {
    OPTIONS_FILE="/etc/bind/named.conf.options"
    sudo tee $OPTIONS_FILE > /dev/null <<EOF
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-query { any; };
    listen-on { any; };
    listen-on-v6 { any; };
    forwarders { 8.8.8.8; 8.8.4.4; };
    dnssec-validation auto;
};
EOF
    sudo systemctl enable bind9
    sudo systemctl restart bind9
    read -p "ENTER PARA SALIR"
}
verificador_dominio(){
    local dominio="$1" 
    local regex="^([a-zA-Z0-9]([a-zA-Z0-9-]{1,}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$"
    if [[ $dominio =~ $regex ]]; then
        return 0
    else
        return 1
    fi
}
agregar_dominio() {
    source /home/limpio/FUNCIONES/verificador_ip.sh
    while true; do
    read -p "NOMBRE: " DOMINIO
    if verificador_dominio "$DOMINIO"; then
       break
    else
    echo "NOMBRE DEL DOMINIO INVALIDO"
    fi
    done
        SERVER_IP=$(ip -4 addr show $INTERFAZ | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    while true; do
        read -p "IP: " IP
        if [ -z "$IP" ]; then
        IP=$SERVER_IP
        fi
        if verificador_ip "$IP"; then 
        break
        else
         echo "IP INVALIDA" 
        fi
    done
    
    if [ -z "$SERVER_IP" ]; then
        echo "SERVIDOR SIN IP, EJECUTANDO DHCP..."
        ./dhcp.sh
        return
    fi

    OCTETOS=$(echo $IP | cut -d. -f1-3)
    ULTIMO_OCTETO=$(echo $IP | cut -d. -f4)
    REVERSE_ZONE=$(echo $OCTETOS | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')
    ZONA_INV_FILE="/var/cache/bind/db.$REVERSE_ZONE"
    CONF_LOCAL="/etc/bind/named.conf.local"
    ZONA_FILE="/var/cache/bind/db.$DOMINIO"

    if grep -q "zone \"$DOMINIO\"" $CONF_LOCAL 2>/dev/null; then
        echo "EL DOMINIO YA EXISTE"
    else
        echo "zone \"$DOMINIO\" { type master; file \"$ZONA_FILE\"; };" | sudo tee -a $CONF_LOCAL > /dev/null
        
        if ! grep -q "$REVERSE_ZONE" $CONF_LOCAL; then
            echo "zone \"$REVERSE_ZONE\" { type master; file \"$ZONA_INV_FILE\"; };" | sudo tee -a $CONF_LOCAL > /dev/null
        fi

        sudo tee $ZONA_FILE > /dev/null <<EOF
\$TTL 604800
@ IN SOA ns1.$DOMINIO. root.$DOMINIO. ( $(date +%s) 604800 86400 2419200 604800 )
@ IN NS ns1.$DOMINIO.
ns1 IN A $SERVER_IP
@ IN A $IP
www IN A $IP
EOF

        sudo tee $ZONA_INV_FILE > /dev/null <<EOF
\$TTL 604800
@ IN SOA ns1.$DOMINIO. root.$DOMINIO. ( $(date +%s) 604800 86400 2419200 604800 )
@ IN NS ns1.$DOMINIO.
$ULTIMO_OCTETO IN PTR $DOMINIO.
$ULTIMO_OCTETO IN PTR www.$DOMINIO.
EOF

        sudo chown bind:bind $ZONA_FILE $ZONA_INV_FILE
        sudo systemctl restart bind9
        echo "DOMINIO CREADO: $DOMINIO <-> $IP"
    fi
    read -p "ENTER PARA SALIR"
}

comprobar_estado() {
    echo "--- ESTADO DEL SERVICIO ---"
    echo "Estado: "&& verificador_status "bind9" 
    read -p "ENTER PARA SALIR"
}
instalar
configurar

while true; do
    clear
    echo "--- MENU DNS ---"
    echo "1. ESTADO"
    echo "2. AGREGAR DOMINIOS"
    echo "3. LISTAR DOMINIOS"
    echo "4. ELIMINAR DOMINIOS"
    echo "5. DHCP"
    echo "6. SALIR"
    read -p "Opción: " OPC

    case $OPC in
        1) comprobar_estado ;;
        2) agregar_dominio ;;
        3) listar ;;
        4) eliminar ;;
        5) ./dhcp.sh ;;
        6) echo "Cerrando script..." 
            clear 
            exit 0 ;;
        *) echo "Opción inválida." ;;
    esac
done
