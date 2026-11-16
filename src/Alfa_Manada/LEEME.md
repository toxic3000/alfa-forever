# Alfa - La Jauría (`Alfa_Manada`)

La página de La Jauría en la ventana de Alfa (orden 8, ícono `flag`): tu manada en el mapa, un botón **Seguir** que te lleva con la flecha y la ruta de Alfa hasta alguien, y la cara del clan para que la gente lo conozca y se una.

## Qué hace

- **Tu grupo**: posición de cada miembro con la API del juego, en una lista con nivel, clase, zona y distancia.
- **Tu hermandad y tus amigos con Alfa**: mensajes de addon ocultos con el prefijo `AlfaManada`, por el canal de la hermandad y por susurro a amigos de tu lista. Un saludo dice quién usa Alfa; quien comparte manda su posición (mapa, x, y), nivel y clase cada 10 s solo si se movió, y cada 4 min si está quieto. Nada sale dentro de instancias. Hay una cola con tope de 2 mensajes por segundo que espera y reintenta si el servidor frena. Lo recibido caduca a los 5 min.
- **Pines** en el mapa del mundo y el minimapa (`Alfa.Pins`): la marca de Alfa con el alfiler del color de la clase y el nombre en su etiqueta. Al pasar el ratón se ve nivel, zona, distancia y hace cuánto se supo; un clic lo sigue. Son tres capas: Grupo, La Jauría y Amigos. Si está `Alfa_Mundo`, se registran en su control de capas.
- **Seguir**: pone a la persona como destino de la navegación de Alfa (`Alfa.Nav.SetTarget` + `StartTrip`) y mueve el destino cada 3 s mientras camina (`Alfa.Nav.MoveTarget`). Se detiene al llegar, al cancelar o si se pierde su rastro.
- **Lista de la hermandad**: quién está conectado, nivel, clase, zona, si usa Alfa y hace cuánto lo viste (se guarda por cuenta). Tiene Seguir, Susurrar e Invitar al grupo, todo con un clic. Susurrar abre el chat: nada se envía solo.
- **El clan**: nombre, lema, descripción y lo que ofrece (`Clan.lua`), el Discord en un cuadro para copiar (`Alfa.DiscordURL`) y el botón **Quiero unirme**. Ese botón pregunta en silencio a los oficiales si están conectados y abre un susurro al primero que responde, con el mensaje listo para enviar con Intro. Si nadie responde, explica cómo pedir invitación y ofrece escribirles a mano.

## Privacidad

La primera vez (al abrir la página o un minuto después de entrar, si estás en una hermandad) se pregunta con un diálogo si compartes tu ubicación. **Por defecto no se comparte nada**, y al aceptar solo se comparte con la hermandad. Compartir con amigos es un ajuste aparte. Todo se apaga cuando quieras. Nunca se usan canales públicos.

## Comandos

- `/alfa manada` abre la página.
- `/alfa manada seguir <nombre>` te lleva con alguien del grupo o que comparte. `/alfa manada parar` deja de seguir.
- `/alfa manada compartir sí|no`
- `/alfa manada clan`, `/alfa manada ajustes`
- `/alfa manada estado` muestra qué se envía y qué se recibe, con la cola y los frenos.

## Ajustes (`manada.*`)

`red` (conectar con la manada), `compartir` (hermandad, se pregunta), `compartirAmigos`, `verAmigos`, `capaGrupo`, `capaJauria`, `capaAmigos`, `minimapa`, `verDesconectados`. Datos: `AlfaNucleoDB.manada` (`preguntado`, `visto`).

## Para el clan: `Clan.lua`

Edita el nombre exacto de la hermandad (`hermandad`), el lema, la descripción, lo que ofrecen y, sobre todo, **`oficiales`**: nombres completos de personaje como salen en el juego (con apellido, por ejemplo "Nombre Apellido"). También puedes cambiar el mensaje para pedir invitación. `discord = nil` usa el enlace de Alfa.

## Para verificar en el juego

1. `/alfa manada`: la insignia, las tres secciones y que todo quepa sin cortarse. Pruébalo también con la apariencia Hearth.
2. Con alguien de la hermandad con Alfa, los dos aceptan compartir: ¿se ven en el mapa y el minimapa con nombre y color de clase? ¿Sale su zona y distancia en la lista? ¿Hace cuánto se supo?
3. **Seguir** a esa persona: ¿la flecha y la ruta la siguen mientras camina? ¿Se detiene al llegar con "Llegaste con..."? ¿"Dejar de seguir" y "Volver a la guía" la sueltan?
4. Grupo: Seguir a alguien del grupo sin que comparta nada. En banda (raid), ¿el juego da posiciones? La documentación dice "solo grupo".
5. Entrar a una mazmorra: el estado dice "En pausa" y nada sale (`/alfa manada estado`). Al salir, la posición vuelve a salir sola.
6. Amigos: con "Compartir con mis amigos" en los dos lados, ¿se ven? ¿Llega algún aviso "no hay ningún jugador llamado..." al saludar? No debería, porque solo se saluda a amigos conectados.
7. **Quiero unirme** desde un personaje sin hermandad, con un oficial de `Clan.lua` conectado y con Alfa: ¿se abre el susurro con el mensaje? ¿Se ocultan los avisos de "no está conectado" de los oficiales desconectados?
8. Susurrar e Invitar desde la lista con nombres con apellido ("Ana Smith"): ¿el susurro va a la persona correcta? ¿La invitación llega?
9. "Hace cuánto lo viste" para desconectados (usa `GetGuildRosterLastOnline` si existe, o lo guardado).
10. Con `Alfa_Mundo` instalado, las capas Grupo, La Jauría y Amigos aparecen en su control y apagarlas allí las apaga aquí.
