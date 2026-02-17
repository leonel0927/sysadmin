function verificador_ip {
    param($ip)
    if ($ip -match '^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$') {
        $partes = $matches[1], $matches[2], $matches[3], $matches[4]
        foreach ($p in $partes) {
            if ([int]$p -gt 255) { return $false }
        }
        $v = [double]$partes[0] * 16777216 + [double]$partes[1] * 65536 + [double]$partes[2] * 256 + [double]$partes[3]
        $min = 16777217  
        $max = 4294967294 
	$ip_host = 2130706432
        if ($v -lt $min -or $v -gt $max -or $v -eq $ip_host -or $v -eq ($ip_host + 1) ) { return $false }
        return $true
    }
    return $false
}