# 📡 wpsAttack

Orquestador en Bash para auditorías WiFi: automatiza modo monitor, escaneo
y ataque según el cifrado detectado (**WEP**, **WPA/WPA2**, **WPS**),
apoyándose en las herramientas estándar del ecosistema
(`aircrack-ng`, `reaver`/`bully`). No reinventa la criptografía: coordina
las herramientas correctas en el orden correcto.

> ⚠️ **Uso legal**: solo en redes propias o con autorización expresa y por
> escrito. Lee [docs/DISCLAIMER.md](docs/DISCLAIMER.md). El script pide
> confirmación explícita antes de operar.

## Qué hace
1. Pone tu tarjeta en **modo monitor** (`airmon-ng`).
2. **Escanea** redes cercanas y te deja elegir el objetivo.
3. Detecta si tiene **WPS** habilitado (`wash`) y te ofrece atacarlo primero.
4. Según el cifrado:
   - **WEP** → fake auth + ARP replay + crackeo de IVs con `aircrack-ng`.
   - **WPA/WPA2** → deauth + captura de handshake + diccionario.
   - **WPS** → pixie dust con `reaver`, con fallback a fuerza bruta o `bully`.
5. Guarda todo (capturas, logs) en `logs/<bssid>_<fecha>/`.

## Requisitos
- Linux con una tarjeta WiFi que soporte **modo monitor** e inyección.
- `aircrack-ng` (incluye `airmon-ng`, `airodump-ng`, `aireplay-ng`).
- `reaver` o `bully` (ataques WPS) — opcional pero recomendado.
- `wash` (detección de WPS, viene con reaver) — opcional.

```bash
sudo apt install aircrack-ng reaver   # Debian/Ubuntu/Kali
```

## Uso
```bash
chmod +x wpsattack.sh
sudo ./wpsattack.sh -i wlan0 -w /ruta/a/diccionario.txt
```
El script te muestra las redes encontradas, eliges el número de la
objetivo, y continúa según corresponda. Al salir (o con Ctrl+C) devuelve
la interfaz a modo managed automáticamente.

```
Uso: sudo ./wpsattack.sh -i <interfaz> [-w diccionario.txt] [-t segundos] [--yes]
  -i   interfaz inalámbrica (debe soportar modo monitor)
  -w   diccionario para ataques de clave WPA/WPA2
  -t   segundos de escaneo inicial (default 15)
  --yes  omite la confirmación interactiva (solo si ya verificaste
         la autorización por otro medio)
```

## Tests
Los tests de parseo corren sin hardware WiFi real (usan un CSV de muestra):
```bash
bash tests/test_parsing.sh
```

## Estructura
```
wpsattack/
├── wpsattack.sh      # orquestador principal
├── lib/
│   ├── common.sh     # logging, confirmación, utilidades
│   ├── scan.sh        # escaneo y parseo de airodump-ng
│   └── attacks.sh     # lógica de ataque por tipo de cifrado
├── tests/
├── docs/DISCLAIMER.md
└── logs/             # resultados por sesión (ignorado por git)
```

## Roadmap
- [ ] Soporte para `hashcat` como alternativa de crackeo (GPU)
- [ ] Modo `--all` que ataque automáticamente varios objetivos en cola
- [ ] Exportar resumen de sesión en Markdown para el informe

## Licencia
MIT
