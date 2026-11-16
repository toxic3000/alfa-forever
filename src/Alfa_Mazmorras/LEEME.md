# Alfa - Mazmorras

Reemplaza a DungeonJournal y a DBM. Complementa el diario de mazmorras del motor
(`Alfa.Dungeons`: misiones, jefes en orden y entrada) con lo que no tiene, y enlaza a
sus páginas en lugar de repetirlas.

## Qué hace

- **Diario por mazmorra** (página *Mazmorras*, orden 50): lista *Para tu nivel / Todas /
  Hechas* con la imagen de cada mazmorra; al elegir una, sus jefes en orden con
  **consejos para principiantes** y **botín**.
- **Botín por jefe y de toda la mazmorra**, sacado del Codex (lo que cada PNJ suelta y con
  qué probabilidad): calidad, ranura, tipo, nivel, si ya lo tienes (✓) y la **flecha de
  mejora** del motor (`Gear.IsUpgrade`; gris si servirá a cierto nivel). Lo poco probable
  va aparte. **Solo lo que me sirve** filtra por clase, mejor tipo de armadura y
  especialización.
- **Modo historia**: el nombre y el botín de cada jefe se descubren al vencerlo
  (`ENCOUNTER_END` / `BOSS_KILL`); la mazmorra entera al vencer su último jefe. Botón
  **Ya la hice antes**. Las misiones entregadas que prueban un jefe vencido lo descubren
  solas. Los consejos siempre se pueden ver con *Ver sus consejos de todos modos*.
- **Mi progreso**: mazmorras hechas (y cuántas veces), jefes vencidos, botín obtenido
  (lo que recibes dentro de la mazmorra y lo que ya tienes). Por personaje.
- **Avisos de jefes**: las opciones de la línea de tiempo y de los avisos de encuentros
  de Blizzard (CVars), explicadas, con un botón para probar la línea de tiempo.
- **Entradas en el minimapa** (capa `mazmorras.entradas` en Alfa_Mundo): el motor ya las
  pinta en el mapa del mundo; aquí se agregan al minimapa, en verde las ya hechas.
- Avisos en el chat al entrar a una mazmorra, al descubrir un jefe y al completarla.

## Comandos

- `/alfa mazmorras` abre la página.
- `/alfa mazmorras <nombre>` abre una mazmorra (sin acentos vale: `sima ignea`).

## Ajustes (`mazmorras.*`, de la cuenta)

`historia` (sí), `avisoDescubrir` (sí), `avisoEntrar` (sí), `meSirve` (no),
`capaEntradas` (sí; con Alfa_Mundo manda su control de capas).
Progreso por personaje en `AlfaNucleoCharDB.mazmorras` (`hechas`, `jefes`, `botin`);
las entradas para el minimapa en `AlfaNucleoDB.mazmorras.entradas`.

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

1. Abrir `/alfa mazmorras`: la lista se llena (carga el Codex fuera de combate), las
   imágenes se ven, y "Para tu nivel" muestra las correctas.
2. En una mazmorra: sale la línea "Entraste a …" en el chat. Al vencer un jefe sale
   "Descubriste a …" y su página se abre. Confirmar que **`ENCOUNTER_END` llega con el id
   de encuentro** de las páginas del motor (2741 Rhahk'Zor…) y `success = 1`.
3. Al recoger botín de un jefe, aparece en *Mi progreso > Botín obtenido* (el texto de
   `CHAT_MSG_LOOT` puede llegar secreto dentro de instancias: entonces solo cuenta lo que
   ya tienes en tus bolsas).
4. El último jefe marca la mazmorra como hecha y suma una vez.
5. Botín: nombres en español, colores de calidad, ranura y tipo; la flecha verde coincide
   con la del motor en las bolsas; *Solo lo que me sirve* oculta lo correcto.
6. *Avisos de jefes*: cada interruptor cambia su CVar (comprobar en Opciones > Avanzado
   del juego, si existe) y *Probar la línea de tiempo* muestra tres marcas que se borran.
7. Minimapa: las entradas aparecen cerca de cada mazmorra; con Alfa_Mundo, el interruptor
   *Entradas en el minimapa* las prende y apaga.
8. *Ya la hice antes* y *Olvidar mi progreso aquí* piden confirmación y hacen lo que dicen.
