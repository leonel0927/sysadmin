#!/bin/bash
verificaion_instalacion(){
    local paquete="$1"
 echo "VERIFICANDO SERVIDOR..."
    if dpkg -l | grep -q $1; then
        echo "ESTADO: INSTALADO"
    else
        echo "INSTALANDO SERVIDOR..."
        sudo apt-get update && sudo apt-get install -y $1  >/dev/null 2>&1
    fi
}