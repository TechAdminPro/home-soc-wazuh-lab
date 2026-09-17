# Incidente #02 — Escaneo de puertos (Nmap) — investigación en profundidad

**Fecha:** 2026-09-16 (primera sesión) / 2026-09-17 (retomado)
**Analista:** Carlos (TechAdminPro)
**Severidad:** N/A (hallazgo de infraestructura y de ingeniería de detección, no de seguridad)
**Estado:** Parcialmente remediado — 3 causas raíz reales identificadas y corregidas; la alerta final aún no se confirma disparándose en vivo

## Resumen

Se intentó detectar un escaneo de puertos con Nmap desde `kali-attacker` (192.168.56.10) contra `victim-ubuntu` (192.168.56.20) mediante una regla de correlación personalizada en Wazuh (`rules/local_rules.xml`, regla `100001`) basada en el log de UFW. La primera sesión (16 sep) concluyó erróneamente que el problema era una anomalía de red (el tráfico llegaba con la IP del host físico en vez de la de Kali). Al retomarlo, una investigación más profunda reveló que ese "misterio de red" fue en realidad un problema puntual, y que el verdadero motivo por el que la regla nunca se disparó son **tres fallos de ingeniería de detección independientes y apilados**, todos dentro de Wazuh/UFW, no de la red.

## Timeline

| Momento | Evento |
|------|--------|
| 2026-09-16 21:29 | Primer intento de Nmap. El tráfico llega a la víctima, pero con SRC=192.168.56.1 (host físico) en vez de la IP de Kali — se documenta (erróneamente, con retrospectiva) como bloqueo de red sin resolver |
| 2026-09-17 16:25 | Se relanza el escaneo con acceso SSH directo a las VMs. El tráfico llega esta vez **con la IP real de Kali** (192.168.56.10) — descarta el "misterio de red" como problema persistente |
| 2026-09-17 16:2x | **Causa raíz #1:** UFW aplica un límite de tasa a su propio log (`-m limit --limit 3/min --limit-burst 10`, hardcodeado por nivel de logging, no está en un fichero editable). Con cualquier volumen de escaneo, nunca se registran más de ~10 líneas de golpe — la regla `100001` exige 15 eventos en 10s, matemáticamente imposible de alcanzar así |
| 2026-09-17 16:2x | Se sube `ufw logging high` para quitar el límite — soluciona la causa #1, pero genera 40.000+ líneas de log en segundos (loguea *todo* el tráfico, no solo lo bloqueado) |
| 2026-09-17 16:26 | `wazuh-logtest` revela **Causa raíz #2**: Wazuh no decodifica estas líneas como `ufw`. El decoder `ufw` de stock (`0140-kernel_decoders.xml`) espera el formato antiguo del kernel con un contador de uptime entre corchetes (`kernel: [ 2870.303541] [UFW BLOCK]...`); el Ubuntu moderno de la víctima no lo incluye (`kernel: [UFW BLOCK]...` directo) — decodifica genéricamente como `kernel`, sin extraer `srcip`. La regla `100000` (`decoded_as>ufw`) nunca puede matchear |
| 2026-09-17 16:5x–17:0x | Se escribe un decoder propio (`ufw-nobracket`, hijo de `kernel`) que sí extrae `srcip`/`dstip` correctamente (confirmado con `wazuh-logtest`) |
| 2026-09-17 17:0x | El manager se queda sin agente activo temporalmente: la cola interna del agente se desborda (`Rule 203: Agent event queue is full`) por el volumen de "logging high" — se revierte a `ufw logging low` y se ajusta el umbral de la regla `100001` (de 15/10s a 8/20s) para que sea alcanzable con el ratio real de UFW en modo bajo |
| 2026-09-17 17:1x | Se descubre **Causa raíz #3**: mi decoder `ufw-nobracket` tenía `<type>firewall</type>`, lo que lo hacía competir con el árbol nativo de reglas por categoría (`<category>firewall</category>`, regla `2` → `4100` → `4101`). Wazuh solo recorre **un** árbol de reglas raíz por evento; con `type=firewall`, el evento se lo quedaba el árbol de categoría nativo y nuestra regla `100000` (basada en `if_sid=0` + `decoded_as`) nunca se intentaba siquiera. Se quita `type=firewall` del decoder — la regla `100000` empieza a aparecer en la traza de depuración de reglas |
| 2026-09-17 17:2x | Con la regla `100000` ya "intentada", `wazuh-logtest` no confirma un match, y el log de alertas real tampoco muestra la descripción de la regla tras relanzar el escaneo. Se pausa la investigación en un estado estable (ver "Estado final") |

## Causas raíz identificadas

1. **Límite de tasa de UFW** (`3/min`, burst 10) — inherente al binario `ufw`, no configurable por fichero; solo se puede evitar subiendo el nivel de logging a `high` (con el coste de loguear todo el tráfico, no solo lo bloqueado).
2. **Decoder de Wazuh desactualizado para syslog moderno** — el decoder `ufw` de stock asume el formato de kernel con `[uptime]` que el rsyslog/journald de Ubuntu 22.04+ ya no emite. Escribir un decoder propio (`ufw-nobracket`) como hijo de `kernel` corrige la extracción de campos.
3. **Conflicto entre el sistema de enrutamiento por categoría y el de `if_sid=0`** — un decoder con `<type>firewall</type>` desvía el evento al árbol de reglas nativo por categoría, impidiendo que reglas propias basadas en `if_sid=0` + `decoded_as` se lleguen a evaluar para ese mismo evento. Son dos mecanismos de enrutamiento mutuamente excluyentes dentro del motor de reglas de Wazuh, algo no evidente sin depurar con `wazuh-logtest -v`.

## Estado final (queda para retomar)

- `victim-ubuntu`: `ufw logging low` (estable, sin desbordar la cola del agente).
- `wazuh-manager`: decoder `ufw-nobracket` instalado en `/var/ossec/etc/decoders/local_decoder.xml` (hijo de `kernel`, sin `type`, extrae `srcip`/`dstip` — confirmado), `rules/local_rules.xml` con el umbral de la regla `100001` ajustado a `frequency="8" timeframe="20"`.
- Pendiente: confirmar en vivo el disparo de la regla `100000`/`100001`, o alternativamente extraer también el campo `action` (`BLOCK`/`AUDIT`) para enganchar con las reglas nativas de Wazuh `4101`/`4151` ("Multiple Firewall drop events from same source", ya pensada para exactamente este caso) — la sintaxis de regex propia de Wazuh (no es PCRE estándar; ver notas) necesita más pruebas para escapar correctamente los corchetes literales `[` `]`.

## Lección aprendida

Esta ha sido, con diferencia, la investigación más profunda del laboratorio hasta ahora — y un buen recordatorio de que un log que "no aparece" puede tener varias causas independientes apiladas, no una sola. Cada arreglo dejó a la vista el siguiente problema: primero el límite de tasa, luego el decoder desactualizado, luego un conflicto de enrutamiento interno de Wazuh que no está documentado de forma obvia. En un SOC real, esto es exactamente el tipo de trabajo de "tuning" de la ingeniería de detección que ocurre antes de que una regla sea fiable — y documentar el proceso completo (incluyendo lo que no se resolvió) es tan valioso como la alerta final.

Nota técnica: el motor de reglas/decoders de Wazuh usa su propia sintaxis de regex ("OSRegex"), no PCRE estándar — por ejemplo, `\.+`/`\.*` representan "cualquier carácter" en su convención, y el escape de corchetes literales (`\[`) que funciona en PCRE puede dar `Syntax error on regex` aquí. Cualquier decoder personalizado debe probarse con `sudo wazuh-logtest -v` antes de asumir que compila.
