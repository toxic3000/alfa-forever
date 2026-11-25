-- Alfa - Bolsas: «Ponte la bolsa» (toxic3000 / La Jauría). GPL-3.0.
-- 1.4.0 (diario, 101)
--
-- Una bolsa nueva que llega (botín, misión, comerciante, correo) se queda
-- muchas veces dentro de otra bolsa, ocupando una casilla en vez de dar
-- espacio. Cuando llega una bolsa común (clase 1, subclase 0: las especiales
-- de munición, almas o hierbas no cuentan):
--   * con un hueco de bolsa libre: «Ponte la bolsa», con «Ponérmela» (tu clic:
--     C_Item.EquipItemByName, como el clic derecho del juego);
--   * sin hueco, si es más grande que tu bolsa más chica: te lo dice
--     («vacíala y cámbiala en la barra de tus bolsas»).
-- Las casillas de la bolsa nueva salen de su cuadro (C_TooltipInfo con el
-- texto del juego CONTAINER_SLOTS, «%d casillas»). Lo que ya traías al entrar
-- no se avisa; nada en combate. Ajuste bolsas.porAbrir (el mismo de «Abrir»).
--
--   Bn.Nuevas() -> { { id, bolsa, casilla, link, casillas } }
--   Bn.Huecos() -> huecos libres, la bolsa equipada más chica { bolsa, casillas }

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local D = M.Datos
local K = N.Kit

local type, ipairs, pcall, tonumber, format = type, ipairs, pcall, tonumber, string.format

local Bn = {}
M.BolsaNueva = Bn

local EQUIPADAS = { 1, 2, 3, 4 }

local function encendido() return M.Get("porAbrir") ~= false end

local function clase(id)
	local CI = rawget(_G, "C_Item")
	local f = CI and CI.GetItemInfoInstant or rawget(_G, "GetItemInfoInstant")
	if type(f) ~= "function" then return nil end
	local ok, _, _, _, _, _, c, s = pcall(f, id)
	if not ok then return nil end
	return M.Num(c), M.Num(s)
end

local patron
local function casillasDe(bolsa, casilla)
	local T = rawget(_G, "C_TooltipInfo")
	if not (T and type(T.GetBagItem) == "function") then return nil end
	if not patron then
		local f = M.Texto(rawget(_G, "CONTAINER_SLOTS"))
		if not f then return nil end
		patron = "^" .. f:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%d", "(%%d+)"):gsub("%%s", ".+") .. "$"
	end
	local ok, datos = pcall(T.GetBagItem, bolsa, casilla)
	if not ok or type(datos) ~= "table" or type(datos.lines) ~= "table" then return nil end
	for _, l in ipairs(datos.lines) do
		local t = type(l) == "table" and M.Texto(l.leftText)
		local n = t and tonumber(t:match(patron))
		if n then return n end
	end
	return nil
end
Bn.CasillasDe = casillasDe

function Bn.Huecos()
	local libres, chica = 0, nil
	for _, b in ipairs(EQUIPADAS) do
		local n = M.Num(M.Llamar(M.CC.GetContainerNumSlots, b)) or 0
		if n <= 0 then
			libres = libres + 1
		elseif not chica or n < chica.casillas then
			chica = { bolsa = b, casillas = n }
		end
	end
	return libres, chica
end

local function bolsasEnBolsas()
	local out = {}
	for _, bolsa in ipairs(D.BOLSAS) do
		local n = M.Num(M.Llamar(M.CC.GetContainerNumSlots, bolsa)) or 0
		for s = 1, n do
			local i = M.Llamar(M.CC.GetContainerItemInfo, bolsa, s)
			local id = type(i) == "table" and M.Num(i.itemID)
			if id then
				local c, sub = clase(id)
				if c == 1 and sub == 0 then out[#out + 1] = { id = id, bolsa = bolsa, casilla = s, link = M.Texto(i.hyperlink) } end
			end
		end
	end
	return out
end

local base -- id -> cuántas había
function Bn.Nuevas()
	local lista = bolsasEnBolsas()
	local cuenta, nuevas = {}, {}
	for _, e in ipairs(lista) do cuenta[e.id] = (cuenta[e.id] or 0) + 1 end
	if base then
		local vistas = {}
		for _, e in ipairs(lista) do
			vistas[e.id] = (vistas[e.id] or 0) + 1
			if vistas[e.id] > (base[e.id] or 0) then nuevas[#nuevas + 1] = e end
		end
	end
	base = cuenta
	return nuevas
end
function Bn.Base() base = nil Bn.Nuevas() end

local function nombre(e)
	if e.link then return e.link end
	local CI = rawget(_G, "C_Item")
	return (CI and CI.GetItemNameByID and M.Texto(M.Llamar(CI.GetItemNameByID, e.id))) or L["una bolsa"]
end

function Bn.Ponerla(e)
	if M.EnCombate() then N.Imprimir(L["No se puede en combate."]) return false end
	local CI = rawget(_G, "C_Item")
	local f = CI and CI.EquipItemByName or rawget(_G, "EquipItemByName")
	if type(f) ~= "function" then return false end
	return pcall(f, e.link or e.id) and true or false
end

local function revisar()
	if not encendido() or M.EnCombate() then return end
	local nuevas = Bn.Nuevas()
	if #nuevas == 0 or not (K and K.Aviso) then return end
	local e = nuevas[1]
	e.casillas = casillasDe(e.bolsa, e.casilla)
	local libres, chica = Bn.Huecos()
	if libres > 0 then
		local t = e.casillas and format(L["%s (%d casillas) está dentro de tus bolsas. Póntela y gana espacio."], nombre(e), e.casillas)
			or format(L["%s está dentro de tus bolsas. Póntela y gana espacio."], nombre(e))
		K.Aviso({
			id = "bolsas.bolsaNueva", titulo = L["Ponte la bolsa"], texto = t, icono = "ic-bolsas", tono = "acento",
			duracion = 12, prioridad = "util",
			acciones = { { texto = L["Ponérmela"], alClic = function() Bn.Ponerla(e) end } },
		})
	elseif chica and e.casillas and e.casillas > chica.casillas then
		K.Aviso({
			id = "bolsas.bolsaNueva", titulo = L["Una bolsa más grande"], icono = "ic-bolsas", tono = "acento", duracion = 12, prioridad = "util",
			texto = format(L["%s tiene %d casillas y tu bolsa más chica %d. Vacía la chica y cámbiala en la barra de tus bolsas."], nombre(e), e.casillas, chica.casillas),
		})
	end
end
Bn.RevisarAhora = revisar

local function pronto() N.Una("bolsas.bolsaNueva", 0.7, function() N.FueraDeCombate("bolsas.bolsaNueva", revisar) end) end
A.RegisterEvent("BAG_UPDATE_DELAYED", pronto)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function() if not base then pronto() end end)
