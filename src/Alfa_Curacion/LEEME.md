# Alfa - Curación

Página **Curación** de la ventana de Alfa (sección Personaje, orden 16, ícono `ic-curacion`), hecha con el Kit (`docs/KIT.md`). Marcos de grupo y banda para curar con un clic, de la forma más sencilla: cualquier curandero (Sacerdote, Druida, Paladín, Chamán) lo usa sin configurar nada, y las demás clases lo usan para buffs y para seleccionar.

## La página y el asistente

- **La página** (`Pagina.lua`, `K.Tablero` con la tarjeta de estado): arriba, cómo están tus marcos y qué hacer ahora (*Encenderlos*, *Listo* en el modo prueba, *Empezar* el asistente si curas y aún no lo haces, o listo para curar con lo que hacen tus dos clics, *Asistente* y *Mover marcos*); los **preajustes** en tarjetas (el que usas, marcado); **Tu ratón**, la cuadrícula de 12 clics (clic en una casilla: elegir qué hace en un menú del Kit; clic derecho: sin acción); y los ajustes en grupos (*Tus clics*, *Marcos*, *Qué muestran*).
- **El asistente de 3 pasos** (`Asistente.lua`, `K.Ventana` con `K.Asistente`): 1) elige tus clics (un preajuste y, si curas, "el clic izquierdo solo selecciona"); 2) acomoda tus marcos con el modo prueba (5 o 20 marcos de ejemplo que arrastras, con ancho, alto, columnas y hacia dónde crecen); 3) prueba tus clics: un clic en un marco de ejemplo (con o sin Mayús, Ctrl o Alt) dice qué lanzaría, sin lanzar nada, y debajo está todo tu mapa. Al terminar, los marcos quedan encendidos. Cerrarlo a medias quita la prueba.
- **A la vista de quien cura** (sacerdote, druida, paladín y chamán): mientras no hagan el asistente, la página lo recomienda arriba y Hoy lo muestra en sus alertas (`AlfaCuracion.Asistente()`, `.AsistentePendiente()`, `.Omitir()`; *Ahora no* lo quita). `/alfa curacion asistente` lo abre cuando quieras.
- El hechizo nuevo se ofrece con un diálogo del Kit (*Usarlo* / *Ahora no*).

## Qué hace

- **Marcos de grupo y banda** (`Marcos.lua`): tú y tu grupo, o tu banda de hasta 40, con una cabecera segura (`SecureGroupHeaderTemplate`) que se reordena sola también en combate. Cada compañero es un botón seguro (`SecureUnitButtonTemplate`) con barra de vida en color de clase, nombre, ícono de rol, curas entrantes (franja verde clara), línea roja de amenaza, borde del color del perjuicio que **tú** puedes quitar (filtro `HARMFUL|RAID`), borde blanco si es tu objetivo, "Muerto", "Fantasma" o "Desconectado" con la barra gris, y atenuado si está fuera de alcance. Todo se pinta por eventos de unidad; el alcance también con un temporizador de medio segundo que revisa como mucho 8 marcos por vuelta.
- **Valores secretos**: la vida y las curas entrantes van directo a `StatusBar:SetMinMaxValues/SetValue`, el porcentaje con `UnitHealthPercent` y una curva, el alcance con `SetAlphaFromBoolean`, el color del perjuicio con `C_UnitAuras.GetAuraDispelTypeColor` y una curva de color. Rol, amenaza y estado solo si llegan legibles (el rol secreto lo pinta `UnitFrameUtil.UpdateUnitFrameRoleIcon` de Blizzard). Nada compara ni suma un valor secreto, y nada decide a quién curar.
- **Curar con clic** (`Mapa.lua`): un mapa del ratón con 12 ranuras (izquierdo, central y derecho; sin tecla, Mayús, Ctrl y Alt). Cada una lanza un hechizo de tu libro (solo los que sirven sobre aliados), selecciona o abre el menú del jugador. Los atributos (`type1`, `shift-spell2`...) se ponen solo fuera de combate; los botones nuevos los copian de la cabecera (`_initialAttributeNames`).
- **Preajustes** (`Hechizos.lua`): "Curandero" por clase y "Solo buffs" para todas, más "Desde cero". Solo usan hechizos que conoces (`C_SpellBook.IsSpellKnown`, `IsPlayerSpell` o tu libro por nombre) y los nombres salen del cliente (`C_Spell.GetSpellName`). Opción "El clic izquierdo solo selecciona": la cura del izquierdo pasa al central. Un personaje nuevo empieza con el preajuste de su clase.
- **Hechizo nuevo**: al aprender un hechizo o subir de nivel, si el preajuste tiene uno mejor para una ranura, Alfa lo ofrece con un aviso (Usarlo / Ahora no). Nunca lo cambia solo, y no vuelve a ofrecer lo que rechazaste.
- **Modo prueba**: 5 o 20 marcos de ejemplo (no seguros) para acomodar y medir estando solo. Se arrastran para mover; en combate se quitan solos.
- **Clic para lanzar de Blizzard**: "Usar también en los marcos de Blizzard" copia tus 12 clics a `C_ClickBindings.SetProfileByInfo` (conserva el resto de tu perfil), lo comprueba leyéndolo de vuelta y, si el juego no lo deja, abre la ventana oficial. La página avisa si tu clic para lanzar de Blizzard usa alguna de tus teclas, porque ese manda también en los marcos de Alfa.
- **Ocultar los marcos de grupo de Blizzard** (`PartyFrame` y `CompactRaidFrameContainer`), fuera de combate y reversible.

## Comandos

- `/alfa curacion`: abre la página.
- `/alfa curacion asistente`: el asistente de 3 pasos.
- `/alfa curacion prueba` / `prueba20` / `listo`: modo prueba con 5 o 20, y quitarlo.
- `/alfa curacion mover`: desbloquea o fija los marcos.
- `/alfa curacion blizzard`: usa tu mapa también en los marcos de Blizzard.
- `/alfa curacion on` / `off`: enciende o apaga los marcos.
- `/alfa curacion reiniciar`: los marcos vuelven a su lugar.

## Ajustes

| Ajuste | Por omisión |
|---|---|
| Usar los marcos de Alfa; verte a ti estando solo; ocultar los de Blizzard | sí; no; sí |
| Ancho; alto; compañeros por columna; crecen hacia; orden | 88 px; 36 px; 5; abajo; por grupo |
| Color de clase; curas entrantes; amenaza; perjuicios que puedes quitar; porcentaje; atenuar a quien está lejos; detalle al pasar el ratón | sí; sí; sí; sí; no; sí; sí |

Se guardan en `AlfaDB.settings.curacion`. El mapa del ratón, el preajuste, "el izquierdo solo selecciona" y los avisos rechazados van por personaje en `AlfaNucleoCharDB.curacion`; la posición de los marcos en `AlfaNucleoDB.curacion`.

## Para verificar en el juego

1. El asistente con un sacerdote nuevo: sale en Hoy y arriba en Curación; los tres pasos, el clic en un marco de ejemplo (con Mayús, Ctrl y Alt) dice lo correcto, y al terminar los marcos quedan encendidos y la alerta se va. Cerrarlo a medias quita la prueba.
2. Solo: `/alfa curacion prueba` muestra 5 marcos de ejemplo; arrastrarlos, cambiar ancho, alto y columnas, y pulsar Listo. Con 20, que las columnas se acomoden.
3. En grupo: aparecen tú y tu grupo; la vida baja y sube en combate y en una mazmorra sin errores de valores secretos (BugSack limpio).
4. Clic izquierdo, derecho, central y con Mayús, Ctrl y Alt lanzan lo que dice la cuadrícula. "Seleccionar objetivo" en una ranura con tecla (va como macro `/target <unidad>`) y el menú en el derecho.
5. Cambiar el grupo en combate (alguien entra o sale): los marcos se reordenan y los clics siguen funcionando.
6. Fuera de alcance se atenúa; el borde de perjuicio sale con el color correcto solo para lo que tú puedes quitar; la línea de amenaza sale cuando un enemigo ataca a ese compañero.
7. Curas entrantes: la franja verde aparece pegada al final de la vida mientras otro curandero lanza.
8. Aprender un hechizo en el instructor (por ejemplo Curación relámpago a nivel 20): sale el aviso; "Ahora no" no lo vuelve a ofrecer.
9. "Usar también en los marcos de Blizzard": confirmar si `SetProfileByInfo` funciona desde un addon y si los bits de Mayús, Ctrl y Alt (sacados de `GetStringFromModifiers`) son los buenos; si no, que abra la ventana oficial. Probar los clics en los marcos de Blizzard.
10. Ocultar los de Blizzard: el marco de grupo y el de banda de Blizzard desaparecen y vuelven al apagar la opción; entrar al Modo edición no da errores.
11. Rol: que el ícono salga en grupos con roles asignados.

## 1.3.0: curar y seleccionar

- **Curar y seleccionar** (por personaje, `AlfaNucleoCharDB.curacion.curarSel`, prendido si nunca lo tocaste): cada clic que cura va como macro segura `/target <unidad>` + `/cast [@<unidad>] <Hechizo>` (la venda, `/use [@<unidad>] item:<id>`). Los atributos `alfa-cmd-<ranura>` y `alfa-arg-<ranura>` guardan la orden y el hechizo; el fragmento seguro `REFRESCO` rehace la macro con la unidad nueva, también en combate. Nada se cambia en combate: `N.FueraDeCombate`.
- **Tus clics** va primero en la página: «Curar y seleccionar» y una lista por cada clic principal (izquierdo, derecho, central, Mayús y Ctrl) con tus hechizos por tipo (`M.HechizosPorCategoria`: curas, quitar perjuicios, buffs, revivir, otros), la venda, seleccionar y el menú. El asistente lo ofrece en el paso 1. Quien no cura tiene la venda en su preajuste.
- **Perjuicios**: el ícono del tipo arriba a la derecha (`M.TIPOS`, `dispelName` de `C_UnitAuras.GetAuraDataByAuraInstanceID`; si llega secreto, el ícono del aura sin leerlo) y el borde con su color. El cuadro del ratón dice qué clic lo quita (`M.RanuraQueQuita`). Si tu clase lo quita pero ningún clic lo hace: aviso en tu chat una vez por tipo y sesión, y en la tarjeta de arriba (`M.QuitarSinClic`).
- **Buff que falta**: punto azul abajo a la derecha (`M.BUFF_CLASE`: Entereza, Marca, Intelecto, Bendiciones, con sus versiones de grupo), revisado fuera de combate con `C_UnitAuras.GetAuraDataBySpellName`.
- **Tanque en apuros**: el borde rojo late bajo el 40 % (curva de color con `UnitHealthPercent`; sin curva, solo con vida legible). Tanque: rol asignado, tanque principal (`GetPartyAssignment`) o, sin roles en grupo, el único guerrero.
- **Alcance**: sin `UnitInRange`, `CheckInteractDistance(u, 4)` fuera de combate.
- **Maná de los curanderos** (`Mana.lua`): arriba de los marcos, solo con otro curandero; fuera de combate con color, en combate con `UnitPowerPercent` y una curva; «Maná tras la pelea» 12 s al terminar cada pelea. Reloj `curacion.mana`.
- **Banda por grupos**: 8 cabeceras `AlfaCuracionBanda1..8` (`groupFilter`, solo banda); la de siempre se oculta en banda con `RegisterStateDriver(..., "visibility", "[group:raid] hide; show")`. Solo con el orden por grupo.
- Ajustes nuevos: `tipoPerjuicio`, `buffs`, `tanque`, `mana`, `porGrupos` (todos sí). Prueba: `tools/banco/prueba_130_curacion.lua`.

## 1.3.1: arreglos

- **La venda sin «Curar y seleccionar»**: apagado, la venda va como `type` = `"item"` e `item` = `"item:<id>"` (el juego la usa sobre la unidad del botón) y no te cambia el objetivo. Prendido sigue siendo la macro `/target` + `/use [@<unidad>]`.
- **Maná de los curanderos**: el porcentaje secreto de `UnitPowerPercent` ya no se compara con nil (daba error en combate dentro de mazmorras y, a los 5, el reloj `curacion.mana` se quitaba). Quiénes curan (nombre, color, si eres tú) se arma solo cuando cambia el grupo (`GROUP_ROSTER_UPDATE`, `PLAYER_ROLES_ASSIGNED`, `UNIT_NAME_UPDATE`, al entrar; `M.Mana.Sucia()`); el reloj de cada segundo solo repinta los porcentajes, sin tablas nuevas.
- **Más ligero**: `M.Conocido` recuerda lo que conoces (clave -> id o `false`) y se vacía en `SPELLS_CHANGED`, `LEARNED_SPELL_IN_SKILL_LINE`, `PLAYER_LEVEL_UP` y `PLAYER_ENTERING_WORLD` (`M.OlvidarConocidos`). La página calcula tus hechizos por tipo una vez por repintado: las 7 filas de «Tus clics» comparten la lista. Prueba: `tools/banco/prueba_131_combate.lua`.

## 1.3.2

- **Sin grupo:** si no estás en grupo ni tienes «Verte a ti estando solo», la tarjeta de arriba dice «Tus marcos aparecen al entrar a un grupo» y ofrece «Ver cómo se ven» (`M.Prueba(5)`).
- **El asa** (mover y modo prueba) está hecha con el Kit (`K.Caja`, `K.Texto`, `K.Boton`) y crece con su texto (`M.TextoAsa`): nada se corta en alemán ni en ruso.
- **Relojes:** `curacion.alcance` solo corre con marcos a la vista (en grupo, o solo con «Verte a ti estando solo») y `curacion.mana` solo en grupo; si no, se quitan con `N.Quitar` (`M.RelojAlcance`, `M.Mana.Reloj`, al entrar, al cambiar el grupo y tus ajustes).
- Prueba: `tools/banco/prueba_132_personaje.lua`.

