# 5. Reglas de detección personalizadas

Wazuh ya trae reglas out-of-the-box para fuerza bruta SSH (grupo `authentication_failed`, IDs 5710-5716) y para FIM. Para el escaneo de puertos con Nmap no hay una regla nativa de host, así que escribimos una propia basada en el volumen de conexiones nuevas desde una misma IP en poco tiempo.

## Instalación de la regla custom

1. Copia el contenido de [`rules/local_rules.xml`](../rules/local_rules.xml) en `/var/ossec/etc/rules/local_rules.xml` del **manager** (192.168.56.30).
2. Reinicia el manager:

```bash
sudo systemctl restart wazuh-manager
```

3. Verifica que la sintaxis es correcta:

```bash
sudo /var/ossec/bin/wazuh-logtest
```

## Cómo funciona la regla de escaneo de puertos

Se basa en los logs de conexión que genera el firewall del host víctima (`iptables`/`ufw` con logging activado) o, alternativamente, en el log del propio `sshd`/servicios expuestos. La regla usa `frequency` y `timeframe` para disparar cuando detecta más de N eventos de "nuevo intento de conexión" desde la misma `srcip` en menos de 10 segundos — patrón típico de un escaneo automatizado tipo Nmap.

Para que UFW loguee las conexiones:

```bash
sudo ufw logging on
```

Y añade el log de ufw como fuente en `ossec.conf` del agente víctima:

```xml
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/ufw.log</location>
</localfile>
```

## Probar la regla

Relanza `scripts/nmap_scan.sh` y busca en el dashboard, en **Threat Hunting**, alertas con `rule.id: 100001` (o el ID que hayas usado) y descripción "Posible escaneo de puertos detectado".

Captura sugerida: `reports/screenshots/05-portscan-custom-rule.png`.

Siguiente paso → [06-incident-report-template.md](06-incident-report-template.md)
