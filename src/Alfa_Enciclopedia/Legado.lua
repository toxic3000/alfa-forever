-- Alfa - Enciclopedia: guía de los puntos del legado (toxic3000 / La Jauría).
-- GPL-3.0.
--
-- El Legado de WoW Forever (cliente 1.60.1): retos (logros) que dan puntos a
-- toda la cuenta; cada personaje los gasta en sus árboles del Legado, y los
-- ganados llenan el registro del Legado (premios de aspecto).
--
-- Lo que se lee del juego (las mismas llamadas que su ventana del Legado,
-- Blizzard_LegacySystem en referencia/):
--   puntos para gastar, gastados y tope: C_Traits.GetTreeCurrencyInfo del
--     árbol de Profesiones (Constants.LegacyConsts.LEGACY_TREE_*_ID, 1187-1189;
--     la moneda es LEGACY_POINTS_TRAIT_CURRENCY_ID, 4225);
--   ganados en la cuenta: C_MajorFactions.GetCurrentRenownLevel del registro
--     (LEGACY_REWARD_TRACK_FACTION_ID, 2802), y sus premios con GetRenownLevels
--     y GetRenownRewardsForLevel;
--   los retos: GetCategoryList / GetCategoryNumAchievements / GetAchievementInfo
--     (en Forever todos los logros son retos del Legado), su avance con
--     GetAchievementCriteriaInfo y sus puntos con C_Traits.GetTraitCurrencyForAchievement.
-- Lo que el juego no dice se explica con lo publicado (ver FUENTES abajo), y
-- la ficha dice qué está confirmado y qué no.

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local F = M.F
local Lg = {}
M.Legado = Lg

local type, tonumber, tostring, ipairs, pairs, pcall, select = type, tonumber, tostring, ipairs, pairs, pcall, select
local floor, max, min, format = math.floor, math.max, math.min, string.format

local function const(nombre, defecto)
	local c = Constants and Constants.LegacyConsts
	local v = c and c[nombre]
	return type(v) == "number" and v or defecto
end
local MONEDA = const("LEGACY_POINTS_TRAIT_CURRENCY_ID", 4225)
local REGISTRO = const("LEGACY_REWARD_TRACK_FACTION_ID", 2802)
local ARBOLES = {
	{ id = const("LEGACY_TREE_PROFESSIONS_ID", 1187), global = "LEGACY_TREE_PROFESSIONS", texto = L["Profesiones"] },
	{ id = const("LEGACY_TREE_ADVENTURE_ID", 1188), global = "LEGACY_TREE_ADVENTURE", texto = L["Aventura"] },
	{ id = const("LEGACY_TREE_PROGRESSION_ID", 1189), global = "LEGACY_TREE_PROGRESSION", texto = L["Recursos"] },
}
local TOPE_PUBLICADO = 16   -- puntos que gasta un personaje al salir Forever (Blizzard)
local TOTAL_PUBLICADO = 65  -- retos (y puntos) al salir Forever (Blizzard)

local secreto = A.Compat and A.Compat.IsSecret or function() return false end
-- Todos los resultados, también los que vienen después de un nil (una tabla
-- con # los perdería en Lua 5.1); nil si falla o si alguno es secreto.
local function devolver(ok, ...)
	if not ok then return nil end
	for i = 1, select("#", ...) do
		if secreto((select(i, ...))) then return nil end
	end
	return ...
end
local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	return devolver(pcall(fn, ...))
end

local function nombreArbol(a)
	local s = rawget(_G, a.global)
	return type(s) == "string" and s ~= "" and s or a.texto
end

---------------------------------------------------------------------------
-- Lo que dice el juego
---------------------------------------------------------------------------
-- -> { disponibles, gastados, tope, ganados, arboles = { { nombre, gastados } } } | nil
function Lg.Puntos()
	local T = C_Traits
	local out = { arboles = {} }
	local hay = false
	if T then
		for _, a in ipairs(ARBOLES) do
			local config = llamar(T.GetConfigIDByTreeID, a.id)
			local info = config and llamar(T.GetTreeCurrencyInfo, config, a.id, false)
			local c = type(info) == "table" and info[1]
			if type(c) == "table" then
				hay = true
				out.disponibles = out.disponibles or tonumber(c.quantity)
				out.gastados = out.gastados or tonumber(c.spent)
				out.tope = out.tope or tonumber(c.maxQuantity)
				out.arboles[#out.arboles + 1] = { nombre = nombreArbol(a), gastados = tonumber(c.spentInTree) or 0 }
			end
		end
	end
	local MF = C_MajorFactions
	local nivel = MF and llamar(MF.GetCurrentRenownLevel, REGISTRO)
	if type(nivel) == "number" then out.ganados = nivel hay = true end
	return hay and out or nil
end

-- El avance de un reto en palabras: "3/5", "2 de 4 partes" o nil.
local function avance(id)
	local n = llamar(GetAchievementNumCriteria, id) or 0
	if n == 0 then return nil, nil end
	if n == 1 then
		local _, _, hecho, cant, req = llamar(GetAchievementCriteriaInfo, id, 1)
		if type(req) == "number" and req > 1 then return format("%d/%d", min(cant or 0, req), req), (cant or 0) / req end
		return nil, hecho and 1 or 0
	end
	local hechos = 0
	for j = 1, n do
		local _, _, hecho = llamar(GetAchievementCriteriaInfo, id, j)
		if hecho then hechos = hechos + 1 end
	end
	return format(L["%d de %d partes"], hechos, n), hechos / n
end

-- -> { { id, nombre, retos = { { id, nombre, texto, puntos, hecho, mio, avance, fraccion } } } } | nil
function Lg.Retos()
	local cats = llamar(GetCategoryList)
	if type(cats) ~= "table" or #cats == 0 or type(GetAchievementInfo) ~= "function" then return nil end
	local nombres = {}
	local out = {}
	for _, cat in ipairs(cats) do
		local nombre, padre = llamar(GetCategoryInfo, cat)
		nombres[cat] = nombre
		local total = llamar(GetCategoryNumAchievements, cat) or 0
		if total > 0 then
			local grupo = { id = cat, nombre = (padre and padre ~= -1 and nombres[padre]) and (nombres[padre] .. M.SEP .. (nombre or "")) or nombre, retos = {} }
			for k = 1, total do
				local id, rnombre, pts, hecho, _, _, _, desc, _, _, _, _, mio = llamar(GetAchievementInfo, cat, k)
				if type(id) == "number" then
					local p = C_Traits and llamar(C_Traits.GetTraitCurrencyForAchievement, MONEDA, id)
					local av, fr = avance(id)
					grupo.retos[#grupo.retos + 1] = { id = id, nombre = rnombre, texto = desc, puntos = type(p) == "number" and p or pts,
						hecho = hecho and true or false, mio = (mio == nil) and (hecho and true or false) or (mio and true or false), avance = av, fraccion = fr }
				end
			end
			out[#out + 1] = grupo
		end
	end
	return #out > 0 and out or nil
end

-- Los premios del registro: { { puntos, nombre, item } }, del juego o lo publicado.
function Lg.Premios()
	local MF = C_MajorFactions
	local out = {}
	local niveles = MF and llamar(MF.GetRenownLevels, REGISTRO)
	if type(niveles) == "table" then
		for _, n in ipairs(niveles) do
			local premios = type(n) == "table" and llamar(MF.GetRenownRewardsForLevel, REGISTRO, n.level)
			for _, p in ipairs(type(premios) == "table" and premios or {}) do
				out[#out + 1] = { puntos = n.level, nombre = p.name, item = p.itemID, juego = true }
			end
		end
	end
	if #out == 0 then
		for item, pts in pairs(M.Col.LEGADO) do out[#out + 1] = { puntos = pts, item = item } end
	end
	table.sort(out, function(a, b) if a.puntos ~= b.puntos then return a.puntos < b.puntos end return (a.item or 0) < (b.item or 0) end)
	return out
end

-- Para la página: disponibles, ganados (nil si el juego no dice).
function Lg.Resumen()
	local p = Lg.Puntos()
	return p and p.disponibles, p and p.ganados
end

local function abrirDelJuego()
	if InCombatLockdown() then return false, L["Se puede al salir de combate."] end
	local fn = rawget(_G, "ToggleLegacySystemUI")
	if type(fn) ~= "function" then return false, L["Este cliente no tiene la ventana del Legado."] end
	local ok = pcall(fn)
	if not ok then return false, L["La ventana del Legado no abrió."] end
	return true
end

---------------------------------------------------------------------------
-- La guía
---------------------------------------------------------------------------
M.GUIAS.legado = L["Puntos del legado"]
M.FICHAS_GUIA = M.FICHAS_GUIA or {}

local PARRAFOS = {
	{ titulo = L["Qué son"], textos = {
		L["Son puntos de tu cuenta: los ganas con los retos del Legado (logros de Forever) en cualquier personaje, y cada personaje los gasta por su cuenta en sus árboles."],
		format(L["Cada reto da 1 punto. Al salir Forever hay %d retos, y cada personaje puede gastar hasta %d."], TOTAL_PUBLICADO, TOPE_PUBLICADO),
		L["El Legado se abre con tu primer punto (casi siempre, al llegar a nivel 25), con la tecla Y o con su botón del menú."],
	} },
	{ titulo = L["Cómo se ganan"], textos = {
		L["Clases (27): llegar a nivel 25, 45 y 60 con cada una de las 9 clases."],
		L["Profesiones (18): llegar a 150, 225 y 300 en Alquimia, Herrería, Encantamiento, Ingeniería, Peletería y Sastrería."],
		L["JcJ (12): rangos de honor 3, 7, 10, 13 y 14; exaltado con las 4 facciones de los campos de batalla; las semanas 4, 7 y 10 del viaje de temporada Campo de Honor."],
		L["Aventura (2): explorar todo el mapa del mundo con un personaje y terminar la cadena de Lord Valthalak (el conjunto de mazmorra 2)."],
		L["Mazmorras (3): derrotar al último jefe de todas las mazmorras de nivel 15-25, 26-45 y 46-60 (un punto por grupo)."],
		L["Bandas (3): derrotar a Onyxia, a los 13 jefes de la Cumbre Hyjal y a los 8 jefes de Barrow Deeps."],
		L["Sin otros personajes, uno solo puede ganar 29: 3 por subir de nivel, 6 de profesiones, 12 de JcJ, 2 de aventura y 6 de mazmorras y bandas. El resto sale de subir otras clases."],
	} },
	{ titulo = L["En qué se gastan"], textos = {
		L["Profesiones: más puntos de habilidad, más recursos al recolectar, mejores precios con los vendedores, más platos y más peces."],
		L["Aventura: descanso más rápido, vida y maná tras cada muerte, ver mejor a los sigilosos, talentos hasta 5 niveles antes y vuelos más baratos y rápidos."],
		L["Recursos: comida que dura más, menos desgaste al morir, más honor, más reputación, beneficios que duran más y algunos componentes de clase gratis."],
	} },
	{ titulo = L["El registro del Legado"], textos = {
		L["Los puntos que ganas en la cuenta también llenan el registro del Legado: premios de aspecto, sin ventaja en el juego. Al salir Forever son un rifle de réplica de Forjaz (juguete), la cría de oso espectral (mascota), el tabardo del oso espectral y las riendas del oso espectral (montura)."],
	} },
	{ titulo = L["Modo extremo"], textos = {
		L["No está al salir Forever. Cuando llegue, lo que ganes ahí cuenta en los otros modos, pero no al revés, y los retos de JcJ no se pueden hacer ahí."],
	} },
	{ titulo = L["Qué está confirmado"], textos = {
		L["Confirmado por Blizzard (su noticia del sistema de Legado de WoW Forever): los 65 retos de 1 punto, el tope de 16 por personaje, los tres árboles, los cuatro premios del registro y lo del modo extremo."],
		L["Solo en warcraft.wiki.gg e Icy Veins: cuántos puntos pide cada premio (15, 25, 40 y 55). Ninguna fuente publica cuánto cuesta cada rango de los árboles: míralo en la ventana del Legado."],
		L["Fuentes: Blizzard (news.blizzard.com), warcraft.wiki.gg (Legacy System), Icy Veins y Method. Lo que ves arriba con tus números sale del juego."],
	} },
}

M.FICHAS_GUIA.legado = function()
	local f = F.Nueva("guia", "legado")
	f.icono = { ic = "ic-nivel", tono = "oro" }
	f.sobre = L["Guía"]
	f.titulo = L["Puntos del legado"]
	f.subtitulo = L["Retos de tu cuenta que dan puntos para los árboles del Legado"]
	local p = Lg.Puntos()
	if p then
		local filas = {}
		if p.disponibles then filas[#filas + 1] = { L["Para gastar"], tostring(p.disponibles) } end
		if p.gastados then filas[#filas + 1] = { L["Gastados"], tostring(p.gastados) } end
		filas[#filas + 1] = { L["Tope por personaje"], tostring(p.tope or TOPE_PUBLICADO) }
		if p.ganados then filas[#filas + 1] = { L["Ganados"], tostring(p.ganados) } end
		for _, a in ipairs(p.arboles) do filas[#filas + 1] = { format(L["En %s"], a.nombre), tostring(a.gastados) } end
		f.datos = { titulo = L["Tus puntos"], filas = filas }
		if p.ganados and p.ganados <= 0 then f.insignias[#f.insignias + 1] = { L["Aún sin abrir: gana tu primer punto"], "aviso" } end
		if p.disponibles and p.disponibles > 0 then f.insignias[#f.insignias + 1] = { format(L["Tienes %d para gastar"], p.disponibles), "exito" } end
	else
		f.nota = L["El juego no dio tus puntos todavía: se ven desde que ganas el primero."]
	end

	-- Los retos, del juego: lo que falta primero.
	local grupos = Lg.Retos()
	local mejor
	local clase = A.Compat.GetPlayerInfo().class
	local deClase = clase and const("LEGACY_DEFAULT_CATEGORY_" .. clase, nil)
	local hechos, total = 0, 0
	for _, g in ipairs(grupos or {}) do
		local filas = {}
		for _, r in ipairs(g.retos) do
			total = total + 1
			if r.hecho then hechos = hechos + 1 end
			local estado = r.mio and L["hecho"] or (r.hecho and L["hecho por otro personaje"] or nil)
			filas[#filas + 1] = { icono = { ic = r.hecho and "ic-exito" or "ic-nivel", tono = r.hecho and "exito" or "oro" }, titulo = r.nombre or "?",
				texto = F.Unir(estado, r.texto), valor = r.hecho and nil or (r.avance or (r.puntos and r.puntos > 0 and format(L["%d pt"], r.puntos)) or nil),
				tenue = r.mio or nil, orden = r.hecho and 2 or 0 }
			-- Lo siguiente: un reto de tu clase sin hacer, o el más avanzado.
			if not r.hecho then
				local peso = (g.id == deClase and 2 or 0) + (r.fraccion or 0)
				if not mejor or peso > mejor.peso then mejor = { peso = peso, r = r } end
			end
		end
		local pos = {}
		for k, fl in ipairs(filas) do pos[fl] = k end
		table.sort(filas, function(a, b) if a.orden ~= b.orden then return a.orden < b.orden end return pos[a] < pos[b] end)
		local s = F.Seccion(f, "retos:" .. tostring(g.id), g.nombre or L["Retos"], filas)
		if s then
			local n = 0
			for _, r in ipairs(g.retos) do if r.hecho then n = n + 1 end end
			s.cuenta = format(L["%d de %d"], n, #g.retos)
		end
	end
	if total > 0 then f.insignias[#f.insignias + 1] = { format(L["%d de %d retos"], hechos, total), "acento" } end
	if mejor then
		f.mejor = { sobre = L["Lo siguiente para ti"], titulo = mejor.r.nombre, texto = F.Unir(mejor.r.avance, mejor.r.texto), icono = "ic-nivel" }
	elseif not grupos then
		if (A.Compat.GetPlayerInfo().level or 1) < 25 then
			f.mejor = { sobre = L["Para empezar"], titulo = L["Llega a nivel 25 con cualquier clase"], texto = L["Es el primer reto: con él se abre el Legado."], icono = "ic-nivel" }
		else
			f.mejor = { sobre = L["Para empezar"], titulo = L["Mira tus retos en el Legado del juego"], texto = L["El juego todavía no dio la lista de retos: ábrelo con la tecla Y."], icono = "ic-nivel" }
		end
	end

	-- El registro del Legado: los premios por puntos ganados.
	local ganados = p and p.ganados
	local premios = {}
	for _, pr in ipairs(Lg.Premios()) do
		local fl
		if pr.item then fl = F.FilaObjeto(pr.item) else fl = { icono = { ic = "ic-nivel", tono = "oro" }, titulo = pr.nombre or "?" } end
		if pr.nombre and not pr.item then fl.titulo = pr.nombre end
		local listo = ganados and ganados >= pr.puntos
		fl.texto = F.Unir(format(L["con %d puntos"], pr.puntos), listo and L["ya lo ganaste"] or (ganados and format(L["te faltan %d"], pr.puntos - ganados) or nil))
		fl.tenue = listo or nil
		premios[#premios + 1] = fl
	end
	F.Seccion(f, "registro", L["El registro del Legado"], premios)

	f.parrafos = PARRAFOS
	if type(rawget(_G, "ToggleLegacySystemUI")) == "function" then
		f.acciones.extra = { texto = L["Abrir el Legado del juego"], icono = "ic-ventana", alClic = abrirDelJuego }
	end
	return f
end

-- Al ganar un reto o cambiar tus puntos, la ficha se rehace (si está a la vista).
-- (CRITERIA_UPDATE llega a ráfagas: se junta en uno por segundo.)
local pronto = false
local function cambio()
	if pronto or not M.alLegado then return end
	pronto = true
	C_Timer.After(1, function() pronto = false if M.alLegado then K.Llamar(M.alLegado) end end)
end
for _, ev in ipairs({ "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_CONFIG_UPDATED",
	"MAJOR_FACTION_RENOWN_LEVEL_CHANGED" }) do
	A.RegisterEvent(ev, cambio)
end
