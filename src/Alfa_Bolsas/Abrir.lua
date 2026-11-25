-- Alfa - Bolsas: «Abrir» y «Aprender» en el momento (toxic3000 / La Jauría).
-- GPL-3.0. 1.4.0 (diario, 92 y 93)
--
-- Dos cosas que se quedan olvidadas en las bolsas ocupando lugar:
--   * lo que se abre (almejas, bolsitas, cajas ya forzadas, regalos): el
--     juego lo marca con hasLoot (C_Container.GetContainerItemInfo);
--   * las recetas que ya puedes aprender: clase de objeto 9 (Receta), sin el
--     «Ya lo conoces» del juego (ITEM_SPELL_KNOWN) y sin requisitos en rojo en
--     su cuadro (C_TooltipInfo.GetBagItem, el mismo que ve el jugador).
-- Cuando una de esas llega a tus bolsas (no lo que ya traías al entrar), un
-- aviso chico con un botón seguro: «Abrir» o «Aprender» (/use item:<id>, el
-- clic es tuyo y del juego). Tras abrir una, si quedan más, el aviso vuelve
-- con las que faltan, así abres todo a clics seguidos.
-- Nada en combate (el aviso espera); nunca abre ni aprende solo; lo que tiene
-- candado no se toca. Ajuste bolsas.porAbrir (sí).
--
--   Ab.Revisar() -> { abrir = { { id, bolsa, casilla, cuantos, link } }, aprender = { ... } }
--   Ab.Pendientes(tipo) -> lista        Ab.Base()  (marca lo de ahora como ya visto)

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local D = M.Datos
local K = N.Kit

local type, ipairs, pairs, tonumber, pcall, format = type, ipairs, pairs, tonumber, pcall, string.format

local Ab = {}
M.Abrir = Ab

local RECETA = 9 -- Enum.ItemClass.Recipe

local function encendido() return M.Get("porAbrir") ~= false end

local function info(bolsa, casilla)
	local f = M.CC.GetContainerItemInfo
	if type(f) ~= "function" then return nil end
	local ok, i = pcall(f, bolsa, casilla)
	return ok and type(i) == "table" and i or nil
end

local function numCasillas(bolsa)
	return M.Num(M.Llamar(M.CC.GetContainerNumSlots, bolsa)) or 0
end

local function claseDe(id)
	local CI = rawget(_G, "C_Item")
	local f = CI and CI.GetItemInfoInstant or rawget(_G, "GetItemInfoInstant")
	if type(f) ~= "function" then return nil end
	local ok, _, _, _, _, _, clase = pcall(f, id)
	return ok and M.Num(clase) or nil
end

local function conCandado(bolsa, casilla)
	local c = M.Candado
	return c and c.TieneCasilla and c.TieneCasilla(bolsa, casilla) and true or false
end

-- El color de una línea del cuadro: -> r, g, b
local function colorDe(c)
	if type(c) ~= "table" then return nil end
	if type(c.GetRGB) == "function" then
		local ok, r, g, b = pcall(c.GetRGB, c)
		if ok then return M.Num(r), M.Num(g), M.Num(b) end
	end
	return M.Num(c.r), M.Num(c.g), M.Num(c.b)
end

-- ¿La receta de esa casilla se puede aprender ya? -> true | false | nil (no se sabe)
function Ab.SePuedeAprender(bolsa, casilla)
	local T = rawget(_G, "C_TooltipInfo")
	if not (T and type(T.GetBagItem) == "function") then return nil end
	local ok, datos = pcall(T.GetBagItem, bolsa, casilla)
	if not ok or type(datos) ~= "table" or type(datos.lines) ~= "table" then return nil end
	local conocida = M.Texto(rawget(_G, "ITEM_SPELL_KNOWN"))
	for _, l in ipairs(datos.lines) do
		if type(l) == "table" then
			local t = M.Texto(l.leftText)
			if t and conocida and t == conocida then return false end
			local r, g, b = colorDe(l.leftColor)
			if r and g and b and r > 0.9 and g < 0.2 and b < 0.2 then return false end
			r, g, b = colorDe(l.rightColor)
			if r and g and b and r > 0.9 and g < 0.2 and b < 0.2 then return false end
		end
	end
	return true
end

function Ab.Revisar()
	local out = { abrir = {}, aprender = {} }
	local vistos = { abrir = {}, aprender = {} }
	for _, bolsa in ipairs(D.BOLSAS) do
		for casilla = 1, numCasillas(bolsa) do
			local i = info(bolsa, casilla)
			local id = i and M.Num(i.itemID)
			if id and not N.Si(i.isLocked) and not conCandado(bolsa, casilla) then
				local tipo
				if N.Si(i.hasLoot) then
					tipo = "abrir"
				elseif claseDe(id) == RECETA and Ab.SePuedeAprender(bolsa, casilla) then
					tipo = "aprender"
				end
				if tipo then
					local cuantos = M.Num(i.stackCount) or 1
					local e = vistos[tipo][id]
					if e then
						e.cuantos = e.cuantos + cuantos
					else
						e = { id = id, bolsa = bolsa, casilla = casilla, cuantos = cuantos, link = M.Texto(i.hyperlink), icono = M.Leer(i.iconFileID) }
						vistos[tipo][id] = e
						out[tipo][#out[tipo] + 1] = e
					end
				end
			end
		end
	end
	return out
end

-- Lo que ya traías (o ya se avisó): id -> cuántos había.
local base = { abrir = nil, aprender = nil }
local seguir = {} -- tipo -> true tras un clic en su botón (vuelve con lo que falta)
local actual = {} -- tipo -> el aviso a la vista
local pend = { abrir = {}, aprender = {} }

function Ab.Pendientes(tipo) return pend[tipo] or {} end

function Ab.Base()
	local r = Ab.Revisar()
	for _, tipo in ipairs({ "abrir", "aprender" }) do
		local b = {}
		for _, e in ipairs(r[tipo]) do b[e.id] = e.cuantos end
		base[tipo] = b
		pend[tipo] = r[tipo]
	end
end

local function nombreDe(e)
	local link = e.link
	if link then return link end
	local CI = rawget(_G, "C_Item")
	local n = CI and CI.GetItemNameByID and M.Texto(M.Llamar(CI.GetItemNameByID, e.id))
	return n or L["un objeto"]
end

local TEXTOS = {
	abrir = { titulo = "Tienes algo por abrir", boton = "Abrir" },
	aprender = { titulo = "Ya puedes aprender una receta", boton = "Aprender" },
}

local function avisar(tipo, lista)
	if not (K and K.Aviso) or #lista == 0 then return end
	local e = lista[1]
	local resto = 0
	for k = 2, #lista do resto = resto + lista[k].cuantos end
	local t = nombreDe(e)
	if e.cuantos > 1 then t = t .. " ×" .. e.cuantos end
	if resto > 0 then t = t .. " " .. format(L["y %s más"], N.Plural(resto, L["%d cosa"], L["%d cosas"])) end
	if tipo == "abrir" then
		t = t .. ". " .. L["Ábrelo de un clic y libera espacio."]
	else
		t = t .. ". " .. L["Apréndela de un clic y libera espacio."]
	end
	local tx = TEXTOS[tipo]
	local id = e.id
	if actual[tipo] and actual[tipo].Cerrar then pcall(actual[tipo].Cerrar, actual[tipo]) end
	local av = K.Aviso({
		id = "bolsas.porAbrir." .. tipo, titulo = L[tx.titulo], texto = t, icono = "ic-bolsas",
		textura = (type(e.icono) == "number" or type(e.icono) == "string") and e.icono or nil,
		tono = "acento", duracion = 12, prioridad = "util", lya = false,
		acciones = { { texto = L[tx.boton], seguro = { type = "macro", macrotext = "/use [nocombat] item:" .. id },
			trasClic = function() seguir[tipo] = true end } },
	})
	actual[tipo] = type(av) == "table" and av or nil
end

local function revisar()
	if not encendido() or M.EnCombate() then return end
	local r = Ab.Revisar()
	for _, tipo in ipairs({ "abrir", "aprender" }) do
		local lista = r[tipo]
		pend[tipo] = lista
		if base[tipo] == nil then
			-- Lo que ya traías al entrar no se avisa.
			local b = {}
			for _, e in ipairs(lista) do b[e.id] = e.cuantos end
			base[tipo] = b
		else
			local nuevos = {}
			for _, e in ipairs(lista) do
				if e.cuantos > (base[tipo][e.id] or 0) then nuevos[#nuevos + 1] = e end
			end
			local b = {}
			for _, e in ipairs(lista) do b[e.id] = e.cuantos end
			base[tipo] = b
			if seguir[tipo] then
				seguir[tipo] = nil
				if #lista > 0 then avisar(tipo, lista) end
			elseif #nuevos > 0 then
				avisar(tipo, lista)
			end
		end
	end
end
Ab.RevisarAhora = revisar

local function pronto() N.Una("bolsas.porAbrir", 0.6, function() N.FueraDeCombate("bolsas.porAbrir", revisar) end) end
A.RegisterEvent("BAG_UPDATE_DELAYED", pronto)
A.RegisterEvent("PLAYER_ENTERING_WORLD", pronto)
