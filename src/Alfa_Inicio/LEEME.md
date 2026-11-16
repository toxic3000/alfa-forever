# Alfa - Inicio

La portada de Alfa: la primera página de la ventana de Alfa (orden 5, ícono de la casa). De un vistazo ves cómo va tu sesión, qué tienes que atender y cuál es tu siguiente paso.

## Qué hace

- **Cabecera:** tu nombre, nivel, clase y zona, el tiempo de sesión y tu barra de XP con la XP descansada detrás (en azul).
- **Tablero de la sesión:** tiempo, XP ganada, XP por hora, tiempo para subir de nivel, oro neto (ganado y gastado en el cuadro de ayuda), misiones entregadas, niveles subidos y muertes. Un `/reload` no corta la sesión. La XP por hora y el tiempo para subir salen del contador del motor (`Alfa.QoL.XP`), no se calculan dos veces.
- **Tu siguiente paso:** el paso actual de la guía con sus metas abiertas (las mismas palabras que la ventana de la guía), el avance de la guía y los botones *Abrir la guía* y *Elegir otra guía*.
- **Revisión rápida:** equipo (la pieza más gastada), bolsas, habilidades por entrenar, tu buff y tu descanso, con un botón que te lleva al reparador, al vendedor o a tu entrenador (la flecha de Alfa).
- **Accesos rápidos:** un mosaico por cada módulo de Alfa instalado, por su orden.
- **Diario:** las últimas sesiones de cada personaje, con una gráfica de barras (XP, XP por hora, oro o tiempo; la sesión de ahora es la última barra) y las cinco más recientes en lista. Al entrar al juego, un resumen de la sesión anterior.
- **Recordatorios** (avisos en pantalla con el estilo de Alfa; se arrastran para moverlos):
  - Durabilidad baja, al 30 % y al 10 % (este con sonido), diciendo qué pieza es.
  - Bolsas casi llenas o llenas.
  - Habilidades por aprender al llegar a una ciudad o posada (una vez por nivel). La tarjeta de habilidades al subir de nivel y la nota de entrenar de la guía son del motor; Inicio no las repite, solo pasa la nota a un aviso si la ventana de la guía está oculta.
  - Buff propio fuera de combate: Grito de batalla (guerrero, solo con 10 de furia o más), Intelecto Arcano y una armadura (mago), Entereza y Fuego interno (sacerdote), Marca de lo Salvaje (druida), Piel o Armadura demoníaca (brujo), un aura y una bendición (paladín), un aspecto (cazador), Escudo de relámpagos (chamán). El pícaro no tiene.
  - XP descansada: al entrar a una zona de descanso y cuando baja del umbral o se acaba.

## Comandos

- `/alfa inicio`: abre la portada.
- `/alfa sesion`: tu sesión de ahora en el chat.

## Ajustes (en la propia página, sección *Recordatorios*)

| Ajuste | Por omisión |
|---|---|
| Avisos de durabilidad, primer aviso y aviso urgente | sí, 30 %, 10 % |
| Aviso de bolsas, con estos espacios libres o menos | sí, 4 |
| Habilidades por aprender en la ciudad, desde cuántas | sí, 1 |
| Buff fuera de combate, repetir a lo más cada, y avisar si le queda menos de | sí, 3 min, solo si falta |
| XP descansada, avisar cuando baje de | sí, 5 % de nivel |
| Resumen de la sesión anterior al entrar | en un aviso y en el chat |
| Duración de un aviso, sonido en los urgentes, sesiones del diario | 10 s, sí, 30 |

Además, en *Habilidades por entrenar* están los dos ajustes del motor que van con ese recordatorio (la tarjeta al subir de nivel y la nota de la guía). Todo se guarda en `AlfaDB.settings.inicio`; el diario, por personaje, en `AlfaNucleoCharDB.inicio`.

## Para verificar en el juego

1. `/alfa inicio`: la página abre primero, se ve completa y los números del tablero cambian cada segundo (tiempo de sesión).
2. Matar algo y entregar una misión: suben XP ganada, XP por hora y misiones; el tiempo para subir aparece.
3. `/reload`: la sesión sigue (no vuelve a cero). Salir y volver a entrar con el personaje: sale el resumen de la sesión anterior y aparece en el diario.
4. Morir una vez: cuenta la muerte y, con equipo gastado, avisa la durabilidad con el nombre de la pieza. Confirmar que `GetInventoryItemDurability` da valores (piezas sin durabilidad no salen).
5. Llenar las bolsas hasta 4 espacios: aviso. Con 0: aviso urgente.
6. Guerrero: aprender Grito de batalla, pelear y al terminar con furia debe avisar si falta; con el buff puesto, la revisión rápida dice *Activo*. Revisar que el nombre del buff salga en español.
7. Entrar a una posada: aviso de descanso. Llegar a la ciudad con habilidades por aprender: aviso con el entrenador; el botón lleva la flecha.
8. Ocultar la ventana de la guía y subir de nivel par: la nota de entrenar del motor llega como aviso.
9. Botones *Abrir la guía* y *Elegir otra guía*, los mosaicos de los módulos y la gráfica (cambiar entre XP, XP/h, Oro y Tiempo; pasar el cursor por una barra).
10. Probar un aviso desde los ajustes, moverlo y devolverlo a su lugar.
