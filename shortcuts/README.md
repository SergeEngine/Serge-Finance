# Shortcuts — instrucciones de construcción (SPEC §8 paso 3)

Dos shortcuts se construyen a mano en la app **Atajos** del iPhone. Los dos hacen
lo mismo al final: dos llamadas HTTP a Supabase (1: obtener token, 2: insertar el
movimiento). El movimiento entra **sin categoría**, así que aparece en el Inbox
de la app para categorizarlo con un toque.

Datos que vas a usar en ambos (cópialos tal cual):

- **URL_TOKEN**: `https://qmftfhvixszzqtfmxsgv.supabase.co/auth/v1/token?grant_type=password`
- **URL_INSERT**: `https://qmftfhvixszzqtfmxsgv.supabase.co/rest/v1/movimientos`
- **APIKEY**: `sb_publishable_nlzZJEr7hFjjoq-IXHZxHA_kE8M3t6Z`
- Tu **correo** y **contraseña** de la app (la contraseña queda guardada solo
  dentro del shortcut, en tu teléfono).

---

## Shortcut 1: «Gasto» (captura manual)

Para efectivo y compras con tarjeta física. Ponlo como widget en la pantalla de
inicio, en el botón de Acción, o en Back Tap (Ajustes → Accesibilidad → Tocar →
Tocar atrás).

En Atajos → **+** → nombre «Gasto» → agrega estas acciones en orden:

1. **Solicitar entrada** (Ask for Input)
   - Tipo: **Número** · Pregunta: `¿Cuánto?`
2. **Solicitar entrada** (otra vez)
   - Tipo: **Texto** · Pregunta: `¿Nota?` · Activa **"Permitir respuesta vacía"** (Allow empty answer? sí)
3. **Calcular** (Calculate)
   - `Entrada proporcionada` (la del paso 1) **× -1**
   (los gastos se guardan en negativo)
4. **Obtener contenido de URL** (Get Contents of URL) — *el token*
   - URL: **URL_TOKEN**
   - Toca la flecha para expandir → Método: **POST**
   - Encabezados (Headers):
     - `apikey` = **APIKEY**
     - `Content-Type` = `application/json`
   - Cuerpo de la solicitud (Request Body): **JSON**
     - `email` (Texto) = tu correo
     - `password` (Texto) = tu contraseña
5. **Obtener valor de diccionario** (Get Dictionary Value)
   - Obtener **Valor** de la clave `access_token` en `Contenido de URL`
6. **Obtener contenido de URL** — *el insert*
   - URL: **URL_INSERT**
   - Método: **POST**
   - Encabezados:
     - `apikey` = **APIKEY**
     - `Authorization` = `Bearer ` + el **Valor del diccionario** del paso 5
       (escribe `Bearer`, un espacio, y luego inserta la variable)
     - `Content-Type` = `application/json`
     - `Prefer` = `return=minimal`
   - Cuerpo: **JSON**
     - `monto` (Número) = **Resultado del cálculo** (paso 3)
     - `nota` (Texto) = **Entrada proporcionada** (paso 2)
     - `origen` (Texto) = `manual`
     - `tipo` (Texto) = `gasto`
7. **Mostrar notificación** (Show Notification)
   - Texto: `Guardado. Categoriza en el inbox 📥`

Pruébalo: ejecútalo, pon 50, y revisa que aparezca en el Inbox de la app.

---

## Shortcut 2: automatización de Apple Pay

Captura automática de cada pago con Apple Pay: monto y comercio, sin teclear.

**Primero el shortcut** («Pago capturado»), en Atajos → **+**:

1. **Recibir entrada**: al crearlo desde la automatización (abajo) la entrada
   llega sola como variable **Transacción** (Transaction); no necesitas una
   acción para recibirla.
2. **Calcular**: **Monto** (Amount, de la variable Transacción) **× -1**
3. **Obtener contenido de URL** — el token: idéntico al paso 4 del shortcut «Gasto».
4. **Obtener valor de diccionario** — `access_token`, idéntico al paso 5 de «Gasto».
5. **Obtener contenido de URL** — el insert: idéntico al paso 6 de «Gasto»,
   pero el cuerpo JSON es:
   - `monto` (Número) = **Resultado del cálculo**
   - `comercio` (Texto) = **Comerciante** (Merchant, de la variable Transacción)
   - `origen` (Texto) = `apple_pay`
   - `tipo` (Texto) = `gasto`
6. **Mostrar notificación**
   - Texto: `Categoriza: ` + **Monto** + ` · ` + **Comerciante**

**Luego la automatización**: Atajos → pestaña **Automatización** → **+** →
**Transacción** → elige tu tarjeta Santander (o "Cualquier tarjeta") →
**Ejecutar inmediatamente** (¡importante!, no "Ejecutar tras confirmación") →
Siguiente → elige el shortcut «Pago capturado».

Pruébalo con cualquier compra de Apple Pay: debe llegar la notificación y el
movimiento debe aparecer en el Inbox con el nombre del comercio.

---

## Notas

- Si el token falla (contraseña mal escrita, sin internet), el movimiento no se
  guarda y no hay aviso claro: si no llega la notificación, captúralo con «Gasto».
- La fecha no se envía: Supabase pone la fecha de hoy (zona America/Chihuahua)
  automáticamente.
- «¿Puedo gastar?» se construye en el paso 5 de SPEC §8, cuando exista el candado.
