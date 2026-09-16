# Plantilla de informe de incidente

Copia este archivo a `reports/incident-XX-nombre.md` y complétalo por cada ataque simulado.

---

## Incidente #XX — [nombre del ataque]

**Fecha:** YYYY-MM-DD
**Analista:** Carlos Munaiz
**Severidad:** Baja / Media / Alta / Crítica
**Estado:** Detectado / Contenido / Resuelto

### Resumen

Breve descripción de qué ocurrió (2-3 líneas).

### Timeline

| Hora | Evento |
|------|--------|
| 10:00:00 | Se lanza el ataque desde 192.168.56.10 |
| 10:00:03 | Wazuh genera la primera alerta (rule.id: XXXXX) |
| 10:00:10 | Se confirma el patrón y se dispara la regla de correlación |

### Indicadores de compromiso (IOCs)

- IP origen: 192.168.56.10
- Usuario objetivo: ...
- Regla(s) Wazuh disparada(s): ...

### Evidencia

- Captura del dashboard: `screenshots/XX-nombre.png`
- Log relevante (extracto):

```
pegar aquí el log de alerta de Wazuh
```

### Análisis

¿Por qué se disparó la alerta? ¿Qué tan realista es este ataque en un entorno de producción? ¿Qué falsos positivos podría generar la regla?

### Remediación / Recomendación

Qué medida tomarías en un entorno real (bloqueo de IP, MFA, rate limiting, etc.).

### Lecciones aprendidas

Qué ajustarías en la regla de detección o en la configuración del agente para mejorar la cobertura.
