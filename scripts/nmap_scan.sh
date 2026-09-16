#!/usr/bin/env bash
# Escaneo de puertos y servicios contra la VM víctima del lab.
# Uso: ./nmap_scan.sh <ip_victima>
#
# Solo pensado para la red host-only del lab (192.168.56.0/24).

set -euo pipefail

TARGET="${1:?Uso: $0 <ip_victima>}"

if [[ "$TARGET" != 192.168.56.* ]]; then
  echo "Aviso: la IP objetivo ($TARGET) no pertenece a la red host-only del lab (192.168.56.0/24)." >&2
  read -rp "¿Continuar de todos modos? (escribe 'si' para confirmar) " confirm
  [[ "$confirm" == "si" ]] || { echo "Cancelado."; exit 1; }
fi

OUT="nmap-scan-$(date +%Y%m%d-%H%M%S).txt"
echo "[*] Escaneando $TARGET (salida en $OUT)"
sudo nmap -sS -sV -A -T4 -p- "$TARGET" -oN "$OUT"
echo "[*] Escaneo completado. Revisa $OUT"
