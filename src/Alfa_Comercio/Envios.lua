-- Alfa - Comercio: mandar a tu alt desde el buzón (1.3.7, toxic3000 / La Jauría). GPL-3.0.
--
-- Listas por personaje: «las hierbas a mi alquimista, las telas a mi sastre».
-- Con la pestaña de enviar del buzón abierta, una placa chica bajo el buzón
-- tiene un botón por lista: «Preparar». Alfa pone el nombre y adjunta lo de
-- tus bolsas que va en esa lista (hasta llenar la carta). El clic en «Enviar»
-- siempre es tuyo: Alfa nunca manda la carta (SendMail y su confirmación
-- C_SecureTransfer.SendMail tienen restricciones; ni se tocan).
--
-- Las listas se arman con un comando (por reino y facción, en los datos de
-- la cuenta):
--   /alfa comercio alt                         tus listas
--   /alfa comercio alt Nombre hierbas telas    agrega tipos o objetos (enlace o nombre)
--   /alfa comercio alt Nombre quitar hierbas   quita un tipo u objeto
--   /alfa comercio alt Nombre quitar           borra la lista
--
-- Tipos: los materiales de oficio del juego (classID 7, Enum.ItemClass.Tradegoods)
-- por su subclase: 5 telas, 6 cuero, 7 metal y piedra, 8 cocina, 9 hierbas,
-- 10 elementales, 12 encantamiento, 1 piezas (ingeniería). (Por confirmar en
-- Forever: algunos materiales viejos pueden venir con otra subclase.)
--
-- API: C_Container.GetContainerItemInfo (isBound, isLocked, itemID),
-- C_Container.PickupContainerItem (sin restricciones, ContainerDocumentation),
-- y las clásicas del buzón ClickSendMailItemButton(i), HasSendMailItem(i),
-- ATTACHMENTS_MAX_SEND y SendMailNameEditBox (Blizzard_MailFrame; no están en
-- la documentación generada: van protegidas). Nada en combate.

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local type, pairs, ipairs, tostring, tonumber, format = type, pairs, ipairs, tostring, tonumber, string.format

local En = {}
M.Envios = En

local CLASE_OFICIO = 7
En.TIPOS = {
	{ id = "hierbas", sub = 9, nombre = "hierbas", palabras = { "hierbas", "hierba", "herbs", "herb" } },
	{ id = "metal", sub = 7, nombre = "metal y piedra", palabras = { "metal", "minerales", "mineral", "piedra", "ore", "metals" } },
	{ id = "telas", sub = 5, nombre = "telas", palabras = { "telas", "tela", "cloth" } },
	{ id = "cuero", sub = 6, nombre = "cuero", palabras = { "cuero", "pieles", "leather" } },
	{ id = "cocina", sub = 8, nombre = "cocina", palabras = { "cocina", "carne", "cooking", "meat" } },
	{ id = "elemental", sub = 10, nombre = "elementales", palabras = { "elemental", "elementales" } },
	{ id = "encantar", sub = 12, nombre = "encantamiento", palabras = { "encantar", "encantamiento", "enchanting" } },
	{ id = "piezas", sub = 1, nombre = "piezas de ingeniería", palabras = { "piezas", "ingenieria", "ingeniería", "parts" } },
}
local POR_PALABRA, POR_ID = {}, {}
for _, t in ipairs(En.TIPOS) do
	POR_ID[t.id] = t
	for _, p in ipairs(t.palabras) do POR_PALABRA[p] = t end
end

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

---------------------------------------------------------------------------
-- Las listas
--   M.Datos().envios = { ["Reino-Facción"] = { [Nombre] = { tipos = { hierbas = true }, ids = { [itemID] = true } } } }
---------------------------------------------------------------------------

function En.Listas()
	local d = M.Datos()
	d.envios = type(d.envios) == "table" and d.envios or {}
	local rk = M.ClaveReino()
	d.envios[rk] = type(d.envios[rk]) == "table" and d.envios[rk] or {}
	return d.envios[rk]
end

local function normal(nombre)
	nombre = tostring(nombre or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if nombre == "" then return nil end
	-- «Nombre» con mayúscula inicial, como en el juego (respeta letras con acento).
	local primera, resto = nombre:match("^([%z\1-\127\194-\244][\128-\191]*)(.*)$")
	if primera and #primera == 1 then return primera:upper() .. resto:lower() end
	return nombre
end
En.Normal = normal

local function lista(nombre, crear)
	local ls = En.Listas()
	local l = ls[nombre]
	if type(l) ~= "table" then
		if not crear then return nil end
		l = {}
		ls[nombre] = l
	end
	l.tipos = type(l.tipos) == "table" and l.tipos or {}
	l.ids = type(l.ids) == "table" and l.ids or {}
	return l
end
En.Lista = lista

-- ¿Este objeto va en esa lista?
function En.Va(l, id, info)
	if type(l) ~= "table" or type(id) ~= "number" then return false end
	if l.ids and l.ids[id] then return true end
	info = info or M.InfoObjeto(id)
	if not info or info.clase ~= CLASE_OFICIO then return false end
	for tid in pairs(l.tipos or {}) do
		local t = POR_ID[tid]
		if t and t.sub == info.subclase then return true end
	end
	return false
end

-- Texto corto de una lista: «hierbas, telas y 2 objetos»
function En.Resumen(l)
	local partes = {}
	for _, t in ipairs(En.TIPOS) do
		if l.tipos[t.id] then partes[#partes + 1] = L[t.nombre] end
	end
	local n = 0
	for _ in pairs(l.ids) do n = n + 1 end
	if n > 0 then partes[#partes + 1] = N.Plural(n, L["%d objeto"], L["%d objetos"]) end
	if #partes == 0 then return L["(vacía)"] end
	return table.concat(partes, ", ")
end

-- Agrega o quita un tipo u objeto por su palabra, enlace o nombre.
-- -> "tipo" | "objeto" | nil, y lo que se agregó (texto)
function En.Cambiar(nombre, palabra, quitar)
	local l = lista(nombre, not quitar)
	if not l then return nil end
	local p = tostring(palabra or ""):lower()
	local t = POR_PALABRA[p]
	if t then
		l.tipos[t.id] = (not quitar) or nil
		return "tipo", L[t.nombre]
	end
	local id = tonumber(tostring(palabra):match("item:(%d+)") or palabra) or M.BuscarPorNombre(palabra)
	if not id then return nil end
	l.ids[id] = (not quitar) or nil
	local info = M.InfoObjeto(id)
	return "objeto", info and (info.link or info.nombre) or ("#" .. id)
end

function En.Borrar(nombre)
	local ls = En.Listas()
	if ls[nombre] == nil then return false end
	ls[nombre] = nil
	return true
end

-- De tus bolsas, lo que va en esa lista: { { bolsa, ranura, id, cantidad }, ... }
function En.Candidatos(l)
	local out = {}
	local C = C_Container
	if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return out end
	local yo = M.NombrePersonaje()
	for bolsa = 0, 4 do
		local n = C.GetContainerNumSlots(bolsa)
		for ranura = 1, (type(n) == "number" and n or 0) do
			local ok, info = pcall(C.GetContainerItemInfo, bolsa, ranura)
			local id = ok and type(info) == "table" and info.itemID
			-- 1.3.8: lo que tiene candado (Alfa_Bolsas, Candado.lua) no se manda.
			local candado = AlfaBolsas and AlfaBolsas.TieneCandado
			if type(id) == "number" and info.isBound ~= true and info.isLocked ~= true and En.Va(l, id)
				and not (candado and candado(bolsa, ranura)) then
				out[#out + 1] = { bolsa = bolsa, ranura = ranura, id = id, cantidad = info.stackCount or 1 }
			end
		end
	end
	out.yo = yo
	return out
end

function En.Piezas(c)
	local n = 0
	for _, e in ipairs(c) do n = n + (e.cantidad or 1) end
	return n
end

---------------------------------------------------------------------------
-- Preparar la carta (tras tu clic)
---------------------------------------------------------------------------

local function maxAdjuntos() return tonumber(rawget(_G, "ATTACHMENTS_MAX_SEND")) or 12 end

local function enviarVisible()
	local f = rawget(_G, "SendMailFrame")
	return type(f) == "table" and type(f.IsVisible) == "function" and f:IsVisible() and true or false
end
En.EnviarVisible = enviarVisible

local function ranuraLibre()
	local has = rawget(_G, "HasSendMailItem")
	if type(has) ~= "function" then return nil end
	for i = 1, maxAdjuntos() do
		local ok, hay = pcall(has, i)
		if ok and not hay then return i end
	end
	return nil
end

local preparando -- { nombre, cola, puestos, piezas }
local placa
local pintar -- abajo

local function fin(texto)
	preparando = nil
	N.Quitar("comercio.envio")
	if placa then placa.estado = texto end
	if pintar then pintar() end
end

-- Un objeto a la carta cada tanto (el buzón tarda en tomar cada uno).
local function adjuntarUno()
	local p = preparando
	if not p then return N.Quitar("comercio.envio") end
	if enCombate() or not enviarVisible() then return fin(L["Se detuvo: cerraste el buzón o entraste en combate."]) end
	local e = table.remove(p.cola, 1)
	local libre = ranuraLibre()
	if not e or not libre then
		local texto = p.puestos > 0 and format(L["Listo: %s para %s. Revisa la carta y pulsa «Enviar»."], N.Plural(p.piezas, L["%d pieza"], L["%d piezas"]), p.nombre)
			or L["No había nada de esa lista en tus bolsas."]
		if e and not libre then texto = texto .. " " .. L["La carta ya está llena: manda esta y prepara otra."] end
		return fin(texto)
	end
	local C = C_Container
	local cursor = rawget(_G, "CursorHasItem")
	if type(cursor) == "function" and cursor() then return fin(L["Suelta lo que traes en el cursor y vuelve a intentarlo."]) end
	local ok = pcall(C.PickupContainerItem, e.bolsa, e.ranura)
	local click = rawget(_G, "ClickSendMailItemButton")
	if ok and type(click) == "function" then
		ok = pcall(click, libre)
	elseif ok and C.UseContainerItem then
		local limpiar = rawget(_G, "ClearCursor")
		if type(limpiar) == "function" then pcall(limpiar) end
		ok = pcall(C.UseContainerItem, e.bolsa, e.ranura)
	end
	if ok then
		p.puestos = p.puestos + 1
		p.piezas = p.piezas + (e.cantidad or 1)
	end
	if pintar then pintar() end
end
En.AdjuntarUno = adjuntarUno

function En.Preparar(nombre)
	if enCombate() then
		N.Imprimir(L["Se puede al salir de combate."])
		return false
	end
	if not enviarVisible() then
		N.Imprimir(L["Abre la pestaña «Enviar» del buzón."])
		return false
	end
	if preparando then return fin(L["Paraste: lo que ya estaba en la carta se queda."]) end
	local l = lista(nombre)
	if not l then return false end
	if M.NombrePersonaje() == nombre then
		N.Imprimir(L["Esa lista es para ti: no te puedes mandar cartas."])
		return false
	end
	local caja = rawget(_G, "SendMailNameEditBox")
	if type(caja) == "table" and caja.SetText then pcall(caja.SetText, caja, nombre) end
	preparando = { nombre = nombre, cola = En.Candidatos(l), puestos = 0, piezas = 0 }
	if placa then placa.estado = nil end
	adjuntarUno()
	if preparando then N.Cada("comercio.envio", 0.15, adjuntarUno) end
	return true
end

function En.Preparando() return preparando end

---------------------------------------------------------------------------
-- La placa bajo el buzón (solo con la pestaña de enviar)
---------------------------------------------------------------------------

local PLACA_W, FILA_H, MAX_FILAS = 320, 26, 4

local function nombres()
	local out = {}
	for nombre, l in pairs(En.Listas()) do
		if type(l) == "table" then out[#out + 1] = nombre end
	end
	table.sort(out)
	return out
end
En.Nombres = nombres

local function armar()
	if placa then return placa end
	local padre = rawget(_G, "MailFrame")
	if type(padre) ~= "table" or type(padre.GetObjectType) ~= "function" or not K then return nil end
	placa = CreateFrame("Frame", nil, K.Raiz())
	if padre.GetFrameStrata then placa:SetFrameStrata(padre:GetFrameStrata()) end
	placa:SetWidth(PLACA_W)
	placa:SetPoint("TOPLEFT", padre, "BOTTOMLEFT", 0, -2)
	placa.caja = K.Caja(placa, { fondo = "fondo", borde = "linea", corte = K.CORTE.panel })
	placa.Titulo = K.Texto(placa, "encabezado", "texto")
	placa.Titulo:SetPoint("TOPLEFT", placa, "TOPLEFT", K.ESP.m, -K.ESP.s)
	K.Escribir(placa.Titulo, L["Mandar a tu alt"])
	placa.Estado = K.Texto(placa, "pequeno", "textoSuave")
	placa.Estado:SetJustifyH("LEFT")
	placa.filas = {}
	for i = 1, MAX_FILAS do
		local f = CreateFrame("Frame", nil, placa)
		f:SetSize(PLACA_W - 2 * K.ESP.m, FILA_H)
		f.Boton = K.Boton(f, L["Preparar"], function(b) if b.alfaNombre then En.Preparar(b.alfaNombre) end end, { tipo = "secundario", tam = "chico" })
		f.Boton:SetPoint("RIGHT", f, "RIGHT", 0, 0)
		f.Texto = K.Texto(f, "pequeno", "texto")
		f.Texto:SetPoint("LEFT", f, "LEFT", 0, 0)
		f.Texto:SetPoint("RIGHT", f.Boton, "LEFT", -K.ESP.s, 0)
		f.Texto:SetJustifyH("LEFT")
		placa.filas[i] = f
	end
	placa:Hide()
	return placa
end

-- 1.3.7: con la placa del buzón a la vista (tomando tus cartas), esta va
-- debajo de ella; si no, bajo el buzón. Las dos usaban el mismo lugar.
local function colocar()
	if not placa then return end
	local bz = M.Buzon and M.Buzon.Placa and M.Buzon.Placa()
	local bajo = type(bz) == "table" and bz:IsShown() and bz or nil
	if placa.alfaBajo == (bajo or false) and placa:GetNumPoints() > 0 then return end
	placa.alfaBajo = bajo or false
	placa:ClearAllPoints()
	if bajo then
		placa:SetPoint("TOPLEFT", bajo, "BOTTOMLEFT", 0, -2)
	else
		local padre = rawget(_G, "MailFrame")
		if type(padre) == "table" then placa:SetPoint("TOPLEFT", padre, "BOTTOMLEFT", 0, -2) end
	end
end
En.Colocar = colocar

function pintar()
	local ver = M.Ajuste("buzonAlt") ~= false and enviarVisible() and not enCombate()
	if not ver then
		if placa then placa:Hide() end
		return
	end
	local p = armar()
	if not p then return end
	local lista = nombres()
	local y = -K.ESP.s - 18
	for i = 1, MAX_FILAS do
		local f, nombre = p.filas[i], lista[i]
		if nombre then
			local l = En.Lista(nombre)
			local c = En.Candidatos(l)
			local piezas = En.Piezas(c)
			f.Boton.alfaNombre = nombre
			local enCurso = preparando and preparando.nombre == nombre
			f.Boton:SetTexto(enCurso and L["Parar"] or L["Preparar"])
			f.Boton:SetActivo(enCurso or (piezas > 0 and nombre ~= M.NombrePersonaje()))
			K.Escribir(f.Texto, nombre .. " · " .. En.Resumen(l) .. " (" .. N.Plural(piezas, L["%d pieza"], L["%d piezas"]) .. ")")
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", p, "TOPLEFT", K.ESP.m, y)
			f:Show()
			y = y - FILA_H
		else
			f:Hide()
		end
	end
	local texto = p.estado
	if #lista == 0 then texto = L["Arma una lista: /alfa comercio alt <nombre> hierbas"] end
	if not texto and preparando then
		texto = format(L["Poniendo %s en la carta…"], N.Plural(preparando.piezas, L["%d pieza"], L["%d piezas"]))
	end
	texto = texto or L["El clic en «Enviar» siempre es tuyo."]
	p.Estado:ClearAllPoints()
	p.Estado:SetPoint("TOPLEFT", p, "TOPLEFT", K.ESP.m, y - 2)
	K.Parrafo(p.Estado, PLACA_W - 2 * K.ESP.m, 2)
	K.Escribir(p.Estado, texto)
	local alto = -y + 2 + K.AltoTexto(p.Estado) + K.ESP.s
	p:SetHeight(math.max(48, math.floor(alto + 0.5)))
	colocar()
	p:Show()
end
En.Pintar = function() pintar() end
function En.Placa() return placa end

-- Mientras el buzón está abierto se mira cada medio segundo si estás en la
-- pestaña de enviar (el juego no avisa al cambiar de pestaña).
A.RegisterEvent("MAIL_SHOW", function()
	if M.Ajuste("buzonAlt") == false then return end
	N.Cada("comercio.envios", 0.5, function()
		local ver = enviarVisible() and not enCombate()
		if ver ~= (placa and placa:IsShown() or false) or (ver and preparando) then pintar() end
		if placa and placa:IsShown() then colocar() end
	end)
end)
A.RegisterEvent("MAIL_CLOSED", function()
	N.Quitar("comercio.envios")
	if preparando then fin(nil) end
	if placa then placa.estado = nil placa:Hide() end
end)
A.RegisterEvent("BAG_UPDATE_DELAYED", function() if placa and placa:IsShown() and not preparando then pintar() end end)
A.RegisterEvent("MAIL_SEND_SUCCESS", function() if placa then placa.estado = nil end if placa and placa:IsShown() then pintar() end end)

---------------------------------------------------------------------------
-- /alfa comercio alt ...
---------------------------------------------------------------------------

function En.Comando(arg)
	arg = tostring(arg or "")
	local palabras = {}
	-- Los enlaces de objeto llevan espacios: cada uno es una palabra.
	arg = arg:gsub("(|c%x+|Hitem:.-|h.-|h|r)", function(link) palabras[#palabras + 1] = link return " " end)
	local sueltas = {}
	for w in arg:gmatch("%S+") do sueltas[#sueltas + 1] = w end
	local nombre = normal(sueltas[1])
	if not nombre then
		local ls = nombres()
		if #ls == 0 then
			N.Imprimir(L["Aún no tienes listas. Ejemplo: /alfa comercio alt Nombre hierbas telas"])
		else
			for _, n in ipairs(ls) do N.Imprimir(n .. ": " .. En.Resumen(En.Lista(n))) end
		end
		N.Imprimir(L["Tipos: hierbas, metal, telas, cuero, cocina, elemental, encantar, piezas. También un objeto (enlace o nombre)."])
		return
	end
	local quitar = sueltas[2] and (sueltas[2]:lower() == "quitar" or sueltas[2]:lower() == "remove")
	local desde = quitar and 3 or 2
	for i = desde, #sueltas do palabras[#palabras + 1] = sueltas[i] end
	if quitar and #palabras == 0 then
		if En.Borrar(nombre) then N.Imprimir(format(L["Borré la lista de %s."], nombre)) end
		pintar()
		return
	end
	if #palabras == 0 then
		local l = En.Lista(nombre)
		N.Imprimir(nombre .. ": " .. (l and En.Resumen(l) or L["(vacía)"]))
		return
	end
	-- Un nombre de objeto con espacios («Hoja de plata») se busca entero si
	-- sus palabras sueltas no son tipos.
	local todo = table.concat(palabras, " ")
	local hechos = {}
	local sinTipo = true
	for _, w in ipairs(palabras) do if POR_PALABRA[w:lower()] or w:find("|Hitem:") then sinTipo = false end end
	if sinTipo and #palabras > 1 then palabras = { todo } end
	for _, w in ipairs(palabras) do
		local que, texto = En.Cambiar(nombre, w, quitar)
		if que then hechos[#hechos + 1] = texto else N.Imprimir(format(L["No reconozco «%s»."], w)) end
	end
	if #hechos > 0 then
		N.Imprimir(format(quitar and L["Quité de la lista de %s: %s."] or L["En la lista de %s: %s."], nombre, table.concat(hechos, ", ")))
	end
	pintar()
end

-- 1.3.9: Bolsas («Lo que me sobra», Sobra.lua) lee tus listas y prepara la carta.
AlfaComercio = type(AlfaComercio) == "table" and AlfaComercio or {}
AlfaComercio.Envios = En
