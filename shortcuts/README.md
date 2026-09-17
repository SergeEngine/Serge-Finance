# Shortcuts — instrucciones de construcción (SPEC §8 paso 3)

Dos shortcuts se construyen a mano en la app **Atajos** del iPhone. Los dos hacen
lo mismo al final: dos llamadas HTTP a Supabase (1: obtener token, 2: guardar el
movimiento). «Gasto» muestra el menú de categorías ahí mismo (elige "Después"
para mandarlo al Inbox); la automatización de Apple Pay guarda sin categoría y
el movimiento se categoriza en el Inbox de la app.

Datos que vas a usar (cópialos tal cual):

- **URL_TOKEN**: `https://qmftfhvixszzqtfmxsgv.supabase.co/auth/v1/token?grant_type=password`
- **URL_RPC**: `https://qmftfhvixszzqtfmxsgv.supabase.co/rest/v1/rpc/agregar_movimiento` (para «Gasto»)
- **URL_INSERT**: `https://qmftfhvixszzqtfmxsgv.supabase.co/rest/v1/movimientos` (para Apple Pay)
- **APIKEY**: `sb_publishable_nlzZJEr7hFjjoq-IXHZxHA_kE8M3t6Z`
- Tu **correo** y **contraseña** de la app (la contraseña queda guardada solo
  dentro del shortcut, en tu teléfono).

---

## Shortcut 1: «Gasto» (captura manual)

Para efectivo y compras con tarjeta física. Ponlo como widget en la pantalla de
inicio, en el botón de Acción, o en Back Tap (Ajustes → Accesibilidad → Tocar →
Tocar atrás).

En Shortcuts → **+** → nombre «Gasto» → agrega estas acciones en orden
(el iPhone está en inglés; entre paréntesis va el nombre en español):

1. **Ask for Input** (Solicitar entrada)
   - Input Type: **Number** · Prompt: `¿Cuánto?`
2. **Calculate** (Calcular)
   - Toma solo el `Provided Input` del paso anterior: **× -1**
   (los gastos se guardan en negativo)
3. **Ask for Input** (otra vez)
   - Input Type: **Text** · Prompt: `¿Nota?` · Activa **"Allow Empty Answer"**
4. **List** (Lista) — un renglón por categoría, con el nombre exacto:
   - `Súper` · `Comida fuera` · `Café/antojos` · `Transporte` ·
     `Renta/servicios` · `Salud` · `Ropa` · `Ocio/salidas` ·
     `Suscripciones` · `Regalos` · `Viajes` · `Ahorro` · `Después`
5. **Choose from List** (Elegir de la lista)
   - List: la **List** del paso 4 · Prompt: `¿Categoría?`
6. **Get Contents of URL** (Obtener contenido de URL) — *el token*
   - URL: **URL_TOKEN**
   - Toca la flecha para expandir → Method: **POST**
   - Headers:
     - `apikey` = **APIKEY**
     - `Content-Type` = `application/json`
   - Request Body: **JSON**
     - `email` (Text) = tu correo
     - `password` (Text) = tu contraseña
7. **Get Dictionary Value** (Obtener valor de diccionario)
   - Get **Value** for `access_token` in `Contents of URL`
8. **Get Contents of URL** — *guardar el movimiento*
   - URL: **URL_RPC**
   - Method: **POST**
   - Headers:
     - `apikey` = **APIKEY**
     - `Authorization` = `Bearer ` + el **Dictionary Value** del paso 7
       (escribe `Bearer`, un espacio, y luego inserta la variable — debe verse
       como cápsula de color, no texto plano)
     - `Content-Type` = `application/json`
   - Request Body: **JSON**
     - `p_monto` (Number) = **Calculation Result** (paso 2)
     - `p_categoria` (Text) = **Chosen Item** (paso 5)
     - `p_nota` (Text) = **Provided Input** (paso 3 — al insertar la variable,
       verifica que sea la del segundo Ask for Input, la de la nota)
9. **Show Notification** (Mostrar notificación)
   - Texto: `Guardado`

(`origen` y `tipo` ya no se envían: la función usa `manual`/`gasto` por defecto.)

Pruébalo: ejecútalo, pon 50, elige `Café/antojos`, y revisa que aparezca ya
categorizado en Movimientos. Con `Después` debe caer al Inbox.

---

## Shortcut 2: automatización de Apple Pay

Captura automática de cada pago con Apple Pay: monto y comercio, sin teclear.

**Primero el shortcut** («Pago capturado»), en Shortcuts → **+**:

1. La entrada llega sola como variable **Transaction** (Transacción) cuando lo
   conectes a la automatización (abajo); no necesitas una acción para recibirla.
2. **Calculate**: **Amount** (Monto, de la variable Transaction) **× -1**
3. **Get Contents of URL** — el token: idéntico al paso 6 del shortcut «Gasto».
4. **Get Dictionary Value** — `access_token`, idéntico al paso 7 de «Gasto».
5. **Get Contents of URL** — el insert. Como «Gasto» pero con **URL_INSERT**
   (inserta directo, sin categoría → Inbox), un header extra
   `Prefer` = `return=minimal`, y el Request Body JSON:
   - `monto` (Number) = **Calculation Result**
   - `comercio` (Text) = **Merchant** (Comerciante, de la variable Transaction)
   - `origen` (Text) = `apple_pay`
   - `tipo` (Text) = `gasto`
6. **Show Notification**
   - Texto: `Categoriza: ` + **Amount** + ` · ` + **Merchant**

**Luego la automatización**: Shortcuts → pestaña **Automation** (Automatización)
→ **+** → **Transaction** (Transacción) → elige tu tarjeta Santander (o "Any
Card") → **Run Immediately** (¡importante!, no "Run After Confirmation") →
Next → elige el shortcut «Pago capturado».

Pruébalo con cualquier compra de Apple Pay: debe llegar la notificación y el
movimiento debe aparecer en el Inbox con el nombre del comercio.

---

## Notas

- Si el token falla (contraseña mal escrita, sin internet), el movimiento no se
  guarda y no hay aviso claro: si no llega la notificación, captúralo con «Gasto».
- La fecha no se envía: Supabase pone la fecha de hoy (zona America/Chihuahua)
  automáticamente.
- «¿Puedo gastar?» se construye en el paso 5 de SPEC §8, cuando exista el candado.
