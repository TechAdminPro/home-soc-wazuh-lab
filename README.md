# 🛡️ Home SOC Wazuh Lab

> Laboratorio casero de Blue Team / SOC: detección, correlación de logs y respuesta a incidentes sobre ataques simulados, usando [Wazuh](https://wazuh.com/) como plataforma SIEM/XDR.
> Carlos Munaiz Cossio · 2026

[![Wazuh](https://img.shields.io/badge/SIEM-Wazuh-3b82f6?style=flat-square&logo=wazuh&logoColor=white)](https://wazuh.com/)
[![Platform](https://img.shields.io/badge/Lab-VirtualBox-183A61?style=flat-square&logo=virtualbox&logoColor=white)](.)
[![Focus](https://img.shields.io/badge/Focus-Blue%20Team%20%2F%20SOC-0f172a?style=flat-square)](.)
[![Status](https://img.shields.io/badge/Estado-Completado-brightgreen?style=flat-square)](.)
[![License](https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square)](LICENSE)

---

## 📋 Descripción

Este proyecto complementa mis laboratorios ofensivos ([syn-flood-lab](https://github.com/TechAdminPro/syn-flood-lab), [badusb-endpoint-analysis](https://github.com/TechAdminPro/badusb-endpoint-analysis), [web-security-audit-lab](https://github.com/TechAdminPro/web-security-audit-lab)) con el lado defensivo: montar un mini-SOC funcional, lanzar ataques reales contra él y documentar cada detección como un informe de incidente, con timeline, indicadores de compromiso, análisis y recomendaciones de remediación mapeadas a MITRE ATT&CK.

No fue un despliegue limpio a la primera. Varios de los ataques dejaron de detectarse por fallos reales de configuración e ingeniería de detección — encontrarlos, entenderlos y corregirlos de raíz es precisamente el tipo de trabajo que documenta este repositorio.

> ⚠️ **Aviso legal**: laboratorio 100% aislado en red host-only local, sin acceso a sistemas de terceros. Todas las herramientas y técnicas se usan únicamente con fines educativos y de práctica defensiva sobre infraestructura propia.

---

## 🗂️ Estructura del repositorio

```
home-soc-wazuh-lab/
│
├── README.md
├── LICENSE
│
├── docs/                       # Guías paso a paso
│   ├── 01-network-setup.md
│   ├── 02-wazuh-install.md
│   ├── 03-agent-install.md
│   ├── 04-attack-simulations.md
│   ├── 05-detection-rules.md
│   └── 06-incident-report-template.md
│
├── scripts/                    # Scripts de simulación de ataques (Kali)
│   ├── ssh_bruteforce.sh
│   ├── nmap_scan.sh
│   └── download_eicar.sh
│
├── rules/
│   └── local_rules.xml         # Reglas de correlación personalizadas
│
├── decoders/
│   └── local_decoder.xml       # Decoder UFW propio (ver incidente 02)
│
└── reports/                     # Informes de incidente + capturas
    ├── incident-01-ssh-bruteforce.md
    ├── incident-02-nmap-portscan.md
    ├── incident-03-fim-passwd.md
    └── screenshots/
```

---

## 🏗️ Arquitectura

```
┌──────────────────┐        red interna host-only (192.168.56.0/24)
│   Kali Linux      │ ─────────────────┐
│   (Atacante)      │                  │
│   192.168.56.10   │                  │
└──────────────────┘                  ▼
                              ┌──────────────────────┐
                              │  Ubuntu Server        │
                              │  (Víctima + Agente    │
                              │   Wazuh)               │
                              │  192.168.56.20        │
                              └──────────────────────┘
                                         │
                                         ▼
                              ┌──────────────────────┐
                              │  Wazuh Manager +      │
                              │  Indexer + Dashboard  │
                              │  192.168.56.30        │
                              └──────────────────────┘
```

Todo corre en VirtualBox sobre una red "solo anfitrión" (host-only) + NAT para salida a internet durante la instalación.

---

## 🎯 Objetivos

| # | Objetivo | Estado |
|---|----------|--------|
| 1 | Recibir telemetría de un endpoint víctima vía agente Wazuh | ✅ Completado |
| 2 | Detectar ataques lanzados desde una máquina atacante | ✅ Completado |
| 3 | Escribir y depurar reglas de detección personalizadas | ✅ Completado |
| 4 | Documentar cada incidente con timeline, IOCs y remediación | ✅ Completado |
| 5 | Probar malware de test (EICAR) + integración ClamAV | 🔜 Línea futura |
| 6 | Active response (bloqueo automático de IP) | 🔜 Línea futura |

---

## 🧪 Ataques simulados

| # | Ataque | Herramienta | Detección |
|---|--------|-------------|-----------|
| 1 | Fuerza bruta SSH | Hydra | Reglas nativas de Wazuh (`5710`, `5551`) — sin necesitar regla propia |
| 2 | Escaneo de puertos | Nmap | Regla de correlación propia (`100001`) + decoder UFW propio |
| 3 | Modificación de archivo crítico | `useradd` sobre `/etc/passwd` | File Integrity Monitoring (`550`) en tiempo real |
| 4 | Malware de prueba (EICAR) | descarga manual | Integración Wazuh + ClamAV — no ejecutado todavía |

---

## 🛡️ Resultados clave

| Incidente | Regla disparada | Nivel | MITRE ATT&CK | Informe |
|-----------|-----------------|-------|---------------|---------|
| Fuerza bruta SSH | `5551` PAM: Multiple failed logins | 10 | T1110 Brute Force | [informe](reports/incident-01-ssh-bruteforce.md) |
| Escaneo de puertos Nmap | `100001` correlación propia | 10 | T1046 Network Service Discovery | [informe](reports/incident-02-nmap-portscan.md) |
| Modificación de `/etc/passwd` | `550` Integrity checksum changed | 7 | T1565.001 Stored Data Manipulation | [informe](reports/incident-03-fim-passwd.md) |

**El hallazgo más interesante:** el escaneo de puertos dejó de detectarse por tres fallos de infraestructura apilados (límite de tasa de UFW, un decoder de Wazuh desactualizado para logs de kernel modernos, y un conflicto interno entre dos sistemas de enrutamiento de reglas de Wazuh) — no por el problema de red que parecía al principio. El detalle completo, incluyendo el proceso de diagnóstico con `wazuh-logtest`, está en el [informe del incidente 02](reports/incident-02-nmap-portscan.md).

---

## 📚 Guías (en orden)

1. [Preparación de red y VMs](docs/01-network-setup.md)
2. [Instalación de Wazuh Manager + Indexer + Dashboard](docs/02-wazuh-install.md)
3. [Instalación y registro del agente en la víctima](docs/03-agent-install.md)
4. [Simulación de ataques](docs/04-attack-simulations.md)
5. [Reglas de detección personalizadas](docs/05-detection-rules.md)
6. [Plantilla de informe de incidente](docs/06-incident-report-template.md)

---

## 🔮 Líneas de ampliación futura

- [ ] Ejecutar el ataque de malware de prueba (EICAR) con integración ClamAV
- [ ] Configurar **active response** en Wazuh para bloqueo automático de IP tras alerta
- [ ] Extender el decoder UFW propio para enganchar con las reglas nativas `4101`/`4151` de Wazuh
- [ ] Añadir un segundo endpoint víctima (Windows) para comparar cobertura de detección

---

## 👨‍💻 Autor

**Carlos Munaiz Cossio**
Ciberseguridad · 2026
[![LinkedIn](https://img.shields.io/badge/LinkedIn-carlos--munaiz-0A66C2?style=flat-square&logo=linkedin)](https://www.linkedin.com/in/carlos-munaiz/)
[![GitHub](https://img.shields.io/badge/GitHub-TechAdminPro-181717?style=flat-square&logo=github)](https://github.com/TechAdminPro)

---

## 📄 Licencia

Este proyecto se distribuye bajo licencia [MIT](LICENSE). Puedes usarlo con fines educativos y de investigación, siempre dentro del marco legal y con los permisos correspondientes.
