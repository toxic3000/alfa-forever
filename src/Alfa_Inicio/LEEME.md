# Alfa - Inicio

La página **Hoy**, la portada de Alfa (sección *Hoy*, clave `inicio`, orden 5, ícono `ic-hoy`), hecha con el Kit (`docs/KIT.md`, `K.Tablero`). También dibuja los avisos de Alfa: los recordatorios y cuatro avisos del motor.

## Qué muestra, de arriba abajo

Cada pieza sale solo si tiene algo útil o una acción; lo vacío no se muestra.

1. **¿Qué hacemos hoy?** El título grande y cuatro caminos: *Subir de nivel*, *Profesiones*, *Hacer oro* y *Mazmorras*. Cada uno abre el asistente de la ruta (`AlfaRuta.Asistente(camino)`); sin él, la página Rutas (Mazmorras para su camino). En el nivel máximo, *Subir de nivel* no sale.
2. **Tu siguiente paso** (la tarjeta grande): el paso vivo de tu guía, hasta tres metas, el número de paso, la distancia y el rumbo hasta la flecha, a quién vas y el avance de la guía. *Seguir* muestra tu guía y la flecha y cierra la ventana; *Ver pasos* abre la lista de pasos. Sin guía no sale (los caminos la eligen). Al terminar una guía: *Elegir qué sigue*.
3. **Liberar misiones** y **Recoger misiones**, a un clic (`AlfaRuta.Liberar()` y `AlfaRuta.Recoger()`). Liberar solo si tienes misiones en tu registro.
   **Tu plan** (solo si sigues uno de *Mis planes*): la meta de ahora, su avance, *Llévame* / *Guíame* y *Ya la hice*; *Ver el plan* abre el editor (`AlfaPlanes.Tarjeta()`; se acomoda con el mensaje `ALFA_PLAN`).
4. **Alertas** (solo lo urgente, con su botón; los *Llévame...* usan `AlfaCerca.Ir`, con sus mensajes y su aviso): equipo gastado (*Llévame a reparar*), bolsas casi llenas (*Llévame a un vendedor*, *Abrir bolsas*), habilidades por entrenar (*Llévame con mi entrenador*), tu buff que falta y, si eres sacerdote, druida, paladín o chamán, **preparar tus marcos de curación** (el asistente de Curación, o *Ahora no*).
   **Buscar cerca** (con `rutas.cercaHoy`): seis botones chicos (Vuelo, Posada, Reparar, Banco, Buzón, Mi entrenador) que ponen la flecha al más cercano (`AlfaCerca.Ir`); al pasar el ratón, el más cercano si ya se sabe; *Más lugares* abre el menú completo (`AlfaCerca.Menu`).
5. **Para tu <clase>**, con tu rama y tu rol: el talento que toca (`AlfaBuilds.SiguienteTalento()`, con *Ver en Talentos*) y las tarjetas de tu clase (`M.Clase`), cada una abre su módulo. Una tarjeta sin dato (el juego no lo dice ahora) no sale.
6. **Hoy en números:** XP por hora, para subir de nivel (los dos, si no eres nivel máximo), oro de hoy, esta sesión y **tu manada** (`AlfaManada.Resumen()`: los que comparten y tu grupo; si no compartes, *Compartir* abre `AlfaManada.PreguntarCompartir()`).
7. Abajo y compacto:
   - **Lo demás, de un vistazo:** equipo, bolsas, entrenador, buff y descanso en insignias; lo que ya está en Alertas no se repite.
   - **Tu diario:** tu sesión de ahora; *Ver las sesiones pasadas* muestra las cuatro últimas (`inicio.verDiario`).
   - **Accesos:** un botón chico por módulo de Alfa.
   - **Tus avisos:** plegados; *Ajustar* abre sus grupos de ajustes (`inicio.verAjustes`).

Mientras la página se ve, los números, la distancia y las tarjetas de la clase se repintan una vez por segundo (un temporizador que se apaga al ocultarla).

## Avisos

- **La tarjeta de aviso** (`Avisos.lua`, `M.Aviso`): Kit (franja, baldosa con el ícono o el del hechizo, título, línea, texto y hasta dos botones). Se va sola a los `inicio.segAviso` segundos (no con el ratón encima), se arrastra (`inicio.avisoPos`), una a la vez con cola corta. La usan los recordatorios y el resumen de la sesión anterior.
- **Los del motor** (`AvisosMotor.lua`, `AlfaNucleo.Reemplazar`), con frases de Alfa:
  - `WHILE_HERE`: un `K.Aviso` "Mientras estás aquí" con *Llévame*. No sale si el rastreador de la ruta ya lo muestra (`AlfaRuta.RastreadorVisible()`).
  - `CLASS_TOAST`: tu misión de clase (recompensa, nivel, quién te la da y dónde) con *Abrir su guía* o *Llévame*, y *Ahora no*.
  - `UPDATE_CARD`: hay una versión nueva, con *Entendido*.
  - `LEVEL_TIP`: lo que una ruta te da en niveles, con la barra por niveles, al pasar el ratón por su ficha.
  Al irse la tarjeta se llama al `Cerrar()` del motor, que deja pasar el siguiente aviso.

## Recordatorios

Durabilidad (30 % y 10 %, este con sonido), bolsas casi llenas, habilidades por aprender al llegar a una ciudad o posada, tu buff fuera de combate, la XP descansada y el resumen de la sesión anterior al entrar. Sus ajustes están en *Tus avisos* (y en la búsqueda de la ventana de Alfa), en `AlfaDB.settings.inicio`; el diario, por personaje, en `AlfaNucleoCharDB.inicio`.

## Comandos

- `/alfa inicio`: abre Hoy.
- `/alfa sesion`: tu sesión de ahora en el chat.

## Archivos

- `Textos.lua`: el inglés de cada texto (`M.EN`).
- `Avisos.lua`: la tarjeta de aviso.
- `Sesion.lua`: la sesión de ahora y el diario.
- `AvisosMotor.lua`: los cuatro avisos del motor.
- `Recordatorios.lua`: los recordatorios y lo que lee la página (`M.Rec`).
- `Clase.lua`: el rol y las tarjetas de cada clase (`M.Clase`).
- `Inicio.lua`: la página.

## Contratos de otras áreas

Todos opcionales: sin ellos, la pieza se cambia por otra o no sale.

| Contrato | Sin él |
|---|---|
| `AlfaRuta.Asistente(camino)` | Los caminos abren la página Rutas (Mazmorras, la suya) |
| `AlfaRuta.Liberar()`, `AlfaRuta.Recoger()` | Esas tarjetas no salen |
| `AlfaRuta.RastreadorVisible()` | "Mientras estás aquí" sale siempre que el motor lo pida |
| `AlfaBuilds.SiguienteTalento()` | Sin tarjeta del talento; queda la de Talentos de la clase |
| `AlfaManada.Resumen()`, `.PreguntarCompartir()`, `.Abrir()` | Sin tarjeta de tu manada |
| `AlfaCuracion` (de Alfa_Curacion) | Sin la alerta de preparar los marcos |
| `AlfaCerca.Ir`, `.Tipos`, `.Texto`, `.Menu` (de la ruta) | Sin la fila Buscar cerca; las alertas van directo al motor (`Alfa.Nav.nearby.Go`) |
| `AlfaPlanes.Tarjeta`, `.Abrir` (de la ruta) | Sin la tarjeta Tu plan |

## Para verificar en el juego

1. `/alfa`: abre en Hoy; sin huecos ni textos encimados en Grafito, Noche y Pizarra.
2. Los cuatro caminos abren el asistente de la ruta (o Rutas). En el nivel 60 no sale Subir de nivel.
3. Con una guía: el paso y sus metas son los de tu guía; al caminar, la distancia y el rumbo cambian cada segundo sin que la página brinque. Seguir muestra la guía y la flecha y cierra Alfa. Al terminar una guía sale "¡Terminaste tu guía!".
4. Liberar y Recoger misiones hacen lo suyo (con la ruta de A1). Sin misiones en el registro, Liberar no sale.
5. Alertas con equipo gastado, bolsas llenas y habilidades por entrenar; cada botón lleva a donde dice. Sin nada urgente, la sección no sale. Con un sacerdote, druida, paladín o chamán nuevo sale "Prepara tus marcos de curación"; *Ahora no* la quita.
6. Para tu clase con varias clases: tarjetas con dato y su color; el talento que toca con la ruta de Talentos (C1).
7. Tu manada: sin compartir, *Compartir* abre la pregunta de La Jauría; compartiendo, cuenta la manada y tu grupo.
8. Los avisos: probar uno desde *Tus avisos*, moverlo y devolverlo. La misión de clase al subir de nivel (`/alfa classtoast`), la versión nueva, "Mientras estás aquí" con la guía oculta y la ficha de niveles en el selector de guías y en una mazmorra.
9. Buscar cerca en Hoy: los seis botones en una fila (o dos, en angosto), cada uno pone la flecha; *Más lugares* abre el menú arriba o abajo según haya lugar. Apagar `rutas.cercaHoy` en la página Ruta la quita sin dejar hueco.
10. Tu plan: con un plan seguido sale arriba de Alertas con la meta de ahora; *Ya la hice* y cumplir la meta la cambian; sin plan no sale.
