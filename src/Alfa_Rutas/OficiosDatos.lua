-- Alfa - Rutas: los hechos de las guías de oficios de Alfa (toxic3000 / La
-- Jauría). GPL-3.0. 1.3.9.
--
-- Lo que no está en otra parte de Alfa y las guías de oficios necesitan:
-- qué guía del motor trae las recetas de cada oficio, su herramienta, los
-- rangos (tope, habilidad y nivel para aprender el siguiente), de qué
-- cuero sale en cada tramo de Desuello. Las
-- recetas, sus colores, sus reactivos, los instructores y los vendedores
-- salen de las guías del motor (Alfa_Guides); los nodos de cada zona, de
-- Recolección (GatherLite); los precios, de Comercio. Oficios.lua arma la guía.

local ADDON, M = ...
local D = {}
M.OficiosDatos = D

-- Los cuatro tramos de cada guía (las secciones del motor).
D.TRAMOS = { { 1, 75 }, { 75, 150 }, { 150, 225 }, { 225, 300 } }

-- Los rangos: tope, desde qué habilidad y nivel se aprenden (el juego clásico).
D.RANGOS = {
	{ tope = 75, desde = 1, nivel = 1, nombre = "Aprendiz" },
	{ tope = 150, desde = 50, nivel = 10, nombre = "Oficial" },
	{ tope = 225, desde = 125, nivel = 20, nombre = "Experto" },
	{ tope = 300, desde = 200, nivel = 35, nombre = "Artesano" },
}

-- tipo: "juntar" (recolección) | "crear" (fabricación).
-- en: el nombre del motor (el token {skill:N} se lee en el idioma del cliente).
-- motor: la guía del motor con sus recetas, instructores y vendedores.
-- recurso: el tipo de Recolección (sus nodos); buscar: el hechizo de rastreo.
D.OFICIOS = {
	[186] = { clave = "mineria", en = "Mining", tipo = "juntar", motor = "forever/professions/mining", recurso = "mineria", buscar = 2580, herramienta = 2901, icono = 2770, forja = true },
	[182] = { clave = "herboristeria", en = "Herbalism", tipo = "juntar", motor = "forever/professions/herbalism", recurso = "hierbas", buscar = 2383, icono = 2447 },
	[393] = { clave = "desuello", en = "Skinning", tipo = "juntar", motor = "forever/professions/skinning", herramienta = 7005, icono = 2318 },
	[164] = { clave = "herreria", en = "Blacksmithing", tipo = "crear", motor = "forever/professions/blacksmithing", herramienta = 5956, icono = 2862, yunque = true },
	[171] = { clave = "alquimia", en = "Alchemy", tipo = "crear", motor = "forever/professions/alchemy", icono = 118 },
	[197] = { clave = "sastreria", en = "Tailoring", tipo = "crear", motor = "forever/professions/tailoring", icono = 2996 },
	[165] = { clave = "peleteria", en = "Leatherworking", tipo = "crear", motor = "forever/professions/leatherworking", icono = 2304 },
	[202] = { clave = "ingenieria", en = "Engineering", tipo = "crear", motor = "forever/professions/engineering", icono = 4357 },
	[333] = { clave = "encantamiento", en = "Enchanting", tipo = "crear", motor = "forever/professions/enchanting", icono = 10940 },
	[185] = { clave = "cocina", en = "Cooking", tipo = "crear", motor = "forever/professions/cooking", icono = 2681, secundario = true },
	[129] = { clave = "auxilios", en = "First Aid", tipo = "crear", motor = "forever/professions/first-aid", icono = 1251, secundario = true },
}

-- El orden en el Asistente y en la Biblioteca.
D.ORDEN = { 186, 182, 393, 164, 171, 197, 165, 202, 333, 185, 129 }

-- La zona de cada tramo de recolección la elige Recolección
-- (AlfaRecoleccion.Zonas: tu facción, tu nivel, cuántos puntos y su densidad).

-- Desuello: lo que sale de las bestias en cada tramo (itemID).
D.CUEROS = {
	{ 2934, 2318, 783 },
	{ 2318, 2319, 4232 },
	{ 2319, 4234, 4235 },
	{ 4304, 8169, 8170 },
}

-- Cada tramo de recolección se parte donde se aprende un rango (50, 125,
-- 200), además de donde aparece un recurso nuevo: así el instructor sale
-- justo cuando ya puedes subir de rango.
D.CORTES_RANGO = { 50, 125, 200 }

-- Desuello: el nivel más alto de bestia que puedes desollar con tu habilidad
-- (hasta el 10, cualquiera; del 11 al 20, (nivel - 10) x 10; desde el 21,
-- nivel x 5).
function D.NivelDesollar(habilidad)
	habilidad = habilidad or 1
	if habilidad < 100 then return math.max(10, 10 + math.floor(habilidad / 10)) end
	return math.floor(habilidad / 5)
end

-- Las barras: de qué mineral se funden (Minería).
D.FUNDIR = { [2840] = 2770, [3576] = 2771, [2841] = 2840, [2842] = 2775, [3575] = 2772, [3577] = 2776,
	[3859] = 3575, [3860] = 3858, [6037] = 7911, [12359] = 10620, [11371] = 11370 }

-- Las aleaciones: dos barras (o barra y carbón) en una forja.
D.ALEACION = { [2841] = { 2840, 3576 }, [3859] = { 3575, 3857 } }

-- La tela: de qué nivel de humanoides sale.
D.TELA = { [2589] = { 5, 20 }, [2592] = { 15, 30 }, [4306] = { 25, 40 }, [4338] = { 35, 50 }, [14047] = { 48, 60 } }

-- 1.3.9 (pedido de Toxic: llegar más rápido y más barato): lo que pesa cada
-- material cuando no hay precio de subasta (OficiosCrear.lua elige la receta
-- más barata por punto). Un material base (mineral, barra, tela, cuero,
-- piedra) pesa 1; lo que venden los proveedores, 0,1; las gemas y lo raro que
-- casi nunca sale, más (una de cada cien vetas o menos).
D.PESO_VENDEDOR = 0.1
D.PESO = {
	[1210] = 3,   -- Gema de las sombras
	[1529] = 3, [1705] = 3, [3864] = 3, -- Jade, Piedra lunar menor, Topacio citrino
	[7909] = 5, [7910] = 5, [7971] = 5, -- Aguamarina, Rubí estrella, Perla negra
	[12799] = 5, [12800] = 5, [12361] = 5, [12364] = 5, -- Ópalo grande, Diamante azur, Zafiro azul, Esmeralda enorme
	[7076] = 4, [7078] = 4, [7080] = 4, [7082] = 4, -- Esencias (tierra, fuego, agua, aire)
	[7077] = 3, [7079] = 3, [7081] = 3, [7075] = 3, -- Corazón de fuego y demás núcleos
}

-- Los cueros, para decir que se desuellan.
D.ES_CUERO = {}
for _, l in ipairs(D.CUEROS) do for _, it in ipairs(l) do D.ES_CUERO[it] = true end end
