# Alfa - Combate

Ayudas de combate que **solo muestran**: nada aquí aprieta, lanza, elige objetivo ni decide por ti. Todo es código propio (toxic3000 / La Jauría).

## Qué hace

- **Ayuda de rotación** (`combate.rotacion`, encendida): un ícono movible con la habilidad que conviene ahora, en grande, y las 2 que siguen (hasta 3, `combate.despues`), más chicas a la derecha.
  - **Barrido de recarga** (`combate.barrido`): un barrido oscuro y suave sobre cada ícono mientras su recarga corre (en el grande, también la global).
  - **Borde que late** cuando el juego hace brillar esa habilidad (un proc: Abrumar, Revancha, Claridad...).
  - **El porqué** (`combate.porque`): una línea corta debajo, como «Golpe mortal: recarga lista». Ver "Explicaciones con tope".
  - **Insignia «Área»** cuando hay 3 o más enemigos peleando a la vista.
  - La tecla de tu barra sobre el ícono (`combate.tecla`), el nombre debajo si lo pides (`combate.nombre`) y el botón de tu barra resaltado (`combate.resaltar`).
  - **La primera vez** (por personaje, fuera de combate) un aviso explica cómo leer el ícono. Sale una sola vez.
- **Avisos de reacción** (`combate.avisos`): Abrumar, Revancha, Ejecutar, Contraataque... cuando se vuelven usables.
- **Barra de golpe** (`combate.golpe`), sin números por omisión (`combate.golpeNumero`).
- **Marca de misión** en las placas de nombre (`combate.marcaMision`, `combate.marcaMisionBrillo`).
- **Medidor de daño** con `C_DamageMeter` y el panel de estadísticas.
- **Aviso para cortar** (1.3.0, `Corte.lua`, `combate.corte`, `corteFoco`, `corteSonido`): tu objetivo o tu foco lanza algo que se puede cortar (`UnitCastingInfo`/`UnitChannelInfo`, `notInterruptible`; los oficios no) → tu corte de clase (`Co.HABILIDADES`; el que puedes usar ya y, si no, aquel al que solo le falta recurso: 1.3.1, en actitud defensiva con poca ira sale Golpe con escudo, no Patada), su tecla de tu barra (`R.Tecla`) y si está listo o cuánto le falta, con el barrido de su recarga (1.3.1: antes no salía). Con datos secretos no se compara ni se prueba con `or` (1.3.1): la textura secreta va tal cual a `SetTexture`, título «¡Está lanzando!» y `SetAlphaFromBoolean(notInterruptible, 0, 1)` si existe. `/alfa combate corte` lo prueba. 1.3.2: tu corte (habilidad, nombre, ícono y tecla) se elige al empezar el lanzamiento o al cambiar de objetivo (`Co.Elegido`, `Co.Revisar(true)`), y se olvida con tus barras (`R.OlvidarBarras` → `Co.Olvidar`); cada vuelta del reloj pide la recarga una sola vez. Yendo solo en el mundo no suena: solo en grupo o en una instancia (`M.EnGrupo`), salvo `corteSonidoSolo`.
- **Barra de amenaza** (1.3.0, `Amenaza.lua`, `combate.amenaza`, `amenazaPapel`, `amenazaAviso`, `amenazaSonido`): en combate, en grupo o con mascota. `UnitDetailedThreatSituation("player", "target")`; no tanque: amarilla desde `amenazaAviso` %, roja si ya te ataca; tanque: aviso con status 2, peligro con 0-1. Papel automático: rol del grupo, actitud defensiva (forma 18), oso (5/8) o Furia justa. Contra un jefe los valores llegan secretos: la barra los muestra tal cual (1.3.1: sin `or`, que daba error) y no avisa.
- **Tecla grande** (1.3.0): `combate.tam` hasta 96 (de fábrica 52), `tamDespues` (proporción de las que siguen) y `teclaGrande` (abajo al centro, letra `numero`/`subtitulo`/`cifra` según el tamaño; también en las que siguen).
- **Resumen de la pelea** (1.3.0, `Resumen.lua`, `combate.resumen`, `resumenMin`): al salir de combate, con `C_DamageMeter` (solo tu fila: daño, curación, por segundo; `DamageTaken` con tu GUID para lo que más te pegó). El registro de combate (`COMBAT_LOG_EVENT*`) es restringido en Forever: no se usa. La última queda en `AlfaNucleoCharDB.combate.ultimaPelea`; `/alfa combate pelea` la muestra otra vez. 1.3.2: yendo solo en el mundo, solo las peleas de `resumenMinSolo` s o más (30 de fábrica); en grupo o instancia, `resumenMin`.
- **Recargas largas** (1.3.0, `Recargas.lua`, `combate.recargas`, `recargasMin`): lo que lanzas (`UNIT_SPELLCAST_SUCCEEDED`) con recarga de 30 s o más entra a una barra discreta; con tiempos secretos se estima con la duración vista (`combate.recargas`). Las conocidas en `combate.largas`; las que ocultas en la página, en `combate.recargasOcultas` (por nombre).

## De dónde sale la sugerencia

Forever trae apagada la ayuda de combate de Blizzard (`C_AssistedCombat`), así que Alfa sugiere con **su propia prioridad** (`Prioridad.lua` + `Prioridades.lua`). Si algún día el cliente la ofrece, se usa la de Blizzard salvo que pidas la de Alfa (`combate.prioridadAlfa`).

La prioridad de Alfa lee solo datos de tu personaje:

| Qué | Cómo |
|---|---|
| Qué sabes | Cada habilidad se busca por su nombre: vale el **rango más alto que conozcas**; lo que no aprendiste no entra (la lista crece contigo). Las entradas con `minNivel`/`maxNivel` se filtran por tu nivel |
| Si se puede usar | `C_Spell.IsSpellUsable` (actitud, forma, recurso, Ejecutar bajo el 20 %, Abrumar tras una esquiva...) y `C_Spell.IsSpellInRange` |
| Recurso | Ira, energía o maná (`UnitPower`, `UnitPowerType` para las formas del druida), maná en %, puntos de combo. No hay runas ni poder rúnico en Forever |
| Recargas | `C_Spell.GetSpellCooldown`. Si los tiempos llegan **secretos**, `isActive` e `isOnGCD` (nunca secretos) dicen si está en recarga, y lo que falta se estima con tu último lanzamiento y la duración que Alfa vio cuando sí se podía leer (`AlfaNucleoCharDB.combate.recargas`). Sin datos, se toma como recarga larga |
| Procs | `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE` y `C_SpellActivationOverlay.IsSpellOverlayed`: lo que brilla pasa al frente. Tus efectos (Claridad, Trance de las Sombras...) con `C_UnitAuras.GetAuraDataBySpellName("player", ...)` |
| Efectos en el enemigo | Tu efecto en el objetivo (`HARMFUL|PLAYER`) si se puede leer; si no, lo que lanzaste a ese objetivo (`UNIT_SPELLCAST_SUCCEEDED` del jugador) y cuánto dura |
| Uno o varios | Las placas de nombre de enemigos que pelean (`C_NamePlate.GetNamePlates`): con 2 entran las de dos objetivos (Mellar, Barrido, Multidisparo...), con 3 las de área |
| Remate | `remate` deja decidir al juego (Ejecutar, Martillo de cólera). `bajoVida` usa la vida del enemigo **si se puede leer**; si es secreta, esa entrada no sale |
| Cortar | `UnitCastingInfo` / `UnitChannelInfo` del objetivo; si es secreto, no se sugiere cortar |
| Tu vida, tu mascota | Para curarte o llamar/curar a tu mascota mientras subes |

Orden: primero lo que **brilla**, luego lo que está **listo** (en el orden de la lista), luego lo que **espera recurso** (sin color) y al final lo que **sale de recarga** (por lo que falta).

### La especialización

`combate.rama` (`auto` por omisión, o la clave de una rama): la que elijas; si no, la de tus talentos (el motor cuenta tus puntos: `Alfa.Gear.GetSpec`); si no, la primera cuya firma conoces; si no, la de tu clase al subir de nivel.

### Las prioridades (de arriba abajo)

Solo salen las que conoces y cuya situación se cumple. Entre paréntesis, la condición principal.

**Guerrero**
- *Armas*: Grito de batalla (te falta) · Cargar · Patada (cortar) · Ataque de la victoria · Ejecutar · Abrumar · **Golpe mortal** · Barrido (2+) · Torbellino (2+) · Atronar (área) · Grito desmoralizador (2+) · Desgarrar (un enemigo, no en los que mueren) · Mellar (2+, ira 30+) · Embate (ira 25+) · Golpe heroico (ira 50+) · Ira sangrienta (ira ≤15).
- *Furia*: Grito · Cargar · Patada · Victoria · Ejecutar · **Sed de sangre** · Torbellino · Deseo de muerte (peleas largas) · Rabia de rabioso (ira ≤20) · Abrumar · Mellar · Golpe heroico (ira 45+) · Ira sangrienta.
- *Protección*: Grito · Cargar · Golpe de escudo y Patada (cortar) · Victoria · Bloqueo con escudo · **Revancha** · **Embate con escudo** · Desmoralizador (2+) · Atronar (2+) · Hender armadura (5 cargas) · Mellar · Ejecutar · Golpe heroico (ira 40+) · Ira sangrienta.

**Pícaro**
- *Asesinato*: Emboscada / Golpe bajo (en sigilo) · Patada (cortar) · Contraataque · Sangre fría (5 puntos) · Hacer picadillo (te falta) · Romper (en grupo, 4+) · Eviscerar (5 puntos; 3 hasta el nivel 19) · Puñalada (en grupo) · Golpe siniestro.
- *Combate*: Golpe bajo (sigilo) · Patada · Contraataque · Aluvión de acero (2+) · Subidón de adrenalina · Hacer picadillo · Eviscerar · Golpe siniestro.
- *Sutileza*: Premeditación / Emboscada / Golpe bajo (sigilo) · Patada · Contraataque · Hacer picadillo · Eviscerar · Golpe fantasmal · Hemorragia · Puñalada (en grupo) · Golpe siniestro.

**Mago**
- *Arcano*: Intelecto Arcano · tu armadura (Mago > Hielo > Escarcha) · Contrahechizo (cortar) · Evocación (maná ≤15 %) · Poder arcano (maná 40 %+) · Presencia mental · Misiles arcanos (con Claridad) · Deflagración arcana (área) · Explosión de fuego · Varita (maná ≤20 %) · Misiles arcanos (maná 50 %+) · Descarga de Escarcha · Bola de Fuego.
- *Fuego*: lo mismo de arriba hasta Evocación · Piroexplosión (antes de pelear) · Combustión · Ola explosiva (2+) · Fogonazo (área) · Varita · Explosión de fuego · Bola de Fuego · Descarga de Escarcha.
- *Escarcha*: igual · Barrera de hielo · Cono de frío (2+) · Ventisca (área) · Explosión de fuego (enemigo ≤15 %) · Varita · Descarga de Escarcha · Explosión de fuego · Bola de Fuego.

**Brujo**
- *Aflicción*: Armadura demoníaca / Piel de demonio · demonio (abisario, diablillo; fuera de combate) · Descarga de las Sombras (con Trance) · Drenar alma (enemigo ≤25 %) · Corrupción · Maldición de agonía · Succionar vida · Inmolar · Drenar vida (tu vida ≤50 %) · Transfusión de vida (maná ≤25 %, vida 50 %+) · Lluvia de fuego (área) · Varita · Descarga de las Sombras.
- *Demonología*: armadura · Dominación vil (sin demonio, en combate) · demonio · Trance · Drenar alma · Corrupción · Agonía · Inmolar · Drenar vida · Transfusión · Lluvia de fuego · Varita · Descarga de las Sombras.
- *Destrucción*: armadura · diablillo / abisario · Trance · Quemadura de las Sombras (enemigo ≤20 %) · Drenar alma · Inmolar · Conflagrar (con Inmolar puesto) · Corrupción · Agonía · Transfusión · Lluvia de fuego · Varita · Descarga de las Sombras.

**Sacerdote**
- *Disciplina*: Entereza · Fuego interior · Escudo (tu vida ≤80 %, sin Alma debilitada) · Sanación relámpago / Sanación inferior (≤35 %) · Renovar (≤60 %) · Enfoque interno · Fuego sagrado · Palabra de las Sombras: dolor · Explosión mental · Plaga devoradora · Varita (maná ≤25 %) · Castigo.
- *Sagrado*: igual, con Nova sagrada (área) en lugar de Enfoque interno.
- *Sombra*: Entereza · Fuego interior · Forma de las Sombras · Escudo · curas · Abrazo vampírico · Dolor · Explosión mental · Plaga devoradora · Varita · Tortura mental · Castigo.

**Cazador**
- *Bestias*: aspecto (Halcón > Mono; ninguno puesto) · Llamar / Revivir mascota · Aliviar mascota (≤40 %) · Marca del cazador · Cólera de las bestias · Intimidación · Fuego rápido · Multidisparo (2+) · Picadura de serpiente · Disparo arcano · Mordedura de mangosta · Golpe de raptor.
- *Puntería*: aspecto · Aura de disparo certero · mascota · Marca · Fuego rápido · **Disparo apuntado** · Multidisparo · Serpiente · Arcano · Mangosta · Raptor.
- *Supervivencia*: aspecto · mascota · Marca · Contraataque · Mangosta · Raptor · Multidisparo · Serpiente · Arcano · Fuego rápido.

**Paladín**
- *Sagrado*: bendición (Sabiduría > Poderío; ninguna puesta) · sello (Rectitud; ninguno puesto) · Martillo de justicia (cortar) · Imposición de manos (≤15 %) · Destello de Luz / Luz sagrada (≤40 %) · Martillo de cólera · Choque sagrado · Sentencia (con sello) · Exorcismo (no-muertos y demonios) · Consagración (área).
- *Protección*: Furia justa (en grupo) · bendición (Santuario > Poderío) · sello · Martillo de justicia · Imposición · Escudo sagrado · Consagración (2+) · Sentencia · Martillo de cólera · Exorcismo · curas.
- *Reprensión*: Poderío · sello (Mando > Rectitud) · Martillo de justicia · Imposición · Martillo de cólera · Sentencia · Exorcismo · Consagración · curas.

**Chamán**
- *Elemental*: Escudo de relámpagos · arma (Lengua de fuego > Muerdepiedras) · Choque de tierra (cortar) · Ola de sanación inferior / Ola de sanación (≤40 %) · Maestría elemental · Choque de llamas (un enemigo) · Cadena de relámpagos (2+) · Tótem abrasador · Tótem de magma (área) · Choque de tierra · Descarga de relámpagos.
- *Mejora*: Escudo · arma (Viento furioso > Lengua de fuego > Muerdepiedras) · cortar · curas · Descarga de relámpagos (para abrir) · tótem de Fuerza de la tierra · **Ataque de tormenta** · Choque de llamas · Choque de tierra · Tótem abrasador · Tótem de magma.
- *Restauración*: como Elemental, sin Maestría elemental.

**Druida**
- *Equilibrio*: Marca de lo Salvaje · Espinas · forma de lechúcico lunar · Rejuvenecimiento (≤65 %) · Recrecimiento / Toque de sanación (≤45 %) · Estimular (maná ≤20 %) · Fuego feérico · Fuego estelar (con Claridad) · Fuego lunar · Enjambre de insectos · Huracán (área) · Fuego estelar · Cólera.
- *Feral*: Marca · Espinas · curas · **felino**: Fuego feérico (feral) · Destripar (5 puntos, en grupo) · Mordedura feroz (5 puntos) · Arañazo · Triturar (en grupo) · Garra · **oso**: Azote (cortar) · Enfurecer (ira ≤10) · Rugido desmoralizador (2+) · Vapulear (2+) · Mazazo (ira 15+) · **sin forma**: Fuego lunar · Cólera. El juego solo deja usar cada una en su forma.
- *Restauración*: Marca · Espinas · curas · Estimular · Fuego estelar (con Claridad) · Fuego lunar · Enjambre · Huracán · Fuego estelar · Cólera.

Los sanadores (Paladín sagrado, Sacerdote disciplina y sagrado, Chamán y Druida restauración) tienen la prioridad **para pelear mientras subes**: daño y curarte a ti. Alfa no elige a quién curar en grupo.

## Explicaciones con tope

Para que no se llene la pantalla de texto al lanzar habilidades:

- Cada texto explicativo (el porqué de la rotación, cada aviso de reacción con su título y su porqué) sale **a lo sumo 4 veces por personaje** (`M.LIMITE_TEXTO`); después se calla y queda solo el ícono (el aviso de reacción pasa a ser un ícono que aparece y se va, sin texto).
- **Uno a la vez** en pantalla y **nunca el mismo dos veces en 30 s** (`M.PAUSA_TEXTO`).
- Cada uno tiene su **×** («No volver a mostrar»); la línea del porqué también se calla con **clic derecho**. El resto del aviso no toma el ratón para no tapar clics en el mundo.
- En *Combate > Avisos, golpe y estadísticas > Explicaciones*, **Volver a mostrarlas** las enciende todas otra vez.
- Se guarda por personaje en `AlfaNucleoCharDB.combate.textos = { vistas = { [clave] = n }, callados = { [clave] = true } }`. El aviso de bienvenida de la rotación, en `presentado`.
- La barra de golpe ya no muestra sus segundos salvo que los pidas (`combate.golpeNumero`).

## Marca de misión (placas de nombre)

`combate.marcaMision` (encendida) y `combate.marcaMisionBrillo` (encendido): quien te falta para una misión de tu registro lleva un ícono de misión de Alfa junto a su barra y un brillo dorado suave que late alrededor.

- Cómo se sabe: las líneas de objetivo de misión de `C_TooltipInfo.GetUnit` que aún no están completas y son tuyas (las de otro del grupo, que van tras su nombre, no cuentan); los datos de misiones del motor (`Alfa.QuestDB.ObjectivesForNpc` por el id del PNJ); y `UnitIsQuestBoss`.
- Se repasa al aparecer una placa (`NAME_PLATE_UNIT_ADDED/REMOVED`), al cambiar tu registro (`QUEST_LOG_UPDATE`, `UNIT_QUEST_LOG_CHANGED`, `QUEST_ACCEPTED`, `QUEST_TURNED_IN`) y al salir de combate. Un cambio del ajuste (también desde el asistente de inicio) se aplica al momento.
- **En mazmorras y encuentros** esos datos llegan secretos: la placa queda sin marca, sin errores.
- El motor ya pone su calavera en las placas de lo que hay que matar (`qol.nameplateIcons`): si está a la vista, Alfa no repite el ícono y solo agrega el brillo.
- **Objetos del mundo** (cajas, plantas, minerales de misión): un addon **no puede** dibujarles un contorno ni un brillo. Se muestran con los marcadores del motor en el mapa y el minimapa (los objetivos de tu guía y de tus misiones) y con las líneas de misión en su cuadro al pasar el ratón.

## Ajustes (`combate.*`)

| Clave | Omisión | Qué |
|---|---|---|
| `rotacion` | `true` | La ayuda de rotación |
| `despues` | `2` | Cuántas después (0 a 3) |
| `porque` | `true` | La línea corta del porqué (con tope) |
| `barrido` | `true` | El barrido de recarga |
| `rama` | `"auto"` | Tu especialización para la prioridad |
| `prioridadAlfa` | `false` | Siempre la de Alfa, aunque el juego ofrezca la de Blizzard |
| `fuera`, `alfaFuera` | `true`, `0.45` | También fuera de combate, transparente |
| `tam`, `tecla`, `nombre`, `resaltar` | `52`, `true`, `false`, `true` | Tamaño, tecla, nombre, botón resaltado |
| `avisos`, `avisosSonido`, `avisosPorque`, `avisosOtros` | `true`, `true`, `true`, `false` | Avisos de reacción |
| `golpe`, `golpeNumero` | `true`, `false` | Barra de golpe y sus segundos |
| `marcaMision`, `marcaMisionBrillo` | `true`, `true` | Marca de misión en las placas |
| `tamDespues`, `teclaGrande` | `0.7`, `true` | Tamaño de las que siguen y la tecla grande (1.3.0) |
| `corte`, `corteFoco`, `corteSonido`, `corteSonidoSolo` | `true`, `true`, `true`, `false` | Aviso para cortar (el sonido yendo solo, 1.3.2) |
| `amenaza`, `amenazaPapel`, `amenazaAviso`, `amenazaSonido` | `true`, `"auto"`, `80`, `true` | Barra de amenaza |
| `resumen`, `resumenMin`, `resumenMinSolo` | `true`, `10`, `30` | Resumen de la pelea (el mínimo yendo solo, 1.3.2) |
| `recargas`, `recargasMin` | `true`, `30` | Recargas largas |

## Para verificar en el juego

1. Con un guerrero (o cualquier clase) en combate: el ícono grande cambia según tu recurso, el barrido corre sobre lo que está en recarga y Abrumar/Revancha laten al activarse. En una mazmorra, nada da error y las recargas se siguen viendo.
2. La línea del porqué sale pocas veces, una a la vez; su × y el clic derecho la callan; *Volver a mostrarlas* la enciende otra vez.
3. Un aviso de reacción, tras 4 veces, sale solo como ícono.
4. Con 3 o más enemigos peleando, entran las de área y la insignia «Área».
5. El druida en felino y en oso ve las de su forma.
6. Marca de misión: un enemigo de una misión de matar o de botín lleva el ícono y el brillo; al completar el objetivo se quita; en una mazmorra no sale nada y no hay errores. Comprobar que `C_TooltipInfo.GetUnit` traiga las líneas de objetivo en Forever y que el ícono no choque con la calavera del motor.
7. Apagar/encender `marcaMision`, `porque`, `barrido` y `rama` desde la página se aplica sin recargar.
8. 1.3.1: en una mazmorra, con tu objetivo lanzando, sale «¡Está lanzando!» sin errores (BugSack limpio); con tu corte en recarga, su ícono muestra el barrido. Contra un jefe, en grupo, la barra de amenaza no da errores.

## 1.3.2

- **A la vista:** «Probar el aviso», «Probar un aviso», «Ver de nuevo» y «Mover marcos» de la página cierran la ventana de Alfa (`N.CerrarVentana`: los marcos de combate salían debajo) y una línea en tu chat dice cómo volver. En combate «Mover marcos» no cierra nada (no se pueden mover).
- **Mismos nombres:** «Mover marcos» / «Fijar marcos», como en Curación; «Probar un aviso» solo en la tarjeta de los avisos.
- **Migración 4** (`M.Migracion132`, Combate.lua): quien ya había prendido a mano el sonido del corte sigue oyéndolo yendo solo, y quien había cambiado `resumenMin` usa el mismo mínimo yendo solo.
- Prueba: `tools/banco/prueba_132_personaje.lua`.
