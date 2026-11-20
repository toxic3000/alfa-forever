-- Alfa - Comercio: el buzón (toxic3000 / La Jauría). GPL-3.0. 1.2.8.
--
-- Con el buzón abierto, una barra de Alfa bajo su ventana con el botón
-- «Tomar todo»: tras ese clic, Alfa toma el dinero y los objetos de tus
-- cartas una por una, con una pausa corta entre cada una (como el «Abrir
-- todo» del juego), y al final te dice qué recibiste. Se salta las cartas
-- con pago contra entrega y las de un MJ (esas se abren a mano), y se
-- detiene si se cierra el buzón, entras en combate o tus bolsas se llenan
-- (el dinero lo sigue tomando). Al abrir el buzón también avisa si alguna
-- carta con objetos vence en menos de 3 días.
--
-- API: las funciones clásicas del buzón (globales, sin documentación
-- generada ni restricciones; el «Abrir todo» del juego las usa igual:
-- Blizzard_MailFrame/MailFrame.lua, OpenAllMailMixin):
--   GetInboxNumItems(), GetInboxHeaderInfo(i) -> icono, papel, remitente,
--   asunto, dinero, contraEntrega, díasRestantes, objetos, leída, devuelta,
--   textoCreado, puedeResponder, esMJ ; GetInboxItem(i, a) -> nombre, id,
--   textura, cantidad ; HasInboxItem(i, a) ; TakeInboxMoney(i) ;
--   TakeInboxItem(i, a).
-- Blizzard_APIDocumentationGenerated/MailInfoDocumentation.lua:
--   C_Mail.IsCommandPending, C_Mail.SetOpeningAll, C_Mail.HasInboxMoney y los
--   eventos MAIL_SHOW, MAIL_CLOSED, MAIL_INBOX_UPDATE, MAIL_FAILED.
-- ContainerDocumentation.lua: C_Container.CalculateTotalNumberOfFreeBagSlots.

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local type, tonumber, floor, max, min, format = type, tonumber, math.floor, math.max, math.min, string.format

local Bz = {}
M.Buzon = Bz

local CADA = 0.2       -- un paso cada tanto
local PAUSA = 0.15     -- lo mínimo entre una toma y la siguiente
local ESPERA_MAX = 2   -- si el buzón no responde, se sigue después de esto
local VENCE = 3        -- días: avisar de las cartas que vencen antes
local MAX_ADJUNTOS = 16

local abierto = false
-- 1.3.0: el buzón llega un instante después de abrirlo (MAIL_INBOX_UPDATE).
-- Antes, «Tomar todo» pulsado en ese instante veía 0 cartas y decía «No había
-- nada que tomar», y ese texto se quedaba aunque luego llegara todo.
local cargado = false
local pendiente = false
local tomando     -- la tanda en curso
local avisoVisto  -- ya se revisó el vencimiento en esta visita

---------------------------------------------------------------------------
-- Lectura del buzón
---------------------------------------------------------------------------

local function secreto(v) return v ~= nil and issecretvalue ~= nil and issecretvalue(v) and true or false end
local function num(v) if secreto(v) then return nil end return tonumber(v) end
local function leer(v) if secreto(v) then return nil end return v end

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local r = { pcall(fn, ...) }
	if not r[1] then return nil end
	return unpack(r, 2)
end

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function cuantas() return num(llamar(GetInboxNumItems)) or 0 end

-- -> { dinero, cod, dias, objetos, mj } de la carta i
local function carta(i)
	local _, _, _, _, dinero, cod, dias, objetos, _, _, _, _, mj = llamar(GetInboxHeaderInfo, i)
	return { dinero = num(dinero) or 0, cod = num(cod) or 0, dias = num(dias), objetos = num(objetos) or 0, mj = leer(mj) and true or false }
end
Bz.Carta = carta

local function maxAdjuntos() return num(rawget(_G, "ATTACHMENTS_MAX_RECEIVE")) or MAX_ADJUNTOS end

-- El primer adjunto que se puede tomar: -> a, id, cantidad
local function adjunto(i, fallidos)
	for a = 1, maxAdjuntos() do
		local nombre, id, _, cantidad = llamar(GetInboxItem, i, a)
		id = num(id)
		local hay = HasInboxItem and leer(llamar(HasInboxItem, i, a))
		if hay == nil then hay = leer(nombre) ~= nil end
		if hay and not (id and fallidos[id]) then return a, id, num(cantidad) or 1 end
	end
	return nil
end

local function libres()
	local C = C_Container
	if not C then return 99 end
	local n = num(llamar(C.CalculateTotalNumberOfFreeBagSlots))
	if n then return n end
	local total = 0
	for b = 0, 4 do
		local f, familia = llamar(C.GetContainerNumFreeSlots, b)
		if (num(familia) or 0) == 0 then total = total + (num(f) or 0) end
	end
	return total
end

local function pendienteDelJuego()
	local CM = C_Mail
	return CM and leer(llamar(CM.IsCommandPending)) and true or false
end

---------------------------------------------------------------------------
-- Tomar todo (siempre tras un clic)
---------------------------------------------------------------------------

local refrescarBarra -- abajo

local function abriendoTodo(si)
	local CM = C_Mail
	if CM and CM.SetOpeningAll then llamar(CM.SetOpeningAll, si and true or false) end
end

-- "Recibiste 3 objetos y 12 de oro" / ...
function Bz.TextoResumen(objetos, dinero)
	local o = objetos == 1 and L["1 objeto"] or format(L["%d objetos"], objetos)
	if objetos > 0 and dinero > 0 then return format(L["Recibiste %s y %s."], o, N.Dinero(dinero, true)) end
	if objetos > 0 then return format(L["Recibiste %s."], o) end
	if dinero > 0 then return format(L["Recibiste %s."], N.Dinero(dinero, true)) end
	return L["No había nada que tomar."]
end

local function terminar(corte)
	local t = tomando
	if not t then return end
	tomando = nil
	if t.ticker then t.ticker:Cancel() end
	abriendoTodo(false)
	local dinero = max(0, (num(GetMoney and GetMoney()) or t.dinero0) - t.dinero0)
	-- Las que se abren a mano y siguen ahí (contra entrega o de un MJ).
	t.saltadas = 0
	if corte ~= "cerrado" then
		for i = 1, cuantas() do
			local c = carta(i)
			if c.cod > 0 or c.mj then t.saltadas = t.saltadas + 1 end
		end
	end
	local partes = { Bz.TextoResumen(t.objetos, dinero) }
	if corte == "lleno" then
		partes[#partes + 1] = L["Tus bolsas se llenaron: lo demás sigue en el buzón."]
	elseif corte == "cerrado" then
		partes[#partes + 1] = L["Se cerró el buzón antes de terminar."]
	elseif corte == "combate" then
		partes[#partes + 1] = L["Paré por el combate: lo demás sigue en el buzón."]
	end
	if t.saltadas > 0 then
		partes[#partes + 1] = t.saltadas == 1 and L["Dejé 1 carta que se abre a mano (pago contra entrega o de un MJ)."]
			or format(L["Dejé %d cartas que se abren a mano (pago contra entrega o de un MJ)."], t.saltadas)
	end
	local texto = table.concat(partes, " ")
	Bz.ultimo = { objetos = t.objetos, dinero = dinero, saltadas = t.saltadas, corte = corte, texto = texto,
		cartas = cuantas(), t = GetTime and GetTime() or 0 }
	if K and K.Aviso then
		K.Aviso({ titulo = L["El buzón"], texto = texto, icono = "ic-oro", tono = corte and "aviso" or "exito", duracion = 8 })
	end
	if refrescarBarra then refrescarBarra() end
end
Bz.Terminar = terminar

-- Un paso: espera al buzón y toma lo siguiente.
local function paso()
	local t = tomando
	if not t then return end
	if not abierto then return terminar("cerrado") end
	if enCombate() then return terminar("combate") end
	local ahora = GetTime and GetTime() or 0
	if t.esperando then
		if ahora - t.desde < PAUSA then return end
		if (t.esperando == "evento" or pendienteDelJuego()) and ahora - t.desde < ESPERA_MAX then return end
		t.esperando = nil
	end
	while t.i >= 1 do
		local c = carta(t.i)
		if c.cod > 0 or c.mj then
			t.i = t.i - 1
		elseif c.dinero > 0 and not t.dineroPedido[t.i] then
			t.dineroPedido[t.i] = true
			llamar(TakeInboxMoney, t.i)
			t.esperando, t.desde = "evento", ahora
			return
		else
			local a, id, cantidad = nil, nil, nil
			if c.objetos > 0 then a, id, cantidad = adjunto(t.i, t.fallidos) end
			if a and libres() <= 0 then
				-- Sin espacio: los objetos se quedan, el dinero de las otras cartas no.
				t.lleno = true
				t.i = t.i - 1
			elseif a and (t.intentos[t.i .. ":" .. a] or 0) >= 3 then
				-- El buzón no lo suelta: se deja esa carta.
				t.i = t.i - 1
			elseif a then
				local clave = t.i .. ":" .. a
				t.intentos[clave] = (t.intentos[clave] or 0) + 1
				llamar(TakeInboxItem, t.i, a)
				t.objetos = t.objetos + (cantidad or 1)
				t.pedido = { id = id, cantidad = cantidad or 1 }
				t.esperando, t.desde = "evento", ahora
				return
			else
				t.i = t.i - 1
			end
		end
	end
	terminar(t.lleno and "lleno" or nil)
end
Bz.Paso = paso

function Bz.Tomando() return tomando ~= nil end

function Bz.Tomar()
	if tomando then return terminar("cancelado") end
	if abierto and not cargado and not enCombate() then
		-- Aún no llegan las cartas: se toma en cuanto lleguen.
		pendiente = true
		if CheckInbox then llamar(CheckInbox) end
		if refrescarBarra then refrescarBarra() end
		return true
	end
	if enCombate() then
		N.Imprimir(L["No se puede en combate."])
		return false
	end
	if not abierto then
		N.Imprimir(L["Abre un buzón para tomar tus cartas."])
		return false
	end
	-- De la última a la primera: una carta vacía se borra sola y las de antes
	-- no cambian de lugar.
	tomando = {
		i = cuantas(), objetos = 0, dineroPedido = {}, fallidos = {}, intentos = {},
		dinero0 = num(GetMoney and GetMoney()) or 0,
	}
	abriendoTodo(true)
	if refrescarBarra then refrescarBarra() end
	paso()
	if tomando and C_Timer and C_Timer.NewTicker then
		tomando.ticker = C_Timer.NewTicker(CADA, paso)
	end
	return true
end

A.RegisterEvent("MAIL_INBOX_UPDATE", function()
	cargado = true
	if pendiente and abierto and not tomando then
		pendiente = false
		Bz.Tomar()
	end
	if tomando and tomando.esperando == "evento" then tomando.esperando = "pausa" end
	if abierto and not avisoVisto then Bz.RevisarVence() end
end)
A.RegisterEvent("MAIL_FAILED", function(_, id)
	local t = tomando
	if not t then return end
	id = num(id)
	if t.pedido and (id == nil or id == t.pedido.id) then
		t.objetos = max(0, t.objetos - (t.pedido.cantidad or 1))
		if t.pedido.id then t.fallidos[t.pedido.id] = true end
		t.pedido = nil
	end
	if t.esperando == "evento" then t.esperando = "pausa" end
end)
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() if tomando then terminar("combate") end end)

---------------------------------------------------------------------------
-- Cartas que vencen pronto
---------------------------------------------------------------------------

local function textoDias(d)
	if d >= 2 then return format(L["%d días"], floor(d)) end
	if d >= 1 then return L["1 día"] end
	return L["menos de un día"]
end

-- -> cuántas cartas con objetos vencen en menos de 3 días, la que vence antes
function Bz.Vencen()
	local n, menor = 0, nil
	for i = 1, cuantas() do
		local c = carta(i)
		if c.objetos > 0 and c.dias and c.dias < VENCE then
			n = n + 1
			if not menor or c.dias < menor then menor = c.dias end
		end
	end
	return n, menor
end

function Bz.RevisarVence()
	if not M.Ajuste("buzonVence") or enCombate() then return end
	if cuantas() == 0 then return end
	avisoVisto = true
	local n, menor = Bz.Vencen()
	if n == 0 or not (K and K.Aviso) then return end
	local titulo = n == 1 and L["Una carta con objetos vence pronto"] or format(L["%d cartas con objetos vencen pronto"], n)
	local texto = format(L["La primera vence en %s. Tómala antes de que regrese a quien te la mandó o se pierda."], textoDias(menor))
	local o = { titulo = titulo, texto = texto, icono = "ic-reloj", tono = "aviso", duracion = 10 }
	if M.Ajuste("buzon") then o.accion = { texto = L["Tomar todo"], alClic = Bz.Tomar } end
	K.Aviso(o)
end

---------------------------------------------------------------------------
-- La barra bajo la ventana del buzón (hecha con el Kit)
---------------------------------------------------------------------------

local barra
local BARRA_W, BARRA_H = 384, 40 -- 1.3.0: más ancha, para que quepa el resumen

local function marcoBuzon() return rawget(_G, "MailFrame") end

local function textoEstado()
	if tomando then return L["Tomando tus cartas..."], "textoSuave" end
	if pendiente or (abierto and not cargado) then return L["Cargando tus cartas..."], "textoSuave" end
	-- El resumen se ve un rato y solo mientras el buzón siga igual.
	local u = Bz.ultimo
	if u and u.cartas == cuantas() and ((GetTime and GetTime() or 0) - (u.t or 0)) < 20 then
		return Bz.TextoResumen(u.objetos, u.dinero), "textoSuave"
	end
	local n = cuantas()
	if n == 0 then return L["No tienes cartas."], "textoSuave" end
	return n == 1 and L["1 carta"] or format(L["%d cartas"], n), "textoSuave"
end

function refrescarBarra()
	if not barra then return end
	local mostrar = abierto and M.Ajuste("buzon") and marcoBuzon() ~= nil
	barra:SetShown(mostrar and true or false)
	if not mostrar then return end
	local texto, color = textoEstado()
	K.Escribir(barra.Estado, texto)
	K.ColorTexto(barra.Estado, color)
	barra.Boton:SetTexto(tomando and L["Parar"] or L["Tomar todo"])
end
Bz.RefrescarBarra = function() refrescarBarra() end

local function crearBarra()
	if barra then return barra end
	local padre = marcoBuzon()
	if type(padre) ~= "table" then return nil end
	-- Como la barra de la subasta: cuelga de la capa de Alfa y solo se ancla
	-- al buzón (crear marcos dentro de una ventana del juego la contamina).
	barra = CreateFrame("Frame", nil, K.Raiz())
	if padre.GetFrameStrata then barra:SetFrameStrata(padre:GetFrameStrata()) end
	barra:SetSize(BARRA_W, BARRA_H)
	barra:SetPoint("TOPLEFT", padre, "BOTTOMLEFT", 0, -2)
	barra.caja = K.Caja(barra, { fondo = "fondo", borde = "linea", corte = K.CORTE.panel })
	barra.Marca = K.Marca(barra, K.CORTE.panel, "acento")
	barra.Icono = K.Icono(barra, "ic-oro", 18, "acento")
	barra.Icono:SetPoint("LEFT", barra, "LEFT", K.ESP.m, 0)
	barra.Titulo = K.Texto(barra, "encabezado", "texto")
	K.Escribir(barra.Titulo, "Alfa")
	barra.Titulo:SetPoint("LEFT", barra.Icono, "RIGHT", K.ESP.s, 0)
	barra.Boton = K.Boton(barra, L["Tomar todo"], function() Bz.Tomar() end, { tipo = "primario", tam = "chico", icono = "ic-oro" })
	barra.Boton:SetPoint("RIGHT", barra, "RIGHT", -K.ESP.m, 0)
	K.ConInfo(barra.Boton, L["Tomar todo"], L["Toma el dinero y los objetos de tus cartas, una por una. Las de pago contra entrega y las de un MJ se quedan para que las abras tú."])
	barra.Estado = K.Texto(barra, "pequeno", "textoSuave")
	barra.Estado:SetPoint("LEFT", barra.Titulo, "RIGHT", K.ESP.s, 0)
	barra.Estado:SetPoint("RIGHT", barra.Boton, "LEFT", -K.ESP.s, 0)
	-- 1.3.0: si el texto no cabe, completo con el ratón encima.
	barra:EnableMouse(true)
	barra:SetScript("OnEnter", function(self)
		local fs = self.Estado
		if fs and fs.IsTruncated and fs:IsTruncated() then K.MostrarInfo(self, L["El buzón"], fs:GetText() or "") end
	end)
	barra:SetScript("OnLeave", function(self) K.OcultarInfo(self) end)
	return barra
end

local function alAbrir()
	abierto = true
	avisoVisto = false
	Bz.ultimo = nil
	pendiente = false
	cargado = (num(llamar(GetInboxNumItems)) or 0) > 0
	if M.Ajuste("buzon") and not enCombate() then
		if crearBarra() then refrescarBarra() end
	end
	-- Las cartas llegan con MAIL_INBOX_UPDATE; si ya estaban, se revisa aquí.
	if C_Timer and C_Timer.After then
		C_Timer.After(1, function() if abierto and not avisoVisto then Bz.RevisarVence() end end)
	end
end

A.RegisterEvent("MAIL_SHOW", alAbrir)
A.RegisterEvent("MAIL_CLOSED", function()
	abierto = false
	cargado, pendiente = false, false
	if tomando then terminar("cerrado") end
	if barra then barra:Hide() end
end)
A.RegisterEvent("MAIL_INBOX_UPDATE", function() if barra and barra:IsShown() and not tomando then refrescarBarra() end end)

A.On("SETTING_CHANGED", function(path)
	if type(path) == "string" and path:sub(1, #M.ID + 1) == M.ID .. "." then
		if abierto and not barra and M.Ajuste("buzon") and not enCombate() then crearBarra() end
		refrescarBarra()
	end
end)

-- Para las pruebas y otros módulos.
function Bz.Abierto() return abierto end
