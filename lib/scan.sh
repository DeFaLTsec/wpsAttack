#!/bin/bash
# Escaneo de redes cercanas usando airodump-ng en modo CSV.

scan_networks() {
    iface="$1"
    duration="${2:-15}"
    prefix="/tmp/wpsattack_scan_$$"

    log_info "Escaneando $duration segundos con $iface..."
    timeout "$duration" airodump-ng --output-format csv -w "$prefix" "$iface" >/dev/null 2>&1

    csv="${prefix}-01.csv"
    if [ ! -f "$csv" ]; then
        log_err "No se generó el archivo de escaneo. ¿La interfaz está en modo monitor?"
        return 1
    fi

    # El CSV de airodump trae dos secciones: APs y luego clientes, separadas por línea en blanco.
    awk -F, '
        BEGIN { section=0; n=0 }
        /^$/ { section++; next }
        section==0 && NR>1 {
            bssid=$1; gsub(/^ +| +$/,"",bssid)
            if (bssid == "" || bssid == "BSSID") next
            power=$9; gsub(/^ +| +$/,"",power)
            channel=$4; gsub(/^ +| +$/,"",channel)
            enc=$6; gsub(/^ +| +$/,"",enc)
            essid=$14; gsub(/^ +| +$/,"",essid)
            wps="no"
            if (enc ~ /WPA/) wps="revisar"  # WPS real se detecta con wash, ver check_wps()
            n++
            printf "%d|%s|%s|%s|%s|%s\n", n, bssid, channel, enc, essid, power
        }
    ' "$csv"

    rm -f "${prefix}"-*.csv "${prefix}"-*.cap "${prefix}"-*.kismet.* "${prefix}"-*.log.csv 2>/dev/null
}

check_wps() {
    iface="$1"
    bssid="$2"
    channel="$3"
    command -v wash >/dev/null 2>&1 || { log_warn "wash no está instalado; no se puede confirmar WPS."; return 1; }
    timeout 8 wash -i "$iface" -c "$channel" 2>/dev/null | grep -qi "$bssid"
}
