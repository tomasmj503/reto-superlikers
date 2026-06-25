# SuperLikers — Bot de WhatsApp · AI Automation Specialist Senior

Bot conversacional de WhatsApp que guía al usuario por el flujo completo de registro y participación en la campaña `3z` de SuperLikers: identificación → registro → subida de ticket → lectura de factura con IA → registro de venta → confirmación de puntos → CSAT.

---

## Objetivo

Orquestar en n8n un flujo de 7 pasos sobre WhatsApp Cloud API que:

1. Identifica al participante por celular (y correo como fallback) en `GET /participants/search`.
2. Lo registra en `POST /participants` si no existe, con confirmación previa de datos.
3. Recibe la foto del ticket y la sube con `POST /photos`.
4. Extrae los datos de la factura con IA (OpenAI Structured Outputs, `json_schema` estricto).
5. Registra la venta con `POST /retail/buy` — SuperLikers calcula los puntos.
6. Acepta la actividad con `POST /entries/accept` y confirma los puntos al usuario.
7. Captura CSAT (calificación 1–5) y cierra el flujo.

---

## Arquitectura

```
WhatsApp Cloud API (Meta)
        ↓
        ▼
  n8n Webhook  ───▶  Validar firma HMAC-SHA256
        ↓
        ▼
  State Machine (nodo Decidir — tabla de transiciones centralizada)
  ──────────────────────────────────────────────────────────────
  │  conversation_state (Supabase) — working memory por celular  │
  │  Router por acción: responder / buscar / registrar / foto    │
  ──────────────────────────────────────────────────────────────
        │
        ├───▶  SuperLikers API  (search · create · photos · buy · accept)
        ├───▶  OpenAI API       (lectura de factura con Structured Outputs)
        └───▶  transactions     (Supabase — log permanente append-only)

  A7 · Schedule (cada 5 min)
        └───▶  conversation_state ───▶  recordatorio / cierre / watchdog
```

---

## Stack

| Capa | Tecnología |
|---|---|
| Orquestación | n8n (self-hosted en DigitalOcean) |
| Canal | WhatsApp Business Cloud API (Meta) |
| IA — factura | OpenAI Structured Outputs (`json_schema` estricto, `gpt-5.4-mini`) |
| Estado + log | Supabase (PostgreSQL + RLS desde día 1) |
| Infraestructura | DigitalOcean Droplet + Docker + Caddy |

---

## Estructura del repositorio

```
├── README.md
├── .gitignore
├── .env.example                          — solo nombres de variables, sin valores
├── workflows/
│   └── superlikers_flujo_completo.json   — export del workflow n8n (v8, 62 nodos, A8c)
├── supabase/
│   └── schema.sql                        — tablas, constraints, RLS e índice de idempotencia
├── prompts/
│   ├── copy.json                         — copy del bot por paso (fuente de verdad)
│   ├── factura_system.txt                — system prompt para la IA de factura
│   └── README.md                         — convención de llaves y cómo actualizar
└── docs/
    └── decisiones/
        ├── A1.md    — Plan y decisiones iniciales
        ├── A2.md    — Sondeo de endpoints (hallazgos empíricos)
        ├── A3.md    — Schema Supabase
        ├── A4.md    — WhatsApp Webhook
        ├── A5.md    — State Machine y bugs resueltos
        ├── A6.md    — Rama de foto + IA + idempotencia
        ├── A7.md    — Casos borde + timeouts + reintentos
        └── A8.md    — E2E + bugs cazados en pruebas + externalización env vars
```

---

## Decisiones técnicas clave

- **IA con garantía de JSON:** OpenAI `json_schema` estricto. Elimina la clase de error "el modelo devolvió algo que no es JSON". Modelo elegido por pruebas: `gpt-5.4-mini` iguala a Full en extracción estructurada al ~15% del costo. Detalle en `docs/decisiones/A6.md`.

- **Copy versionado:** todos los textos del bot viven en `prompts/copy.json`, separados de la lógica del workflow.

- **Idempotencia en 3 capas:**
  1. Normalización del `ref` a solo dígitos (`"AEKH 102875"` → `"102875"`).
  2. Chequeo en aplicación contra `transactions WHERE estado='completada'`.
  3. Índice único parcial `uq_transactions_ref_completada` + rechazo `422` de SuperLikers.

- **RLS desde el día 1:** `service_role` (n8n) ALL; `authenticated` (dashboard) SELECT; `anon` denegado implícitamente.

- **State machine centralizada:** un solo nodo Code (`Decidir`) contiene todas las transiciones. El Switch enruta por tipo de acción, no por estado. Menos nodos, una sola fuente de verdad.

- **Búsqueda: celular primero, email como fallback:** el API de `3z` solo resuelve search por `email`. El flujo intenta primero por celular (honra el brief) y cae a pedir el correo si no resuelve.

- **Timeouts por polling, no por job diferido:** Schedule cada 5 min barre `conversation_state`. Stateless, self-healing, sobrevive reinicios. Umbrales como env vars afinables.

- **Bugs cazados en E2E** (ver `docs/decisiones/A8.md`): pérdida de correo en rama de registro + falso positivo en detección de duplicado. Ambos resueltos y verificados en ejecuciones reales.

---

## Variables de entorno

Copiar `.env.example` a `.env` y completar los valores:

```bash
cp .env.example .env
```

| Variable | Descripción |
|---|---|
| `API_KEY` | API key de SuperLikers (obtener del panel) |
| `CAMPAIGN` | ID de campaña (`3z` para labs) |
| `BASE_URL` | URL base del API (`https://api.superlikerslabs.com/v1` para labs) |
| `WHATSAPP_VERIFY_TOKEN` | Token de verificación del webhook de Meta |
| `WHATSAPP_APP_SECRET` | App Secret de la app de Meta (para validar firma HMAC) |
| `WHATSAPP_PHONE_NUMBER_ID` | Phone Number ID del número emisor (requerido por el Schedule de A7) |
| `SUPABASE_URL` | URL del proyecto Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key de Supabase (solo en el servidor) |
| `SL_RECORDATORIO_MIN` | Minutos de inactividad antes del recordatorio (default: 30) |
| `SL_CIERRE_MIN` | Minutos antes de cerrar la conversación (default: 180) |
| `SL_MAX_INTENTOS` | Fotos ilegibles antes de escalar a revisión manual (default: 3) |
| `SL_API_RETRIES` | Reintentos ante timeout/5xx del API (default: 2) |

`CAMPAIGN` y `BASE_URL` tienen fallback en el código: si no están declaradas, el flujo usa los valores por defecto sin romperse.

---

## Cómo correr el flujo

1. Importar `workflows/superlikers_flujo_completo.json` en n8n.
2. Configurar credenciales en n8n:
   - **Header Auth** `WhatsApp Cloud API` — token permanente de Meta (System User, caducidad Never).
   - **Supabase** — URL + service role key.
   - **OpenAI API** — API key de OpenAI.
   - Las demás variables vía `$env.*` en el droplet.
3. Activar el workflow. URL del webhook: `https://<tu-dominio>/webhook/superlikers-whatsapp`.
4. En el Panel de Meta: registrar el webhook con esa URL y el `WHATSAPP_VERIFY_TOKEN`.
5. El Schedule de A7 (barrido de inactivos) se activa automáticamente con el workflow.

---

## Pruebas del checklist — resultados E2E

| # | Caso | Estado | Evidencia |
|---|---|---|---|
| 1 | Usuario nuevo → registro + foto + venta + aceptación | ✅ validado en vivo (A8) | 52.200 pts — ejec. 22249, 22280 |
| 2 | Usuario existente → salta registro, sube ticket directo | ✅ validado en vivo (A8) | ejec. 22187, 22325 |
| 3 | Factura ilegible → el bot pide nueva foto | ✅ validado en vivo (A8) | ejec. 22209, 22214 |
| 4 | Foto o factura duplicada → mensaje correcto | ✅ validado en vivo (A8) | ejec. 22200, 22397 |
| 5 | Timeout sin foto: recordatorio + cierre automático | ✅ validado en vivo (A8) | ejec. 22173, idle_min=47 |
| 6 | Límite de ilegibles → revisión manual | ✅ validado en vivo (A8) | ejec. 22219, validacion_fallida |

---

## Mejoras futuras

- **Backup/fallback de modelo IA:** si OpenAI devuelve baja confianza o el ticket supera cierto valor, escalar a un segundo modelo. El patrón está documentado; fuera del alcance por costo/latencia.
- **Retention rate real:** tabla `transactions` y queries preparadas. Requiere datos longitudinales.
- **Job diferido por conversación:** el polling actual es robusto; el job diferido sería más preciso (recordatorio exactamente a los 30 min). Trade-off documentado en `docs/decisiones/A7.md`.
- **Migración a observabilidad completa:** integrar APM (Sentry, Datadog) para trazas distribuidas.

---

## Video Loom

Demostración del flujo corriendo en vivo con casos reales (registro,
foto + puntos, y casos borde):

https://www.loom.com/share/0cc0632a0fe6495cac309569be01718e
