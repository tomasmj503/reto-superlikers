-- ============================================================
-- JUTILABS · Reto SuperLikers
-- Supabase project: kphactyefgkdlwpyqfzi
-- Schema generado: 2026-06-25
-- ============================================================

-- ============================================================
-- TABLA: conversation_state
-- Working memory del bot WhatsApp SuperLikers.
-- Una fila por celular activo, se resetea por flujo.
-- El log permanente vive en transactions.
-- ============================================================
CREATE TABLE IF NOT EXISTS public.conversation_state (
  celular               TEXT        NOT NULL,
  paso                  TEXT        NOT NULL DEFAULT 'bienvenida',
  distinct_id           TEXT,
  nombre                TEXT,
  correo                TEXT,
  cedula                TEXT,
  ocupacion             TEXT,
  tags                  TEXT[],
  participante_existe   BOOLEAN,
  id_actividad_foto     TEXT,
  datos                 JSONB       NOT NULL DEFAULT '{}',
  intentos              INTEGER     NOT NULL DEFAULT 0,
  recordatorio_enviado  BOOLEAN     NOT NULL DEFAULT false,
  last_activity_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT conversation_state_pkey PRIMARY KEY (celular),

  CONSTRAINT conversation_state_celular_check
    CHECK (celular ~ '^[0-9]{10}$'),

  CONSTRAINT conversation_state_paso_check
    CHECK (paso = ANY (ARRAY[
      'inicio', 'esperando_correo', 'esperando_nombre',
      'esperando_cedula', 'esperando_ocupacion', 'esperando_confirmacion',
      'buscando', 'registrando', 'esperando_foto', 'procesando',
      'esperando_csat', 'finalizado', 'revision_manual', 'error', 'abandonado'
    ]))
);

-- RLS
ALTER TABLE public.conversation_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role full access" ON public.conversation_state
  FOR ALL TO service_role USING (true) WITH CHECK (true);


-- ============================================================
-- TABLA: transactions
-- Log permanente append-only de transacciones SuperLikers.
-- Campos exactos del reto + extras (id_actividad_foto, csat, error_type).
-- Idempotencia por ref_factura via índice único parcial.
-- ============================================================
CREATE TABLE IF NOT EXISTS public.transactions (
  id                UUID        NOT NULL DEFAULT gen_random_uuid(),
  celular           TEXT        NOT NULL,
  correo            TEXT        NOT NULL,
  ref_factura       TEXT,
  puntos            INTEGER     NOT NULL DEFAULT 0,
  estado            TEXT        NOT NULL,
  timestamp         TIMESTAMPTZ NOT NULL DEFAULT now(),
  id_actividad_foto TEXT,
  csat              SMALLINT,
  error_type        TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT transactions_pkey PRIMARY KEY (id),

  CONSTRAINT transactions_celular_check
    CHECK (celular ~ '^[0-9]{10}$'),

  CONSTRAINT transactions_estado_check
    CHECK (estado = ANY (ARRAY[
      'pendiente', 'procesando', 'completada', 'duplicada', 'error'
    ])),

  CONSTRAINT transactions_csat_check
    CHECK (csat >= 1 AND csat <= 5),

  CONSTRAINT transactions_error_type_check
    CHECK (error_type = ANY (ARRAY[
      'factura_ilegible', 'sha1_duplicado', 'ref_duplicado',
      'execution_error', 'timeout_api', 'timeout_usuario', 'validacion_fallida'
    ]))
);

-- Índice único parcial: idempotencia por ref_factura completada
CREATE UNIQUE INDEX IF NOT EXISTS transactions_ref_completada_unique
  ON public.transactions (ref_factura)
  WHERE estado = 'completada' AND ref_factura IS NOT NULL;

-- RLS
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role full access" ON public.transactions
  FOR ALL TO service_role USING (true) WITH CHECK (true);
