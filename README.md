# SuperLikers — Bot de WhatsApp · AI Automation Specialist Senior

Bot conversacional de WhatsApp que guía al usuario por el flujo completo de registro y participación en la campaña `3z` de SuperLikers: identificación → registro → subida de ticket → lectura de factura con IA → registro de venta → confirmación de puntos.

---

## Objetivo

Orquestar en n8n un flujo de 8 pasos sobre WhatsApp Cloud API que:
1. Identifica al participante por correo en `GET /participants/search`.
2. Lo registra en `POST /participants` si no existe (con confirmación previa).
3. Recibe la foto del ticket y la sube con `POST /photos`.
4. Extrae los datos de la factura con IA (OpenAI Structured Outputs).
5. Registra la venta con `POST /retail/buy` → SuperLikers calcula los puntos.
6. Acepta la actividad con `POST /entries/accept` y confirma los puntos al usuario.

---

## Arquitectura

```
WhatsApp Cloud API (Meta)
        │
        ▼
  n8n Webhook  ──▶  Validar firma HMAC-SHA256
        │
        ▼
  State Machine (nodo Decidir)
  ┌─────────────────────────────────────────────────────┐
  │  conversation_state (Supabase) — working memory     │
  │  Router por acción: responder / buscar / registrar / foto │
  └─────────────────────────────────────────────────────┘
        │
        ├──▶  SuperLikers API  (search · create · photos · buy · accept)
        ├──▶  OpenAI API       (lectura de factura con Structured Outputs)
        └──▶  transactions     (Supabase — log permanente append-only)
```

---

## Stack

| Capa | Tecnología |
|------|-----------|
| Orquestación | n8n (self-hosted en DigitalOcean) |
| Canal | WhatsApp Business Cloud API (Meta) |
| IA — factura | OpenAI `gpt-5.4-mini` · Structured Outputs (`json_schema` estricto) |
| Estado + log | Supabase (PostgreSQL + RLS) |
| Dashboard | Next.js + Supabase → Vercel |
| Infraestructura | DigitalOcean Droplet + Docker + Caddy |

---

## Estructura del repositorio

```
├─ README.md
├─ .gitignore
├─ .env.example              ← solo nombres de variables, sin valores
├─ workflows/
│   └─ superlikers_flujo_completo.json   ← export del workflow n8n (flujo completo, A6 incluida)
├─ prompts/
│   ├─ copy.json             ← copy del bot por paso (fuente de verdad)
│   ├─ factura_system.txt    ← system prompt para la IA de lectura de factura
│   └─ README.md             ← convención de llaves y cómo actualizar
└─ docs/
    └─ decisiones/
        ├─ A1.md             ← Plan y decisiones iniciales
        ├─ A2.md             ← Sondeo de endpoints (hallazgos empíricos)
        ├─ A3.md             ← Schema Supabase
        ├─ A4.md             ← WhatsApp Webhook
        ├─ A5.md             ← State Machine y bugs resueltos
        └─ A6.md             ← Rama de foto: lectura IA, venta, aceptación
```

---

## Decisiones técnicas

Cada actividad tiene su nota en [`docs/decisiones/`](docs/decisiones/). Resumen ejecutivo:

- **IA con garantía de JSON:** OpenAI en modo `json_schema` estricto. Si el esquema no se cumple, la API reintenta internamente. Elimina la clase de error "el modelo devolvió algo que no es JSON".
- **Copy versionado:** todos los textos del bot viven en `prompts/copy.json`, separados de la lógica del workflow.
- **Modelo elegido por pruebas, no por intuición:** se arrancó en `gpt-5.4-nano` (el más barato); fallaba al leer precios en facturas de columnas densas. Se corrigió primero el *prompt* (gratis) y, como persistía, se subió a `gpt-5.4-mini` — que leyó correctamente. No se usó el modelo full: la lectura de factura es extracción, no razonamiento. Regla aplicada: el modelo más barato que cumple. Detalle en [`docs/decisiones/A6.md`](docs/decisiones/A6.md).
- **Idempotencia en tres capas:** (1) normalización del `ref` a solo dígitos antes de comparar — el OCR lee la misma factura distinto en cada foto; (2) chequeo en aplicación contra `transactions`; (3) el índice único parcial `uq_transactions_ref_completada` + el rechazo del propio SuperLikers (`/retail/buy` → 422). Físicamente imposible otorgar puntos dos veces por la misma factura.
- **RLS desde el día 1:** `service_role` (n8n) tiene ALL; `authenticated` (dashboard) tiene SELECT; `anon` denegado. No se habilitó retroactivamente.
- **Búsqueda por email, no por celular:** el API de `3z` solo resuelve `GET /participants/search` por `email`. El celular llega del `from` de WhatsApp y se usa como llave de `conversation_state` (normalizado a 10 dígitos).
- **State machine centralizada:** un solo nodo Code (`Decidir`) contiene todas las transiciones. El Switch enruta por tipo de acción, no por estado. Menos nodos, una sola fuente de verdad.

---

## Variables de entorno

Copiar `.env.example` a `.env` y completar los valores:

```bash
cp .env.example .env
```

| Variable | Descripción |
|----------|-------------|
| `API_KEY` | API key de SuperLikers (obtener del panel) |
| `CAMPAIGN` | ID de campaña (`3z` para labs) |
| `BASE_URL` | URL base del API de labs |
| `WHATSAPP_VERIFY_TOKEN` | Token de verificación del webhook de Meta |
| `WHATSAPP_APP_SECRET` | App Secret de la app de Meta (para validar firma HMAC) |
| `SUPABASE_URL` | URL del proyecto Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key de Supabase (solo en el servidor) |

En n8n self-hosted, estas variables se declaran en `.env` y `docker-compose.yml` del droplet. Se acceden en los nodos como `$env.NOMBRE_VARIABLE`.

---

## Cómo correr el flujo

1. Importar `workflows/superlikers_flujo_completo.json` en n8n.
2. Configurar las credenciales en n8n:
   - **Header Auth** `WhatsApp Cloud API` — token permanente de Meta (System User, caducidad Never).
   - **Supabase** — URL + service role key.
   - Las demás variables vía `$env.*`.
3. Activar el workflow. La URL del webhook es `https://<tu-dominio>/webhook/superlikers-whatsapp`.
4. En el Panel de Meta: registrar el webhook con esa URL y el `WHATSAPP_VERIFY_TOKEN`.

---

## Pruebas del checklist

| # | Caso | Estado |
|---|------|--------|
| 1 | Usuario nuevo → registro + foto + venta + aceptación | ✅ validado (11.600 pts, buy 200, accept 200) |
| 2 | Usuario existente → salta registro, sube ticket directo | identificación validada en A5 |
| 3 | Factura ilegible → el bot pide nueva foto | ✅ validado |
| 4 | Foto o factura duplicada → mensajes de error correctos | ✅ ref duplicado validado · Sha1/timeout en A7 |

---

## Mejoras futuras

- **Backup/fallback de modelo IA:** si OpenAI devuelve baja confianza o el ticket supera cierto valor, escalar a Claude para una segunda lectura. Deliberadamente fuera del alcance del reto (costo/latencia), pero el patrón está documentado.
- **Retention rate real:** la tabla `transactions` y la query están preparadas. Requiere datos longitudinales (varios días de uso). El dashboard muestra la métrica como "disponible cuando haya datos históricos", sin inventar números.
- **Migración del log a observabilidad completa:** integrar con una herramienta de APM (Sentry, Datadog) para trazas distribuidas del flujo completo.
- **Botones de WhatsApp para `ocupacion`:** hoy se captura como texto libre validado. Con la API de WhatsApp Interactive Messages se puede presentar como lista de opciones, reduciendo errores de entrada.

---

## Video Loom

_(pendiente A8 — video 3–5 min mostrando el flujo en vivo con casos reales)_
