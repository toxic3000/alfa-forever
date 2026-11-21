-- Alfa - Bolsas: el oro de esta sesión (1.2.8). GPL-3.0.
--
-- Desde que entras al juego, Alfa cuenta cuánto oro ganaste (solo lo que
-- sube), cuánto gastaste y el cambio neto, y saca lo que ganas por hora.
-- Se ve en «Tu oro» (el botón de monedas del pie de tus bolsas, Oro.lua) y en
-- la página Bolsas.
-- 1.3.2: el oro que sale del buzón (de tu otro personaje, de la subasta) no
-- es «ganado»: va aparte (correo) y no cuenta en lo que ganas por hora. El
-- oro del buzón llega un momento después de tomarlo, así que se cuenta como
-- del correo hasta CORREO_GRACIA segundos después de cerrarlo.
-- 1.3.7: la sesión se guarda (N.DatosPersonaje("bolsas").sesion) y sigue
-- después de un /reload: antes volvía a cero y el «por hora» salía mal. Una
-- entrada nueva al juego (isInitialLogin) empieza otra; si no se sabe (la
-- página pidió los datos antes de entrar), sigue la guardada si es de hace
-- menos de RECIENTE segundos. Y cuenta tu farmeo: lo que recoges (botín, su
-- precio de venta) y el oro de cada zona, para decirte tu mejor zona.
--   AlfaBolsas.Sesion() -> { oro = cambio neto en cobre, ganado, gastado, correo,
--                            segundos = tiempo de la sesión,
--                            porHora = cobre por hora (de lo ganado),
--                            botin = objetos recogidos, valor = su precio de venta,
--                            mejor = { nombre, porHora, oro, botin } | nil }
-- Cliente: GetMoney, PLAYER_MONEY, CHAT_MSG_LOOT, GetRealZoneText.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L

local type, pairs, tonumber, floor, max, format = type, pairs, tonumber, math.floor, math.max, string.format

local Se = {}
M.Sesion = Se

local MIN_SEG = 60 -- antes de un minuto no se calcula por hora
local CORREO_GRACIA = 3
local RECARGA = 3600 -- una sesión guardada sigue tras un /reload si es de hace menos de esto
local RECIENTE = 120 -- ... y sin saber si es /reload, si es de hace menos de esto
local ZONA_MIN = 300 -- para «tu mejor zona», al menos 5 minutos en ella
local MAX_ZONAS = 20

local inicio      -- GetTime() al empezar (o al recargar) en esta carga de la interfaz
local seg0 = 0    -- segundos de la sesión antes de esta carga (tras un /reload)
local vistoPEW = false
local nuevaPendiente = false -- entraste al juego pero el dinero aún no se podía leer
local buzon, buzonHasta = false, 0 -- el buzón abierto / cerrado hace poco
local zonaDesde   -- GetTime() desde que estás en la zona actual

local function dinero() return M.Num(GetMoney and GetMoney()) end
local function ahora() return GetTime and GetTime() or 0 end
local function reloj() return time and time() or 0 end

-- Lo guardado del personaje (se pide cada vez: el juego puede devolverlo en nil al arrancar).
local function guardado()
	local d = N.DatosPersonaje(M.ID)
	if type(d.sesion) ~= "table" then d.sesion = {} end
	local s = d.sesion
	if type(s.zonas) ~= "table" then s.zonas = {} end
	return s
end

local function zonaActual()
	local z = M.Texto(GetRealZoneText and GetRealZoneText()) or M.Texto(GetZoneText and GetZoneText())
	if z == "" then z = nil end
	return z
end

local function segundos()
	if not inicio then return 0 end
	return max(0, seg0 + ahora() - inicio)
end

-- La zona donde estás, con su tiempo al día. -> registro de la zona | nil
local function zona(s)
	s = s or guardado()
	local nombre = s.z
	if not nombre then return nil end
	local z = s.zonas[nombre]
	if type(z) ~= "table" then
		local n = 0
		for _ in pairs(s.zonas) do n = n + 1 end
		if n >= MAX_ZONAS then return nil end
		z = { oro = 0, botin = 0, valor = 0, seg = 0 }
		s.zonas[nombre] = z
	end
	return z
end

-- El tiempo en la zona actual pasa a su registro.
local function sumarZona(s)
	local t = ahora()
	local z = zonaDesde and zona(s)
	if z then z.seg = (tonumber(z.seg) or 0) + max(0, t - zonaDesde) end
	zonaDesde = t
end

local function guardar()
	local s = guardado()
	sumarZona(s)
	s.seg = floor(segundos())
	s.t = reloj()
end

local function nueva()
	local d = dinero()
	if not d then return false end
	local d0 = N.DatosPersonaje(M.ID)
	d0.sesion = { base = d, ultimo = d, ganado = 0, gastado = 0, correo = 0, botin = 0, valor = 0, seg = 0, t = reloj(), zonas = {} }
	inicio, seg0, zonaDesde = ahora(), 0, ahora()
	d0.sesion.z = zonaActual()
	return true
end

-- Sigue la sesión guardada (tras un /reload): -> true si siguió.
local function seguir(limite)
	local s = guardado()
	local t = tonumber(s.t)
	if not (t and tonumber(s.ultimo) and tonumber(s.base)) then return false end
	local hueco = reloj() - t
	if hueco < 0 or hueco > limite then return false end
	inicio, seg0, zonaDesde = ahora(), (tonumber(s.seg) or 0) + hueco, ahora()
	s.z = zonaActual() or s.z
	return true
end

-- Empieza (o sigue) si aún no hay sesión en esta carga.
local function empezar(recarga)
	if inicio then return true end
	if nuevaPendiente then
		nuevaPendiente = not nueva()
		return not nuevaPendiente
	end
	if recarga ~= false and seguir(recarga and RECARGA or RECIENTE) then return true end
	return nueva()
end

local function alCambiar()
	local d = dinero()
	if not d then return end
	if not inicio and not empezar() then return end
	local s = guardado()
	local ultimo = tonumber(s.ultimo)
	if not ultimo then nueva() return end
	local delta = d - ultimo
	local delCorreo = buzon or ahora() <= buzonHasta
	if delta > 0 and delCorreo then s.correo = (tonumber(s.correo) or 0) + delta
	elseif delta > 0 then
		s.ganado = (tonumber(s.ganado) or 0) + delta
		local z = zona(s)
		if z then z.oro = (tonumber(z.oro) or 0) + delta end
	elseif delta < 0 then s.gastado = (tonumber(s.gastado) or 0) - delta end
	s.ultimo = d
	s.t = reloj()
	s.seg = floor(segundos())
	M.Avisar("SESION")
end

---------------------------------------------------------------------------
-- El botín (1.3.7): lo que recoges tú, con su precio de venta
---------------------------------------------------------------------------

local inicios -- el principio de «Recibes botín: » de cada texto del juego
local function misInicios()
	if inicios then return inicios end
	inicios = {}
	for _, g in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF" }) do
		local p = rawget(_G, g)
		local ini = type(p) == "string" and p:match("^(.-)%%") or nil
		if ini and ini ~= "" then inicios[#inicios + 1] = ini end
	end
	return inicios
end

local function precioVenta(link)
	local CI = rawget(_G, "C_Item")
	local fn = (type(CI) == "table" and CI.GetItemInfo) or rawget(_G, "GetItemInfo")
	if type(fn) ~= "function" then return 0 end
	local ok, _, _, _, _, _, _, _, _, _, _, precio = pcall(fn, link)
	return ok and M.Num(precio) or 0
end

function Se.AlBotin(msg, guid)
	msg = M.Texto(msg)
	if not msg then return false end
	local yo = M.Texto(UnitGUID and UnitGUID("player"))
	guid = M.Texto(guid)
	local mio
	if guid and guid ~= "" and yo then
		mio = guid == yo
		-- Lo que te dan las misiones o lo que fabricas no es botín.
		local push = rawget(_G, "LOOT_ITEM_PUSHED_SELF")
		local ini = type(push) == "string" and push:match("^(.-)%%")
		if mio and ini and ini ~= "" and msg:sub(1, #ini) == ini then mio = false end
	else
		mio = false
		for _, ini in ipairs(misInicios()) do
			if msg:sub(1, #ini) == ini then mio = true break end
		end
	end
	if not mio then return false end
	local link = msg:match("(|c%x+|Hitem:.-|h.-|h|r)")
	if not link then return false end
	local n = tonumber(msg:match("|h|rx(%d+)")) or tonumber(msg:match("x(%d+)%.?%s*$")) or 1
	if not inicio and not empezar() then return false end
	local s = guardado()
	local valor = (precioVenta(link) or 0) * n
	s.botin = (tonumber(s.botin) or 0) + n
	s.valor = (tonumber(s.valor) or 0) + valor
	local z = zona(s)
	if z then
		z.botin = (tonumber(z.botin) or 0) + n
		z.valor = (tonumber(z.valor) or 0) + valor
	end
	M.Avisar("SESION")
	return true
end

-- Tu mejor zona de esta sesión (lo ganado más el botín, por hora). -> { nombre, porHora, oro, botin } | nil
local function mejorZona(s)
	local mejor
	for nombre, z in pairs(s.zonas) do
		if type(z) == "table" then
			local seg = tonumber(z.seg) or 0
			if nombre == s.z and zonaDesde then seg = seg + max(0, ahora() - zonaDesde) end
			local total = (tonumber(z.oro) or 0) + (tonumber(z.valor) or 0)
			if seg >= ZONA_MIN and total > 0 then
				local ph = floor(total * 3600 / seg)
				if not mejor or ph > mejor.porHora then
					mejor = { nombre = nombre, porHora = ph, oro = tonumber(z.oro) or 0, botin = tonumber(z.botin) or 0 }
				end
			end
		end
	end
	return mejor
end

---------------------------------------------------------------------------
-- Consultas
---------------------------------------------------------------------------

-- -> { oro, ganado, gastado, correo, segundos, porHora, botin, valor, mejor }
function Se.Datos()
	if not inicio then empezar() end
	local s = guardado()
	local seg = segundos()
	local ganado = tonumber(s.ganado) or 0
	local porHora = seg >= MIN_SEG and floor(ganado * 3600 / seg) or 0
	return {
		oro = (tonumber(s.ultimo) or 0) - (tonumber(s.base) or 0), ganado = ganado,
		gastado = tonumber(s.gastado) or 0, correo = tonumber(s.correo) or 0,
		segundos = floor(seg), porHora = porHora,
		botin = tonumber(s.botin) or 0, valor = tonumber(s.valor) or 0,
		mejor = mejorZona(s),
	}
end

-- "Esta sesión: +1g 20s · 2g 40s por hora" (nil si aún no ganaste nada).
function Se.Texto()
	local s = Se.Datos()
	if s.ganado <= 0 then return nil end
	if s.porHora > 0 then
		return format(L["Esta sesión: +%s · %s por hora"], N.Dinero(s.ganado, true), N.Dinero(s.porHora, true))
	end
	return format(L["Esta sesión: +%s"], N.Dinero(s.ganado, true))
end

-- Las líneas del cuadro de información (y de «Tu oro»).
function Se.Lineas()
	local s = Se.Datos()
	local out = {}
	out[#out + 1] = format(L["Ganaste: %s"], N.Dinero(s.ganado, true))
	if s.gastado > 0 then out[#out + 1] = format(L["Gastaste: %s"], N.Dinero(s.gastado, true)) end
	if s.correo > 0 then out[#out + 1] = format(L["Del buzón: %s (no cuenta por hora)"], N.Dinero(s.correo, true)) end
	local neto = s.oro >= 0 and ("+" .. N.Dinero(s.oro, true)) or N.Dinero(s.oro, true)
	out[#out + 1] = format(L["En total: %s"], neto)
	if s.porHora > 0 then out[#out + 1] = format(L["Por hora: %s"], N.Dinero(s.porHora, true)) end
	out[#out + 1] = format(L["Tiempo: %s"], N.Duracion(s.segundos))
	return out
end

-- 1.3.7: el farmeo, en líneas: el botín y tu mejor zona (vacío si aún no hay).
function Se.LineasFarmeo()
	local s = Se.Datos()
	local out = {}
	if s.botin > 0 then
		local objetos = N.Plural(s.botin, L["%d objeto"], L["%d objetos"])
		if s.valor > 0 then
			out[#out + 1] = format(L["Botín: %s (unos %s al venderlo)"], objetos, N.Dinero(s.valor, true))
		else
			out[#out + 1] = format(L["Botín: %s"], objetos)
		end
		if s.segundos >= MIN_SEG and s.valor > 0 then
			out[#out + 1] = format(L["Con el botín: %s por hora"], N.Dinero(floor((s.ganado + s.valor) * 3600 / s.segundos), true))
		end
	end
	if s.mejor then
		out[#out + 1] = format(L["Tu mejor zona: %s (%s por hora)"], s.mejor.nombre, N.Dinero(s.mejor.porHora, true))
	end
	return out
end

-- Para la prueba del banco: olvida lo de esta carga, como un /reload.
function Se.OlvidarCarga()
	guardar()
	inicio, seg0, vistoPEW, zonaDesde = nil, 0, false, nil
end

A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, login, recarga)
	login, recarga = M.Leer(login), M.Leer(recarga)
	if not vistoPEW then
		vistoPEW = true
		if login == true and not recarga then
			-- Una entrada nueva al juego: sesión nueva (aunque la página la haya pedido antes).
			inicio = nil
			nuevaPendiente = not nueva()
			return
		end
		if not inicio then empezar(recarga == true) end
		return
	end
	if not inicio then empezar() end
end)
A.RegisterEvent("PLAYER_MONEY", alCambiar)
A.RegisterEvent("MAIL_SHOW", function() buzon = true end)
A.RegisterEvent("MAIL_CLOSED", function()
	buzon = false
	buzonHasta = ahora() + CORREO_GRACIA
end)
A.RegisterEvent("PLAYER_LEAVING_WORLD", guardar)
A.RegisterEvent("PLAYER_LOGOUT", guardar)
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
	if not inicio then return end
	local s = guardado()
	sumarZona(s)
	s.z = zonaActual() or s.z
end)
A.RegisterEvent("CHAT_MSG_LOOT", function(_, msg, _, _, _, _, _, _, _, _, _, _, guid)
	M.Seguro(Se.AlBotin, msg, guid)
end)

-- Para otros módulos (Lya, Inicio): AlfaBolsas.Sesion().
AlfaBolsas = type(rawget(_G, "AlfaBolsas")) == "table" and rawget(_G, "AlfaBolsas") or {}
AlfaBolsas.Sesion = function() return Se.Datos() end
