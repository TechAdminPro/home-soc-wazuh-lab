# Incidente #02 — Escaneo de puertos (Nmap) — investigación parcial

**Fecha:** 2026-09-16
**Analista:** Carlos (TechAdminPro)
**Severidad:** N/A (hallazgo de infraestructura, no de seguridad)
**Estado:** Bloqueado por anomalía de red — pendiente de retomar

## Resumen

Se intentó lanzar un escaneo de puertos con Nmap desde `kali-attacker` (192.168.56.10) contra `victim-ubuntu` (192.168.56.20), con UFW activo y logging habilitado en la víctima, y una regla de correlación personalizada instalada en Wazuh (`rules/local_rules.xml`, regla `100001`) para detectar el patrón.

**El ataque se ejecutó correctamente desde Kali** (confirmado en su propia terminal: Nmap reportó los puertos como "filtered", indicando que los paquetes SYN se enviaron y no obtuvieron respuesta). Sin embargo, **el tráfico nunca apareció en `/var/log/ufw.log` de la víctima con la IP real de Kali**.

## Investigación realizada

1. Se confirmó conectividad normal entre Kali y la víctima (ping, SSH) — descartando un problema de enrutamiento básico.
2. Se verificó que UFW estaba activo y con logging en nivel `low`, luego `high` (sin límite de frecuencia) — sin cambios.
3. Se hizo `grep` del log completo (10.238 líneas) buscando la IP de Kali en sus dos variantes (`192.168.56.10` estática y `192.168.56.108` dinámica, ya que la interfaz tenía ambas configuradas) — **0 coincidencias en ambos casos**.
4. Se usó `tcpdump` directamente en la interfaz de red de la víctima para observar el tráfico a nivel de paquete, evitando depender del log de UFW. **Resultado inesperado:** el tráfico SÍ llega a la víctima, pero con IP origen `192.168.56.1` — que corresponde al host físico (Windows), no a la VM de Kali.
5. Se descartaron NAT, IP forwarding e Internet Connection Sharing (ICS) en el adaptador host-only de Windows (comprobado con PowerShell: `Get-NetNat`, `Get-NetIPInterface`, `Get-CimInstance HNet_ConnectionProperties` — todo negativo).

## Hipótesis (sin confirmar)

El host tiene instalados tanto VirtualBox como VMware simultáneamente, cada uno con sus propios adaptadores de red virtuales. Es posible que exista algún tipo de interacción entre ambos stacks de virtualización, o algún software adicional (se detectaron indicios de una VPN tipo Tailscale en configuraciones de DNS durante otras partes del lab) que esté interceptando o traduciendo el tráfico en la red host-only `192.168.56.0/24` de forma no evidente a través de las herramientas estándar de diagnóstico de Windows.

## Decisión

Se aparca esta investigación para no bloquear el resto del laboratorio. La regla personalizada (`rules/local_rules.xml`, id `100001`) queda escrita y lista para cuando se retome. Se continúa con el siguiente ataque (FIM sobre `/etc/passwd`), que no depende de logs de red y por tanto no debería verse afectado por esta anomalía.

## Lección aprendida

Este es en sí mismo un ejercicio real de análisis: no todos los problemas de telemetría tienen una causa evidente, y saber **documentar una investigación inconclusa con lo que se descartó y lo que queda pendiente** es una habilidad tan válida como resolver el incidente. Un entorno de laboratorio casero, con múltiples hipervisores y software de red instalados a la vez, introduce variables que no existirían en un entorno de producción controlado — vale la pena anotarlo como limitación del entorno, no como fallo de Wazuh.
