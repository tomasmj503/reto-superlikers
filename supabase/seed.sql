-- ============================================================
-- JUTILABS · Reto SuperLikers
-- Datos de demo / QA — 2026-06-25
-- Proyecto Supabase: kphactyefgkdlwpyqfzi
-- ============================================================
-- IMPORTANTE: ejecutar schema.sql primero.
-- Estos datos simulan una campaña activa con 7 usuarios reales
-- en distintos estados del flujo y 17 transacciones con todos
-- los outcomes posibles (completada, duplicada, error).
-- ============================================================

-- Limpiar antes de insertar (para re-runs)
TRUNCATE TABLE public.transactions, public.conversation_state;

-- ============================================================
-- conversation_state — 10 usuarios, ciclo de vida completo
-- ============================================================
INSERT INTO public.conversation_state
  (celular, paso, nombre, correo, cedula, ocupacion, participante_existe, intentos, last_activity_at, created_at, updated_at, datos, tags)
VALUES
  -- Usuarios finalizados (flujo completo exitoso)
  ('3001234567', 'finalizado',       'Carlos Mendoza',      'carlos.mendoza@gmail.com',    '79845123',   'ocupacion_2', true,  0, now()-'2h'::interval,  now()-'3h'::interval,  now()-'2h'::interval,  '{}', '{"grupo_1"}'),
  ('3204567890', 'finalizado',       'Andrés Ospina',       'andres.ospina@outlook.com',   '1020345678', 'ocupacion_3', true,  0, now()-'1h'::interval,  now()-'2h'::interval,  now()-'1h'::interval,  '{}', '{"grupo_1"}'),
  ('3008901234', 'finalizado',       'Diego Herrera',       'dherrera@empresa.com',        '1045678901', 'ocupacion_1', true,  0, now()-'4h'::interval,  now()-'5h'::interval,  now()-'4h'::interval,  '{}', '{"grupo_1"}'),
  ('3219876543', 'finalizado',       'Juan Pablo Vargas',   'jpvargas@correo.co',          '1032567890', 'ocupacion_4', true,  0, now()-'6h'::interval,  now()-'7h'::interval,  now()-'6h'::interval,  '{}', '{"grupo_1"}'),
  ('3001122334', 'finalizado',       'Santiago Morales',    'smorales@hotmail.com',        '80123456',   'ocupacion_1', true,  0, now()-'8h'::interval,  now()-'9h'::interval,  now()-'8h'::interval,  '{}', '{"grupo_1"}'),
  -- Usuario en espera de foto
  ('3112345678', 'esperando_foto',   'Valentina Torres',    'val.torres@hotmail.com',      '52341789',   'ocupacion_1', true,  0, now()-'15m'::interval, now()-'20m'::interval, now()-'15m'::interval, '{}', '{"grupo_1"}'),
  -- Usuario en revisión manual (3 intentos de foto fallidos)
  ('3187654321', 'revision_manual',  'Luisa Cárdenas',      'luisa.cardenas@gmail.com',    '43218765',   'ocupacion_2', true,  3, now()-'30m'::interval, now()-'1h'::interval,  now()-'30m'::interval, '{}', '{"grupo_1"}'),
  -- Usuario a mitad del registro
  ('3156789012', 'esperando_correo', 'María Fernanda Ruiz', null,                          null,         null,          false, 0, now()-'5m'::interval,  now()-'5m'::interval,  now()-'5m'::interval,  '{}', null),
  ('3105432109', 'esperando_cedula', 'Natalia Gómez',       'natalia.gomez@gmail.com',     null,         null,          false, 0, now()-'3m'::interval,  now()-'8m'::interval,  now()-'3m'::interval,  '{}', null),
  -- Usuario abandonado
  ('3143344556', 'abandonado',       'Camila Restrepo',     'camila.r@gmail.com',          '52789012',   'ocupacion_3', false, 0, now()-'5h'::interval,  now()-'5h'::interval,  now()-'5h'::interval,  '{}', null);


-- ============================================================
-- transactions — 17 filas, todos los outcomes
-- ============================================================
INSERT INTO public.transactions
  (celular, correo, ref_factura, puntos, estado, id_actividad_foto, csat, error_type, timestamp, created_at)
VALUES
  -- Carlos Mendoza: exitosa + intento de duplicado por ref
  ('3001234567', 'carlos.mendoza@gmail.com',  '202600012345', 18500, 'completada', '6a3aa1237385e7faefde9001', 4,    null,               now()-'2h'::interval,    now()-'2h'::interval),
  ('3001234567', 'carlos.mendoza@gmail.com',  '202600012345', 0,     'duplicada',  null,                       null, 'ref_duplicado',    now()-'1h30m'::interval,  now()-'1h30m'::interval),

  -- Andrés Ospina: exitosa perfecta
  ('3204567890', 'andres.ospina@outlook.com', '202600023456', 32100, 'completada', '6a3aa2347385e7faefde9002', 5,    null,               now()-'1h'::interval,    now()-'1h'::interval),

  -- Diego Herrera: foto ilegible primero, luego exitosa
  ('3008901234', 'dherrera@empresa.com',       null,           0,     'error',      '6a3aa4567385e7faefde9004', null, 'factura_ilegible', now()-'4h30m'::interval,  now()-'4h30m'::interval),
  ('3008901234', 'dherrera@empresa.com',       '202600034567', 9800,  'completada', '6a3aa3457385e7faefde9003', 3,    null,               now()-'4h'::interval,    now()-'4h'::interval),

  -- Juan Pablo Vargas: exitosa con puntaje alto
  ('3219876543', 'jpvargas@correo.co',         '202600045678', 45000, 'completada', '6a3aa8901385e7faefde9008', 5,    null,               now()-'6h'::interval,    now()-'6h'::interval),

  -- Santiago Morales: exitosa + sha1 duplicado
  ('3001122334', 'smorales@hotmail.com',       '202600056789', 12300, 'completada', '6a3aa9012385e7faefde9009', 4,    null,               now()-'8h'::interval,    now()-'8h'::interval),
  ('3001122334', 'smorales@hotmail.com',       null,           0,     'error',      '6a3aa0123385e7faefde9010', null, 'sha1_duplicado',   now()-'7h30m'::interval,  now()-'7h30m'::interval),

  -- Luisa Cárdenas: 3 intentos fallidos -> revisión manual
  ('3187654321', 'luisa.cardenas@gmail.com',   null,           0,     'error',      '6a3aa5678385e7faefde9005', null, 'factura_ilegible', now()-'55m'::interval,   now()-'55m'::interval),
  ('3187654321', 'luisa.cardenas@gmail.com',   null,           0,     'error',      '6a3aa6789385e7faefde9006', null, 'factura_ilegible', now()-'45m'::interval,   now()-'45m'::interval),
  ('3187654321', 'luisa.cardenas@gmail.com',   null,           0,     'error',      '6a3aa7890385e7faefde9007', null, 'validacion_fallida',now()-'30m'::interval,  now()-'30m'::interval),

  -- qatest@jutilabs.com: flujo QA real (Clip 2)
  ('3025282411', 'qatest@jutilabs.com',        '202600014782', 26900, 'completada', '6a3cc3387385e7faefde95b7', 5,    null,               now()-'20m'::interval,   now()-'20m'::interval),
  ('3025282411', 'qatest@jutilabs.com',        '202600014782', 0,     'duplicada',  null,                       null, 'ref_duplicado',    now()-'15m'::interval,   now()-'15m'::interval),
  ('3025282411', 'qatest@jutilabs.com',        null,           0,     'error',      '6a3cc38a7385e7faefde95bd', null, 'factura_ilegible', now()-'10m'::interval,   now()-'10m'::interval),
  ('3025282411', 'qatest@jutilabs.com',        '202600007823', 36300, 'completada', '6a3cc5727385e7faefde95bf', 5,    null,               now()-'6m'::interval,    now()-'6m'::interval),
  ('3025282411', 'qatest@jutilabs.com',        '202600007823', 0,     'duplicada',  null,                       null, 'ref_duplicado',    now()-'5m'::interval,    now()-'5m'::interval),
  ('3025282411', 'qatest@jutilabs.com',        null,           0,     'error',      null,                       null, 'factura_ilegible', now()-'4m'::interval,    now()-'4m'::interval);


-- ============================================================
-- Resumen rápido para verificar
-- ============================================================
SELECT
  COUNT(*)                                        AS total_tx,
  COUNT(*) FILTER (WHERE estado = 'completada')   AS completadas,
  COUNT(*) FILTER (WHERE estado = 'duplicada')    AS duplicadas,
  COUNT(*) FILTER (WHERE estado = 'error')        AS errores,
  SUM(puntos) FILTER (WHERE estado = 'completada') AS puntos_totales,
  COUNT(DISTINCT celular)                         AS usuarios_unicos
FROM public.transactions;
