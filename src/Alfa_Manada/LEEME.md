# Alfa - La Jauría (`Alfa_Manada`)

La página de La Jauría en la ventana de Alfa (sección Manada, orden 8, ícono `ic-manada`), hecha con el Kit (`docs/KIT.md`). Muestra **solo** a tu grupo o banda y a los **usuarios de Alfa que aceptaron compartir su ubicación**: ni la lista de la hermandad ni la de amigos. Desde el juego no se puede saber quién está en el Discord, así que La Jauría son quienes usan Alfa.

## La página (un Tablero)

1. **Lo que toca ahora**, en grande: compartir tu rastro (si aún no), a quién sigues (Dejar de seguir), en pausa (instancia, bloqueo del juego, cuenta de prueba), quién anda más cerca (Seguir a…, Invitar al grupo) o, si no hay nadie, cómo hacer crecer la manada (Copiar el Discord).
2. **La manada a la vista**: una tarjeta por persona con la huella y el nombre en el color de su clase, nivel, clase, zona, distancia y hace cuánto se supo, con **Seguir** (la flecha del motor; el estilo de lobo lo pone la apariencia) e **Invitar**. Seis y "Ver todos". Si no hay nadie, la sección no sale.
3. **El clan**: el lobo aullando, nombre, lema, descripción, lo que ofrece (`Clan.lua`), el Discord para copiar y **Quiero unirme** (solo si aún no eres de la hermandad del clan).
4. **Ajustes**: compartir (con lo que se envía y por dónde va ahora) y qué se ve en el mapa.

## Cómo viaja la ubicación

- **Canal oculto propio** `AlfaJauria` (`Canal.lua`): temporal, sin contraseña y sin ventana de chat; un filtro oculta cualquier cosa que diga en el chat. Se entra cuando ya están los canales del juego (el General sigue siendo /1). `JoinTemporaryChannel` o `JoinChannelByName` se buscan al vuelo: no están en la documentación de Forever, pero la interfaz de Forever usa `JoinPermanentChannel`, `LeaveChannelByName` y `GetChannelName` (`Blizzard_ChatFrameBase/Shared`), y `SendAddonMessage` documenta el destino de canal y sus respuestas `InvalidChannel` y `ChannelThrottle`.
- **Sin canal** (el juego no deja entrar, o todavía no se entró): la hermandad, y solo se ve a quien usa Alfa y comparte.
- Mensajes con el prefijo `AlfaManada` (`Red.lua`): `1H` (estoy aquí, al entrar al canal; los demás responden con su posición tras una espera al azar, una vez cada 30 s como mucho), `1P` (mapa, x, y, nivel, clase: cada 10 s si te moviste 10 yardas, cada 4 min quieto), `1X` (dejé de compartir), y `1J`/`1K` por susurro para **Quiero unirme**. Cola con tope de 1 mensaje por segundo (ráfaga de 3) que espera si el servidor frena.
- Nada sale dentro de instancias, con el bloqueo de mensajes del juego (`InChatMessagingLockdown`) ni desde una cuenta de prueba o restringida. Lo recibido caduca a los 5 min y se olvida a los 15; como mucho 200 personas.

## Privacidad

**Por defecto no se comparte nada.** Al instalar sale la pregunta "¿Compartes tu ubicación con La Jauría?" (un `K.Dialogo`), una sola vez, fuera de combate y de instancias; si está el asistente de primer arranque (`Alfa_Bienvenida`), lo pregunta él. Quien no comparte no entra al canal ni envía ni recibe nada: se ve entre quienes comparten. Tu grupo siempre se ve (posiciones del juego). La respuesta de la 0.1.0 ("compartir con la hermandad") no cuenta: se vuelve a preguntar.

## Contrato (global `AlfaManada`)

- `AlfaManada.PreguntarCompartir(alTerminar)`: la pregunta; `alTerminar(comparte)` al responder o cerrarla.
- `AlfaManada.Compartir(si)`, `AlfaManada.Comparte()`.
- `AlfaManada.Abrir()`.
- `AlfaManada.Resumen()` → `{ comparte, manada, grupo, siguiendo, via }` (para Hoy, por ejemplo).

## Comandos

- `/alfa manada` abre la página.
- `/alfa manada seguir <nombre>` te lleva con alguien del grupo o que comparte. `/alfa manada parar` deja de seguir.
- `/alfa manada compartir sí|no`
- `/alfa manada estado`: qué se envía y por dónde, el canal (estado, número, intentos), la cola y los frenos.

## Ajustes (`manada.*`)

`compartir` (se pregunta), `capaGrupo`, `capaJauria`, `minimapa`. Datos: `AlfaNucleoDB.manada` (`preguntado`, `consentimiento`).

## Para el clan: `Clan.lua`

Nombre exacto de la hermandad (`hermandad`), lema, descripción, lo que ofrecen y **`oficiales`** (nombres completos de personaje, con apellido). `discord = nil` usa el enlace de Alfa.

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
