# Alfa - Curación

Página **Curación** de la ventana de Alfa (orden 16, ícono `plus`). Marcos de grupo y banda para curar con un clic, de la forma más sencilla: cualquier curandero (Sacerdote, Druida, Paladín, Chamán) lo usa sin configurar nada, y las demás clases lo usan para buffs y para seleccionar.

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

1. Solo: `/alfa curacion prueba` muestra 5 marcos de ejemplo; arrastrarlos, cambiar ancho, alto y columnas, y pulsar Listo. Con 20, que las columnas se acomoden.
2. En grupo: aparecen tú y tu grupo; la vida baja y sube en combate y en una mazmorra sin errores de valores secretos (BugSack limpio).
3. Clic izquierdo, derecho, central y con Mayús, Ctrl y Alt lanzan lo que dice la cuadrícula. "Seleccionar objetivo" en una ranura con tecla (va como macro `/target <unidad>`) y el menú en el derecho.
4. Cambiar el grupo en combate (alguien entra o sale): los marcos se reordenan y los clics siguen funcionando.
5. Fuera de alcance se atenúa; el borde de perjuicio sale con el color correcto solo para lo que tú puedes quitar; la línea de amenaza sale cuando un enemigo ataca a ese compañero.
6. Curas entrantes: la franja verde aparece pegada al final de la vida mientras otro curandero lanza.
7. Aprender un hechizo en el instructor (por ejemplo Curación relámpago a nivel 20): sale el aviso; "Ahora no" no lo vuelve a ofrecer.
8. "Usar también en los marcos de Blizzard": confirmar si `SetProfileByInfo` funciona desde un addon y si los bits de Mayús, Ctrl y Alt (sacados de `GetStringFromModifiers`) son los buenos; si no, que abra la ventana oficial. Probar los clics en los marcos de Blizzard.
9. Ocultar los de Blizzard: el marco de grupo y el de banda de Blizzard desaparecen y vuelven al apagar la opción; entrar al Modo edición no da errores.
10. Rol: que el ícono salga en grupos con roles asignados.
