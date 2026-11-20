# Diseño: guías con pasos diferidos (1.3.4, «la manada ligera»)

Estado: **aplicado** (20/11/2026). Lo que quedó, en corto:
- `tools/diferir.py` (lo llama `build.py`): `steps` → `stepCount` + `stepsSrc`, y en la ficha `qref` (q/p/c) y `groupQuests`. Hay 73 guías que arman tablas antes de registrarse (`local candidateRecords = ...`); ese **preámbulo** va también al principio de `stepsSrc`, y si la ficha no lo usa sale de `register()` (queda la marca `-- alfa: preambulo en stepsSrc`). `--revertir` devuelve el archivo idéntico, byte por byte.
- Parches (`tools/parches.py`, bloque 1.3.4): `Guides.QuestGuides(kind, q)` en `Core/Guides.lua`; `Closes.lua` y `Unlocks.lua` arman su índice por misión, al preguntar; `Own.sweep` no suelta pasos en combate (lo hace al salir).
- Pruebas: `tools/banco/prueba_134_guias.lua` (guías armadas al entrar, solo las candidatas al preguntar, `Closes.For`/`Unlocks.For` iguales a la 1.3.3 en 1875 misiones al cambiar su `guideIndex` por el viejo, `qref` sin huecos, combate) y en `tools/prueba.py` `guias_iguales()` (las 260 guías armadas por el motor, diferidas contra revertidas, con `volcar_guias.lua`) y `tope_entrada()` (lectura al entrar ≤ 120 ms y ≤ 8 guías armadas, con `tools/perfil.py`).
- Quedan como estaban, por ser raros o pequeños: `UI/ClassToast.lua` (arma las 5 o 6 guías de tu clase) y `Guides.FollowLog`. No se hizo el «dejar armada la siguiente guía»: abrirla cuesta unos milisegundos.

## El problema

Medido con `tools/perfil.py` (tiempos del banco, Lua 5.1 de lupa; sirven para comparar, no son los del juego). La línea base está en `docs/perfil-1.3.3.txt`.

| Al entrar (1.3.3) | Banco |
|---|---|
| `Alfa_Guides_Horde` (77 guías, 2,8 MB), con lo que trae | 147 ms |
| `Alfa_Guides` (96 guías de clase, mascotas y monturas, 2 MB; no es LoadOnDemand) | 48 ms |
| Todo el resto de archivos de Alfa | ~20 ms |
| Memoria Lua al final de la prueba | 65,8 MB |

Cada guía hace `register()` al cargarse: Lua compila y arma **todas** las tablas de **todos** los pasos de las 173 guías de tu facción, aunque uses una sola. Eso pasa en cada entrada y en cada `/reload`.

## La idea

El motor (Polestar) ya trae los **pasos diferidos**, pensados para las partes por raza (`Core/Guides.lua`, «Deferred steps»): una guía puede traer sus pasos como texto, `stepsSrc = "return { ... }"`, más `stepCount`. El texto se compila la primera vez que alguien lee `g.steps` (`Guides.Steps`, con un `__index`), y `Guides.Release` lo suelta cuando ninguna pestaña muestra la guía (`Own.sweep` en `TABS_CHANGED`/`GUIDE_CHANGED`). Hoy ninguna guía de Alfa lo usa: las 260 traen `steps = { ... }`.

**Propuesta:** al construir, `build.py` pasa los pasos de cada guía de `Alfa_Guides`, `Alfa_Guides_Alliance` y `Alfa_Guides_Horde` a `stepsSrc` + `stepCount`. Al entrar, Lua solo lee un texto largo por guía (eso es casi gratis) y arma la ficha (título, niveles, zona, `next`...). Los pasos se arman cuando abres la guía.

Con eso ya no hace falta partir las guías por rango de niveles, que era el plan anterior: el selector, la búsqueda y las sugerencias siguen viendo las 173 guías con su ficha completa.

## El experimento (ya corrido)

Se hizo en una copia de `dist` con un convertidor de prueba (scratchpad, `diferir.py`), sin tocar el proyecto:

| | 1.3.3 | Diferidas | |
|---|---|---|---|
| Lectura de archivos al entrar | 185 ms | 43 ms | −77 % |
| `LoadAddOn Alfa_Guides_Horde` | 147 ms | 24 ms | −84 % |
| Memoria Lua al final | 65,8 MB | 54,0 MB | −12 MB |
| Guías con sus pasos armados al entrar | 173 | 6 | |
| `tools/prueba.py` (todas las escenas) | todo bien | **todo bien** | |

Las 6 guías que se arman igual son la guía que estás siguiendo y 5 guías de clase de guerrero, que pide `UI/ClassToast.lua`.

## Lo que hay que hacer

### 1. El convertidor en la construcción
- `tools/diferir.py` (nuevo), llamado por `build.py` después de copiar los paquetes de guías. Por cada `steps = { ... }` de primer nivel dentro de `Alfa.RegisterGuide({ ... })`:
  - buscar el cierre de la tabla saltando textos `"..."`, textos largos `[[...]]` y comentarios;
  - escribir `stepCount = N, stepsSrc = [====[return { ... }]====]` y elegir un nivel de `=` que no aparezca dentro del texto;
  - copiar a la ficha lo que el motor lee sin abrir los pasos (ver el punto 2).
- Trabaja byte por byte en latin-1, como el resto de `build.py`, para no romper el UTF-8 de los textos.
- Si algo no encaja (tabla sin cierre, nivel de `=` imposible), la construcción se detiene y lo dice, igual que con los parches.

### 2. Lo que el motor lee de **todas** las guías (hay que cubrirlo o se pierde lo ganado)
Busqué los recorridos de `Guides.List()` que tocan `.steps`:

| Sitio | Qué lee | Cuándo | Qué hacer |
|---|---|---|---|
| `Core/Engine.lua` `GroupQuests` | `when group` | Opciones | Ya lee `g.groupQuests` de la ficha si la guía está diferida: el convertidor lo escribe (`{ quest = N }`). Falta el título. |
| `Core/Engine.lua` `GuideDungeons` | `when dungeon` | Opciones | Ya busca en `stepsSrc` con un patrón: no requiere nada. |
| **`Core/Closes.lua` `guideIndex`** | `closedBy` de cada `accept` | **Al abrir el diálogo de un PNJ que da misiones** (`Automation.lua`, `HoldsOffer`) | **Urgente:** si no se cubre, el primer diálogo arma las 173 guías de golpe (un tirón grande) y ya no las suelta. Hay que escribir en la ficha `closes = { [quest que cierra] = { quest aceptada, ... } }` y construir el índice desde ahí; los pasos se leen solo para la guía de la misión que tienes enfrente. |
| `Core/Unlocks.lua` `guideIndex` | `accept`/`turnin`/`pre` de todas | Al pedir qué desbloquea una misión | Igual que el anterior: en la ficha, `quests = { a = {...}, t = {...} }`, y el índice se arma con eso. Las tablas `step`/`goal` se piden al momento. |
| `UI/ClassToast.lua` | guías de clase que te tocan | Al aceptar una misión de clase | Usar `quests` de la ficha antes de abrir la guía (son 5 o 6 guías, no es urgente). |
| `Core/Guides.lua` `FollowLog` | guías de subida de tu paquete | Cuando una actualización rehízo tu guía | Poco frecuente; se puede dejar, o usar `quests`. |
| `Core/Engine.lua` `feederIndex` | hasta `FEED_BACK` guías anteriores | Al rearmar una guía | Ya lee pocas: se deja. |
| `Core/RoutePlan.lua` | `next` / `nextChoices` | Plan de ruta | Están en la ficha: no requiere nada. |

Faltan por revisar a mano los módulos propios de `src/` que hacen `A.Guides.Get(id).steps` dentro de un recorrido (Rutas: `Circuito`, `Cadena`, `Siguiente`, `Grises`, `ObjetoMision`; Mazmorras; Lya `Aprende`). La regla: **nada recorre los pasos de todas las guías; si hace falta un dato de todas, va en la ficha**.

### 3. Seguridad en combate
`Guides.Steps` compila al leer. Una guía grande (~100 KB) tarda unos 1–3 ms en el juego. No debería pasar en combate, porque abrir una guía es un clic del jugador. Aun así:
- `Own.sweep` no suelta pasos en combate (evita soltar y volver a armar en medio de una pelea);
- la guía que sigues y la siguiente (`next`) quedan armadas después de entrar (`N.Una` fuera de combate), para que el primer clic no espere.

### 4. Pruebas
- `tools/banco/prueba_134_guias.lua` (nueva):
  - **Ida y vuelta exacta:** para cada guía, los pasos de `stepsSrc` compilados son iguales, tabla por tabla, a los de la guía sin diferir (se carga un `dist` sin convertir para comparar).
  - Al entrar hay como mucho 3 guías armadas.
  - Abrir el diálogo de un PNJ (`HoldsOffer`), pedir `Unlocks.For`, aceptar una misión de clase y abrir Opciones > misiones de grupo: ninguna de esas acciones arma más de 3 guías.
  - Cambiar de guía suelta la anterior (`Guides.Release`) y vuelve a armarla igual.
- `tools/perfil.py` en `prueba.py` como tope: falla si la lectura al entrar pasa de 80 ms o si hay más de 3 guías armadas (el perfilador ya imprime las dos cifras).
- `revisar.py`, `humo.py` y `prueba.py` en «todo bien», y Toxic lo prueba en el juego con `/alfa rendimiento` antes y después.

## Riesgos
- **Algo que recorre todas las guías y que no encontré:** volvería a armarlas todas, sin romper nada, pero perdiendo lo ganado. La prueba de «como mucho 3 armadas» lo atrapa.
- **Textos en el idioma del cliente:** `GuideTexts.PrepareSteps` traduce al compilar (ya existe para las partes por raza). La ida y vuelta lo cubre, y conviene correrla también en enUS y en un idioma con letras raras (zhCN).
- **Guías importadas** (`Guides.DropImported`): no pasan por `build.py`; quedan como hoy.
- **Upstream:** si Polestar cambia `Guides.Steps`, el parche no aplica y la construcción lo dice (`tools/parches.py`).

## Orden de trabajo
1. `tools/diferir.py` + llamada en `build.py` (con `closes`, `quests` y `groupQuests` en la ficha).
2. `Closes.lua` y `Unlocks.lua` leen la ficha (parches en `tools/parches.py`).
3. `ClassToast`, `FollowLog` y la revisión de `src/`.
4. Que la guía actual quede armada al entrar y que `sweep` no suelte pasos en combate.
5. `prueba_134_guias.lua`, el tope en `prueba.py` y la nueva medición en `docs/perfil-1.3.4.txt`.

Ganancia esperada para el jugador: entra al juego y hace `/reload` claramente más rápido (en el banco, ~140 ms menos de Lua en cada carga), con ~12 MB menos de memoria de Alfa, lo que también espacia los tirones del recolector de basura.
