-- Alfa - Pesca: los datos fijos de la pesca (toxic3000 / La Jauría). GPL-3.0.
--
-- Todo aquí son IDs del juego (objetos, hechizos, PNJ, misiones, mapas) y
-- números de reglas; los nombres se leen del cliente en vivo (el idioma del
-- jugador) y las fuentes, los lugares y los PNJ del Codex del motor cuando
-- hace falta (Alfa.Codex, que se carga solo al abrir el diario o la guía).
--
-- De dónde sale cada lista (para rehacerla con otra versión de los datos):
--   * CATALOGO: los objetos del Codex de Forever que se pescan: los peces
--     crudos (sin receta que los cree), los que dan los bancos de peces (las
--     fuentes "objeto" de cada banco), los peces de peso ("10 Pound...", que
--     se venden caros), los de concurso y de misión de pesca, las sorpresas
--     ("Bloated...", que se abren) y los cofres que salen del agua. Lo que
--     pesques y no esté aquí entra solo a tu diario.
--   * RECETAS: las recetas de Cocina del Codex (fuente "craft", habilidad
--     185) cuyo ingrediente principal es uno de esos peces, con su hechizo,
--     su habilidad y el objeto que la enseña.
--   * BANCOS: los bancos de peces del Codex (objetos) con los mapas donde
--     salen y lo que dan (las fuentes "objeto" de sus objetos).
--   * MISIONES: las misiones del Codex que dan los instructores de pesca
--     (rol "trainer:356"), Nat Pagle, los del concurso de Tuercespina, o que
--     piden un pez del catálogo.
--   * CEBOS: los cebos del juego y lo que suman; un cebo nuevo de Forever se
--     reconoce además por su descripción (Equipo.lua).

local ADDON, M = ...
local N = AlfaNucleo
local L = N.Textos(M.EN)
M.L = L

M.ID = "pesca"
M.SKILL = 356   -- Pesca
M.COCINA = 185  -- Cocina
M.FOGATA = 818  -- Fogata básica (un hechizo de Cocina)
M.CANA_BASICA = 6256

-- Los rangos de la profesión por su tope de habilidad. Desde: la habilidad con
-- la que ya se puede aprender el siguiente.
M.RANGOS = {
	{ tope = 75, nombre = L["Aprendiz"], siguiente = 50 },
	{ tope = 150, nombre = L["Oficial"], siguiente = 125 },
	{ tope = 225, nombre = L["Experto"], siguiente = 200 },
	{ tope = 300, nombre = L["Artesano"], siguiente = 275 },
	{ tope = 375, nombre = L["Maestro"] },
}

function M.NombreRango(tope)
	tope = tonumber(tope) or 0
	for _, r in ipairs(M.RANGOS) do
		if tope <= r.tope then return r.nombre, r end
	end
	return M.RANGOS[#M.RANGOS].nombre, M.RANGOS[#M.RANGOS]
end

---------------------------------------------------------------------------
-- Cebos: id -> { bono, habilidad que pide, minutos que dura }
---------------------------------------------------------------------------
M.CEBOS = {
	[6529] = { bono = 25, pide = 0, min = 10 },    -- Baratija brillante
	[6530] = { bono = 50, pide = 50, min = 10 },   -- Lombrices
	[6811] = { bono = 50, pide = 50, min = 10 },   -- Lente acuadinámica
	[6532] = { bono = 75, pide = 100, min = 10 },  -- Baratijas brillantes
	[7307] = { bono = 75, pide = 100, min = 10 },  -- Gusano comecarne
	[6533] = { bono = 100, pide = 100, min = 5 },  -- Atrayente de peces acuadinámico
}

-- Equipo con bonificación de Pesca que se consigue en Forever (para la guía:
-- "cómo conseguirlo" sale del Codex). La bonificación real se lee del objeto.
M.EQUIPO_GUIA = { 6256, 6365, 6366, 6367, 12225, 19022, 19970, 7996, 19972, 19969, 19979, 276203, 276272, 259846 }

-- Juguetes y cosas de pesca de Forever (se fabrican con Pesca) que salen en
-- el menú de juguetes además de lo que se reconozca en tus bolsas.
M.JUGUETES = { 279967, 279965, 279966 }

---------------------------------------------------------------------------
-- Catálogo de lo que se pesca. clase:
--   pez       un pez para cocinar o vender
--   trofeo    un pez de peso, raro y caro
--   concurso  los peces raros del concurso de Tuercespina
--   mision    los que pide una misión de pesca
--   sorpresa  un pez hinchado que se abre (trae otra cosa adentro)
--   botin     cofres, cajas y restos que salen del agua
---------------------------------------------------------------------------
local CATALOGO = {
	pez = { 6291, 6303, 6289, 6317, 6361, 6308, 21071, 6358, 6359, 6362, 8365, 21153, 4603, 13754, 13758, 13756,
		13755, 13759, 13760, 13889, 13893, 13888, 13890, 13422, 13757, 6522, 19807, 8959, 6299, 6458, 13546,
		19996, 286205 },
	trofeo = { 6292, 6294, 6295, 6309, 6310, 6311, 6363, 6364, 13885, 13886, 13882, 13883, 13884, 13887, 13876,
		13877, 13878, 13879, 13880, 13901, 13902, 13903, 13904, 13905, 13906, 13907, 13908, 13909, 13910, 13911,
		13912, 13913, 13914, 13915, 13916, 13917, 6360 },
	concurso = { 19803, 19805, 19806, 19808 },
	mision = { 16967, 16968, 16969, 16970 },
	sorpresa = { 6643, 6644, 6645, 6646, 6647, 8366, 13881, 13891, 21162, 21163, 21164, 21243 },
	botin = { 6351, 6352, 6353, 6354, 6355, 6356, 6357, 13875, 13918, 20708, 21113, 21150, 21228, 6307, 17057, 17058 },
}
M.CLASES = { "pez", "trofeo", "concurso", "mision", "sorpresa", "botin" }
M.CLASE = {}       -- id -> clase
M.CATALOGO = {}    -- { { id, clase } } en orden
for _, clase in ipairs(M.CLASES) do
	for _, id in ipairs(CATALOGO[clase]) do
		if not M.CLASE[id] then
			M.CLASE[id] = clase
			M.CATALOGO[#M.CATALOGO + 1] = { id = id, clase = clase }
		end
	end
end
M.NOMBRE_CLASE = {
	pez = L["Pez"], trofeo = L["Trofeo"], concurso = L["Concurso"], mision = L["De misión"],
	sorpresa = L["Sorpresa"], botin = L["Del agua"], otro = L["Otra captura"],
}
M.TONO_CLASE = { pez = "acento", trofeo = "oro", concurso = "raro", mision = "mazmorra", sorpresa = "aviso", botin = "neutro", otro = "neutro" }

---------------------------------------------------------------------------
-- Recetas de pescado: { crudo, cocinado, receta (el objeto que la enseña),
-- hechizo, habilidad de Cocina }
---------------------------------------------------------------------------
M.RECETAS = {
	{ crudo = 6291, cocinado = 6290, receta = 6325, hechizo = 7751, habilidad = 1 },
	{ crudo = 6303, cocinado = 787, receta = 6326, hechizo = 7752, habilidad = 1 },
	{ crudo = 6289, cocinado = 4592, receta = 6328, hechizo = 7753, habilidad = 50 },
	{ crudo = 6317, cocinado = 6316, receta = 6329, hechizo = 7754, habilidad = 50 },
	{ crudo = 6361, cocinado = 5095, receta = 6368, hechizo = 7827, habilidad = 50 },
	{ crudo = 21071, cocinado = 21072, receta = 21099, hechizo = 25704, habilidad = 80 },
	{ crudo = 6522, cocinado = 6657, receta = 6661, hechizo = 8238, habilidad = 85 },
	{ crudo = 6308, cocinado = 4593, receta = 6330, hechizo = 7755, habilidad = 100 },
	{ crudo = 6362, cocinado = 4594, receta = 6369, hechizo = 7828, habilidad = 175 },
	{ crudo = 8365, cocinado = 8364, receta = 17062, hechizo = 20916, habilidad = 175 },
	{ crudo = 21153, cocinado = 21217, receta = 21219, hechizo = 25954, habilidad = 175 },
	{ crudo = 4603, cocinado = 6887, receta = 13939, hechizo = 18238, habilidad = 225 },
	{ crudo = 13754, cocinado = 13927, receta = 13940, hechizo = 18239, habilidad = 225 },
	{ crudo = 13758, cocinado = 13930, receta = 13941, hechizo = 18241, habilidad = 225 },
	{ crudo = 13890, cocinado = 286152, receta = 286153, hechizo = 1319313, habilidad = 225 },
	{ crudo = 13755, cocinado = 13928, receta = 13942, hechizo = 18240, habilidad = 240 },
	{ crudo = 13756, cocinado = 13929, receta = 13943, hechizo = 18242, habilidad = 240 },
	{ crudo = 13759, cocinado = 13931, receta = 13945, hechizo = 18243, habilidad = 250 },
	{ crudo = 13760, cocinado = 13932, receta = 13946, hechizo = 18244, habilidad = 250 },
	{ crudo = 13888, cocinado = 13933, receta = 13947, hechizo = 18245, habilidad = 275 },
	{ crudo = 13893, cocinado = 13934, receta = 13948, hechizo = 18246, habilidad = 275 },
	{ crudo = 13889, cocinado = 13935, receta = 13949, hechizo = 18247, habilidad = 275 },
}
M.RECETAS_DE = {} -- crudo -> { receta, ... }
for _, r in ipairs(M.RECETAS) do
	local t = M.RECETAS_DE[r.crudo] or {}
	t[#t + 1] = r
	M.RECETAS_DE[r.crudo] = t
end

---------------------------------------------------------------------------
-- Bancos de peces: objeto -> { mapas, da }
---------------------------------------------------------------------------
M.BANCOS = {
	[180248] = { mapas = { 1434 }, da = { 6358, 6359, 13422, 19803, 19805, 19806, 19808 } },
	[180582] = { mapas = { 1413, 1421, 1436, 1439 }, da = { 6358 } },
	[180655] = { mapas = { 1421, 1432, 1436, 1439 }, da = { 20708, 6643, 6645, 21162 } },
	[180656] = { mapas = { 1421, 1432 }, da = { 21071 } },
	[180657] = { mapas = { 1417, 1424, 1437 }, da = { 6359 } },
	[180658] = { mapas = { 1413 }, da = { 6522 } },
	[180661] = { mapas = { 1442 }, da = { 6359 } },
	[180662] = { mapas = { 1417, 1424, 1437, 1442 }, da = { 21113, 6647, 13881 } },
	[180663] = { mapas = { 1416, 1424, 1440, 1442 }, da = { 21071 } },
	[180664] = { mapas = { 1417, 1424, 1437 }, da = { 6358 } },
	[180682] = { mapas = { 1413, 1434, 1443, 1445 }, da = { 6358 } },
	[180683] = { mapas = { 1413, 1434, 1443, 1445 }, da = { 6359 } },
	[180684] = { mapas = { 1416, 1421, 1434 }, da = { 21153 } },
	[180685] = { mapas = { 1416, 1434, 1443, 1445 }, da = { 21150, 8366, 21164 } },
	[180712] = { mapas = { 1434, 1444, 1446, 1447 }, da = { 13422 } },
	[180750] = { mapas = { 1444, 1446, 1447 }, da = { 6358 } },
	[180751] = { mapas = { 1444, 1446, 1447 }, da = { 21228, 13881, 13891, 21243 } },
	[180752] = { mapas = { 1444, 1446, 1447 }, da = { 6359 } },
	[180753] = { mapas = { 1447 }, da = { 7070 } },
	[180900] = { mapas = { 1434 }, da = { 6358 } },
	[180901] = { mapas = { 1434 }, da = { 21228, 13881, 13891, 21243 } },
	[180902] = { mapas = { 1434 }, da = { 6359 } },
	[400006] = { mapas = { 1444 }, da = { 16967 } },
	[400007] = { mapas = { 1435 }, da = { 16970 } },
	[400008] = { mapas = { 1443 }, da = { 16968 } },
	[400009] = { mapas = { 1434 }, da = { 16969 } },
}
M.BANCOS_DE = {} -- objeto pescado -> { banco, ... }
for banco, b in pairs(M.BANCOS) do
	for _, id in ipairs(b.da) do
		local t = M.BANCOS_DE[id] or {}
		t[#t + 1] = banco
		M.BANCOS_DE[id] = t
	end
end

---------------------------------------------------------------------------
-- PNJ y misiones de pesca
---------------------------------------------------------------------------
M.NAT_PAGLE = 12919
M.HEMING = 2626            -- el pescador de Bahía del Botín
M.CONCURSO_PNJ = { 15077, 15078, 15079 }
M.MISIONES = { 6607, 6608, 6609, 7815, 7816, 5386, 8193, 8194, 8221, 8224, 8225, 9204, 9205, 9206, 99143,
	96050, 97904, 97920, 97932, 97943, 97956, 97967 }

---------------------------------------------------------------------------
-- Guía de 1 a 300: tramos de habilidad y dónde conviene pescar (mapas). Es
-- orientativo: la habilidad que pide cada agua no está en los datos, así que
-- tu diario dice cuántos se te escapan en cada zona.
---------------------------------------------------------------------------
M.TRAMOS = {
	{ desde = 1, hasta = 75, mapas = { 1411, 1412, 1420, 1426, 1429, 1438, 1453, 1454, 1455, 1456, 1457, 1458 },
		cebo = 6529, texto = L["Aprende Pesca con un instructor, compra una caña y pesca en tu zona de inicio o en la capital. Pide el rango Oficial desde 50."] },
	{ desde = 75, hasta = 150, mapas = { 1413, 1421, 1432, 1436, 1439 },
		cebo = 6530, texto = L["Muévete a las zonas de nivel 10 a 20. Las lombrices ayudan a que no se escapen. Pide el rango Experto desde 125."] },
	{ desde = 150, hasta = 225, mapas = { 1424, 1431, 1433, 1437, 1440, 1441, 1442 },
		cebo = 6532, texto = L["Las aguas de nivel 20 a 35. El rango Experto se aprende con el libro que vende el pescador de Bahía del Botín."] },
	{ desde = 225, hasta = 300, mapas = { 1417, 1425, 1434, 1435, 1443, 1444, 1445, 1446, 1447 },
		cebo = 6533, texto = L["Mar abierto y zonas de nivel 35 en adelante. El rango Artesano lo da Nat Pagle en el Marjal Revolcafango con su misión."] },
}

---------------------------------------------------------------------------
-- Maestría de cada captura y logros de la manada
---------------------------------------------------------------------------
M.MAESTRIA = {
	{ n = 10, nombre = L["Conocido"] },
	{ n = 50, nombre = L["Habitual"] },
	{ n = 100, nombre = L["Diestro"] },
	{ n = 250, nombre = L["Veterano"] },
	{ n = 500, nombre = L["Maestro del agua"] },
	{ n = 1000, nombre = L["Leyenda"] },
}

-- -> nivel (0-6), nombre, siguiente (cantidad), anterior
function M.Maestria(n)
	n = tonumber(n) or 0
	local nivel, nombre, anterior = 0, nil, 0
	for i, t in ipairs(M.MAESTRIA) do
		if n >= t.n then nivel, nombre, anterior = i, t.nombre, t.n end
	end
	local sig = M.MAESTRIA[nivel + 1]
	return nivel, nombre, sig and sig.n or nil, anterior
end

-- Los logros: cada uno lee el registro (Registro.lua: L.Medir).
--   que: "capturas" | "especies" | "trofeo" | "habilidad" | "maximo" | "cebos" | "bancos" | "zonas"
--        | "especiesZona" | "lotes" | "cocinado" | "hora" | "racha" | "maestria" | "concurso" | "valor" | "escapes"
M.LOGROS = {
	{ id = "primera", que = "capturas", n = 1, icono = "ic-pesca", nombre = L["Primer tirón"], texto = L["Saca tu primera captura del agua."] },
	{ id = "cien", que = "capturas", n = 100, icono = "ic-pesca", nombre = L["Cien al cesto"], texto = L["Junta 100 capturas."] },
	{ id = "quinientas", que = "capturas", n = 500, icono = "ic-pesca", nombre = L["Red llena"], texto = L["Junta 500 capturas."] },
	{ id = "mil", que = "capturas", n = 1000, icono = "ic-raros", nombre = L["Mil y un peces"], texto = L["Junta 1000 capturas."] },
	{ id = "especies5", que = "especies", n = 5, icono = "ic-enciclopedia", nombre = L["Ojo de pescador"], texto = L["Pesca 5 especies distintas."] },
	{ id = "especies25", que = "especies", n = 25, icono = "ic-enciclopedia", nombre = L["Coleccionista del agua"], texto = L["Pesca 25 especies distintas."] },
	{ id = "trofeo", que = "trofeo", n = 1, icono = "ic-oro", nombre = L["De los que se presumen"], texto = L["Pesca un trofeo o un pez de concurso."] },
	{ id = "oficial", que = "habilidad", n = 75, icono = "ic-nivel", nombre = L["Ya no eres aprendiz"], texto = L["Llega a 75 de habilidad."] },
	{ id = "experto", que = "habilidad", n = 150, icono = "ic-nivel", nombre = L["Mano firme"], texto = L["Llega a 150 de habilidad."] },
	{ id = "artesano", que = "habilidad", n = 225, icono = "ic-nivel", nombre = L["Lectura del agua"], texto = L["Llega a 225 de habilidad."] },
	{ id = "maximo", que = "maximo", n = 300, icono = "ic-lobo", nombre = L["Señor de las aguas"], texto = L["Llega a la habilidad máxima de pesca."] },
	{ id = "cebos", que = "cebos", n = 10, icono = "ic-mas", nombre = L["Siempre con cebo"], texto = L["Pon un cebo 10 veces."] },
	{ id = "bancos", que = "bancos", n = 25, icono = "ic-recoleccion", nombre = L["Cazador de bancos"], texto = L["Saca 25 capturas de bancos de peces."] },
	{ id = "zonas", que = "zonas", n = 10, icono = "ic-mapa", nombre = L["Caña viajera"], texto = L["Pesca en 10 zonas distintas."] },
	{ id = "especiesZona", que = "especiesZona", n = 5, icono = "ic-mundo", nombre = L["Aguas conocidas"], texto = L["Pesca 5 especies distintas en una misma zona."] },
	{ id = "lotes", que = "lotes", n = 10, icono = "ic-oficios", nombre = L["Cocina junto al agua"], texto = L["Cocina 10 lotes desde tu cola de cocina."] },
	{ id = "cocinado", que = "cocinado", n = 100, icono = "ic-oficios", nombre = L["Olor a fogata"], texto = L["Cocina 100 piezas de pescado."] },
	{ id = "hora", que = "hora", n = 3600, icono = "ic-reloj", nombre = L["Paciencia de lobo"], texto = L["Pesca una hora en una sola sesión."] },
	{ id = "racha", que = "racha", n = 15, icono = "ic-exito", nombre = L["Ni uno se escapa"], texto = L["Saca 15 capturas seguidas sin que se te escape ninguna."] },
	{ id = "maestria", que = "maestria", n = 3, icono = "ic-huella", nombre = L["Lo conozco de memoria"], texto = L["Llega a la maestría Diestro con una captura."] },
	{ id = "concurso", que = "concurso", n = 1, icono = "ic-raros", nombre = L["Domingo de concurso"], texto = L["Saca una captura en Tuercespina durante el concurso de pesca."] },
	{ id = "valor", que = "valor", n = 100000, icono = "ic-oro", nombre = L["El mar paga"], texto = L["Pesca 10 de oro en valor en una sola sesión."] },
}

---------------------------------------------------------------------------
-- Sonidos (kits del juego; nada de grabaciones)
---------------------------------------------------------------------------
local SK = type(SOUNDKIT) == "table" and SOUNDKIT or {}
M.SONIDOS = {
	{ id = "suave", nombre = L["Suave"], kit = SK.U_CHAT_SCROLL_BUTTON or 1115 },
	{ id = "carrete", nombre = L["Carrete"], kit = SK.FISHING_REEL_IN or 3407 },
	{ id = "monedas", nombre = L["Monedas"], kit = SK.LOOT_WINDOW_COIN_SOUND or 120 },
	{ id = "campana", nombre = L["Campana"], kit = SK.ALARM_CLOCK_WARNING_2 or 12867 },
	{ id = "aviso", nombre = L["Aviso"], kit = SK.MAP_PING or 3175 },
}
M.SONIDO_DE = {}
for _, s in ipairs(M.SONIDOS) do M.SONIDO_DE[s.id] = s end
M.SONIDO_TROFEO = SK.UI_EPICLOOT_TOAST or 31578
M.SONIDO_LOGRO = SK.UI_AUTO_QUEST_COMPLETE or 23404

-- El concurso de pesca de Tuercespina: los domingos de 14:00 a 16:00 del reino.
M.CONCURSO = { dia = 1, desde = 14, hasta = 16, mapa = 1434 }

-- Los días de la semana (1 = domingo, como el calendario del juego).
M.DIAS = { L["domingo"], L["lunes"], L["martes"], L["miércoles"], L["jueves"], L["viernes"], L["sábado"] }
