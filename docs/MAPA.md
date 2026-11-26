# El mapa del código de Alfa

Generado por `python -I tools/mapa.py` desde la cabecera de cada archivo (no se edita a mano;
lo de «Si pasa esto, mira aquí» vive en `tools/mapa.py`). `tools/prueba.py` revisa que esté al día.

## Si pasa esto, mira aquí

| Lo que pasa | Dónde mirar | Su prueba |
|---|---|---|
| No puedo clicar algo del juego, la cámara no gira o la rueda no hace zoom | `/alfa raton` en el juego (dice quién se queda con el clic). Código: `src/Alfa_Nucleo/Kit/Raton.lua` (guardia, `K.SinRaton`, `K.Enganchar`), `Kit/Movible.lua` (Mayús+arrastre). | `prueba_141_raton.lua`, `tools/banco/raton.lua` (barrido del ratón) |
| El volumen o el sonido no me obedece | `src/Alfa_Pesca/Pesca.lua` (deseadas, Aplicar, Restaurar, `/alfa sonido`), `src/Alfa_Comodidades/Sonidos.lua`. | `prueba_140_control.lua` |
| Un error de Lua | `/alfa errores` (lista y copia). Código: `src/Alfa_Nucleo/Errores.lua`. | el banco: agrega el caso primero |
| «Alfa_X se ha bloqueado de una acción…» | Una función restringida o protegida en combate: busca la función en `referencia/` (`HasRestrictions`) y pásala por `N.FueraDeCombate` o un botón seguro. | `NOTE("ADDON_ACTION_BLOCKED", ...)` en el banco |
| Un texto cortado o que se sale de su caja | El Kit (`src/Alfa_Nucleo/Kit/`) y la página del módulo (`Pagina.lua`). | `prueba_letras.lua`, galería (`tools/prueba.py`) |
| Los anuncios grandes (zona, raro, barco) | `src/Alfa_Nucleo/Kit/Anuncio.lua`, `src/Alfa_Nucleo/Zonas.lua`. | `prueba_140_anuncios.lua` |
| Los avisos pequeños y Lya diciéndolos | `src/Alfa_Nucleo/Kit/Ventanas.lua` (`K.Aviso`), `src/Alfa_Nucleo/Momentos.lua`, `src/Alfa_Lya/Cerebro.lua`. | `prueba_138_avisos.lua`, `prueba_139_avisos.lua` |
| La flecha, sus placas o la tarjeta de viaje | `motor/Alfa/Nav/Arrow.lua`. | `prueba_139_flecha.lua` |
| Una guía o un paso que no avanza | `src/Alfa_Rutas/` (Guias, Rastreador, Ruta), paquetes de pasos de `tools/tramos.py`. | `prueba_134_guias.lua`, `prueba_140_misiones.lua` |
| Un ajuste que no se guarda o cambia solo | `motor/Alfa/UI/Options.lua`, migraciones `N.Migracion` (`src/Alfa_Nucleo/`). | `prueba_ajustes.lua` (3 fases) |
| La pantalla se ve rara tras Dos pantallas | `src/Alfa_Bienvenida/Escritorio*.lua`, `/alfa pantallas reparar`. | `prueba_140_pantallas.lua` |
| Va lento o tiene tirones | `/alfa rendimiento`; `src/Alfa_Nucleo/Reloj.lua` (todo lo que se repite va ahí). | `tools/perfil.py`, `prueba_140_velocidad.lua` |
| Algo en combate o en mazmorra (valores secretos) | `issecretvalue` primero: `N.Leer`, `N.LeerNumero` (`src/Alfa_Nucleo/Nucleo.lua`). | `prueba_140_secretos.lua` |

## Para agregar algo nuevo

1. **El lugar:** el módulo de la tabla de abajo cuyo tema es el tuyo; un archivo nuevo va en su carpeta y en su `.toc`, con su cabecera `-- Alfa - <Módulo>: <qué hace> (versión). toxic3000 / La Jauría. GPL-3.0.`
2. **Sus textos:** en español en el código (`L["..."]`), el inglés en el `Textos.lua` del módulo y los demás idiomas en `textos/<idioma>/Alfa_<versión>.json` (`tools/textos.py estado`).
3. **Sus ajustes:** `A.RegisterDefaults` en el módulo y su fila en la `Pagina.lua` del módulo; si cambia un valor de fábrica, una migración (`N.Migracion`).
4. **Lo que se ve en pantalla:** con el Kit (`src/Alfa_Nucleo/Kit/`). Un marco que no dibuja nada (un ancla) nunca toma el ratón: `K.SinRaton(marco)`. Un gancho a un marco del juego: `K.Enganchar(marco, script, fn)`, nunca `HookScript` directo con scripts del ratón. Que se pueda mover: `K.Movible`.
5. **Lo que se repite:** `N.Cada` / `N.Una` (`src/Alfa_Nucleo/Reloj.lua`); lo que espera al fin del combate, `N.FueraDeCombate`.
6. **Su prueba:** `tools/nueva_version.py` deja la plantilla (`tools/banco/plantilla_prueba.lua`); termina siempre con `RATON_LIMPIO`.
7. **Lya lo presenta:** `AlfaLya.Ensenar({ id, pregunta, respuesta, icono, modulo })`.

## Los módulos

### `src/Alfa_Bienvenida/` — 28 archivos. 14.935 líneas
Pruebas que lo usan (34): `prueba_140_bugs.lua`, `prueba_140_dia.lua`, `prueba_140_interfaz.lua`, `prueba_140_misiones.lua`, `prueba_140_pantallas.lua`, `prueba_140_revision.lua`, `prueba_140_revision2.lua`, `prueba_140_ventana.lua` y más

- `Acomodar.lua` — acomodar la pantalla (1.3.1; 1.4.0: todo se mueve)
- `Aprendiz.lua` — el Modo aprendiz (1.3.9)
- `Asistente.lua` — la ventana de configuración
- `Bienvenida.lua` — la configuración de Alfa, las novedades y el aullido
- `Diagnostico.lua` — «Revisar Alfa», el diagnóstico (1.2.9)
- `Escritorio.lua` — el Escritorio de Alfa, Alfa en tu segundo monitor (1.3.8)
- `EscritorioAsistente.lua` — el asistente de «Dos pantallas» (1.3.8)
- `EscritorioAuto.lua` — Dos pantallas en un clic (1.3.8)
- `EscritorioEditor.lua` — «Editar escritorio» (1.3.8)
- `EscritorioFondo.lua` — el fondo del Escritorio de Alfa, una noche (1.4.0)
- `EscritorioPagina.lua` — la página «Dos pantallas» en Ajustes (1.3.8)
- `EscritorioPaneles.lua` — los paneles del Escritorio de Alfa (1.3.8)
- `EscritorioReparar.lua` — Dos pantallas deja tu pantalla como estaba (1.4.0)
- `Intro.lua` — la intro, un lobo que aúlla a la luna antes de la configuración, de las notas de una versión nueva o como saludo al entrar
- `Notas.lua` — las notas de una versión nueva
- `Novedades.lua` — lo nuevo de Alfa 1.0
- `Pagina.lua` — la página "Estilo y sonido" en Ajustes
- `Pasos.lua` — lo que pregunta la configuración
- `Perfiles.lua` — tus perfiles y la copia de tus ajustes (1.2.7)
- `PrimeraVez.lua` — la primera vez en cada página (1.3.9)
- `Recorrido.lua` — el recorrido por la ventana de Alfa (1.2.7)
- `Reporte.lua` — "Reportar un error, una mejora o un comentario"
- `Respaldos.lua` — tus respaldos y los errores atrapados (1.2.9)
- `Teclas.lua` — tus atajos de Alfa (1.3.0)
- `Textos.lua` — textos en inglés para clientes que no son esMX/esES El español es el idioma principal: aquí solo va su traducción
- `Usados.lua` — «Lo más usado» en Ajustes (1.3.8)
- `Ventana.lua` — la ventana de Alfa, más cómoda (1.3.7)
- `Zen.lua` — el modo Zen (1.3.8)

### `src/Alfa_Bolsas/` — 33 archivos. 12.396 líneas
Pruebas que lo usan (23): `prueba_139_bolsas.lua`, `prueba_139_revision.lua`, `prueba_140_bolsas.lua`, `prueba_140_bugs.lua`, `prueba_140_dia.lua`, `prueba_140_diario.lua`, `prueba_140_interfaz.lua`, `prueba_140_revision2.lua` y más

- `Abrir.lua` — «Abrir» y «Aprender» en el momento 1.4.0 (diario, 92 y 93)
- `Acomodar.lua` — acomodar con un clic 1.3.0
- `Atajos.lua` — atajos a lo nuevo y a tus mejoras
- `Banco.lua` — depositar rápido y comprar espacio en el banco
- `Barra.lua` — la barra de las bolsas equipadas, en la ventana
- `BolsaNueva.lua` — «Ponte la bolsa» 1.4.0 (diario, 101)
- `Bolsas.lua` — Bolsas
- `Botones.lua` — los botones de objeto y sus marcas
- `Cambio.lua` — cambiar de equipo con un clic 1.3.7
- `Candado.lua` — el candado de objetos 1.3.8
- `Comparar.lua` — comparar con lo que llevas puesto 1.3.0
- `Compat.lua` — Bolsas
- `Conjuntos.lua` — tus conjuntos de equipo 1.3.0
- `Datos.lua` — el registro de lo que lleva cada personaje de la cuenta
- `Guardar.lua` — qué guardar en el banco o para otro personaje 1.2.9
- `Lotes.lua` — mover objetos por lotes, siempre tras un clic
- `Mejora.lua` — «Ponte esto», el equipo nuevo que es mejor 1.2.9
- `Objetos.lua` — lo que se sabe de cada objeto, sus categorías y la búsqueda
- `Ordenar.lua` — ordenar a tu manera 1.3.9
- `Oro.lua` — «Tu oro», el desglose del oro de tus personajes 1.3.7
- `Pagina.lua` — la página "Bolsas" en la ventana de Alfa
- `ParaMisiones.lua` — lo que piden tus misiones y está en tu banco 1.4.0 (diario, 98)
- `Personajes.lua` — la seccion "Personajes" del motor se abre aqui La pagina de Bolsas ya muestra a tus personajes con lo que lleva cada uno, asi que el centro de guias del…
- `Previa.lua` — «Ordenar» con vista previa 1.4.0
- `Ranuras.lua` — el nivel de objeto y la durabilidad sobre cada ranura de tu personaje y de la inspección 1.3.7
- `Reemplazo.lua` — la ventana de Alfa en lugar de las bolsas y el banco de Blizzard
- `Separar.lua` — «Separar»: lo que vale la pena subastar y lo que conviene vender al comerciante, en un clic 1.3.8
- `Sesion.lua` — el oro de esta sesión (1.2.8)
- `Sobra.lua` — «Lo que me sobra» 1.3.9
- `Sugerencias.lua` — qué vender, qué conservar o ir al comerciante cuando las bolsas se empiezan a llenar
- `Textos.lua` — los textos en inglés (el español es el idioma principal y va escrito en el código)
- `Todos.lua` — buscar en las bolsas y bancos de todos tus personajes 1.3.0
- `Ventana.lua` — las ventanas de bolsas y de banco

### `src/Alfa_Builds/` — 20 archivos. 6.314 líneas
Pruebas que lo usan (7): `prueba_116.lua`, `prueba_120.lua`, `prueba_122.lua`, `prueba_133_personaje.lua`, `prueba_137_nivel.lua`, `prueba_137_oficios.lua`, `prueba_137_revision.lua`

- `Arbol.lua` — el árbol de talentos real del juego
- `Avisos.lua` — las ventanas y avisos del motor que toma Talentos
- `Builds/Druid.lua` — Builds del druida
- `Builds/Hunter.lua` — Builds del cazador
- `Builds/Mage.lua` — Builds del mago
- `Builds/Paladin.lua` — Builds del paladín
- `Builds/Priest.lua` — Builds del sacerdote
- `Builds/Rogue.lua` — Builds del pícaro
- `Builds/Shaman.lua` — Builds del chamán
- `Builds/Warlock.lua` — Builds del brujo
- `Builds/Warrior.lua` — Builds del guerrero
- `Builds.lua` — el módulo
- `Compartir.lua` — compartir builds con una cadena de texto
- `Datos.lua` — vocabulario y registro de builds
- `Equipo.lua` — equipo meta por ranura
- `Inspeccion.lua` — ver el equipo de un compañero (1.3.7,
- `Lienzo.lua` — el árbol de talentos dibujado con el Kit
- `Pagina.lua` — la página Talentos, hecha con el Kit
- `Pesos.lua` — pesos de estadísticas de cada build
- `Textos.lua` — textos en inglés El español es el idioma principal; esta tabla los traduce al inglés para los clientes que no son esMX ni esES

### `src/Alfa_Combate/` — 22 archivos. 8.173 líneas
Pruebas que lo usan (15): `prueba_137_medidor.lua`, `prueba_137_revision.lua`, `prueba_137c_personaje.lua`, `prueba_138_oficios.lua`, `prueba_139_modulos.lua`, `prueba_140_mundo.lua`, `prueba_140_pulido.lua`, `prueba_140_secretos.lua` y más

- `Amenaza.lua` — tu amenaza
- `Combate.lua` — Combate
- `Corte.lua` — el aviso para cortar
- `Cuenta.lua` — la cuenta para jalar
- `Datos.lua` — habilidades de reacción por clase
- `Detalle.lua` — el detalle de un compañero en el medidor
- `Efectos.lua` — tus efectos a la vista
- `Golpe.lua` — barra de golpe
- `Jefes.lua` — temporizadores de jefe sencillos
- `MarcaMision.lua` — marca de misión en las placas de nombre
- `Medidor.lua` — los datos del medidor de daño
- `Pagina.lua` — su página en la ventana de Alfa
- `Panel.lua` — panel de estadísticas
- `Prioridad.lua` — la prioridad propia de Alfa
- `Prioridades.lua` — prioridades propias por clase y especialización
- `Reacciones.lua` — avisos de reacción
- `Recargas.lua` — tus recargas largas
- `Resumen.lua` — el resumen de tu pelea
- `Rotacion.lua` — la ayuda de rotación
- `SalDeAhi.lua` — «¡Sal de ahí!»
- `Textos.lua` — textos en inglés para clientes que no son esMX/esES. El español es el idioma principal: aquí solo va su traducción
- `Ventana.lua` — la ventana del medidor de daño

### `src/Alfa_Comercio/` — 24 archivos. 7.743 líneas
Pruebas que lo usan (19): `prueba_137d_datos.lua`, `prueba_138_candado.lua`, `prueba_138_oficios.lua`, `prueba_139_modulos.lua`, `prueba_140_diario.lua`, `prueba_140_oficios.lua`, `prueba_140_revision.lua`, `prueba_140_velocidad.lua` y más

- `Buscados.lua` — lo de tu lista, barato en la subasta (1.4.0, plan 46;
- `Buzon.lua` — el buzón 1.2.8
- `Consejo.lua` — qué conviene hacer con cada objeto
- `Datos.lua` — datos fijos del juego
- `Envios.lua` — mandar a tu alt desde el buzón (1.3.7,
- `Fabricar.lua` — qué fabricar para ganar más oro 1.3.0
- `Gangas.lua` — gangas en la subasta (1.3.7,
- `Lista.lua` — tu lista de compras 1.2.9
- `ListaCuenta.lua` — tu lista de compras con lo de todos tus personajes 1.3.8
- `Oficios.lua` — tus oficios de 1 a 300 1.2.9
- `OficiosDatos.lua` — las guías de oficios de 1 a 300 1.2.9
- `Pagina.lua` — la página "Comercio"
- `Pila.lua` — Alt+clic compra una pila 1.4.0 (diario, 95)
- `Precios.lua` — precios de la subasta
- `Recetas.lua` — recetas que conoces y Encantamiento
- `RecetasVerde.lua` — la receta que pasa a verde (1.4.0, plan 51;
- `RecetasZona.lua` — las recetas que te faltan cerca de ti 1.3.8
- `Recompra.lua` — lo valioso que vendiste sin querer 1.4.0 (diario, 94)
- `Semana.lua` — tu semana en la subasta (1.4.0, plan 47;
- `Subasta.lua` — escaneo completo de la subasta
- `Textos.lua` — textos en inglés El español es el idioma principal: cada clave es el texto en español
- `Tooltip.lua` — el consejo en el cuadro de cada objeto
- `Vender.lua` — subastar fácil 1.2.9
- `VentanaOficios.lua` — la ventana de oficios de 1 a 300 1.2.9

### `src/Alfa_Comodidades/` — 19 archivos. 5.788 líneas
Pruebas que lo usan (6): `prueba_128_rutas.lua`, `prueba_130_interfaz.lua`, `prueba_131_varios.lua`, `prueba_132_ajustes.lua`, `prueba_137_cierre.lua`, `prueba_137_comodidades.lua`

- `Barras.lua` — las barras de abajo con el estilo de Alfa
- `Charla.lua` — tu chat, más a la mano (1.3.7)
- `Chat.lua` — el chat con el estilo de Alfa
- `Comodidades.lua` — Comodidades
- `Cuadro.lua` — el cuadro de información de las unidades (a quién apunta, rango de hermandad, ocultarlo en combate y verlo con Mayús)
- `Estilo.lua` — el estilo de Alfa fuera de sus ventanas
- `Formas.lua` — la barra de una forma que está vacía
- `Ids.lua` — el número (ID) en el cuadro de información (1.3.7)
- `Info.lua` — la barra de información (1.3.7)
- `Marcos.lua` — colores de clase en los marcos, los grifos de la barra de acción y la distancia de la cámara
- `Minimapa.lua` — el minimapa (cuadrado, botones de addons ocultos y sin el menú de addons)
- `MinimapaEstilo.lua` — el minimapa con el estilo de Alfa
- `Misiones.lua` — aceptar y entregar todas las misiones
- `Pagina.lua` — su página, hecha con el Kit
- `Probador.lua` — el probador (botones de objetos y control de la animación)
- `Recargas.lua` — números en las recargas de tus barras (1.3.7)
- `Sonidos.lua` — silenciar sonidos molestos (grupos del juego y una lista propia)
- `Textos.lua` — los textos en inglés (el español es el idioma principal y va escrito en el código)
- `Vuelo.lua` — la siguiente parada del vuelo

### `src/Alfa_Curacion/` — 14 archivos. 6.750 líneas
Pruebas que lo usan (15): `prueba_137c_bugs.lua`, `prueba_137c_personaje.lua`, `prueba_138_curacion.lua`, `prueba_138_revision.lua`, `prueba_139_modulos.lua`, `prueba_139_revision.lua`, `prueba_140_mundo.lua`, `prueba_140_revision.lua` y más

- `Asistente.lua` — el asistente de 3 pasos
- `Color.lua` — el color de los marcos
- `Hechizos.lua` — los hechizos, las ranuras del ratón y los preajustes
- `Listos.lua` — «¿Listos?» y los hechizos de apoyo que faltan en el grupo (1.3.7,
- `Mana.lua` — el maná de los curanderos del grupo
- `Mapa.lua` — el mapa del ratón
- `Marcos.lua` — los marcos de grupo y banda
- `Pagina.lua` — su página en la ventana de Alfa
- `Peligro.lua` — quién está en peligro, a la primera mirada
- `Perfiles.lua` — tus mapas de clics guardados (1.3.9)
- `Raton.lua` — el dibujo del ratón (1.3.9)
- `SinBuff.lua` — quién no tiene tu hechizo de apoyo, en un ícono (1.4.0, mejora 41)
- `Tamanos.lua` — las medidas de tus marcos según el tamaño del grupo (1.4.0, mejora 40)
- `Textos.lua` — textos en inglés para clientes que no son esMX/esES. El español es el idioma principal: aquí solo va su traducción

### `src/Alfa_Enciclopedia/` — 11 archivos. 7.733 líneas
Pruebas que lo usan (11): `prueba_137b_enciclopedia.lua`, `prueba_137e_planes.lua`, `prueba_138_enciclopedia.lua`, `prueba_138_facciones.lua`, `prueba_139_calidad.lua`, `prueba_139_modulos.lua`, `prueba_140_pulido.lua`, `prueba_141_materiales.lua` y más

- `Base.lua` — lo común
- `Catalogo.lua` — el catálogo de cada tipo, la búsqueda y los filtros
- `Coleccion.lua` — monturas y mascotas
- `Cuadro.lua` — el cuadro de un objeto al pasar el ratón y el menú del clic derecho (1.3.7,
- `Fichas.lua` — lo que dice la ficha de cada cosa
- `Indices.lua` — los índices al revés
- `Legado.lua` — guía de los puntos del legado
- `Origen.lua` — cómo se consigue cada objeto y de qué facción es (1.3.8)
- `Pagina.lua` — su página en la ventana de Alfa, los reemplazos del motor y lo que usan los demás módulos
- `Textos.lua` — textos en inglés para clientes que no son esMX/esES. El español es el idioma principal: aquí solo va su traducción
- `Ventana.lua` — la ventana

### `src/Alfa_Idioma/` — 1 archivos. 52 líneas

- `Idioma.lua` — el idioma de Alfa, aunque el juego esté en otro

### `src/Alfa_Inicio/` — 16 archivos. 8.150 líneas
Pruebas que lo usan (18): `prueba_137_hoy.lua`, `prueba_137_revision.lua`, `prueba_137b_bugs.lua`, `prueba_139_interfaz.lua`, `prueba_140_acomodar.lua`, `prueba_140_interfaz.lua`, `prueba_140_revision2.lua`, `prueba_140_ventana.lua` y más

- `Acomodo.lua` — cómo se acomoda Hoy (1.3.9)
- `Avisos.lua` — la tarjeta de aviso
- `AvisosMotor.lua` — los avisos del motor, con el Kit
- `Barras.lua` — lo de Alfa en el cuadro de las barras de experiencia y de reputación del juego -- 1.3.7 (169, 177)
- `Camino.lua` — «Camino al 60» -- 1.2.9
- `Clase.lua` — la tarjeta «Para tu <clase>»
- `Comida.lua` — comida y agua -- 1.2.9
- `Inicio.lua` — la página Hoy, la portada de Alfa
- `Jugado.lua` — tu tiempo jugado 1.3.7 (191)
- `Listo.lua` — listo para la mazmorra -- 1.2.9
- `Recordatorios.lua` — los recordatorios
- `Reputacion.lua` — tu reputación al día 1.3.7 (177)
- `Sesion.lua` — la sesión actual y el diario de sesiones
- `Subir.lua` — cuánto te falta para subir de nivel -- 1.3.7
- `Textos.lua` — textos en inglés El español es el idioma principal: aquí solo va su traducción al inglés, para los clientes que no son esMX ni esES (N.Textos)
- `Tiempo.lua` — «¿Cuánto tiempo tienes?», el plan de tu rato de juego -- 1.2.9

### `src/Alfa_Lya/` — 35 archivos. 13.290 líneas
Pruebas que lo usan (33): `prueba_140_acomodar.lua`, `prueba_140_bugs.lua`, `prueba_140_control.lua`, `prueba_140_mundo.lua`, `prueba_140_social.lua`, `prueba_141_raton.lua`, `prueba_botones.lua`, `prueba_letras.lua` y más

- `Ahora.lua` — Lya según el momento (1.2.9)
- `Aprende.lua` — Lya aprende (1.2.8)
- `Cerebro.lua` — cuándo habla y qué dice
- `Charla.lua` — la plática de los ratos tranquilos
- `Clase.lua` — Lya te enseña tu clase (1.2.9)
- `Cumple.lua` — los cumpleaños (1.3.0)
- `Dia.lua` — tu día de caza y lo que festeja (1.2.5)
- `EnGrupo.lua` — las Lyas de tu grupo se saludan (1.3.0)
- `Festejos.lua` — Lya festeja lo que logras con Alfa (1.3.8)
- `FinMazmorra.lua` — el fin de la mazmorra (1.2.8)
- `Foco.lua` — el modo foco (1.2.9)
- `Frases.lua` — lo que dice
- `Guia.lua` — «Pregúntale a Lya», la guía de todo Alfa (1.2.4)
- `Historias.lua` — las historias de tus misiones y los datos curiosos de cada zona
- `HoraReal.lua` — Lya según tu hora del día (1.3.8)
- `Llegada.lua` — un brinco al llegar (1.3.7c)
- `Lore.lua` — datos curiosos de cada zona y lore del mundo
- `LoreMas.lua` — más lore del mundo y más datos de cada zona
- `LoreMisiones.lua` — el lore de tus misiones (1.4.0, 12)
- `Lya.lua` — la loba en pantalla y su globo
- `Mascota.lua` — Lya y tu mascota (1.3.0)
- `Momentos.lua` — los momentos (1.2.7)
- `Muerte.lua` — cuando caes (1.2.9)
- `Oficios.lua` — Lya y tus oficios (1.2.8)
- `Pagina.lua` — su página en la ventana de Alfa
- `Pausa.lua` — «¿Una pausa?» (1.3.8)
- `Recuerdos.lua` — sus recuerdos y sus días especiales (1.4.0, 12)
- `Retos.lua` — los retos de la semana (1.3.0)
- `Saberes.lua` — lo que sabe de tu gente, tu clase y tus profesiones, y sus consejos de amiga
- `SuVoz.lua` — tus misiones en su voz (1.3.0)
- `Temporada.lua` — tu temporada con la manada (1.4.0, 11)
- `Textos.lua` — textos en inglés para clientes que no son esMX/esES El español es el idioma principal
- `TuHistoria.lua` — tu historia (1.2.8)
- `VentanaHistorias.lua` — la ventana Historias
- `VentanaTemporada.lua` — la ventana de tu temporada con la manada (1.4.0, 11)

### `src/Alfa_Manada/` — 35 archivos. 13.205 líneas
Pruebas que lo usan (24): `prueba_138_revision.lua`, `prueba_139_bandos.lua`, `prueba_139_modulos.lua`, `prueba_139_revision.lua`, `prueba_140_bugs.lua`, `prueba_140_pulido.lua`, `prueba_140_social.lua`, `prueba_insignias.lua` y más

- `Bienvenida.lua` — la bienvenida a la manada (1.4.0, 52)
- `Botin.lua` — el botín de la manada (1.3.0)
- `Callados.lua` — silenciar a un lobo (1.4.0, 56)
- `Canal.lua` — el canal oculto entre los usuarios de Alfa
- `Censo.lua` — los lobos de tu hermandad que usan Alfa (1.3.9)
- `Cerca.lua` — un lobo de la manada anda cerca (1.3.2)
- `Cita.lua` — la cita de la manada (1.2.8)
- `Clan.lua` — los datos del clan que se muestran en su página
- `Compartir.lua` — compartir tu plan o tu guía con un lobo (1.3.8)
- `Ficha.lua` — la ficha de cada lobo (1.3.8)
- `Gente.lua` — quién es quién. Tu grupo o banda (con la API del juego) y los usuarios de Alfa que aceptaron compartir su ubicación (lo que llega por Red.lua). Nada más: ni…
- `Guaridas.lua` — las guaridas (1.2.4)
- `Insignias.lua` — las insignias de la manada
- `Invitar.lua` — «Invitar al clan» en el menú del clic derecho de un jugador (su retrato, su nombre en el chat, tu grupo o banda, la lista de una comunidad). Se abre con tu…
- `Juntos.lua` — cazar juntos (1.2.7)
- `Llamado.lua` — llamar a la manada (1.2.6)
- `Logros.lua` — los logros de la manada y la semana de la manada (1.2.9)
- `Manada.lua` — el módulo. Registra la página, los ajustes y el comando /alfa manada, mueve el pulso (grupo, envío de tu posición, marcas del mapa) y publica el contrato…
- `Mapa.lua` — la manada en el mapa del mundo y el minimapa
- `Marcador.lua` — el marcador por bando (1.3.9, pedido de Toxic)
- `Mentor.lua` — el mentor de la manada (1.3.0)
- `Notas.lua` — las notas del lobo (1.2.8)
- `Pagina.lua` — su página en la ventana de Alfa, hecha con el Kit
- `Plano.lua` — cambiar de plano cuando está lleno (1.2.9)
- `QuienTiene.lua` — «¿Quién tiene...?» (1.2.9)
- `QuienVa.lua` — ¿quién va? (1.2.8)
- `Raro.lua` — marcar el raro para todos (1.2.7)
- `Red.lua` — los mensajes entre los Alfa de la manada
- `Reloj.lua` — los raros con reloj (1.2.8)
- `Retrato.lua` — la insignia en el retrato (1.2.2)
- `Saludo.lua` — el saludo de la manada (1.2.7)
- `Seguir.lua` — "Seguir" a alguien de la manada con la flecha de Alfa (la del motor: el estilo de la flecha de lobo lo pone la apariencia) y su ruta
- `Tablon.lua` — el tablón de la manada (1.3.0)
- `Textos.lua` — los textos en inglés (el español es el idioma principal y va escrito en el código)
- `Util.lua` — piezas comunes del módulo (nombres, posiciones, distancias, tiempos, susurros e invitaciones)

### `src/Alfa_Mazmorras/` — 29 archivos. 7.786 líneas
Pruebas que lo usan (8): `prueba_116.lua`, `prueba_129_lya.lua`, `prueba_137_mundo.lua`, `prueba_137_revision.lua`, `prueba_138_oficios.lua`, `prueba_139_modulos.lua`, `prueba_140_diario.lua`, `prueba_140_mundo.lua`

- `Ajustes.lua` — sus ajustes, en Ajustes > Descubrir > Mazmorras
- `Avisos.lua` — los avisos de jefes del propio juego
- `BotinGrupo.lua` — el botín de tu grupo, con su historial (1.3.7)
- `Capa.lua` — las entradas de mazmorras en el minimapa
- `Consejos/CastilloDeColmilloOscuro.lua` — consejos por jefe para principiantes Castillo de Colmillo Oscuro (shadowfang-keep). Formato en LEEME.md
- `Consejos/CavernasDeBrazanegra.lua` — consejos por jefe para principiantes Cavernas de Brazanegra (blackfathom-deeps). Formato en LEEME.md
- `Consejos/CuevasDeLosLamentos.lua` — consejos por jefe para principiantes Cuevas de los Lamentos (wailing-caverns). Formato en LEEME.md
- `Consejos/Gnomeregan.lua` — consejos por jefe para principiantes Gnomeregan (gnomeregan). Formato en LEEME.md
- `Consejos/HoradoRajacieno.lua` — consejos por jefe para principiantes Horado Rajacieno (razorfen-kraul). Formato en LEEME.md
- `Consejos/MazmorrasDeVentormenta.lua` — consejos por jefe para principiantes Mazmorras de Ventormenta (stormwind-stockade). Formato en LEEME.md
- `Consejos/MinasDeLaMuerte.lua` — consejos por jefe para principiantes Minas de la Muerte (deadmines). Formato en LEEME.md
- `Consejos/MonasterioEscarlata.lua` — consejos por jefe para principiantes Monasterio Escarlata (scarlet-monastery). Formato en LEEME.md
- `Consejos/SimaIgnea.lua` — consejos por jefe para principiantes Sima Ígnea (ragefire-chasm). Formato (también en LEEME.md): [id de PNJ del jefe] = { { "español", "English", rol =…
- `Consejos/Uldaman.lua` — consejos por jefe para principiantes Uldaman (uldaman). Formato en LEEME.md
- `Consejos/ZahurdaRajacieno.lua` — consejos por jefe para principiantes Zahúrda Rajacieno (razorfen-downs). Formato en LEEME.md
- `Consumibles.lua` — lo que te falta tomar antes de un jefe (1.3.7)
- `Cotejo.lua` — «Prepárame» con su lista de cotejo (1.3.9)
- `Cronometro.lua` — el cronómetro de las mazmorras (1.3.7)
- `Datos.lua` — datos y progreso
- `EnVivo.lua` — la mazmorra en vivo (1.2.9)
- `MapaDentro.lua` — el mapa por dentro (1.3.9)
- `ParaMi.lua` — «¿Qué cae aquí para mí?» (1.4.0, mejora 43)
- `Piezas.lua` — las piezas propias de la página, hechas con el Kit
- `Plan.lua` — qué misiones de una mazmorra puedes tomar ya y qué le falta a cada una de las demás
- `Reemplazos.lua` — toma el lugar del diario de mazmorras del motor y de su tarjeta de "mazmorra abierta"
- `Reiniciar.lua` — «Reiniciar la mazmorra» al salir 1.4.0 (diario, 91)
- `Resumen.lua` — el resumen al terminar una mazmorra (1.3.8)
- `Textos.lua` — textos en inglés El español es el idioma principal: cada texto se escribe en español en el código, dentro de L["..."], y aquí va su traducción al inglés.…
- `Vista.lua` — la página en la ventana de Alfa, hecha con el Kit

### `src/Alfa_Mundo/` — 26 archivos. 10.191 líneas
Pruebas que lo usan (16): `prueba_137_mundo.lua`, `prueba_137c_mundo.lua`, `prueba_137d_datos.lua`, `prueba_138_facciones.lua`, `prueba_138_mundo.lua`, `prueba_139_bandos.lua`, `prueba_140_diario.lua`, `prueba_140_mundo.lua` y más

- `Buscar.lua` — buscar un lugar por su nombre y la leyenda de las capas (1.3.9, mejora 78)
- `Capas.lua` — un solo control de capas para todo lo que se pinta en los mapas
- `Datos.lua` — geometría del mapa continuo
- `Descubrir.lua` — lo que te falta en tu zona (1.2.9)
- `DistanciaPines.lua` — a qué distancia está cada pin (1.3.7c)
- `Editor.lua` — la ficha de un marcador, para ponerlo o cambiarlo (Toxic / La Jauría)
- `Emergente.lua` — la base de los paneles que se abren desde un botón (las capas y los marcadores)
- `Entradas.lua` — entradas y salidas
- `Horarios.lua` — los horarios de barcos de La Jauría (1.4.0, mejora 37)
- `Ir.lua` — «Llévame» a quien sea, escribiendo su nombre (1.4.0, mejora 39)
- `Lienzo.lua` — el arte del mapa continuo
- `MapaJuego.lua` — el control de capas en el mapa del juego y la tecla del mapa
- `Marcadores.lua` — tus marcadores
- `Marcas.lua` — lo que se dibuja encima del mapa continuo (Toxic / La Jauría)
- `MisionesColor.lua` — misiones cercanas por color (1.3.8)
- `Mundo.lua` — la página del módulo, sus comandos y su tecla (Toxic / La Jauría)
- `PanelCapas.lua` — el panel de capas que abre el botón del mapa (el de Alfa y el del juego)
- `PanelMarcadores.lua` — la lista de tus marcadores
- `Peligros.lua` — los peligros de tu zona (1.3.0)
- `Rastro.lua` — tu camino de hoy en el mapa de Alfa (1.3.7c)
- `Servicios.lua` — tus entrenadores y tus provisiones en el mapa (1.4.0, mejoras 35 y 36)
- `TerrenoDatos.lua` — qué mosaicos del minimapa tiene cada continente (datos). GENERADO desde TerrainWorldMap (MIT, Dramacydal; LICENSE-TerrainWorldMap.txt),…
- `Textos.lua` — textos en inglés (el español es el idioma principal)
- `Trayecto.lua` — tu camino en el mapa de Alfa
- `Ventana.lua` — la ventana del mapa continuo
- `VueloCerca.lua` — «Aquí cerca hay un vuelo que no conoces» 1.4.0 (diario, 99)

### `src/Alfa_Nucleo/` — 29 archivos. 15.726 líneas
Pruebas que lo usan (1): `prueba_121.lua`

- `Comandos.lua` — los comandos de /alfa a la mano (1.4.0, 110 y 111)
- `Entrada.lua` — la entrada en silencio (1.3.3)
- `Errores.lua` — los errores de Alfa que se atrapan (1.2.9)
- `Eventos.lua` — eventos más baratos (1.3.5)
- `Faccion.lua` — la Horda y la Alianza, cada una por su lado (1.3.8)
- `Informe.lua` — los datos técnicos del reporte (1.3.9)
- `Kit/Anuncio.lua` — el anuncio animado (1.2.7; estilos y turnos, 1.3.7; la franja de cine, 1.4.0)
- `Kit/Ayuda.lua` — «¿Qué es esto?», la ayuda de cada control (1.3.0)
- `Kit/Bando.lua` — la temática por bando (1.3.9, pedido de Toxic)
- `Kit/Basicos.lua` — piezas básicas
- `Kit/Bloques.lua` — bloques de página
- `Kit/Estilos.lua` — elegir el estilo y el acento
- `Kit/Firmas.lua` — la firma de cada módulo (1.3.8)
- `Kit/Formas.lua` — formas del diseño A
- `Kit/Movible.lua` — todo lo de Alfa en pantalla se mueve (1.4.0, n.º 78)
- `Kit/Plantillas.lua` — plantillas de página
- `Kit/Raton.lua` — el ratón es del jugador (1.4.1)
- `Kit/Tokens.lua` — tokens del diseño A
- `Kit/Ventanas.lua` — ventanas, diálogos y avisos
- `Limpia.lua` — la pantalla limpia (1.3.0)
- `Modo.lua` — Alfa sencillo o completo (1.2.9)
- `Momentos.lua` — los momentos (1.3.7)
- `Nucleo.lua` — Núcleo de los módulos propios
- `Reloj.lua` — un solo reloj para las tareas de Alfa (1.2.9)
- `Respaldos.lua` — respaldos automáticos de tus ajustes (1.2.9)
- `Revisar.lua` — /alfa revisar (1.4.0)
- `Textos.lua` — textos en inglés del Kit para clientes que no son esMX/esES. El español es el idioma principal: aquí solo va su traducción
- `UltimaVez.lua` — «La última vez…» (1.3.8)
- `Zonas.lua` — llegar a una zona se siente (1.3.7)

### `src/Alfa_Pesca/` — 22 archivos. 9.995 líneas
Pruebas que lo usan (12): `prueba_138_revision.lua`, `prueba_139_bolsas.lua`, `prueba_139_modulos.lua`, `prueba_140_bugs.lua`, `prueba_140_control.lua`, `prueba_140_oficios.lua`, `prueba_140_secretos.lua`, `prueba_141_raton.lua` y más

- `Barra.lua` — la barra de pesca
- `Cocina.lua` — cocina junto al agua
- `Compat.lua` — Pesca
- `Datos.lua` — los datos fijos de la pesca
- `Diario.lua` — el diario de pesca
- `Equipo.lua` — el equipo, los cebos y los juguetes de pesca
- `Estadisticas.lua` — estadísticas y logros
- `Guia.lua` — la guía de pesca
- `Jauria.lua` — la tabla de pescadores de La Jauría
- `MetaDia.lua` — la meta del día (1.4.0, plan 49;
- `Metas.lua` — las metas de pesca
- `Pagina.lua` — su página en la ventana de Alfa
- `Pelear.lua` — «A pelear» / «Volver a mi equipo»
- `Pesca.lua` — Pesca
- `Pescador.lua` — tamaños, récords, tu nivel de pescador y el pez de la semana
- `Previa.lua` — la ventana de antes de pescar
- `Registro.lua` — el registro
- `Textos.lua` — textos en inglés para clientes que no son esMX/esES. El español es el idioma principal: aquí solo va su traducción
- `Ventana.lua` — la ventana de pesca
- `VistaCocina.lua` — la pestaña Cocina
- `VistaPescador.lua` — la pestaña Pescador
- `VistaSesiones.lua` — la pestaña Sesiones

### `src/Alfa_Recoleccion/` — 14 archivos. 11.572 líneas
Pruebas que lo usan (9): `prueba_128_interfaz.lua`, `prueba_137_oficios.lua`, `prueba_139_oficios.lua`, `prueba_139_revision.lua`, `prueba_140_dia.lua`, `prueba_140_diario.lua`, `prueba_140_oficios.lua`, `prueba_141_materiales.lua` y más

- `Avisos.lua` — dos avisos en el momento justo 1.4.0 (diario, 96 y 97)
- `Base.lua` — base de nodos de WoW Forever
- `Catalogo.lua` — el catálogo de recursos,)
- `Deteccion.lua` — saber qué recolectaste y dónde,)
- `Junta.lua` — los pasos de guía que piden juntar un mineral o una hierba,). 1.4.0, plan 73 (Toxic: «buscando Mena de estaño a nivel 33 en Los Humedales la flecha me…
- `Llevar.lua` — «Llévame» a un material que se recolecta,). 1.3.9, pedido de Toxic: «Buscando plata me manda a un lugar donde literalmente no hay»
- `Mapa.lua` — los nodos y la ruta en el mapa del mundo,)
- `MapaMundo.lua` — los nodos en el mapa continuo de Alfa_Mundo,). 1.1.8
- `Minimapa.lua` — los nodos en el minimapa,)
- `Nodos.lua` — los nodos, los filtros y el historial,)
- `Pines.lua` — el aspecto de un pin y su cuadro de información,). Lo comparten el mapa del mundo y el minimapa
- `Recoleccion.lua` — nodos, rutas de farmeo e historial
- `Ruta.lua` — la ruta de farmeo,)
- `Textos.lua` — textos en inglés para clientes que no son esMX/esES. El español es el idioma principal y va en el código, dentro de L["..."]

### `src/Alfa_Rutas/` — 61 archivos. 24.527 líneas
Pruebas que lo usan (38): `prueba_140_hud.lua`, `prueba_140_misiones.lua`, `prueba_140_oficios.lua`, `prueba_141_misiones.lua`, `prueba_botones.lua`, `prueba_humedales.lua`, `prueba_letras.lua`, `prueba_rutas.lua` y más

- `Asistente.lua` — el asistente "¿Qué quieres hacer?"
- `Banda.lua` — la banda de color de los títulos 1.4.0 (70)
- `Barcos.lua` — barcos y zepelines en el mapa, con su cuenta atrás 1.3.0
- `Base.lua` — piezas comunes (ramas, datos guardados, plantillas, exportar e importar)
- `Biblioteca.lua` — la biblioteca de guías
- `Cadena.lua` — la cadena completa de una misión 1.3.0
- `Cadenas.lua` — las cadenas de misiones 1.2.7
- `Camino.lua` — elegir el camino cuando una guía termina en varias (Toxic / La Jauría)
- `Cerca.lua` — «Buscar cerca», los lugares que más se buscan
- `Cerrar.lua` — el plan para cerrar tus misiones ("Liberar"). Toxic / La Jauría
- `CerrarTodo.lua` — «Cerrar mis misiones», de punta a punta 1.3.9
- `Circuito.lua` — el circuito de la zona 1.3.0
- `Ciudad.lua` — «Cerrar mis misiones» con la vuelta a la ciudad 1.4.0 (30)
- `Comprar.lua` — «Comprar lo que falta» en las guías de oficio 1.4.0 (31)
- `Confirmar.lua` — «Confirma en el juego» 1.4.0 (7)
- `Contrato.lua` — lo que esta área ofrece a las demás
- `Diario.lua` — tu registro casi lleno 1.3.9 (27)
- `Disponible.lua` — si una misión se puede tomar ya y, si no, qué falta para tomarla
- `EnCurso.lua` — «Lo que sigues» (1.3.7), todo lo que tienes en curso
- `Entrega.lua` — el PNJ de la entrega, marcado en el minimapa 1.4.0 (29)
- `Entrenador.lua` — «Aprender todo» en el entrenador 1.4.0 (diario, 90)
- `Foco.lua` — modo foco en el rastreador 1.2.9
- `Grifo.lua` — «Toma el grifo» 1.3.8
- `Grises.lua` — misiones grises que puedes soltar 1.3.0
- `Grupo.lua` — misiones de élite y compartir con tu grupo 1.2.9
- `Guias.lua` — las rutas como guías del motor. Cada ruta compilada es una guía del paquete "mis-rutas" (A.RegisterPack / A.RegisterGuide, como cualquier paquete de la…
- `Historial.lua` — tus guías terminadas, con su fecha y su tiempo 1.4.0 (32)
- `Hogar.lua` — «Piedra de hogar a tiempo» 1.2.8
- `Hora.lua` — «Una hora de caza» y cuánto te falta -- 1.2.7
- `Indice.lua` — el índice de misiones de este personaje y las piezas para medirlas (XP, oro estimado, dónde empiezan y terminan, cuánto camino y esfuerzo llevan) y para…
- `Ligero.lua` — lo que se sabe sin el Codex 1.3.2
- `MapaGrupo.lua` — el mapa de misiones de tu grupo 1.3.0
- `MiNivel.lua` — «Saltar a mi nivel» 1.4.0 (26)
- `Nivel.lua` — pasos de nivel claros 1.2.9
- `ObjetoMision.lua` — el botón del objeto de misión, más claro 1.3.0
- `Oficios.lua` — las guías de oficios de Alfa 1.3.9, pedido de Toxic: «las guías de profesiones están algo genéricas, por no decir que son de ayuda cero»
- `OficiosComprar.lua` — «Comprar lo que falta» en las guías de oficios de Alfa (1.4.0, plan 31;
- `OficiosCrear.lua` — las guías de oficios de fabricación (Herrería, Alquimia, Sastrería, Peletería, Ingeniería, Encantamiento, Cocina y Primeros auxilios). 1.3.9
- `OficiosDatos.lua` — los hechos de las guías de oficios de Alfa 1.3.9
- `OficiosJuntar.lua` — las guías de oficios de recolección (Minería, Herboristería, Desuello). 1.3.9
- `Pagina.lua` — la página Ruta de la ventana de Alfa
- `PaginaPlanes.lua` — la sección Planes de la ventana de Alfa (1.3.7,
- `Peligro.lua` — «Zona peligrosa» 1.2.8
- `Plan.lua` — el planificador. Elige las misiones de cada tramo, las ordena por el camino más corto con el planificador de paradas del motor (Dungeons.PlanStops, el mismo…
- `Planes.lua` — Mis planes, listas de metas que arma el jugador
- `Rastreador.lua` — el rastreador de pasos
- `Recoger.lua` — dos guías al momento
- `Recompensa.lua` — qué recompensa elegir en cada misión de tu guía 1.4.0 (28)
- `Restablecer.lua` — restablecer una guía y empezar desde un paso 1.3.9 (pedido de Toxic)
- `RutaGrupo.lua` — seguir la ruta de alguien de tu grupo 1.3.3
- `Rutas.lua` — las acciones de tus rutas propias (seguir una, agregarle un objeto) y el comando /alfa rutas
- `Siguiente.lua` — la siguiente guía, sola 1.2.9
- `Tareas.lua` — trabajo en segundo plano. Leer miles de misiones u objetos de una vez congelaría el juego, así que cada trabajo corre en una corrutina que se reparte en…
- `Textos.lua` — textos en inglés (el español es el idioma principal)
- `VentanaSimple.lua` — una ventana sencilla con una línea de arriba y una lista 1.3.0: la usan las misiones grises, la cadena completa y «Llévame a…»
- `Viaje.lua` — «Llévame a…», de donde estés a donde quieras 1.3.0
- `VistaArbol.lua` — el bloque "Mis rutas" de la página Ruta
- `VistaMisiones.lua` — el bloque "Tu plan de misiones" de la página Ruta (Toxic / La Jauría)
- `VistaPlanes.lua` — Mis planes en pantalla, la sección de la página Ruta y el editor de un plan
- `Vuelo.lua` — vuelo listo 1.2.9
- `Vuelta.lua` — «Vuelta a entregar» 1.2.8

### `src/Alfa_Vista/` — 6 archivos. 2.157 líneas
Pruebas que lo usan (3): `prueba_132_hoy.lua`, `prueba_137_oficios.lua`, `prueba_140_bugs.lua`

- `Datos.lua` — el catálogo de ajustes y los preajustes
- `Filtros.lua` — los filtros que dibuja Alfa
- `Motor.lua` — leer y escribir las variables del juego
- `Pagina.lua` — su página, los comandos y la API para otros módulos
- `Textos.lua` — textos en inglés para clientes que no son esMX/esES El español es el idioma principal
- `Ventana.lua` — la ventana

### `motor/Alfa/Core/` — 1 archivos. 188 líneas

- `Reemplazos.lua` — los reemplazos de las ventanas del motor,). La tabla de claves, con quien abre cada ventana, esta en docs/KIT.md

### `motor/Alfa/Interfaz/` — 4 archivos. 560 líneas

- `Textos.lua` — Textos de la interfaz propia del motor
- `TextosGuia.lua` — Textos de la interfaz (Guia). Mismo formato que Textos.lua: la clave es el texto en espanol y aqui va su ingles. Se carga despues de Textos.lua (Alfa.toc),…
- `TextosVentanas.lua` — Textos de la interfaz (Ventanas). Mismo formato que Textos.lua: la clave es el texto en espanol y aqui va su ingles. Se carga despues de Textos.lua…
- `TitulosGuia.lua` — Títulos de pasos de guía en tu idioma (1.3.9)

### `motor/Alfa/Maps/` — 1 archivos. 245 líneas

- `MinimapButton.lua` — el clic izquierdo abre o cierra la ventana principal de Alfa (y trae de vuelta un Alfa oculto); ocultar Alfa queda en el menu del clic derecho, que conserva…

### `motor/Alfa/Nav/` — 2 archivos. 3.498 líneas

- `Alerts.lua` — a heads-up before your boat, zeppelin or tram comes in, for anyone waiting away from the keyboard
- `Arrow.lua` — turns smoothly toward the target, with distance, label and ETA underneath, and while a timed quest's timer runs its countdown between the distance and the…

### `motor/Alfa/Quests/` — 1 archivos. 488 líneas

- `PartyChat.lua` — in a party, plain chat lines about your quests that everyone in the party sees, Polestar or not, each starting with a star marker: "{rt1} Polestar: [Plagued…

### `motor/Alfa/Rares/` — 1 archivos. 560 líneas

- `Toast.lua` — a small card in Polestar's world with the welcome's chrome, read in three steps. On top, under the gold rim (W.Rim), a compact night band (the band, and in…

### `motor/Alfa/Theme/` — 2 archivos. 6.675 líneas

- `Theme.lua` — colours, fonts, media and frame skins for the UI and Nav. Basado en Polestar.Theme (, The Polestar authors); reescrito por para la interfaz propia de Alfa…
- `Widgets.lua` — the widget kit the guide window, picker and options are built from. Every piece paints itself from Alfa.Theme. Basado en Polestar.Widgets (, The Polestar…

### `motor/Alfa/UI/` — 9 archivos. 18.527 líneas

- `Dungeons.lua` — El diario de mazmorras del motor, una seccion del centro (la ventana del selector de guias). Basado en la seccion Dungeons de Polestar (, The Polestar…
- `GameMenu.lua` — el botón «Alfa» del menú Esc hace lo mismo que el ícono del minimapa: clic, cierra el menú y abre la ventana de Alfa (la última página que viste); clic…
- `GuideFrame.lua` — el acomodo propio de la ventana de guia,; docs/INTERFAZ.md), sobre la ventana de guia de Polestar (, The Polestar authors). De arriba abajo:
- `Lookup.lua` — El Buscador "como conseguirlo", una seccion del centro (la ventana del selector de guias, UI.RegisterSection "Lookup"). Basado en el Lookup de Polestar (,…
- `Options.lua` — La ventana principal de Alfa (docs/INTERFAZ.md). Basada en la ventana de opciones de Polestar (, The Polestar authors); reescrita por Arriba, en el armazon…
- `Picker.lua` — El selector de guias y el centro de Alfa (la ventana AlfaPicker). Basado en el menu de guias de Polestar (, The Polestar authors); reescrito por con la…
- `StepList.lua` — la lista de pasos con el acomodo propio de la ventana de guia,; docs/INTERFAZ.md): cada paso, una tarjeta de esquinas cortadas en el color de los paneles,…
- `Welcome.lua` — la bienvenida,; docs/INTERFAZ.md). Reemplaza la presentacion de Polestar (cielo nocturno, demostracion de ruta y textos de su proyecto) por una bienvenida…
- `WhatsNew.lua` — las novedades,; docs/INTERFAZ.md). Las notas de Polestar cambian por las de Alfa; el mecanismo de cuando se muestran es el de Polestar (, The Polestar authors)

