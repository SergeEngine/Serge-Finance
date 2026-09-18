# Shortcuts — instrucciones de construcción (SPEC §8 paso 3)

Dos shortcuts se construyen a mano en la app **Atajos** del iPhone. Los dos
hacen lo mismo al final: dos llamadas HTTP a Supabase (1: obtener token,
2: guardar con la función `agregar_movimiento`), y los dos muestran el menú de
categorías ahí mismo — elige "Después" para mandarlo al Inbox. La automatización
de Apple Pay además registra con qué tarjeta pagaste (cuenta).

Datos que vas a usar (cópialos tal cual):

- **URL_TOKEN**: `https://qmftfhvixszzqtfmxsgv.supabase.co/auth/v1/token?grant_type=password`
- **URL_RPC**: `https://qmftfhvixszzqtfmxsgv.supabase.co/rest/v1/rpc/agregar_movimiento`
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

Captura automática de cada pago con Apple Pay: monto, comercio y tarjeta
(cuenta) sin teclear; solo eliges la categoría en el menú que aparece al pagar.

**Se construye como automatización en blanco** (no como shortcut aparte: un
shortcut separado recibe la transacción como "Shortcut Input" sin propiedades
visibles al editarlo — construida inline, la variable **Transaction** sí ofrece
Amount/Merchant/Card or Pass). Shortcuts → pestaña **Automation** → **+** →
**Transaction** (aparece como "When Any Card Is Tapped") → marca SOLO las
tarjetas que quieres capturar → **Run Immediately** (¡no "Run After
Confirmation"!) → Next → **New Blank Automation**, y arma ahí estas acciones
(las de token puedes copiarlas de «Gasto»: mantén presionada la acción → Copy →
Paste):

1. **Calculate**: **Amount** (Monto, de la variable Transaction) **× -1**
2. **If** (Si) — condición: **Card or Pass** (de Transaction) — **Contains** —
   una palabra que solo aparezca en el nombre de UNA de tus dos tarjetas en
   Wallet (ábrela en Wallet para ver el nombre exacto).
   - Si "Contains" no aparece: Card or Pass llega como objeto, no texto. Toca
     la cápsula y cambia **Type** a **Text**, o mete antes una acción **Text**
     con la cápsula dentro y usa esa como sujeto del If.
   - Dentro del **If**: acción **Text** con el nombre EXACTO de esa cuenta en
     el app, p. ej. `Santander TDC`
   - Dentro del **Otherwise** (Si no): acción **Text** con la otra, p. ej.
     `Santander débito`
   - Después del **End If**, la variable **If Result** vale el texto de la rama
     que se ejecutó — esa se usa abajo.
3. **List** — las mismas 13 categorías del shortcut «Gasto»
   (incluye `Después` para mandarlo al Inbox).
4. **Choose from List** — List del paso 3 · Prompt: `¿Categoría?`
5. **Get Contents of URL** — el token: idéntico al paso 6 de «Gasto».
6. **Get Dictionary Value** — `access_token`, idéntico al paso 7 de «Gasto».
7. **Get Contents of URL** — guardar. Igual que el paso 8 de «Gasto»
   (URL_RPC, POST, mismos headers) pero con este Request Body JSON:
   - `p_monto` (Number) = **Calculation Result** (paso 1)
   - `p_categoria` (Text) = **Chosen Item** (paso 4)
   - `p_comercio` (Text) = **Merchant** (de Transaction)
   - `p_cuenta` (Text) = **If Result** (paso 2)
   - `p_origen` (Text) = `apple_pay`
8. **Show Notification**
   - Texto: `Guardado: ` + **Amount** + ` · ` + **Merchant**

Pruébalo con una compra real: al pagar aparece el menú de categorías; elige una
y revisa en el app que el movimiento traiga comercio, categoría y cuenta. Si al
pagar no puedes atender el menú, elige `Después` y cae al Inbox; si lo ignoras
por completo el shortcut no termina y el movimiento NO se guarda — captúralo
luego con «Gasto».

---

## Shortcut 3: «¿Puedo gastar?»

Pregunta rápida desde el teléfono: contesta en una notificación si el candado
está abierto y cuánto queda de gasto discrecional este mes. Ponlo en el botón de
Acción o como widget.

En Shortcuts → **+** → nombre «¿Puedo gastar?»:

1. **Get Contents of URL** — el token: idéntico al paso 6 de «Gasto»
   (cópialo de ahí: mantén presionada la acción → Copy → Paste).
2. **Get Dictionary Value** — `access_token` del paso 1.
3. **Get Contents of URL** — el estado
   - URL: `https://qmftfhvixszzqtfmxsgv.supabase.co/rest/v1/estado?select=*`
   - Method: **GET**
   - Headers: `apikey` = APIKEY · `Authorization` = `Bearer ` + la cápsula del paso 2
   - (sin Request Body)
4. **Get Dictionary Value** — `candado` en **Contents of URL** (paso 3).
   La respuesta es una lista de un elemento; si Shortcuts se queja, agrega antes
   un **Get Item from List** → First Item.
5. **Get Dictionary Value** — `discrecional_restante`, misma fuente.
6. **Show Notification**
   - Texto: `Candado ` + cápsula del paso 4 + ` · quedan $` + cápsula del paso 5

Pruébalo: debe decir «Candado abierto · quedan $5,170» (o cerrado). El candado se
calcula con la lista semanal que defines en el app, en Más → Candado.

---

## Notas

- Si el token falla (contraseña mal escrita, sin internet), el movimiento no se
  guarda y no hay aviso claro: si no llega la notificación, captúralo con «Gasto».
- La fecha no se envía: Supabase pone la fecha de hoy (zona America/Chihuahua)
  automáticamente.
- El candado nunca bloquea nada: informa. Si está cerrado, el app marca los
  gastos discrecionales con una línea en oxblood y ya.
