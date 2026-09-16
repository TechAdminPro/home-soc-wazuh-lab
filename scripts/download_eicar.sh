#!/usr/bin/env bash
# Descarga el fichero de test EICAR (estándar de la industria antivirus, inofensivo)
# para verificar que la integración Wazuh + ClamAV detecta malware de prueba.
# Ejecutar en la VM víctima.

set -euo pipefail

DEST="${1:-/tmp/eicar.com}"

echo "[*] Descargando fichero de test EICAR en $DEST"
curl -sSL https://secure.eicar.org/eicar.com -o "$DEST"
echo "[*] Listo. Si ClamAV + Wazuh active response están configurados, debería generarse una alerta."
