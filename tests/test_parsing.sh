#!/bin/bash
# Prueba el parseo del CSV de airodump sin necesitar hardware WiFi real.
set -u
SELF_DIR=$(cd "$(dirname "$0")/.." && pwd)
. "$SELF_DIR/lib/common.sh"

fail=0

parse_csv() {
    awk -F, '
        BEGIN { section=0; n=0 }
        /^$/ { section++; next }
        section==0 && NR>1 {
            bssid=$1; gsub(/^ +| +$/,"",bssid)
            if (bssid == "" || bssid == "BSSID") next
            channel=$4; gsub(/^ +| +$/,"",channel)
            enc=$6; gsub(/^ +| +$/,"",enc)
            essid=$14; gsub(/^ +| +$/,"",essid)
            n++
            printf "%d|%s|%s|%s|%s\n", n, bssid, channel, enc, essid
        }
    ' "$1"
}

out=$(parse_csv "$SELF_DIR/tests/sample_airodump.csv")
count=$(echo "$out" | grep -c '|')

[ "$count" -eq 2 ] || { echo "FALLÓ: se esperaban 2 redes, hubo $count"; fail=1; }
echo "$out" | grep -q "AA:BB:CC:DD:EE:01" || { echo "FALLÓ: no se encontró el primer BSSID"; fail=1; }
echo "$out" | grep -q "WEP" || { echo "FALLÓ: no se detectó cifrado WEP"; fail=1; }
echo "$out" | grep -q "CasaRouter" || { echo "FALLÓ: no se encontró el ESSID"; fail=1; }

if [ "$fail" -eq 0 ]; then
    echo "Todas las pruebas de parseo pasaron."
    exit 0
else
    exit 1
fi
