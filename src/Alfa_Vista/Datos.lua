-- Alfa - Paisaje y gráficos: el catálogo de ajustes y los preajustes
-- (toxic3000 / La Jauría). GPL-3.0.
--
-- Solo datos. Cada fila es una variable de la consola del juego (CVar) con
-- su nombre real en el cliente de Forever 1.60.1 (las fuentes de cada una
-- están en LEEME.md). Lo que el cliente no tenga se oculta solo (Motor.lua
-- pregunta con C_CVar.GetCVarInfo antes de mostrar o escribir nada).
--
-- Una fila:
--   cvar      el nombre exacto de la variable
--   tipo      "deslizador" | "interruptor" | "lista"
--   min, max, paso   (deslizador) el rango del control y del valor escrito
--   opciones  (lista) { { "valor", texto }, ... }
--   menu      true: también está en el menú de opciones del juego (estrella)
--   padre     otra CVar de sí/no: apagada, esta fila se atenúa
--   reinicio  true: se ve después de reiniciar los gráficos
--   invertir  n: se muestra n - valor (la nitidez: en el juego 0 es lo más nítido)
--   buscar    palabras extra para el buscador (también en inglés)
-- Un grupo: { pestana, titulo, filas, info = { titulo, texto } (una fila sin control arriba) }

local ADDON, M = ...
local L = M.L

M.PESTANAS = {
	{ id = "calidad", nombre = L["Calidad"] },
	{ id = "entorno", nombre = L["Entorno"] },
	{ id = "camara", nombre = L["Cámara"] },
	{ id = "interfaz", nombre = L["Interfaz"] },
	{ id = "filtros", nombre = L["Filtros"] },
	{ id = "avanzado", nombre = L["Avanzado"] },
}

local NIVELES4 = { { "0", L["Bajo"] }, { "1", L["Medio"] }, { "2", L["Alto"] }, { "3", L["Ultra"] } }

M.GRUPOS = {
	---------------------------------------------------------------- Calidad
	{ pestana = "calidad", titulo = L["Sombras"], filas = {
		{ cvar = "shadowMode", tipo = "lista", titulo = L["Calidad de las sombras"],
			opciones = { { "0", L["Bajas"] }, { "1", L["Medias"] }, { "2", L["Altas"] }, { "3", L["Ultra"] } },
			texto = L["Qué tan definidas se ven las sombras del mundo y de los personajes."], buscar = "shadow quality" },
		{ cvar = "shadowTextureSize", tipo = "lista", titulo = L["Resolución de las sombras"],
			opciones = { { "1024", L["Normal"] }, { "2048", L["Alta"] } },
			texto = L["Sombras con bordes más finos. Usa más memoria de video."], buscar = "shadow texture size resolution" },
		{ cvar = "shadowNumCascades", tipo = "deslizador", min = 1, max = 4, paso = 1, titulo = L["Alcance de las sombras"],
			texto = L["Cuántas capas de sombra se dibujan: con más capas, las sombras nítidas llegan más lejos."], buscar = "shadow distance cascades" },
		{ cvar = "shadowBlendCascades", tipo = "interruptor", titulo = L["Unir las capas de sombra"],
			texto = L["Quita el corte visible donde termina una capa de sombra y empieza la siguiente."], buscar = "blend shadow cascades" },
		{ cvar = "shadowSoft", tipo = "interruptor", titulo = L["Sombras suaves"],
			texto = L["Orillas de sombra difuminadas, como la luz de verdad."], buscar = "soft shadows" },
	} },
	{ pestana = "calidad", titulo = L["Luz y efectos"], filas = {
		{ cvar = "SSAO", tipo = "lista", titulo = L["Oclusión ambiental"],
			opciones = { { "0", L["Apagada"] }, { "1", L["Baja"] }, { "2", L["Media"] }, { "3", L["Alta"] }, { "4", L["Ultra"] } },
			texto = L["Sombra suave en rincones, pliegues y bajo los objetos: da volumen a todo."], buscar = "ssao ambient occlusion" },
		{ cvar = "particleDensity", tipo = "deslizador", min = 10, max = 100, paso = 5, titulo = L["Densidad de partículas"],
			texto = L["Chispas, humo, polvo y efectos de hechizos."], buscar = "particle density effects" },
		{ cvar = "projectedTextures", tipo = "interruptor", titulo = L["Texturas proyectadas"],
			texto = L["Las marcas en el suelo de hechizos y áreas. Apagarlas esconde avisos de combate: mejor dejarlas encendidas."], buscar = "projected textures spell ground" },
	} },
	{ pestana = "calidad", titulo = L["Texturas y nitidez"], filas = {
		{ cvar = "textureFilteringMode", tipo = "lista", menu = true, titulo = L["Filtrado de texturas"],
			opciones = { { "0", L["Bilineal"] }, { "1", L["Trilineal"] }, { "2", L["Anisotrópico 2x"] }, { "3", L["Anisotrópico 4x"] }, { "4", L["Anisotrópico 8x"] }, { "5", L["Anisotrópico 16x"] } },
			texto = L["El suelo y los muros se ven nítidos aunque estén lejos o de lado."], buscar = "texture filtering anisotropic" },
		{ cvar = "ResampleAlwaysSharpen", tipo = "interruptor", titulo = L["Afinar siempre"],
			texto = L["Aplica la nitidez de abajo aunque no uses el escalado de resolución."], buscar = "sharpen sharpening always" },
		{ cvar = "ResampleSharpness", tipo = "deslizador", min = 0, max = 2, paso = 0.1, invertir = 2, menu = true, titulo = L["Nitidez"],
			texto = L["Más alto, más nítido. Demasiado puede marcar bordes y brillos."], buscar = "sharpness sharpen fsr" },
	} },

	---------------------------------------------------------------- Entorno
	{ pestana = "entorno", titulo = L["Distancia"], filas = {
		{ cvar = "farclip", tipo = "deslizador", min = 300, max = 8000, paso = 50, titulo = L["Distancia de visión"],
			texto = L["Hasta dónde se dibuja el mundo. Es lo que más FPS cuesta."], buscar = "view distance far clip draw" },
		{ cvar = "horizonStart", tipo = "deslizador", min = 200, max = 8000, paso = 50, titulo = L["Inicio del horizonte"],
			texto = L["Dónde empieza el paisaje lejano simplificado."], buscar = "horizon start" },
		{ cvar = "horizonClip", tipo = "deslizador", min = 400, max = 10000, paso = 100, titulo = L["Fin del horizonte"],
			texto = L["Hasta dónde llegan las montañas lejanas."], buscar = "horizon clip end" },
		{ cvar = "terrainLodDist", tipo = "deslizador", min = 100, max = 1000, paso = 25, titulo = L["Detalle del terreno"],
			texto = L["Distancia a la que el suelo conserva su forma completa."], buscar = "terrain lod detail distance" },
		{ cvar = "wmoLodDist", tipo = "deslizador", min = 100, max = 1000, paso = 25, titulo = L["Detalle de los edificios"],
			texto = L["Distancia a la que ciudades, torres y cuevas conservan su detalle."], buscar = "building wmo lod detail" },
		{ cvar = "doodadLodScale", tipo = "deslizador", min = 25, max = 200, paso = 5, titulo = L["Detalle de los objetos"],
			texto = L["Árboles, rocas, cercas y adornos: más alto, se ven completos desde más lejos."], buscar = "doodad lod scale objects trees" },
		{ cvar = "lodObjectCullSize", tipo = "deslizador", min = 1, max = 40, paso = 1, titulo = L["Ocultar objetos chicos lejanos"],
			texto = L["Más bajo, se siguen viendo objetos pequeños a lo lejos."], buscar = "lod object cull size" },
		{ cvar = "lodObjectFadeScale", tipo = "deslizador", min = 50, max = 300, paso = 10, titulo = L["Desvanecer objetos lejanos"],
			texto = L["Más alto, los objetos lejanos tardan más en desaparecer."], buscar = "lod object fade scale" },
	} },
	{ pestana = "entorno", titulo = L["Vegetación"], filas = {
		{ cvar = "groundEffectDensity", tipo = "deslizador", min = 16, max = 256, paso = 8, titulo = L["Más pasto"],
			texto = L["Cuánto pasto, flores y hierbas cubren el suelo."], buscar = "grass ground clutter density foliage pasto" },
		{ cvar = "groundEffectDist", tipo = "deslizador", min = 30, max = 600, paso = 10, titulo = L["Distancia del pasto"],
			texto = L["Hasta dónde se dibuja el pasto. Más lejos, menos «alfombra» que aparece al caminar."], buscar = "grass ground clutter distance" },
	} },
	{ pestana = "entorno", titulo = L["Niebla"], filas = {
		{ cvar = "disableHorizonStart", tipo = "interruptor", titulo = L["Quitar la niebla del horizonte"],
			texto = L["El paisaje lejano deja de perderse en la niebla espesa. A veces se nota dónde termina lo que está cargado."], buscar = "fog remove disable horizon quitar niebla" },
		{ cvar = "volumeFog", tipo = "interruptor", titulo = L["Niebla volumétrica"],
			texto = L["La niebla con cuerpo de valles, pantanos y amaneceres."], buscar = "volumetric fog volume" },
		{ cvar = "volumeFogLevel", tipo = "lista", padre = "volumeFog", opciones = NIVELES4, titulo = L["Calidad de la niebla"],
			texto = L["Más baja, la niebla se ve más ligera y cuesta menos."], buscar = "volumetric fog level" },
		{ cvar = "volumeFogInterior", tipo = "interruptor", padre = "volumeFog", titulo = L["Niebla en interiores"],
			texto = L["También dentro de cuevas, criptas y edificios."], buscar = "fog interior" },
	} },
	{ pestana = "entorno", titulo = L["Agua"], filas = {
		{ cvar = "waterDetail", tipo = "lista", opciones = NIVELES4, titulo = L["Detalle del agua"],
			texto = L["Olas y superficie del agua. Llega hasta Ultra (3) y no más: valores mayores pueden cerrar el juego, por eso Alfa no los deja."], buscar = "water detail liquid" },
		{ cvar = "reflectionMode", tipo = "lista", titulo = L["Reflejos en el agua"],
			opciones = { { "0", L["Apagados"] }, { "1", L["Bajos"] }, { "2", L["Altos"] }, { "3", L["Ultra"] } },
			texto = L["Qué se refleja en el agua: el cielo, el terreno y lo demás."], buscar = "water reflections" },
		{ cvar = "rippleDetail", tipo = "lista", titulo = L["Ondas"],
			opciones = { { "0", L["Bajas"] }, { "1", L["Medias"] }, { "2", L["Altas"] } },
			texto = L["Las ondas al caminar o nadar en el agua."], buscar = "water ripples" },
		{ cvar = "refraction", tipo = "interruptor", titulo = L["Refracción"],
			texto = L["El fondo se ve deformado a través del agua."], buscar = "water refraction" },
	} },
	{ pestana = "entorno", titulo = L["Cielo y clima"], filas = {
		{ cvar = "sunShafts", tipo = "lista", titulo = L["Rayos de sol"],
			opciones = { { "0", L["Apagados"] }, { "1", L["Bajos"] }, { "2", L["Altos"] } },
			texto = L["Haces de luz entre árboles, nubes y montañas."], buscar = "sun shafts god rays light" },
		{ cvar = "weatherDensity", tipo = "lista", titulo = L["Clima"],
			opciones = { { "0", L["Mínimo"] }, { "1", L["Bajo"] }, { "2", L["Medio"] }, { "3", L["Alto"] } },
			texto = L["Cuánta lluvia, nieve y polvo se ve cuando hay mal tiempo."], buscar = "weather density rain snow" },
	} },

	---------------------------------------------------------------- Cámara
	{ pestana = "camara", titulo = L["Distancia y velocidad"], filas = {
		{ cvar = "cameraDistanceMaxZoomFactor", tipo = "deslizador", min = 1, max = 2.6, paso = 0.1, menu = true, titulo = L["Alejar la cámara"],
			texto = L["Hasta dónde puedes alejar la cámara con la rueda. El juego puede limitarlo: Alfa muestra el valor que de verdad quedó."], buscar = "max camera distance zoom out" },
		{ cvar = "cameraZoomSpeed", tipo = "deslizador", min = 1, max = 50, paso = 1, titulo = L["Velocidad del zoom"],
			texto = L["Qué tan rápido se acerca y aleja la cámara."], buscar = "camera zoom speed" },
		{ cvar = "cameraFov", tipo = "deslizador", min = 50, max = 90, paso = 1, menu = true, titulo = L["Campo de visión"],
			texto = L["Más alto, ves más a los lados."], buscar = "fov field of view camera" },
	} },
	{ pestana = "camara", titulo = L["Seguimiento"], filas = {
		{ cvar = "cameraSmoothStyle", tipo = "lista", menu = true, titulo = L["La cámara te sigue"],
			opciones = { { "4", L["Solo al moverte"] }, { "1", L["Al moverte, solo de lado"] }, { "2", L["Siempre"] }, { "0", L["Nunca"] } },
			texto = L["Cuándo vuelve sola detrás de tu personaje."], buscar = "camera follow style smooth" },
		{ cvar = "cameraTerrainTilt", tipo = "interruptor", menu = true, titulo = L["Seguir el terreno"],
			texto = L["Inclina la cámara al subir y bajar cuestas."], buscar = "camera follow terrain tilt" },
		{ cvar = "cameraBobbing", tipo = "interruptor", menu = true, titulo = L["Balanceo al caminar"],
			texto = L["La cámara se mece un poco con tus pasos."], buscar = "head bob camera bobbing" },
		{ cvar = "cameraPivot", tipo = "interruptor", menu = true, titulo = L["Giro inteligente"],
			texto = L["Cerca del suelo, la cámara gira sobre tu personaje en lugar de chocar."], buscar = "smart pivot camera" },
	} },
	{ pestana = "camara", titulo = L["Choques de la cámara"], filas = {
		{ cvar = "cameraIndirectVisibility", tipo = "interruptor", titulo = L["Atravesar objetos pequeños"],
			texto = L["La cámara no salta hacia ti por cada árbol o poste entre ella y tu personaje."], buscar = "camera collision indirect visibility" },
		{ cvar = "cameraIndirectOffset", tipo = "deslizador", min = 1, max = 10, paso = 0.5, padre = "cameraIndirectVisibility", titulo = L["Tamaño de lo que atraviesa"],
			texto = L["Más alto, atraviesa objetos más grandes antes de acercarse."], buscar = "camera collision offset" },
		{ cvar = "cameraWaterCollision", tipo = "interruptor", menu = true, titulo = L["Chocar con el agua"],
			texto = L["La cámara se queda sobre el agua en lugar de meterse."], buscar = "camera water collision" },
	} },

	---------------------------------------------------------------- Interfaz
	{ pestana = "interfaz", titulo = L["Placas de nombre"], filas = {
		{ cvar = "nameplateMaxDistance", tipo = "deslizador", min = 10, max = 60, paso = 1, titulo = L["Distancia de las placas"],
			texto = L["Hasta qué distancia se ven las placas de nombre. El juego puede limitarlo."], buscar = "nameplate max distance range" },
		{ cvar = "nameplateShowEnemies", tipo = "interruptor", menu = true, titulo = L["Placas de enemigos"],
			texto = L["Las placas de nombre de los enemigos."], buscar = "nameplates enemies" },
		{ cvar = "nameplateShowEnemyPets", tipo = "interruptor", padre = "nameplateShowEnemies", titulo = L["Mascotas enemigas"],
			texto = L["También las de las mascotas de enemigos."], buscar = "nameplates enemy pets" },
		{ cvar = "nameplateShowEnemyGuardians", tipo = "interruptor", padre = "nameplateShowEnemies", titulo = L["Guardianes enemigos"],
			texto = L["Las criaturas que invocan los enemigos por un rato."], buscar = "nameplates enemy guardians" },
		{ cvar = "nameplateShowEnemyTotems", tipo = "interruptor", padre = "nameplateShowEnemies", titulo = L["Tótems enemigos"],
			texto = L["Para ver y romper los tótems enemigos."], buscar = "nameplates enemy totems" },
		{ cvar = "nameplateShowEnemyMinions", tipo = "interruptor", padre = "nameplateShowEnemies", menu = true, titulo = L["Esbirros enemigos"],
			texto = L["Los ayudantes de los enemigos."], buscar = "nameplates enemy minions" },
		{ cvar = "nameplateShowEnemyMinus", tipo = "interruptor", padre = "nameplateShowEnemies", menu = true, titulo = L["Enemigos menores"],
			texto = L["Los enemigos más débiles, que el juego marca con un signo de menos."], buscar = "nameplates enemy minus minor" },
	} },
	{ pestana = "interfaz", titulo = L["Texto de combate flotante"], filas = {
		{ cvar = "enableFloatingCombatText", tipo = "interruptor", menu = true, titulo = L["Texto sobre tu personaje"],
			texto = L["Lo que te pasa a ti: curación recibida, esquivas, recursos. Puede necesitar /reload la primera vez."], buscar = "floating combat text self" },
		{ cvar = "floatingCombatTextFloatMode_v2", tipo = "lista", padre = "enableFloatingCombatText", menu = true, titulo = L["Cómo se mueve"],
			opciones = { { "1", L["Hacia arriba"] }, { "2", L["Hacia abajo"] }, { "3", L["En arco"] } },
			texto = L["La dirección del texto sobre tu personaje."], buscar = "combat text float mode" },
		{ cvar = "floatingCombatTextCombatDamage_v2", tipo = "interruptor", menu = true, titulo = L["Daño sobre tus enemigos"],
			texto = L["Los números de tu daño encima de quien golpeas."], buscar = "combat damage numbers" },
		{ cvar = "floatingCombatTextCombatLogPeriodicSpells_v2", tipo = "interruptor", padre = "floatingCombatTextCombatDamage_v2", menu = true, titulo = L["Daño periódico"],
			texto = L["También el de venenos, sangrados y efectos que duran."], buscar = "periodic damage dot" },
		{ cvar = "floatingCombatTextPetMeleeDamage_v2", tipo = "interruptor", padre = "floatingCombatTextCombatDamage_v2", titulo = L["Golpes de tu mascota"],
			texto = L["Los números de los golpes de tu mascota."], buscar = "pet melee damage" },
		{ cvar = "floatingCombatTextPetSpellDamage_v2", tipo = "interruptor", padre = "floatingCombatTextCombatDamage_v2", titulo = L["Hechizos de tu mascota"],
			texto = L["Los números de las habilidades de tu mascota."], buscar = "pet spell damage" },
		{ cvar = "floatingCombatTextCombatDamageDirectionalScale_v2", tipo = "deslizador", min = 0, max = 3, paso = 0.1, padre = "floatingCombatTextCombatDamage_v2", titulo = L["Números que saltan de lado"],
			texto = L["En cero los números suben derechos; más alto, salen disparados hacia los lados."], buscar = "directional damage numbers scale" },
		{ cvar = "floatingCombatTextCombatHealing_v2", tipo = "interruptor", menu = true, titulo = L["Tu curación"],
			texto = L["Los números de lo que curas encima de quien recibe."], buscar = "combat healing numbers" },
	} },

	---------------------------------------------------------------- Avanzado
	{ pestana = "avanzado", titulo = L["Detalle fino"], filas = {
		{ cvar = "worldBaseMip", tipo = "lista", titulo = L["Texturas del mundo"],
			opciones = { { "0", L["Completas"] }, { "1", L["Medias"] }, { "2", L["Bajas"] }, { "3", L["Mínimas"] } },
			texto = L["Bajarlas ayuda en tarjetas de video con poca memoria."], buscar = "world texture base mip resolution" },
		{ cvar = "terrainMipLevel", tipo = "lista", titulo = L["Texturas del suelo"],
			opciones = { { "0", L["Completas"] }, { "1", L["Reducidas"] } },
			texto = L["La mezcla de texturas del terreno."], buscar = "terrain mip level" },
		{ cvar = "DepthBasedOpacity", tipo = "interruptor", titulo = L["Bordes suaves"],
			texto = L["Humo, agua y efectos se funden con lo que tocan en lugar de cortarse en seco."], buscar = "soft edges depth based opacity" },
	} },
	{ pestana = "avanzado", titulo = L["Efectos de pantalla del juego"], filas = {
		{ cvar = "ffxGlow", tipo = "interruptor", titulo = L["Resplandor"],
			texto = L["El brillo suave de luces y cielo en toda la pantalla."], buscar = "glow bloom full screen" },
		{ cvar = "ffxDeath", tipo = "interruptor", titulo = L["Pantalla gris al morir"],
			texto = L["El mundo pierde el color mientras eres espíritu."], buscar = "death desaturate grey" },
		{ cvar = "ffxNether", tipo = "interruptor", titulo = L["Efecto del vacío"],
			texto = L["El velo de pantalla de algunas zonas y hechizos de las sombras."], buscar = "nether effect" },
	} },
	{ pestana = "avanzado", titulo = L["HDR (Windows)"],
		info = { titulo = L["Necesita un monitor HDR"], texto = L["Solo sirve con un monitor HDR y el HDR de Windows encendido (Configuración > Pantalla). Sin eso, déjalo apagado: los colores se ven lavados."] },
		filas = {
		{ cvar = "HDROutput", tipo = "interruptor", reinicio = true, titulo = L["Imagen HDR"],
			texto = L["El juego manda la imagen en HDR."], buscar = "hdr output high dynamic range" },
		{ cvar = "HDRFactor", tipo = "deslizador", min = 1, max = 4, paso = 0.1, padre = "HDROutput", titulo = L["Fuerza del HDR"],
			texto = L["Cuánto más brillan las luces que en una pantalla normal. El juego no pasa del máximo de tu monitor."], buscar = "hdr factor" },
		{ cvar = "useHDRPeakBrightness", tipo = "interruptor", padre = "HDROutput", titulo = L["Fijar el brillo máximo"],
			texto = L["Usa el número de abajo en lugar del que detecta el juego."], buscar = "hdr peak brightness" },
		{ cvar = "HDRPeakBrightness", tipo = "deslizador", min = 200, max = 2000, paso = 50, padre = "useHDRPeakBrightness", titulo = L["Brillo máximo (nits)"],
			texto = L["El brillo más alto que da tu monitor; viene en su caja o su ficha."], buscar = "hdr peak nits" },
		{ cvar = "useHDRBrightness", tipo = "interruptor", padre = "HDROutput", titulo = L["Fijar el brillo de la interfaz"],
			texto = L["Usa el número de abajo para el blanco normal."], buscar = "hdr brightness paper white" },
		{ cvar = "HDRBrightness", tipo = "deslizador", min = 80, max = 500, paso = 5, padre = "useHDRBrightness", titulo = L["Brillo normal (nits)"],
			texto = L["El blanco de la interfaz y del cielo de día."], buscar = "hdr brightness nits" },
	} },
}

-- La fila de cada CVar (para el motor y el buscador).
M.FILA = {}
for _, g in ipairs(M.GRUPOS) do
	for _, f in ipairs(g.filas) do
		f.grupo = g
		M.FILA[f.cvar] = f
	end
end

---------------------------------------------------------------------------
-- Preajustes: solo gráficos (nunca cámara, ratón ni interfaz). Valores
-- elegidos por Alfa a partir de los rangos del juego; los que el cliente no
-- tenga se saltan.
---------------------------------------------------------------------------
local function preset(id, nombre, icono, texto, v)
	return { id = id, nombre = nombre, icono = icono, texto = texto, valores = v }
end

local C = { "farclip", "horizonStart", "horizonClip", "terrainLodDist", "wmoLodDist", "doodadLodScale",
	"lodObjectCullSize", "lodObjectFadeScale", "groundEffectDensity", "groundEffectDist", "volumeFog",
	"volumeFogLevel", "disableHorizonStart", "shadowMode", "shadowTextureSize", "shadowSoft",
	"shadowNumCascades", "shadowBlendCascades", "SSAO", "sunShafts", "waterDetail", "reflectionMode",
	"rippleDetail", "particleDensity", "weatherDensity", "projectedTextures", "textureFilteringMode" }

-- Una columna por preajuste, en el orden de C.
local COLUMNAS = {
	bajo = { 600, 450, 1000, 200, 150, 75, 25, 80, 16, 40, 0, 0, 0, 0, 1024, 0, 1, 0, 0, 0, 0, 0, 0, 40, 0, 0, 1 },
	medio = { 1000, 800, 1600, 400, 300, 100, 15, 100, 48, 70, 1, 1, 0, 1, 1024, 0, 2, 0, 1, 0, 1, 1, 1, 70, 1, 1, 3 },
	alto = { 2000, 1600, 3200, 600, 500, 125, 10, 150, 128, 150, 1, 2, 0, 2, 2048, 1, 3, 1, 2, 1, 2, 2, 2, 100, 2, 1, 4 },
	ultra = { 4000, 3000, 6000, 1000, 800, 150, 6, 200, 256, 300, 1, 3, 0, 3, 2048, 1, 4, 1, 4, 2, 3, 3, 2, 100, 3, 1, 5 },
	manada = { 2600, 2000, 4400, 700, 600, 125, 8, 175, 192, 220, 1, 1, 1, 2, 2048, 1, 3, 1, 2, 2, 2, 2, 2, 100, 3, 1, 5 },
}

local function columna(id)
	local t = {}
	for i, cvar in ipairs(C) do t[cvar] = tostring(COLUMNAS[id][i]) end
	return t
end

M.PRESETS = {
	preset("bajo", L["Bajo"], "ic-reloj", L["Lo más ligero: para equipos modestos o para subir los FPS en peleas grandes."], columna("bajo")),
	preset("medio", L["Medio"], "ic-ajustes", L["Equilibrado: se ve bien y corre bien en casi cualquier equipo."], columna("medio")),
	preset("alto", L["Alto"], "ic-apariencia", L["Más distancia, sombras finas y agua con reflejos."], columna("alto")),
	preset("ultra", L["Ultra"], "ic-raros", L["Todo al máximo seguro. Pide una tarjeta de video fuerte."], columna("ultra")),
	preset("manada", L["Paisaje de la manada"], "ic-lobo", L["Más pasto, más horizonte, niebla ligera y rayos de sol. Bonito sin pedir de más."], columna("manada")),
}
M.PRESET = {}
for _, p in ipairs(M.PRESETS) do M.PRESET[p.id] = p end
