# Incidente #03 — File Integrity Monitoring (FIM) sobre /etc/passwd

**Fecha:** 2026-09-17
**Analista:** Carlos (TechAdminPro)
**Severidad:** Baja (acción administrativa simulada, no un ataque real; demuestra la cobertura de FIM sobre archivos críticos)
**Estado:** Detectado

## Resumen

Se simuló la creación de una cuenta de usuario no autorizada (`useradd backdoor_user`) en `victim-ubuntu` (192.168.56.20), lo que modifica `/etc/passwd`. La vigilancia FIM en tiempo real (`realtime="yes"`) sobre `/etc` y `/root`, prevista desde el paso 4 de la instalación del agente, se había quedado sin aplicar por un error de sintaxis en la sesión anterior. Se corrigió la configuración, se verificó que el agente la cargó correctamente, y al ejecutar el ataque Wazuh detectó el cambio en segundos, generando dos alertas (regla `550`, nivel 7) sobre `/etc/passwd` y su copia de seguridad `/etc/passwd-`.

## Timeline

| Momento | Evento |
|------|--------|
| 2026-09-16 ~22:03–22:17 | Primeros intentos de activar `realtime`/`check_all` en `<syscheck>` vía `sed` — fallan sin dar error (el patrón buscado tenía espacios que no coinciden con el archivo real) y luego con errores de sintaxis de bash (`\n` literal dentro del script de `sed`) |
| 2026-09-16 22:19 | Se aparca el problema sin resolver; se comitea el resto del trabajo del día (incidentes 01 y 02) |
| 2026-09-17 | Se retoma la sesión: se verifica por SSH que `ossec.conf` seguía sin el cambio aplicado (config idéntica a la original) |
| 2026-09-17 | Se corrige la edición (patrón exacto, un `sed` por línea insertada) y se reinicia `wazuh-agent`; el log confirma `Directory set for real time monitoring: '/etc'` y `'/root'`, y `Real-time file integrity monitoring started` |
| 2026-09-17 14:30:37 | Se ejecuta `sudo useradd -m backdoor_user` en la víctima; Wazuh genera 2 alertas de regla `550` sobre `/etc/passwd` y `/etc/passwd-` |

## Indicadores de compromiso (IOCs)

- **Host afectado:** victim-ubuntu (192.168.56.20, agente Wazuh `victima`, ID 001)
- **Usuario que ejecutó el cambio:** root (vía `sudo`)
- **Archivos modificados:** `/etc/passwd`, `/etc/passwd-`
- **Regla Wazuh disparada:** `550` — Integrity checksum changed (nivel 7)
- **MITRE ATT&CK:** `T1565.001` (Stored Data Manipulation), táctica *Impact*
- **Cumplimiento relacionado:** GDPR II_5.1.f, HIPAA 164.312.c.1 / 164.312.c.2

## Evidencia

- Verificación de la configuración corregida en `ossec.conf` tras el reinicio del agente (log `wazuh-syscheckd`).
- Dashboard de Wazuh → File Integrity Monitoring → Events, filtro `passwd`, 2 hits: `reports/screenshots/11-fim-passwd-alert.png`

Log completo del evento (`full_log`):

```
File '/etc/passwd' modified
Mode: realtime
Changed attributes: size,inode,mtime,md5,sha1,sha256
Size changed from '1813' to '1868'
Old modification time was: '1789581561', now it is '1789648237'
Old inode was: '525980', now it is '525992'
Old md5sum was: '3f25977f51540609feeac16da8ceb228'
New md5sum is : 'd574cd2eb5a1da83cc927a412b6af26b'
Old sha1sum was: '7124eb22f4a3bc665902fd425790d2729ad08975'
New sha1sum is : '625d7775a16193c252d9c3fa0be80f9e0eb6c640'
Old sha256sum was: '40e36ae8d4bd9f57094e8015531833753f9e040f768442264e8704e911002984'
New sha256sum is : 'b2d97cd27f108ebd3ff9acca306ec5aaa55a0d48e967287881578d257e84ee2c'
```

## Análisis

La regla `550` se dispara ante cualquier cambio de checksum en un fichero vigilado por `syscheck`, sin distinguir intención — es una regla de integridad, no de "ataque" en sí misma. Lo que la hace valiosa aquí es `Mode: realtime`: el cambio se reporta en segundos (vía inotify), no en el siguiente escaneo periódico (cada 12h por defecto), algo crítico para detectar una modificación de `/etc/passwd` — como la creación de un usuario backdoor — casi en el instante en que ocurre, en vez de horas después.

**Falsos positivos esperados:** cualquier gestión legítima de usuarios (`useradd`, `passwd`, `usermod`) o actualización del sistema que toque `/etc/passwd` disparará la misma alerta. Por eso el nivel es solo 7 (medio) — es una señal para correlar con quién y cuándo, no una alerta de bloqueo automático. En producción, esta regla se enriquecería con contexto (¿la sesión que hizo el cambio es de un admin autorizado? ¿hay un ticket de cambio asociado?) antes de decidir si es incidente o ruido.

## Remediación / Recomendación

- Correlar esta alerta con logs de auditoría (`auditd`, historial de `sudo`) para atribuir el cambio a una sesión/usuario concreto y distinguir cambios autorizados de no autorizados.
- Configurar una **active response** en Wazuh que notifique de inmediato ante cambios en `/etc/passwd`, `/etc/shadow` o `/etc/sudoers` fuera de una ventana de mantenimiento conocida.
- Añadir explícitamente `/etc/shadow` y `/etc/sudoers` con `realtime="yes"` si no quedan ya cubiertos por la vigilancia genérica de `/etc` (revisar que no estén en la lista `<ignore>`).

## Lecciones aprendidas

- **Un `sed` sin coincidencia no da error, falla en silencio.** El primer intento buscaba `/bin, /sbin, /boot` (con espacios) cuando el archivo real tenía `/bin,/sbin,/boot` (sin espacios) — cero coincidencias, cero cambios, cero avisos. Lección operativa: **verificar siempre el resultado de una edición de configuración con un `grep`/`diff` posterior**, nunca asumir que "no hubo error" significa "se aplicó".
- Insertar varias líneas con `sed -i '...a\ ... \n ...'` en una sola invocación es frágil: si el `\n` llega como salto de línea literal (p. ej. por un copy-paste) en vez de ser interpretado por `sed`, bash rompe con `syntax error near unexpected token 'newline'`. Es más robusto usar un comando `sed` por línea a insertar, o subir un script y ejecutarlo en vez de escapar todo en una sola línea de shell.
- Reiniciar el agente sin verificar antes que el fichero de configuración cambió de verdad da una falsa sensación de "ya está aplicado". El log de arranque (`Directory set for real time monitoring: ...`) es la fuente de verdad, no el propio comando de reinicio.
