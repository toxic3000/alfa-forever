-- Alfa - Comercio: el buzón (toxic3000 / La Jauría). GPL-3.0. 1.2.8.
--
-- 1.3.2 (Toxic): ya no hay barra bajo el buzón (se quedaba a la vista y el
-- juego trae su propio «Abrir todo»). «Tomar todo» sigue en el aviso de las
-- cartas que vencen: tras ese clic, Alfa toma el dinero y los objetos de tus
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

-- "Recibiste 3 piezas y 12 de oro" / ... 1.3.7: cuenta piezas (20 de una
-- pila son 20 piezas), así que dice «piezas», no «objetos».
function Bz.TextoResumen(objetos, dinero)
	local o = N.Plural(objetos, L["%d pieza"], L["%d piezas"])
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
	if Bz.PintarProgreso then Bz.PintarProgreso() end
	-- 1.3.1: en el juego tu oro sube un momento después de tomarlo (PLAYER_MONEY
	-- llega tarde), así que no basta con comparar tu oro: también cuenta el
	-- dinero que ya salió de las cartas (t.recibido). Sin esto decía «No había
	-- nada que tomar» aunque el chat dijera «Obtuviste: 7s 35c».
	local dinero = max(0, (num(GetMoney and GetMoney()) or t.dinero0) - t.dinero0, t.recibido or 0)
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
	elseif corte == "cancelado" then
		partes[#partes + 1] = L["Paraste: lo demás sigue en el buzón."]
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
		-- El dinero pedido a esta carta ya salió de ella: es tuyo aunque tu oro
		-- todavía no suba (si la carta se borró al vaciarse, también).
		local monto = t.dineroMonto[t.i]
		if monto and c.dinero < monto then
			t.recibido = t.recibido + (monto - c.dinero)
			t.dineroMonto[t.i] = nil
		end
		if c.cod > 0 or c.mj then
			t.i = t.i - 1
		elseif c.dinero > 0 and not t.dineroPedido[t.i] then
			t.dineroPedido[t.i] = true
			t.dineroMonto[t.i] = c.dinero
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
function Bz.Pendiente() return pendiente end

function Bz.Tomar()
	if tomando then return terminar("cancelado") end
	-- 1.3.2: pedido mientras cargan las cartas: el botón dice «Parar» y otro
	-- clic lo cancela (antes seguía «Tomar todo» y empezaba solo al llegar).
	if pendiente then
		pendiente = false
		if refrescarBarra then refrescarBarra() end
		return false
	end
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
		dineroMonto = {}, recibido = 0,
		dinero0 = num(GetMoney and GetMoney()) or 0,
	}
	tomando.total = tomando.i
	abriendoTodo(true)
	if refrescarBarra then refrescarBarra() end
	paso()
	Bz.PintarProgreso()
	-- 1.3.1: el paso lo mueve el reloj de Alfa (N.Ticker: se ve en /alfa
	-- rendimiento y un error repetido lo quita), no un C_Timer.NewTicker suelto.
	if tomando and N.Ticker then
		tomando.ticker = N.Ticker("comercio.buzon", CADA, function() paso() Bz.PintarProgreso() end)
	end
	return true
end

---------------------------------------------------------------------------
-- 1.3.7: cómo va «Tomar todo». Una placa chica bajo el buzón, solo mientras
-- Alfa toma tus cartas (o espera a que carguen): «Tomando tus cartas: 3 de
-- 12», una barra y el botón «Parar». Al terminar se va sola (el resumen sale
-- en el aviso). No es la barra de antes: esa no vuelve (1.3.2).
---------------------------------------------------------------------------

local placa
local PLACA_W, PLACA_H = 320, 40

local function armarPlaca()
	if placa then return placa end
	local padre = rawget(_G, "MailFrame")
	if type(padre) ~= "table" or type(padre.GetObjectType) ~= "function" or not K then return nil end
	placa = CreateFrame("Frame", nil, K.Raiz())
	if padre.GetFrameStrata then placa:SetFrameStrata(padre:GetFrameStrata()) end
	placa:SetSize(PLACA_W, PLACA_H)
	placa:SetPoint("TOPLEFT", padre, "BOTTOMLEFT", 0, -2)
	placa.caja = K.Caja(placa, { fondo = "fondo", borde = "linea", corte = K.CORTE.panel })
	placa.Icono = K.Icono(placa, "ic-oro", 16, "acento")
	placa.Icono:SetPoint("LEFT", placa, "LEFT", K.ESP.m, 0)
	placa.Boton = K.Boton(placa, L["Parar"], function() Bz.Tomar() end, { tipo = "secundario", tam = "chico" })
	placa.Boton:SetPoint("RIGHT", placa, "RIGHT", -K.ESP.m, 0)
	placa.Texto = K.Texto(placa, "pequeno", "texto")
	placa.Texto:SetPoint("LEFT", placa.Icono, "RIGHT", K.ESP.s, 0)
	placa.Texto:SetPoint("RIGHT", placa.Boton, "LEFT", -K.ESP.s, 0)
	placa.Texto:SetWordWrap(true)
	if placa.Texto.SetMaxLines then placa.Texto:SetMaxLines(2) end
	placa.Texto:SetJustifyH("LEFT")
	placa.Barra = K.Progreso(placa, { alto = 2 })
	placa.Barra:SetPoint("BOTTOMLEFT", placa, "BOTTOMLEFT", K.CORTE.panel, 1)
	placa.Barra:Acomodar(PLACA_W - 2 * K.CORTE.panel)
	placa:Hide()
	return placa
end

function Bz.PintarProgreso()
	local ver = abierto and (tomando ~= nil or pendiente)
	if not ver then
		if placa then placa:Hide() end
		return
	end
	local p = armarPlaca()
	if not p then return end
	local t = tomando
	if t then
		local total = max(1, t.total or 1)
		local hechas = min(total, max(0, total - (t.i or 0)))
		local texto = format(L["Tomando tus cartas: %d de %d"], hechas, total)
		if t.objetos > 0 then texto = texto .. " · " .. N.Plural(t.objetos, L["%d pieza"], L["%d piezas"]) end
		K.Escribir(p.Texto, texto)
		p.Barra:Show()
		p.Barra:Set(hechas / total)
	else
		K.Escribir(p.Texto, L["Cargando tus cartas..."])
		p.Barra:Hide()
	end
	p:Show()
end
function Bz.Placa() return placa end

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
	Bz.PintarProgreso()
	if not barra then return end
	local mostrar = abierto and M.Ajuste("buzon") and marcoBuzon() ~= nil
	barra:SetShown(mostrar and true or false)
	if not mostrar then return end
	local texto, color = textoEstado()
	K.Escribir(barra.Estado, texto)
	K.ColorTexto(barra.Estado, color)
	barra.Boton:SetTexto((tomando or pendiente) and L["Parar"] or L["Tomar todo"])
end
Bz.RefrescarBarra = function() refrescarBarra() end

local function alAbrir()
	abierto = true
	avisoVisto = false
	Bz.ultimo = nil
	pendiente = false
	cargado = (num(llamar(GetInboxNumItems)) or 0) > 0
	-- 1.3.2: sin barra bajo el buzón.
	-- Las cartas llegan con MAIL_INBOX_UPDATE; si ya estaban, se revisa aquí.
	N.Una("comercio.buzonVence", 1, function() if abierto and not avisoVisto then Bz.RevisarVence() end end)
end

A.RegisterEvent("MAIL_SHOW", alAbrir)
A.RegisterEvent("MAIL_CLOSED", function()
	abierto = false
	cargado, pendiente = false, false
	if tomando then terminar("cerrado") end
	if barra then barra:Hide() end
	if placa then placa:Hide() end
end)
A.RegisterEvent("MAIL_INBOX_UPDATE", function() if barra and barra:IsShown() and not tomando then refrescarBarra() end end)

A.On("SETTING_CHANGED", function(path)
	if type(path) == "string" and path:sub(1, #M.ID + 1) == M.ID .. "." then
		refrescarBarra()
	end
end)

-- Para las pruebas y otros módulos.
function Bz.Abierto() return abierto end
function Bz.Barra() return barra end
