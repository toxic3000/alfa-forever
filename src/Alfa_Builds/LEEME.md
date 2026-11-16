# Alfa - Builds

Página **Builds** de la ventana de Alfa (orden 14, ícono `icon-skill`). Ayuda a armar el personaje aunque no sepas ni por dónde empezar: guía de talentos, ayuda de rotación y comparar equipo.

## Qué hace

- **Asistente:** detecta tu clase y la rama donde tienes más puntos. Eliges un **objetivo** (Subir solo, Mazmorras, Tanque, JcJ) y un **estilo** (Tranquilo, Equilibrado, Arriesgado, con un medidor de riesgo). Alfa muestra el build recomendado con su porqué, tus próximos talentos, la **prioridad de estadísticas** (con barras y por qué sirve cada una), las **profesiones sugeridas** y consejos. Si no existe la combinación exacta, usa la más parecida y lo dice.
- **Talentos:** el árbol dibujado con tus puntos y el plan encima (número de orden, borde verde = hecho, dorado = falta, naranja = fuera del plan, flechas), y la lista de qué tomar y en qué orden por nivel. Los talentos se resuelven en el juego con `C_Traits` (por spellID, luego por nombre); si uno no existe se avisa y se salta.
- **Aplicar con un clic:** fuera de combate y con confirmación (`W.Modal`): muestra qué rangos se compran con tus puntos libres y luego compra (`C_Traits.PurchaseRank`) y confirma (`C_ClassTalents.CommitConfig`). Si algo falla explica por qué (combate, sin puntos, fila cerrada, flecha, el juego lo rechazó). Alfa nunca quita talentos.
- **Pesos:** cada build trae su escala (pesos del motor para su rama y tu nivel, ajustados por estilo y objetivo). Al elegir un build se activa como escala del motor (`Custom: Alfa: <build>`), así las flechas de mejora de Alfa la usan. Se renueva al subir de nivel.
- **Equipo meta:** busca en el Codex lo mejor que tu clase puede usar cerca de tu nivel, por ranura, puntuado con los pesos del build y comparado con lo que llevas, con el botón **Cómo conseguirlo** (el "Guíame" del motor).
- **Combate (solo lo permitido):** la sugerencia oficial de Blizzard (`C_AssistedCombat.GetNextCastSpell`) como ícono movible con su tecla; el resaltado oficial del botón si el cliente lo trae, o un borde de Alfa en tu barra si no; alertas de reacción (guerrero: Abrumar, Revancha, Ejecutar, Ataque victorioso; pícaro y cazador: las suyas) con `C_Spell.IsSpellUsable`, su recarga y el brillo oficial; temporizador de golpe con `PLAYER_SWING`; panel compacto de tus estadísticas.
- **Compartir:** exportar un build (o tus talentos de ahora) en una cadena `ALFA1;...` e importarla.
- **Recordatorio:** al subir de nivel, una línea en el chat con el talento que toca. Los recordatorios de buffs son del módulo Inicio.

Contenido: el guerrero completo (13 builds: Armas solo ×3, Armas mazmorras, Armas JcJ, Furia solo ×2, Furia mazmorras, Furia JcJ, Protección tanque ×3, Protección solo). Las demás clases tienen un "Subir solo / Equilibrado" por rama. Todos revisados contra el árbol de Forever 1.60.1 (51 puntos, filas y flechas).

## Comandos

- `/alfa builds`: abre la página.
- `/alfa builds aplicar`: abre la vista previa para aplicar talentos.
- `/alfa builds mover`: desbloquea o fija los marcos en pantalla.
- `/alfa builds alerta`: muestra una alerta de prueba.

## Ajustes (pestaña Combate)

| Ajuste | Por omisión |
|---|---|
| Sugerencia de Blizzard; también fuera de combate; nombre del hechizo; marcar el botón; tamaño | sí; no; no; sí; 52 px |
| Alertas de reacción; con sonido; explicar por qué | sí; sí; sí |
| Temporizador de golpe | sí |
| Panel de estadísticas | no |
| Avisar al subir de nivel; activar los pesos al elegir un build | sí; sí |

Se guardan en `AlfaDB.settings.builds`. La elección de build, la pestaña y los builds importados van por personaje en `AlfaNucleoCharDB.builds`; las posiciones de los marcos en `AlfaNucleoDB.builds`.

## Para verificar en el juego

1. Con el guerrero, abrir `/alfa builds`: la cabecera dice tu rama y puntos libres; el árbol se dibuja con tus puntos reales y los nombres en español del cliente.
2. Elegir Tanque / Tranquilo: cambia a "Tanque muralla" y `/alfa gear` dice `Custom: Alfa: Tanque muralla`; las flechas de las bolsas cambian.
3. Con puntos libres, **Aplicar talentos**: la vista previa lista los rangos; al aceptar se aprenden y el chat dice cuántos. Probar también en combate (debe negarse) y sin puntos (debe explicar cuándo llega el siguiente).
4. Confirmar si en Forever el commit es instantáneo o tiene lanzamiento, y que llega `TRAIT_CONFIG_UPDATED` (o `CONFIG_COMMIT_FAILED`) tras `C_ClassTalents.CommitConfig`.
5. Revisar si algún talento sale en "No está en tu árbol" (cambios del parche de lanzamiento, p. ej. Furia: Flurry y Bloodthirst, Reckless Swings, Improved Whirlwind).
6. Equipo: **Buscar equipo para mi nivel** carga el Codex sin trabar el juego y muestra piezas por ranura; **Cómo conseguirlo** abre la guía.
7. En combate: el ícono de sugerencia cambia y muestra la tecla; el borde aparece en el botón correcto (también con la barra de actitud); Abrumar avisa cuando el enemigo esquiva; el temporizador de golpe sigue tus golpes; el panel no muestra errores con valores secretos.
8. Exportar un build, pegarlo en Importar y usarlo.
