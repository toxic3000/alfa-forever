# Alfa - La Jauría (`Alfa_Manada`)

La página de La Jauría en la ventana de Alfa (sección Manada, orden 8, ícono `ic-manada`), hecha con el Kit (`docs/KIT.md`). Muestra **solo** a tu grupo o banda y a los **usuarios de Alfa que aceptaron compartir su ubicación**: ni la lista de la hermandad ni la de amigos. Desde el juego no se puede saber quién está en el Discord, así que La Jauría son quienes usan Alfa.

## La página (un Tablero)

1. **Lo que toca ahora**, en grande: compartir tu rastro (si aún no), a quién sigues (Dejar de seguir), en pausa (instancia, bloqueo del juego, cuenta de prueba), quién anda más cerca (Seguir a…, Invitar al grupo) o, si no hay nadie, cómo hacer crecer la manada (Copiar el Discord).
2. **La manada a la vista**: una tarjeta por persona con la huella y el nombre en el color de su clase, nivel, clase, zona, distancia y hace cuánto se supo, con **Seguir** (la flecha del motor; el estilo de lobo lo pone la apariencia) e **Invitar**. Seis y "Ver todos". Si no hay nadie, la sección no sale.
3. **El clan**: el lobo aullando, nombre, lema, descripción, lo que ofrece (`Clan.lua`), el Discord para copiar y **Quiero unirme** (solo si aún no eres de la hermandad del clan).
4. **Apoya a Alfa**: donar es totalmente opcional, una forma de agradecer el trabajo del desarrollador; no desbloquea nada. El enlace sale de `Clan.lua` (`donar`, el enlace del botón de donar de PayPal: `https://www.paypal.com/donate/?hosted_button_id=...`). Vacío (como ahora): la insignia "Muy pronto" y ningún botón; con enlace: un cuadro para copiar. Nunca un correo. La configuración (Alfa_Bienvenida) enlaza aquí desde su resumen.
5. **Ajustes**: compartir (con lo que se envía y por dónde va ahora) y qué se ve en el mapa.

## Cómo viaja la ubicación

- **Canal oculto propio** `AlfaJauria` (`Canal.lua`): temporal, sin contraseña y sin ventana de chat; un filtro oculta cualquier cosa que diga en el chat. Se entra cuando ya están los canales del juego (el General sigue siendo /1). `JoinTemporaryChannel` o `JoinChannelByName` se buscan al vuelo: no están en la documentación de Forever, pero la interfaz de Forever usa `JoinPermanentChannel`, `LeaveChannelByName` y `GetChannelName` (`Blizzard_ChatFrameBase/Shared`), y `SendAddonMessage` documenta el destino de canal y sus respuestas `InvalidChannel` y `ChannelThrottle`.
- **Sin canal** (el juego no deja entrar, o todavía no se entró): la hermandad, y solo se ve a quien usa Alfa y comparte.
- Mensajes con el prefijo `AlfaManada` (`Red.lua`): `1H` (estoy aquí, al entrar al canal; los demás responden con su posición tras una espera al azar, una vez cada 30 s como mucho), `1P` (mapa, x, y, nivel, clase: cada 10 s si te moviste 10 yardas, cada 4 min quieto), `1X` (dejé de compartir), y `1J`/`1K` por susurro para **Quiero unirme**. Cola con tope de 1 mensaje por segundo (ráfaga de 3) que espera si el servidor frena.
- Nada sale dentro de instancias, con el bloqueo de mensajes del juego (`InChatMessagingLockdown`) ni desde una cuenta de prueba o restringida. Lo recibido caduca a los 5 min y se olvida a los 15; como mucho 200 personas.

## En el mapa

- **Tu grupo** (`manada.grupo`): la marca de mapa de Alfa con el alfiler del color de su clase, como siempre.
- **Andar en manada** (`manada.jauria`): quien usa Alfa y aceptó compartir se ve con una huella de lobo pequeña (`ic-huella`), más chica que las marcas de tu grupo, del color de su clase (o el verde de Alfa), sobre un disco oscuro. Nadie sale sin aceptar compartir.
- Quien tiene **insignia** lleva además un aro de su rango (oro o verde) y queda encima de los demás.

## Insignias (`Insignias.lua`)

Una chapita discreta y solo visual para ciertas personas de La Jauría, no para todos los que usan Alfa: **los Alfas** (`"alfa"`: el lobo en oro, "Alfa de La Jauría") y **La Jauría** (`"jauria"`: el lobo en verde, "De La Jauría"). Se ve en el cuadro del jugador (una línea), junto a su nombre en la página y como un aro en su marca del mapa.

La lista `I.LISTA` la lleva Toxic a mano, con permiso de cada persona: `["Nombre Apellido-Reino"] = "alfa"`. Se compara sin mayúsculas ni acentos; con reino cuenta solo en ese reino (a quien el juego no le da reino, como el cuadro de un jugador en Forever, se le toma como de tu reino); sin reino pero con apellido cuenta en cualquier reino; un nombre solo, sin apellido ni reino, no cuenta. Vacía, no engancha nada.

## Privacidad

**Por defecto no se comparte nada.** Al instalar sale la pregunta "¿Compartes tu ubicación con La Jauría?" (un `K.Dialogo`), una sola vez, fuera de combate y de instancias; si está la configuración de Alfa (`Alfa_Bienvenida`), lo pregunta ella en su paso de La Jauría, con "No compartir" elegido hasta que pulses el sí. Quien no comparte no entra al canal ni envía ni recibe nada: se ve entre quienes comparten. Tu grupo siempre se ve (posiciones del juego). La respuesta de la 0.1.0 ("compartir con la hermandad") no cuenta: se vuelve a preguntar.

## Contrato (global `AlfaManada`)

- `AlfaManada.PreguntarCompartir(alTerminar)`: la pregunta; `alTerminar(comparte)` al responder o cerrarla.
- `AlfaManada.Compartir(si)`, `AlfaManada.Comparte()`.
- `AlfaManada.Abrir()`.
- `AlfaManada.Apoyar()`: abre la página en "Apoya a Alfa".
- `AlfaManada.Resumen()` → `{ comparte, manada, grupo, siguiendo, via }` (para Hoy, por ejemplo).
- `AlfaManada.Insignia(nombre)` → `"alfa"` | `"jauria"` | `nil`; `AlfaManada.InsigniaDeUnidad(unit)`; `AlfaManada.EstiloInsignia(tipo)` → `{ texto, icono, color }`.

## Comandos

- `/alfa manada` abre la página.
- `/alfa manada seguir <nombre>` te lleva con alguien del grupo o que comparte. `/alfa manada parar` deja de seguir.
- `/alfa manada compartir sí|no`
- `/alfa manada estado`: qué se envía y por dónde, el canal (estado, número, intentos), la cola y los frenos.

## Ajustes (`manada.*`)

`compartir` (se pregunta), `capaGrupo`, `capaJauria`, `minimapa`, `marcarRaro`, `cazarJuntos`, `saludo` (1.2.7). Datos: `AlfaNucleoDB.manada` (`preguntado`, `consentimiento`).

## 1.2.7: cazar en manada

- **El mapa de la manada** (`Mapa.lua`): el cuadro de un lobo dice su guarida (`Gu.DeLobo`); un llamado de ayuda (`1A`) deja 3 minutos una marca propia en ese lugar (capa `manada.llamados`; clic: la flecha).
- **Marcar el raro** (`Raro.lua`, `manada.marcarRaro`): `SetRaidTarget` tiene restricciones, así que Alfa no marca solo. En grupo (en banda, líder o ayudante), fuera de combate, al seleccionar un raro sin marca sale un aviso con «Marcar con calavera»: el botón seguro del Kit pulsa un botón seguro de Blizzard (acción `raidtarget`, `set-unmarked`, marca 8). Una vez por criatura en la sesión.
- **Cazar juntos** (`Juntos.lua`, `manada.cazarJuntos`): `1M|id,id,...` (hasta 15 misiones; al cambiar el diario, una vez por minuto como mucho, y cada 5 min para quien llegó después). Con los lobos de tu zona: «Hacen N misiones contigo» en su tarjeta y, una vez por lobo, «¿Cazan juntos?» con «Invitar».
- **El saludo** (`Saludo.lua`, `manada.saludo`): a los 30 s de entrar, una vez, quién de tu hermandad anda conectado y dónde (hasta 3 y «y N más»). Solo lee la lista de la hermandad.
- **Logros de la insignia** (`Retrato.lua`): una estrella en el nivel máximo y, en el tuyo, el ícono de raros con 100 raros vistos (`A.Rares.History`, de la cuenta en el reino). Solo visual.
- Prueba: `tools/banco/prueba_127_manada.lua`.

## Para el clan: `Clan.lua`

Nombre exacto de la hermandad (`hermandad`), lema, descripción, lo que ofrecen y **`oficiales`** (nombres completos de personaje, con apellido). `discord = nil` usa el enlace de Alfa. `donar = ""` es el enlace para donar de "Apoya a Alfa" (vacío: "Muy pronto").

## Para verificar en el juego

1. Al entrar por primera vez: ¿sale la pregunta a los ~20 s (sin el asistente de primer arranque)? Esc no comparte; "Sí, compartir" sí.
2. Con compartir encendido: `/alfa manada estado` dice "canal oculto AlfaJauria (dentro, número N)". ¿El General sigue en /1? ¿Nada del canal sale en el chat ni al entrar?
3. Dos personajes con Alfa **fuera de grupo y de hermandad**, los dos comparten: ¿se ven en la página y en el mapa con nombre, zona y distancia? Si no: `/alfa manada estado` en los dos (respuesta del último envío) y anotar el número del resultado.
4. **Seguir** a esa persona: ¿la flecha la sigue mientras camina y se detiene al llegar? "Dejar de seguir" la suelta.
5. Apagar compartir: el otro deja de verte enseguida (llega `1X`) y `/chatlist` ya no muestra AlfaJauria.
6. Entrar a una mazmorra: la tarjeta dice "En pausa"; al salir la posición vuelve a salir sola.
7. Cuenta de prueba: la tarjeta lo dice y no intenta nada.
8. **Quiero unirme** desde un personaje sin la hermandad del clan, con un oficial de `Clan.lua` conectado y con Alfa.
9. Copiar el Discord: el botón de la tarjeta lleva al enlace y lo deja elegido; Ctrl+C lo copia.
10. Apoya a Alfa: con `donar` vacío dice "Muy pronto" sin botón; con un enlace, el cuadro lo deja elegido y Ctrl+C lo copia. Desde el resumen de la configuración, "Ver cómo" abre la página justo en ese bloque.
