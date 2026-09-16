# 1. Preparación de red y máquinas virtuales

## Requisitos

- VirtualBox instalado (ya lo tienes en el escritorio).
- ISOs: Ubuntu Server 22.04 LTS, Kali Linux (VM oficial de Offensive Security, más rápido que instalar desde ISO).
- Al menos 8 GB de RAM libres en el host (Wazuh recomienda 4 GB para el manager en labs pequeños).

## Paso 1 — Crear red host-only

1. VirtualBox → `Archivo > Herramientas de red host` (Host Network Manager).
2. Crear una red nueva, por ejemplo `VirtualBox Host-Only Ethernet Adapter`.
3. Configurar el rango: `192.168.56.0/24`, DHCP deshabilitado (asignaremos IPs estáticas).

## Paso 2 — Crear las 3 VMs

| VM | SO | RAM | vCPU | Disco | Red |
|----|----|----|------|-------|-----|
| `wazuh-manager` | Ubuntu Server 22.04 | 4 GB | 2 | 40 GB | Adaptador 1: NAT · Adaptador 2: Host-only (192.168.56.30) |
| `victim-ubuntu` | Ubuntu Server 22.04 | 2 GB | 1 | 20 GB | Adaptador 1: NAT · Adaptador 2: Host-only (192.168.56.20) |
| `kali-attacker` | Kali Linux (VM oficial) | 4 GB | 2 | 40 GB | Adaptador 1: NAT · Adaptador 2: Host-only (192.168.56.10) |

> El adaptador NAT es solo para poder hacer `apt update`/descargar Wazuh durante la instalación. Las pruebas de ataque se hacen por el adaptador host-only, para mantener el lab aislado del resto de tu red doméstica.

## Paso 3 — Configurar IP estática en cada VM (Ubuntu, netplan)

En `victim-ubuntu` y `wazuh-manager`, edita `/etc/netplan/00-installer-config.yaml` (el segundo adaptador, `enp0s8` normalmente):

```yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      dhcp4: false
      addresses: [192.168.56.20/24]   # .30 en wazuh-manager
```

```bash
sudo netplan apply
```

En Kali, configura la interfaz host-only con IP fija `192.168.56.10` desde el gestor de red o `/etc/network/interfaces`.

## Paso 4 — Verificar conectividad

Desde `kali-attacker`:

```bash
ping -c3 192.168.56.20   # victim-ubuntu
ping -c3 192.168.56.30   # wazuh-manager
```

Deberías tener respuesta de ambas. Captura de pantalla sugerida: `reports/screenshots/01-network-ping.png`.

Siguiente paso → [02-wazuh-install.md](02-wazuh-install.md)
