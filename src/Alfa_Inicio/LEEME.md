# Alfa - Inicio

La página **Hoy**, la portada de Alfa (sección *Hoy*, clave `inicio`, orden 5, ícono de la casa). Es lo primero que ves al abrir Alfa: cuál es tu siguiente paso, qué es urgente y qué le toca a tu clase, con el diseño nuevo (paleta grafito, acento verde, color de tu clase como segundo acento, esquinas cortadas).

## Qué muestra, de arriba abajo

1. **Tu siguiente paso:** una tarjeta grande con el borde verde a la izquierda. El paso de la guía con hasta tres metas (las mismas palabras que la ventana de guía), la distancia y el rumbo hasta la flecha («120 m al noreste · Hacia: Alguacil McBride»; «Ya llegaste»; «Lejos de aquí: Tanaris»; dentro de una instancia o en vuelo lo dice), «Paso N de M», la guía con su avance y tres botones:
   - **Seguir ruta** (el de acento): muestra la ventana de guía y enciende la flecha, y cierra la ventana de Alfa para que las veas.
   - **Ver pasos:** abre la lista de pasos en la ventana de guía.
   - **Cambiar guía:** el selector de guías.
   Sin guía, al terminarla o si la guía no tiene paso aún, un solo botón: *Elegir una guía*, *Elegir la siguiente guía* o *Abrir la guía*.
2. **Alertas:** solo lo urgente, del más grave al menos, con su botón donde hay a dónde ir: equipo gastado (la pieza y cuántas más; *Llévame a reparar*), bolsas casi llenas o llenas (*Llévame a un vendedor*), habilidades por entrenar con su costo (*Llévame con mi entrenador*) y el descanso (estás descansando, o te queda poca XP descansada). Si no hay nada: *Todo en orden*. Usa los mismos umbrales que los recordatorios.
3. **Para tu <clase>:** la tarjeta con la franja del color de tu clase, tu rama y tu rol en una etiqueta («Armas · Daño», «Sagrado · Sanador») y tres mini tarjetas. Cada una abre su módulo con un clic (la flecha de la esquina dice que se puede). Solo datos tuyos que el juego deja leer; nada decide en combate.
4. **La fila de números:** XP por hora (el ritmo de los últimos 15 minutos del motor), tiempo para subir, oro de hoy (las sesiones de hoy de este personaje más la de ahora; ganado y gastado en la ayuda) y **lobos conectados** (los de tu hermandad en línea, sin contarte; un clic abre La Jauría).
5. **Plegables, más compactos** (se recuerda cuáles abriste):
   - **Diario** (abierto): tu sesión de ahora en una línea, la gráfica de las últimas sesiones (XP, XP/h, Oro o Tiempo; la de ahora es la última barra) y las cuatro más recientes.
   - **Revisión rápida** (cerrada): equipo, bolsas, entrenador, tu buff y tu descanso, con sus botones.
   - **Accesos rápidos** (abiertos): un mosaico por cada módulo de Alfa instalado, tres por fila; lo que hace cada uno va en su ayuda.
   - **Recordatorios** (cerrada): los ajustes de los avisos.

### Las mini tarjetas de cada clase

El rol sale de tu rama en el motor (`Alfa.Gear.GetSpec`: la columna de talentos con más puntos, o la que elegiste); sin ella, de `C_SpecializationInfo`. Curan: sacerdote disciplina y sagrado, paladín sagrado, chamán y druida restauración (si el módulo Curación está instalado).

| Clase | Tarjetas | Abren |
|---|---|---|
| Guerrero | Grito de batalla (activo y cuánto le queda; «con 10 de furia o más lo lanzas»), Talentos (puntos por gastar o al día, tu rama), Mejoras de equipo (cuántas hay en tus bolsas y la primera) | Builds, Builds, Bolsas |
| Paladín | Aura, Sello, Bendición (la que llevas y cuánto le queda) | Builds |
| Paladín sanador | Curación (marcos encendidos o apagados), Maná, Aura | Curación, Curación, Builds |
| Cazador | Munición (cuánta, su nombre; «no la usas» si tu arma no usa), Tu mascota (feliz, contenta o descontenta; nombre y familia), Aspecto | Bolsas, Builds, Builds |
| Pícaro | Venenos (desde el nivel 20: en cuántas armas y cuánto les queda), Talentos, Mejoras de equipo | Builds, Builds, Bolsas |
| Sacerdote | Entereza, Fuego interno, Maná | Builds |
| Sacerdote sanador | Curación, Maná, Entereza | Curación, Curación, Builds |
| Chamán | Tótems (cuántos puestos y cuáles), Escudo de relámpagos (con sus cargas), Maná; el de mejora ve su Arma encantada en lugar del maná | Builds |
| Chamán sanador | Curación, Maná, Tótems | Curación, Curación, Builds |
| Mago | Agua y comida conjuradas que llevas, Intelecto Arcano, Armadura (Escarcha, Hielo o Mago) | Bolsas, Builds, Builds |
| Brujo | Fragmentos de alma, Tu demonio (su familia y nombre), Piel o armadura demoníaca | Bolsas, Builds, Builds |
| Druida | Forma (la que llevas o «forma normal»), Marca de lo Salvaje, Maná | Builds |
| Druida sanador | Curación, Maná, Marca de lo Salvaje | Curación, Curación, Builds |

Si un módulo no está instalado, su tarjeta se ve igual pero no abre nada (Mejoras, Munición, Agua y comida y Fragmentos caen en Builds o en nada).

## Recordatorios

Avisos en pantalla con el estilo de Alfa (se arrastran para moverlos), sin cambios:

- Durabilidad baja, al 30 % y al 10 % (este con sonido), diciendo qué pieza es.
- Bolsas casi llenas o llenas.
- Habilidades por aprender al llegar a una ciudad o posada (una vez por nivel). La tarjeta de habilidades al subir de nivel y la nota de entrenar de la guía son del motor; Inicio no las repite, solo pasa la nota a un aviso si la ventana de la guía está oculta.
- Buff propio fuera de combate: Grito de batalla (guerrero, solo con 10 de furia o más), Intelecto Arcano y una armadura (mago), Entereza y Fuego interno (sacerdote), Marca de lo Salvaje (druida), Piel o Armadura demoníaca (brujo), un aura y una bendición (paladín), un aspecto (cazador), Escudo de relámpagos (chamán). El pícaro no tiene.
- XP descansada: al entrar a una zona de descanso y cuando baja del umbral o se acaba.
- Al entrar al juego, un resumen de la sesión anterior.

## Comandos

- `/alfa inicio`: abre la portada.
- `/alfa sesion`: tu sesión de ahora en el chat.

## Ajustes (en la propia página, bloque *Recordatorios*)

| Ajuste | Por omisión |
|---|---|
| Avisos de durabilidad, primer aviso y aviso urgente | sí, 30 %, 10 % |
| Aviso de bolsas, con estos espacios libres o menos | sí, 4 |
| Habilidades por aprender en la ciudad, desde cuántas | sí, 1 |
| Buff fuera de combate, repetir a lo más cada, y avisar si le queda menos de | sí, 3 min, solo si falta |
| XP descansada, avisar cuando baje de | sí, 5 % de nivel |
| Resumen de la sesión anterior al entrar | en un aviso y en el chat |
| Duración de un aviso, sonido en los urgentes, sesiones del diario | 10 s, sí, 30 |

Además, en *Habilidades por entrenar* están los dos ajustes del motor que van con ese recordatorio (la tarjeta al subir de nivel y la nota de la guía). Los bloques plegables guardan si están abiertos en `inicio.abrirDiario`, `abrirRevision`, `abrirAccesos` y `abrirAjustes`. Todo se guarda en `AlfaDB.settings.inicio`; el diario, por personaje, en `AlfaNucleoCharDB.inicio`.

## Archivos

- `Textos.lua`: el inglés de cada texto (`M.EN`).
- `Avisos.lua`: los avisos en pantalla.
- `Sesion.lua`: la sesión de ahora y el diario.
- `Recordatorios.lua`: los recordatorios y lo que lee la página (`M.Rec`, con `M.Rec.Grupo` para el estado de un buff).
- `Clase.lua`: la tarjeta «Para tu <clase>»: el rol y las mini tarjetas (`M.Clase`).
- `Inicio.lua`: la página.

## API que usa (Forever 1.60.1)

Verificadas en `Blizzard_APIDocumentationGenerated`: `C_UnitAuras.GetPlayerAuraBySpellID` y `GetAuraDataBySpellName`, `C_Spell.GetSpellName`, `UnitPower`/`UnitPowerMax`, `UnitExists`, `UnitName`, `UnitCreatureFamily`, `UnitUsesAmmo`, `IsInGuild`, `C_PetInfo.GetPetHappiness`, `GetTotemInfo`, `C_Item.GetItemCount`, `GetItemNameByID` y `GetWeaponEnchantInfo`, `C_ClassTalents.HasUnspentTalentPoints`, `C_SpecializationInfo.GetSpecialization`/`GetSpecializationInfo`, `C_Container.GetContainerNumSlots`/`GetContainerItemLink`, `C_GuildInfo.GuildRoster` y los eventos `PLAYER_TALENT_UPDATE` y `TRAIT_CONFIG_UPDATED`. Globales clásicas que no están en la documentación (todas con `pcall`): `GetInventoryItemID` e `INVSLOT_AMMO` (las usa el FrameXML de Forever), `PET_HAPPINESS1..3` (PetHappiness.lua), `GetNumGuildMembers` y `GetGuildInfo` (las usa La Jauría), y `GetWeaponEnchantInfo()` solo como respaldo. Del motor: `Engine`, `UI.GoalText`/`StepSummary`/`StepList`, `Nav.GetTarget`/`TargetOffset`/`GetTargetZoneName`, `FormatDistance`, `Gear.GetSpec`/`IsUpgrade`/`FillsEmptySlot`, `Compat` y `QoL`.

## Para verificar en el juego

1. `/alfa`: abre en **Hoy** y la página se ve completa, sin huecos ni textos encimados, en los esquemas Grafito, Noche y Pizarra, y también con otra apariencia (las franjas van de arriba abajo).
2. **Tu siguiente paso** con una guía abierta: el título del paso y sus metas son los de la ventana de guía; «Paso N de M» y el avance coinciden. Caminar: la distancia baja cada segundo y el rumbo (norte, noreste...) es el correcto según el mapa. Llegar al punto: «Ya llegaste». En otro continente, en vuelo y en una mazmorra dice lo suyo. Revisar que la distancia salga en yardas o metros según *Unidad de distancia*.
3. **Seguir ruta** con la ventana de guía oculta y la flecha apagada: aparecen las dos y la ventana de Alfa se cierra. **Ver pasos**: la ventana de guía abre en su lista de pasos. **Cambiar guía**: el selector. Sin guía, y al terminar una, el botón único hace lo que dice.
4. **Alertas:** con el equipo gastado (morir unas veces), las bolsas casi llenas, habilidades por entrenar y en una posada; cada botón lleva la flecha a donde dice. Sin nada pendiente: *Todo en orden*. Una alerta nueva aparece sola, sin reabrir la página.
5. **Para tu <clase>** con cada una de las 9 clases (y con un sacerdote, paladín, chamán y druida sanadores): el título dice tu clase en minúscula («Para tu guerrero», «Para tu sacerdotisa»), la etiqueta tu rama en español y tu rol, y la franja tiene el color de tu clase. Cada tarjeta muestra lo de la tabla y abre su módulo. Verificar en especial:
   - Guerrero: Grito de batalla activo y su tiempo; sin furia, «Con 10 de furia o más lo lanzas». Talentos con puntos libres dice «Puntos por gastar» (`C_ClassTalents.HasUnspentTalentPoints` en Forever).
   - Cazador: la munición cuenta lo que llevas (`GetInventoryItemID("player", 0)` + `C_Item.GetItemCount`) y `UnitUsesAmmo`; la felicidad de la mascota cambia al darle de comer (`C_PetInfo.GetPetHappiness`, 1 a 3).
   - Pícaro desde el nivel 20: con veneno en una o dos armas, y el tiempo en minutos (`C_Item.GetWeaponEnchantInfo`: confirmar que devuelve la lista de encantamientos de esa mano y si `timeLeft` viene en segundos o milisegundos).
   - Chamán: los tótems puestos y sus nombres (`GetTotemInfo` 1 a 4); el escudo con sus cargas; el de mejora, su arma encantada.
   - Paladín: el aura y la bendición que llevas por su nombre; el sello solo al pelear.
   - Druida: la forma que llevas (oso, felino, viaje, acuática, lechúcico) leída como aura.
   - Mago: agua y comida conjuradas (ids de los rangos 1 a 7). Brujo: fragmentos de alma (6265) y la familia del demonio.
   - En combate nada da error y nada cambia de forma rara (los valores secretos se leen como «no se sabe»).
6. **Números:** XP por hora y tiempo para subir cambian al matar; oro de hoy suma tus sesiones de hoy; lobos conectados coincide con la lista de tu hermandad menos tú (y en La Jauría dice «Lobos conectados»); un clic abre La Jauría.
7. **Plegables:** abrir y cerrar cada bloque; tras `/reload` se quedan como los dejaste. La gráfica cambia entre XP, XP/h, Oro y Tiempo y muestra el detalle al pasar el cursor.
8. `/reload`: la sesión sigue (no vuelve a cero). Salir y volver a entrar: sale el resumen de la sesión anterior y aparece en el diario.
9. Probar un aviso desde los ajustes, moverlo y devolverlo a su lugar.
10. Cambiar de talentos (o elegir otra rama en Ajustes > Equipo): la etiqueta y las tarjetas de la clase cambian solas.
