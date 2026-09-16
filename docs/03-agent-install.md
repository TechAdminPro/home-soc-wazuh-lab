# 3. Instalación y registro del agente en la víctima

En `victim-ubuntu` (192.168.56.20):

## Paso 1 — Instalar el agente

```bash
curl -sO https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.9.0-1_amd64.deb
sudo WAZUH_MANAGER='192.168.56.30' dpkg -i ./wazuh-agent_4.9.0-1_amd64.deb
```

(Ajusta la versión del paquete a la que instalaste en el manager.)

## Paso 2 — Habilitar y arrancar el servicio

```bash
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
```

## Paso 3 — Verificar en el dashboard

En `https://192.168.56.30` → **Agents**, el agente `victim-ubuntu` debe aparecer como **Active**.

Captura sugerida: `reports/screenshots/03-agent-active.png`.

## Paso 4 — Habilitar File Integrity Monitoring (FIM)

Edita `/var/ossec/etc/ossec.conf` en la víctima y añade dentro de `<syscheck>`:

```xml
<syscheck>
  <directories check_all="yes" realtime="yes">/etc</directories>
  <directories check_all="yes" realtime="yes">/root</directories>
</syscheck>
```

```bash
sudo systemctl restart wazuh-agent
```

Esto es lo que nos permitirá detectar modificaciones en `/etc/passwd` más adelante.

Siguiente paso → [04-attack-simulations.md](04-attack-simulations.md)
