#!/bin/bash
# Funciones compartidas: color, logging, chequeo de dependencias, limpieza.

C_RED='\033[0;31m'; C_GRN='\033[0;32m'; C_YEL='\033[0;33m'; C_CYA='\033[0;36m'; C_RST='\033[0m'

log_info()  { printf "${C_CYA}[*]${C_RST} %s\n" "$1"; }
log_ok()    { printf "${C_GRN}[+]${C_RST} %s\n" "$1"; }
log_warn()  { printf "${C_YEL}[!]${C_RST} %s\n" "$1"; }
log_err()   { printf "${C_RED}[-]${C_RST} %s\n" "$1" >&2; }

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_err "Este script necesita privilegios root (manejo de interfaces inalámbricas)."
        exit 1
    fi
}

require_bin() {
    for b in "$@"; do
        command -v "$b" >/dev/null 2>&1 || { log_err "Falta el binario requerido: $b"; MISSING=1; }
    done
    [ "${MISSING:-0}" -eq 1 ] && exit 1
    return 0
}

confirm_authorization() {
    cat <<BANNER
${C_YEL}============================================================${C_RST}
 wpsAttack - auditoría de redes WiFi (WEP/WPA/WPA2/WPS)
 Úsalo SOLO en redes propias o con autorización expresa y por
 escrito. Atacar redes ajenas sin permiso es ilegal.
${C_YEL}============================================================${C_RST}
BANNER
    printf "Escribe EXACTAMENTE 'ACEPTO' para continuar: "
    read -r ans
    if [ "$ans" != "ACEPTO" ]; then
        log_err "No confirmado. Saliendo."
        exit 1
    fi
}

mk_session_dir() {
    bssid_clean=$(echo "$1" | tr -d ':')
    dir="logs/${bssid_clean}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$dir"
    echo "$dir"
}

restore_interface() {
    iface="$1"
    log_info "Restaurando $iface a modo managed..."
    airmon-ng stop "$iface" >/dev/null 2>&1
}
