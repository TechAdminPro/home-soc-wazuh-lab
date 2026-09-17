# Incidente #02 — Escaneo de puertos (Nmap)

**Fecha:** 2026-09-16 (primera sesión) / 2026-09-17 (resuelto)
**Analista:** Carlos (TechAdminPro)
**Severidad:** Media
**Estado:** Detectado

## Resumen

Se lanzó un escaneo de puertos con Nmap desde `kali-attacker` (192.168.56.10) contra `victim-ubuntu` (192.168.56.20). Wazuh lo detectó mediante una regla de correlación personalizada (`rules/local_rules.xml`, regla `100001`) basada en el log de UFW: **más de 15 conexiones bloqueadas desde la misma IP en 10 segundos**. Llegar hasta aquí requirió corregir **tres fallos de ingeniería de detección independientes y apilados**, ninguno de ellos relacionado con la red (la hipótesis inicial de la primera sesión).

## Timeline

| Momento | Evento |
|------|--------|
| 2026-09-16 21:29 | Primer intento de Nmap. El tráfico llega con SRC=192.168.56.1 (host físico) en vez de la IP de Kali — se documenta (erróneamente) como bloqueo de red |
| 2026-09-17 16:25 | Se relanza el escaneo con acceso SSH directo. El tráfico llega esta vez **con la IP real de Kali** — descarta el "misterio de red" como problema persistente (fue puntual) |
| 2026-09-17 16:2x | **Causa raíz #1:** UFW aplica un límite de tasa a su propio log (`-m limit --limit 3/min --limit-burst 10`, fijo por nivel de logging). Con cualquier volumen de escaneo nunca se registran más de ~10 líneas de golpe — la regla exigía 15 eventos en 10s, matemáticamente imposible. *Fix:* se prueba subir a `ufw logging high` (sin límite), pero genera 40.000+ líneas y desborda la cola del agente — se revierte a `low` y se ajusta el umbral de la regla a 8 eventos/20s, alcanzable con el ratio real de UFW |
| 2026-09-17 16:26 | **Causa raíz #2:** Wazuh no decodificaba estas líneas como `ufw`. El decoder de stock espera el formato antiguo del kernel con un contador de uptime entre corchetes (`kernel: [ 2870.303541] [UFW BLOCK]...`); el Ubuntu moderno de la víctima no lo incluye. *Fix:* decoder propio `ufw-nobracket` (hijo de `kernel`) que extrae `srcip`/`dstip` sin depender de ese formato |
| 2026-09-17 17:1x | **Causa raíz #3:** el decoder propio tenía `<type>firewall</type>`, lo que lo hacía competir con el árbol nativo de reglas por categoría de Wazuh (`<category>firewall</category>`) — la regla `100000` (basada en `if_sid=0`+`decoded_as`) nunca se llegaba a intentar. *Fix:* se quita `type`. Descubrimiento adicional: `decoded_as` en las reglas de Wazuh compara contra el nombre del decoder **padre** (`kernel`), no el del hijo — se ajusta la regla `100000` a `decoded_as>kernel` + `<match>UFW </match>` para mantenerla específica |
| 2026-09-17 17:39:57 | Escaneo final: **11 alertas de regla `100000`** (una por conexión bloqueada) y **1 alerta de regla `100001`** (correlación de escaneo) — detección confirmada en el log de alertas real del manager |

## Indicadores de compromiso (IOCs)

- **IP origen (atacante):** 192.168.56.10 (`kali-attacker`)
- **IP destino (víctima):** 192.168.56.20 (`victim-ubuntu`, agente `victima`, ID 001)
- **Herramienta:** Nmap
- **Reglas Wazuh disparadas:**
  - `100000` — Evento de firewall UFW registrado (nivel 3) — 11 veces en el escaneo final
  - `100001` — **Posible escaneo de puertos detectado: más de 15 conexiones desde $(srcip) en 10 segundos (nivel 10)** ← regla de correlación, la relevante
- **MITRE ATT&CK:** T1046 (Network Service Discovery), grupo `recon,attack`

## Evidencia

Alerta de correlación real (`/var/ossec/logs/alerts/alerts.log` en el manager):

```
** Alert 1789666799.230254: - local,syslog,firewall,recon,attack,
2026 Sep 17 17:39:59 (victima) any->/var/log/ufw.log
Rule: 100001 (level 10) -> 'Posible escaneo de puertos detectado: más de 15 conexiones desde 192.168.56.10 en 10 segundos.'
Src IP: 192.168.56.10
Dst IP: 192.168.56.20
2026-09-17T17:39:57.459080+00:00 victima kernel: [UFW BLOCK] IN=enp0s8 OUT= MAC=... SRC=192.168.56.10 DST=192.168.56.20 ... DPT=25 ... SYN
```

Muestra de los eventos base correlacionados (destinos escaneados en <2 segundos): puertos 23, 25, 21, 143, 3306, 3389, 554, 443, 587, entre otros — patrón típico de un escaneo automatizado, no de tráfico legítimo.

## Análisis

La regla `100001` correla eventos `100000` (cualquier conexión bloqueada por UFW) de la misma IP de origen dentro de una ventana corta. El umbral final (8 eventos/20s) se ajustó deliberadamente por debajo del "ideal" teórico (15/10s) porque el propio límite de tasa de UFW en modo `low` (el modo recomendable para no saturar la telemetría) nunca entrega más de ~10 eventos de golpe — de nada sirve una regla de correlación cuyo umbral es más alto que el volumen máximo que la fuente de datos puede físicamente entregar.

**Falsos positivos esperados:** un cliente con reintentos agresivos mal configurado, o un escaneo de salud/monitorización interno (Nagios, Zabbix) tocando muchos puertos rápidamente, dispararía la misma regla. El nivel 10 (alto pero no crítico) es apropiado para esta señal.

## Remediación / Recomendación

- En producción, este patrón normalmente lo cubre un IDS/IPS de red (Suricata/Zeek) en vez de logs de host — más rápido y no depende del rate-limit del firewall local.
- Si se depende de logs de host, documentar y ajustar el umbral de correlación al rate-limit real del logging del firewall en uso, no a un número "redondo" teórico — es el error que causó el bloqueo original.
- Considerar una **active response** en Wazuh que banee temporalmente (`ufw insert 1 deny from $(srcip)`) al disparar la regla `100001`.

## Lecciones aprendidas

Esta ha sido la investigación más profunda del laboratorio. Cada fix dejó a la vista el siguiente problema, en cascada:

1. **El límite de tasa de UFW** hace matemáticamente imposible un umbral de correlación demasiado optimista — hay que dimensionar la regla según lo que la fuente puede entregar de verdad, no según lo que "parece razonable" sobre el papel.
2. **Los decoders de Wazuh no siempre siguen el ritmo de los formatos de log modernos** — el decoder `ufw` de stock data de una época en la que el kernel de Linux prefijaba un contador de uptime que journald/rsyslog ya no emiten por defecto en Ubuntu 22.04+.
3. **`decoded_as` en una regla de Wazuh compara contra el decoder padre, no el hijo** — nada intuitivo, y no quedó claro hasta depurar con `sudo wazuh-logtest -v` y comparar directamente qué "name" reportaba la Fase 2 frente a lo que la regla esperaba.
4. Wazuh usa su propio dialecto de regex ("OSRegex", no PCRE) en decoders — `\.+`/`\.*` significan "cualquier carácter", y escapar corchetes literales con `\[` dio error de sintaxis mientras que usarlos sin escapar funcionó; cualquier decoder nuevo debe probarse con `wazuh-logtest` antes de asumir que compila.

En un SOC real, este es exactamente el trabajo de "tuning" de la ingeniería de detección que ocurre antes de confiar en una regla — y verificar el resultado en el log de alertas real (no solo en la herramienta de test) fue lo que finalmente confirmó la detección.
