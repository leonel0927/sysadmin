#!/bin/bash
clear
while true; do
echo "********* BIENVENIDO AL SERVIDOR LINUX************"
echo "--SELECCIONE UNA OPCION:"
    echo "1) DHCP"
    echo "2) DNS"
    echo "3) SSH"
    echo "4) Salir"
    read -p "SELECCIONE UNA OPCION: " opcion
    case $opcion in
    1)bash ./dhcp.sh ;;
    2)bash ./dns.sh ;;
    3)bash ./ssh.sh ;;
    4) echo "Saliendo.."
        exit 0 ;;
    *) 
        echo "Opcion no válida."
        sleep 1 ;;
    esac
done
clear   