# Alfa - Builds (página Talentos)

Página **Talentos** de la ventana de Alfa (sección Personaje, clave `builds`, ícono `ic-talentos`). Te dice **qué talento poner ahora y por qué** y lo aplica con un clic; tu build se elige en dos clics. Hecha con el Kit (`docs/KIT.md`, plantilla Tablero).

## La página

1. **Arriba, en grande, qué hacer ahora** (una sola tarjeta que cambia según tu caso):
   - *Pon ahora*: el talento que toca, su porqué, su rango, tu rama y tus puntos libres, con **Aplicar** (o "Aplicar N puntos") y "Verlo en el árbol". En combate lo dice.
   - *Tu siguiente talento*: sin puntos libres, cuál sigue y en qué nivel llega (antes del 10, "Tu primer talento").
   - *Tus puntos van por otro camino*: con 3 o más puntos fuera del build y ninguno libre; explica que Alfa no quita talentos y ofrece seguir el build de la rama que ya llevas.
   - *Lo que sigue no está en tu árbol*, *el juego todavía no carga tu árbol* (con "Abrir la ventana de talentos") y *Build completo* (lleva a Equipo).
2. **Tu camino**: "Quiero" (Subir solo, Mazmorras, Tanque, JcJ), "Cómo juego" (Tranquilo, Equilibrado, Arriesgado) y la rama si hay varias, en segmentos; debajo, el build que resulta con su resumen, insignias (rama, arma, recomendado, importado, "lo más parecido") y su avance en huellas.
3. **Tu árbol** (`Lienzo.lua`): las tres ramas en paneles, tus puntos reales y el plan encima (número de orden, verde = ya lo tienes, anillo = toca ahora, acento tenue = falta, rojo = fuera del plan) y las flechas del árbol. El cuadro de cada talento es el del juego con lo que dice Alfa.
4. **Plan por nivel**: los 6 talentos que siguen con su nivel, rango, estado y porqué; "Ver todo el plan" muestra también lo hecho y lo de después.
5. **Consejos para jugarlo** (si el build los trae).
6. **Más para tu personaje**: Equipo y estadísticas, Compartir con la manada y Ayudas de combate.
7. **Avisos** (al final): el del talento que toca, comparar equipo con tu build y los de hechizos nuevos y rangos viejos.

**Equipo y estadísticas** y **Compartir** son vistas de la misma página con "Volver a Talentos": los pesos de tus flechas de mejora (activos o no, con el botón), qué estadísticas buscar y por qué, lo mejor para tu nivel por ranura con "Cómo conseguirlo", las profesiones que te sirven; y la cadena `ALFA1;...` para copiar, importar y la lista de importados (solo si hay).

El porqué de cada talento: el del build (los del guerrero lo traen), si no, lo que hace según el juego (`C_Spell.GetSpellDescription`), y si no, su lugar en el build.

## Ventanas y avisos del motor que reemplaza (`Avisos.lua`)

| Clave | Ahora |
|---|---|
| `SHOW_TALENTS` | Abre esta página. |
| `SPELL_CARDS` | Aviso del Kit: "Nivel N: X hechizos nuevos para aprender", cuáles, con qué entrenador (o en cuántos pasos te lleva tu guía) y cuánto cuestan, con **Llévame**. Los rangos viejos en tus barras: cuáles y **Actualizar mis barras**. Al cerrarse avisa al motor para que pase el siguiente. |
| `CLASS_CARD` | Aviso del Kit, una vez por misión y etapa: "Misión de clase: ...", qué te enseña o te da, quién te la da y dónde, con **Llévame**; ya tomada, a quién entregarla. |

Además, al subir de nivel (y una vez al entrar con puntos sin gastar) un aviso dice qué talento poner, con **Aplicar**. El recordatorio en el chat del motor (`talents.reminder`) se apaga una vez porque decía lo mismo (a veces de otro plan).

## Contrato

```lua
AlfaBuilds.SiguienteTalento() -> { nombre, icono, porque, rango, max, spell, nivel, libres, ahora, build } | nil
AlfaBuilds.Abrir(vista)   -- nil (Talentos), "equipo" o "compartir"
AlfaBuilds.Aplicar()      -- la vista previa y, si aceptas, aplica
```

`nil` sin build, con el árbol sin cargar o con el build completo. `ahora` es true cuando hay punto libre y se puede aplicar. Al cambiar tus talentos, tu build o tus puntos se dispara el mensaje `ALFA_TALENTOS` (para refrescar Hoy, por ejemplo).

## Aplicar

Fuera de combate y con confirmación (`K.Dialogo`): muestra qué rangos se compran con tus puntos libres y luego compra (`C_Traits.PurchaseRank`) y confirma (`C_ClassTalents.CommitConfig`). Si algo falla explica por qué (combate, sin puntos, fila cerrada, flecha, el juego lo rechazó). Alfa nunca quita talentos.

## Ayudas de combate

Ya no viven aquí: la ayuda de rotación, los avisos de reacción, la barra de golpe y el medidor son del módulo `Alfa_Combate` (página `combate`). Talentos solo muestra su tarjeta "Ayudas de combate" en "Más para tu personaje", y solo si esa página existe (`AlfaCombate.Abrir()`).

## Comandos

- `/alfa talentos` o `/alfa builds`: abre la página. `/alfa builds aplicar | equipo | compartir`.
- `/alfa builds mover`: se pasa al área de combate (`AlfaCombate.Mover()`).

## Datos

Ajustes en `AlfaDB.settings.builds` (`aviso`, `escalaAuto`). La elección de build y los importados van por personaje en `AlfaNucleoCharDB.builds`.

## Para verificar en el juego

1. Con puntos libres: la tarjeta de arriba dice "Pon ahora", el talento, su porqué y "Aplicar N puntos". Aplicar muestra la vista previa; al aceptar, el aviso "Listo: aprendiste N rangos" y la tarjeta pasa a "Tu siguiente talento". En combate debe negarse.
2. "Quiero" y "Cómo juego" cambian el build en un clic (Tanque → el de protección); "Rama" aparece si hay varias.
3. El árbol se ve completo y alineado en los tres paneles, con los nombres del cliente, el anillo en el que toca y las flechas entre talentos.
4. "Verlo en el árbol" baja hasta el árbol; "Ver todo el plan" muestra lo hecho.
5. Subir de nivel: aviso del talento que toca (con Aplicar) y aviso de hechizos nuevos con el entrenador y **Llévame** (la flecha lleva al entrenador). Cerrar el aviso deja pasar el siguiente aviso del motor.
6. Una misión de clase en la guía (ventana de guía del motor): sale el aviso con quién te la da y Llévame. Nota: con este reemplazo, la ventana de guía del motor ya no muestra la tarjeta ni la casilla de aceptar plegada en ella.
7. Equipo: los pesos se activan con un clic; "Buscar equipo para mi nivel" no traba el juego y muestra piezas con "Cómo conseguirlo".
8. Compartir: "Seleccionar para copiar" selecciona la cadena (Ctrl + C); pegar una cadena y "Importar" la agrega a "Tus builds importados" y "Seguir este build" la usa.
9. En inglés: la página sale traducida.

## 1.3.2

- El cuadro del ratón de cada talento (el plan y el árbol) termina con «Mayús + clic: ponerlo en el chat», lo único que hace un clic; las filas del plan ya no se iluminan como botón al pasar el ratón. Prueba: `tools/banco/prueba_132_personaje.lua`.

