#!/bin/bash
echo "DESDE SERVIDOR UBUNTU"
echo "NOMBRE DEL EQUIPO: $(hostname)"
echo "IP ACTUAL:  $(ip addr show enp0s8 | grep "inet"|awk '{print $2}'| head -n 1 | cut -d/ -f1)"
echo "ESPACIO EN EL DISCO: $(df -h | grep "/$" | awk '{print $4}')"
date
