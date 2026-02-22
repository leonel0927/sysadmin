#!/bin/bash
clear
while true; do
echo "********* BIENVENIDO AL SERVIDOR LINUX************"
echo "--SELECCIONE UNA OPCION:"
    echo "1) DHCP"
    echo "2) DNS"
    echo "3 Salir"
    read -p "SELECCIONE UNA OPCION: " opcion
    case $opcion in
    1)./dhcp.sh ;;
    2)./dns.sh ;;
    3) echo "Saliendo.."
        exit 0 ;;
    *) 
        echo "Opcion no válida."
        sleep 1 ;;
    esac
done
clear   