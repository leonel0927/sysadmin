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
        local valor_host=$((( (127 << 24) + 0 )))
        local valor_ip=$((( (${partes[0]} << 24) + (${partes[1]} << 16) + (${partes[2]} << 8) + ${partes[3]} )))
        local valor_minimo=$((( (1 << 24) + (0 << 16) + (0 << 8) + 1 )))
        local valor_maximo=$((( (255 << 24) + (255 << 16) + (255 << 8) + 254 )))
       if [[ $valor_ip -lt $valor_minimo || $valor_ip -gt $valor_maximo || $valor_ip -eq $valor_host ||  $valor_ip -eq $(($valor_host + 1 )) ]]; then
            return 1
        fi
        return 0
    fi
    return 1
}