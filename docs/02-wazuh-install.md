# 2. Instalación de Wazuh (Manager + Indexer + Dashboard)

Se usa el instalador todo-en-uno oficial sobre la VM `wazuh-manager` (192.168.56.30). Es la opción más simple para un lab de un solo nodo.

## Paso 1 — Descargar e instalar

```bash
curl -sO https://packages.wazuh.com/4.9/wazuh-install.sh
sudo bash wazuh-install.sh -a
```

Esto instala Wazuh indexer, manager y dashboard en la misma máquina. Al finalizar, el script muestra las credenciales de administrador del dashboard (usuario `admin` y una contraseña generada) — **guárdalas**, no se vuelven a mostrar.

Si las pierdes, puedes regenerarlas con:

```bash
sudo tar -xvf wazuh-install-files.tar
sudo bash wazuh-passwords-tool.sh -a -A
```

## Paso 2 — Acceder al dashboard

Desde el navegador del host (o de Kali):

```
https://192.168.56.30
```

Acepta el certificado autofirmado y entra con `admin` + la contraseña generada.

Captura sugerida: `reports/screenshots/02-dashboard-login.png`.

## Paso 3 — Verificar servicios

```bash
sudo systemctl status wazuh-manager
sudo systemctl status wazuh-indexer
sudo systemctl status wazuh-dashboard
```

Los tres deben estar `active (running)`.

Siguiente paso → [03-agent-install.md](03-agent-install.md)
