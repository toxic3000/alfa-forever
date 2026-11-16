# Alfa - Mazmorras

La mazmorra para tu nivel con un clic para prepararte, y de cada mazmorra sus jefes,
botín, misiones y consejos. Desde la 1.0 es **la única vista de las mazmorras**: el
diario del motor (`SHOW_DUNGEON`) y su tarjeta de mazmorra abierta (`DUNGEON_TOAST`)
se reemplazan con esta página y con avisos del Kit (`Reemplazos.lua`).

## Qué hace

- **Inicio** (`/alfa mazmorras`): arriba, **Para tu nivel ahora** en grande: una
  mazmorra recomendada (la de tu nivel con más misiones que ya puedes recoger; la que
  pisas si estás dentro; la siguiente si aún no llegas a ninguna) con el arte de su
  zona y su botón **Prepárame**. Debajo, **todas las mazmorras** por rango (10–20 …
  50–60, Bandas) en tarjetas con su arte, rango, zona e insignias (tu nivel, hecha,
  jefes vencidos, de Forever, entrada enemiga). Al final, tu progreso en corto, solo
  si ya tienes.
- **Prepárame** (`Plan.lua`): recoge **solo las misiones que ya puedes tomar** y te
  lleva a la entrada (la guía de recogida del motor con la regla de la tarjeta:
  `Dungeons.PickUp(key, true)`), y dice qué les falta a las demás: tu nivel o una
  misión antes. Una misión cuya cadena pasa por una previa de un nivel que aún no
  tienes espera. Sin nada que recoger, solo la flecha a la entrada.
- **Página de cada mazmorra**: cabecera con su arte, rango, mejor nivel, zona y tus
  jefes vencidos (huellas), y pestañas (solo las que tienen algo):
  - **Resumen**: qué hacer ahora (prepárate, entrega tus misiones, estás dentro y
    quién sigue, o todavía es pronto y por qué), lo que valen sus misiones, sus
    requisitos y llaves con «Guíame», y atajos (ver en el mapa, ya la hice antes,
    olvidar mi progreso aquí).
  - **Jefes**: cada uno con su número o su marca de vencido, su nivel, si es el
    final, opcional o raro, sus consejos (por papel), su botín en íconos y sus
    misiones. En **modo historia** los jefes sin vencer quedan por descubrir; sus
    consejos se pueden ver a propósito.
  - **Botín**: por jefe, con «Todo» o «Lo que me sirve», la probabilidad, si ya lo
    tienes y la flecha de mejora del motor; lo poco probable aparte.
  - **Misiones**: para recoger ahora, en tu registro (lista para entregar, en curso),
    todavía no (con lo que le falta), no son para ti y hechas. «Llévame» pone la
    flecha en quien la da o la recibe.
  - **Consejos**: antes de entrar (solo en las mazmorras que los tienen) y los avisos
    de jefes del juego, con un enlace a sus ajustes.
- **Tu progreso** (`/alfa mazmorras progreso`): mazmorras hechas, jefes vencidos y botín
  obtenido, por personaje.
- **Avisos del Kit**: al entrar a una mazmorra (con un clic a sus jefes), al descubrir
  un jefe (a su botín), al completarla (a entregar tus misiones) y cuando una mazmorra
  se abre para ti (con «Prepárame»).
- **Entradas en el minimapa** (capa `mazmorras.entradas`, con Alfa_Mundo en su control
  de capas): el motor ya las pinta en el mapa del mundo; en verde las que ya hiciste.

## Ajustes (Ajustes > Descubrir > Mazmorras)

**Tu diario de mazmorras**: `historia` (sí), `avisoDescubrir` (sí), `avisoEntrar` (sí),
`meSirve` (no), entradas en el minimapa (`capaEntradas`, sí) y borrar todo tu progreso.
**Avisos de jefes**: las opciones de la línea de tiempo y de los mensajes de Blizzard
(CVars, `Avisos.lua`), explicadas, con «Dejarlo como recomienda Alfa» y «Probar la línea
de tiempo». `/alfa mazmorras ajustes` abre esa pestaña.

Progreso por personaje en `AlfaNucleoCharDB.mazmorras` (`hechas`, `jefes`, `botin`);
las entradas para el minimapa en `AlfaNucleoDB.mazmorras.entradas`.

## Para otras áreas

```lua
AlfaMazmorras.Abrir(key | nil[, pestana])   -- "resumen" | "jefes" | "botin" | "misiones" | "consejos"
AlfaMazmorras.Recomendada()  -- { key, nombre, zona, min, max, modo, recoger, esperan, hecha } | nil
AlfaMazmorras.Preparar(key)  -- recoge lo que puedes tomar y te lleva a la entrada
AlfaMazmorras.Frase(key)     -- qué hará Prepárame, en palabras
```

## Archivos

`Datos.lua` (diario del motor, botín del Codex, progreso, eventos), `Avisos.lua` (CVars
de los avisos de jefes), `Plan.lua` (qué misiones puedes tomar y qué les falta),
`Piezas.lua` (bloques propios hechos con el Kit), `Ajustes.lua`, `Vista.lua` (la
página), `Reemplazos.lua`, `Capa.lua` (minimapa), `Consejos/*.lua`.

## Consejos (`Consejos/<Mazmorra>.lua`)

```lua
M.Consejos["deadmines"] = {
	general = { { "español", "English" } },
	[644] = { { "español", "English", rol = "tanque" } },  -- id del PNJ del jefe
	e548 = { ... },                                        -- grupo sin PNJ: "e" .. encuentro
}
```
`rol`: `tanque`, `cura`, `dano` o nada (todos). Hay consejos para Sima Ígnea, Cuevas de los
Lamentos, Minas de la Muerte, Castillo de Colmillo Oscuro, Mazmorras de Ventormenta,
Cavernas de Brazanegra, Gnomeregan, Horado Rajacieno, Monasterio Escarlata, Zahúrda
Rajacieno y Uldaman.

## Para verificar en el juego

1. `/alfa mazmorras`: «Para tu nivel ahora» recomienda una que te queda bien; el arte de
   las tarjetas se ve; los rangos tienen sus mazmorras.
2. **Prepárame** en una mazmorra con misiones: se abre la guía en una pestaña nueva, la
   ventana de guía se muestra y **ningún paso manda a una misión que todavía no puedes
   tomar**. Un aviso dice cuántas recoges y cuáles esperan.
3. Pestaña **Misiones**: cada una dice lo que le falta (nivel, la misión antes, otra
   clase, se toma dentro). «Llévame» pone la flecha en quien la da.
4. Al subir de nivel y abrirse una mazmorra: sale el aviso del Kit (no la tarjeta del
   motor); al cerrarlo, la siguiente tarjeta del motor puede salir.
5. `/alfa dungeons`, el acceso «Diario de mazmorras» de Tu guía y el botón del centro
   abren esta página, nunca el diario del motor.
6. Dentro de una mazmorra: aviso de entrada; al vencer un jefe, aviso de descubierto;
   al vencer el último, aviso de completada. Confirmar que `ENCOUNTER_END` llega con el
   id de encuentro de las páginas del motor y `success = 1`.
7. Ajustes > Descubrir > Mazmorras: las dos secciones nuevas; cada interruptor de avisos
   cambia su CVar; «Probar la línea de tiempo» muestra tres marcas que se borran.
8. Las insignias y sobretítulos con acentos («ESTÁS AQUÍ», «DESPUÉS DE OTRA») salen
   bien en mayúsculas.
