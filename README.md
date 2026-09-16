# home-soc-wazuh-lab

Laboratorio casero de **Blue Team / SOC** con [Wazuh](https://wazuh.com/) para detectar, analizar y responder a ataques simulados en un entorno controlado con VirtualBox.

Complementa mis laboratorios ofensivos ([syn-flood-lab](https://github.com/TechAdminPro/syn-flood-lab), [badusb-endpoint-analysis](https://github.com/TechAdminPro/badusb-endpoint-analysis), [web-security-audit-lab](https://github.com/TechAdminPro/web-security-audit-lab)) con el lado defensivo: monitorización, correlación de logs y respuesta a incidentes.

## Objetivo

Montar un mini-SOC funcional que:

1. Recibe telemetría de un endpoint víctima (Ubuntu Server) vía agente Wazuh.
2. Detecta ataques lanzados desde una máquina atacante (Kali Linux).
3. Genera alertas y reglas de detección personalizadas.
4. Documenta cada incidente con un informe estilo SOC (timeline, IOCs, severidad, remediación).

## Arquitectura

```
┌─────────────────┐        red interna NAT (192.168.56.0/24)
│  Kali Linux      │ ───────────────┐
│  (Atacante)      │                │
│  192.168.56.10   │                │
└─────────────────┘                │
                                     ▼
                          ┌──────────────────┐
                          │ Ubuntu Server     │
                          │ (Víctima + Agente │
                          │  Wazuh)           │
                          │ 192.168.56.20     │
                          └──────────────────┘
                                     │
                                     ▼
                          ┌──────────────────┐
                          │ Wazuh Manager +   │
                          │ Indexer + Dashboard│
                          │ 192.168.56.30     │
                          └──────────────────┘
```

Todo corre en VirtualBox sobre una red "solo anfitrión" (host-only) + NAT para salida a internet durante la instalación.

## Estructura del repo

```
docs/       Guías paso a paso (red, instalación, agente, ataques, reglas, informe)
scripts/    Scripts de simulación de ataques usados en la máquina Kali
rules/      Reglas de detección personalizadas de Wazuh (XML)
reports/    Informes de incidentes generados durante las pruebas + capturas
```

## Guías (en orden)

1. [Preparación de red y VMs](docs/01-network-setup.md)
2. [Instalación de Wazuh Manager + Indexer + Dashboard](docs/02-wazuh-install.md)
3. [Instalación y registro del agente en la víctima](docs/03-agent-install.md)
4. [Simulación de ataques](docs/04-attack-simulations.md)
5. [Reglas de detección personalizadas](docs/05-detection-rules.md)
6. [Plantilla de informe de incidente](docs/06-incident-report-template.md)

## Ataques simulados

| # | Ataque | Herramienta | Detección esperada |
|---|--------|-------------|---------------------|
| 1 | Fuerza bruta SSH | Hydra | Regla Wazuh `5710`/`5712` + regla custom de bloqueo tras N intentos |
| 2 | Escaneo de puertos | Nmap | Regla custom basada en volumen de conexiones desde una IP |
| 3 | Malware de prueba (EICAR) | descarga manual | Integración Wazuh + ClamAV (FIM + active response) |
| 4 | Modificación de archivo crítico | `/etc/passwd` | File Integrity Monitoring (FIM) de Wazuh |

## Resultados

_(se completa a medida que se ejecutan las pruebas — ver `reports/`)_

- [ ] Dashboard de Wazuh operativo con agente reportando
- [ ] Alerta de fuerza bruta SSH detectada y documentada
- [ ] Alerta de escaneo Nmap detectada y documentada
- [ ] FIM detectando cambios en archivos críticos
- [ ] Regla custom escrita y probada
- [ ] Informe de incidente completo con timeline

## Disclaimer

Laboratorio 100% aislado en red host-only local, sin acceso a sistemas de terceros. Todas las herramientas y técnicas se usan únicamente con fines educativos y de práctica defensiva sobre infraestructura propia.
