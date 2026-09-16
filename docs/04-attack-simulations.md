# 4. Simulación de ataques

Todos los ataques se lanzan desde `kali-attacker` (192.168.56.10) contra `victim-ubuntu` (192.168.56.20). Los scripts están en [`scripts/`](../scripts/).

## 4.1 Fuerza bruta SSH (Hydra)

```bash
sudo apt install -y hydra
./scripts/ssh_bruteforce.sh 192.168.56.20 usuarios.txt contraseñas.txt
```

Genera decenas de intentos fallidos de login SSH en segundos. En el dashboard de Wazuh, busca en **Threat Hunting** eventos con `rule.groups: authentication_failed` y la IP de Kali como origen.

Captura sugerida: `reports/screenshots/04-ssh-bruteforce-alert.png`.

## 4.2 Escaneo de puertos (Nmap)

```bash
./scripts/nmap_scan.sh 192.168.56.20
```

Ejecuta un escaneo `-sS -A -T4` de todos los puertos. Por defecto Wazuh no tiene una regla dedicada a "escaneo de puertos" (eso se detecta a nivel de red/IDS, no de host), así que este ataque es el motivo para escribir la **regla personalizada** de la sección 5: contar conexiones nuevas por segundo desde una misma IP.

## 4.3 Archivo malicioso de prueba (EICAR)

```bash
./scripts/download_eicar.sh
```

Descarga el fichero de test estándar de la industria antivirus (inofensivo, diseñado para ser detectado por cualquier AV). Si integras ClamAV + Wazuh active response, esto dispara una alerta de malware.

## 4.4 Modificación de archivo crítico

Desde Kali, si has dejado alguna cuenta con SSH débil comprometida en el paso 4.1 (o simplemente desde la propia víctima para simular un insider):

```bash
sudo useradd -m backdoor_user
```

Esto modifica `/etc/passwd`, lo que FIM (configurado en el paso 3) debe detectar y reportar en tiempo real.

Captura sugerida: `reports/screenshots/04-fim-passwd-alert.png`.

## Registro de resultados

Por cada ataque, completa un informe usando la [plantilla de incidente](06-incident-report-template.md) y guárdalo en `reports/` (ej. `reports/incident-01-ssh-bruteforce.md`).

Siguiente paso → [05-detection-rules.md](05-detection-rules.md)
