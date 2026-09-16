# Incidente #01 — Fuerza bruta SSH

**Fecha:** 2026-09-16
**Analista:** Carlos (TechAdminPro)
**Severidad:** Media
**Estado:** Detectado

## Resumen

Se lanzó un ataque de fuerza bruta contra el servicio SSH de `victim-ubuntu` (192.168.56.20) desde `kali-attacker` (192.168.56.10) usando Hydra, probando 4 usuarios × 6 contraseñas (24 combinaciones). Ninguna combinación fue válida (ataque no exitoso), pero Wazuh detectó correctamente el patrón de múltiples intentos fallidos en poco tiempo mediante sus reglas nativas de `sshd`/`PAM`, sin necesidad de reglas personalizadas.

## Timeline

| Hora | Evento |
|------|--------|
| 19:51:51 | Primer intento de lanzar Hydra — falla porque las listas de usuarios/contraseñas no existían todavía |
| 19:56:52 | Segundo intento de Hydra — falla con "Connection refused": el servicio SSH no estaba instalado en la víctima |
| ~19:58 | Se instala y arranca `openssh-server` en `victim-ubuntu` |
| 20:00:25 | Hydra lanza el ataque real: 24 intentos de login SSH contra 192.168.56.20 |
| 20:00:42 – 20:00:45 | Pico de alertas en Wazuh: reglas 5710, 5760, 5503 y 5551 disparadas repetidamente |
| 20:00:45 | Hydra finaliza: "1 of 1 target completed, 0 valid password found" |

## Indicadores de compromiso (IOCs)

- **IP origen (atacante):** 192.168.56.10 (`kali-attacker`)
- **IP destino (víctima):** 192.168.56.20 (`victim-ubuntu`, agente Wazuh `victima`, ID 001)
- **Herramienta:** Hydra v9.7 (THC-Hydra)
- **Usuarios probados:** root, admin, cm, test
- **Reglas Wazuh disparadas:**
  - `5710` — sshd: Attempt to login using a non-existent user (nivel 5)
  - `5760` — sshd: authentication failed (nivel 5)
  - `5503` — PAM: User login failed (nivel 5)
  - `5551` — **PAM: Multiple failed logins in a small period of time (nivel 10)** ← regla de correlación, la más relevante

## Evidencia

- Ejecución del ataque en Kali: `reports/screenshots/07-hydra-bruteforce-attack.png`
- Alertas en el dashboard de Wazuh (Events, 103 hits en 24h, regla 5551 visible): `reports/screenshots/08-ssh-bruteforce-alert.png`

Log relevante (regla de correlación disparada):

```
Sep 16, 2026 @ 20:00:42.328  victima  PAM: Multiple failed logins in a small period of time.  level: 10  rule.id: 5551
```

## Análisis

La alerta se dispara porque Wazuh correla varios eventos `PAM: User login failed` de la misma sesión/usuario en una ventana de tiempo corta (regla 5551, nivel 10 — bastante más alta que un fallo aislado, nivel 5). Esto es exactamente el comportamiento esperado de un ataque de fuerza bruta automatizado: múltiples intentos en segundos, algo que un usuario legítimo equivocándose de contraseña no genera con esa frecuencia.

**Falsos positivos posibles:** un usuario legítimo con un gestor de contraseñas roto, un script de despliegue mal configurado reintentando conexión, o un healthcheck que use credenciales antiguas podrían disparar esta misma regla. Por eso el nivel 10 (no crítico) es razonable — amerita revisión, no bloqueo automático inmediato sin contexto.

## Remediación / Recomendación

En un entorno real:
- Limitar intentos de conexión SSH con `fail2ban` o `sshguard`, baneando la IP origen tras N fallos.
- Deshabilitar autenticación por contraseña en SSH y forzar solo claves públicas (`PasswordAuthentication no`).
- Restringir el acceso SSH por IP de origen (firewall/`ufw`) cuando sea posible.
- Configurar una **active response** en Wazuh para bloquear automáticamente la IP origen cuando se dispare la regla 5551 (`ossec-response`/`firewall-drop`).

## Lecciones aprendidas

- Las reglas nativas de Wazuh (sin configuración adicional) ya cubren bien la detección de fuerza bruta SSH — no fue necesario activar la regla personalizada `100010` de `rules/local_rules.xml` para este caso.
- Importante verificar que los servicios objetivo estén realmente activos antes de lanzar un ataque de prueba (perdimos tiempo por no tener OpenSSH instalado en la víctima).
- Sería interesante, como mejora futura, comparar el tiempo de detección con y sin la regla de correlación personalizada para cuantificar su aporte.
