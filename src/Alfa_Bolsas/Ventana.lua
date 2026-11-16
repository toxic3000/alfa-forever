-- Alfa - Bolsas: las ventanas de bolsas y de banco. GPL-3.0.
--
-- Hechas con el Kit de Alfa (docs/KIT.md): la caja con sus esquinas
-- cortadas y la marca de acento; una cabecera con el título, las tres vistas
-- y sus botones; una franja con la búsqueda, Ordenar y, en el banco,
-- Depositar; la barra de las bolsas equipadas (Barra.lua); cuando las bolsas
-- se llenan, la sugerencia de qué vender (Sugerencias.lua); el cuerpo con
-- las casillas (se desplaza si no cabe) y un pie con tu dinero, el de toda la
-- cuenta y el espacio libre. Vive en UIParent (no en la capa de Alfa): tus
-- bolsas se abren aunque ocultes Alfa.
--
-- Tres vistas (ajuste "vista"): todo junto ("una": cada casilla en su
-- orden), por categorías (encabezados plegables, Espacio libre al final) y
-- por bolsa (cada bolsa en su bloque, con su ícono, nombre y espacio).
--
-- En vivo (tus bolsas; tu banco mientras está abierto) cada casilla es un
-- botón seguro de Blizzard (Botones.lua); de foto (el banco cerrado, otro
-- personaje) son botones simples con los datos guardados (Datos.lua).
--
-- Trabajo por lotes: los cambios (BAG_UPDATE, una búsqueda, un ajuste)
-- solo marcan qué falta; un OnUpdate que existe mientras hay trabajo lee
-- las bolsas marcadas, crea a lo sumo TOPE_CREAR botones y pinta a lo sumo
-- TOPE_PINTAR casillas por cuadro. Una casilla cuyo contenido no cambió no
-- se vuelve a pintar (su firma es la misma). Los botones se reutilizan.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local D, O, B = M.Datos, M.Objetos, M.Botones
local K = N.Kit
local ESP = K.ESP

local type, pairs, ipairs, tonumber, tostring, next, format = type, pairs, ipairs, tonumber, tostring, next, string.format
local floor, max, min = math.floor, math.max, math.min

local V = {}
M.Ventana = V

local CAB_H, FRANJA_H, PIE_H = 48, 44, 36
local PAD, GAP, CAB_CAT = ESP.m, 4, 26
local MIN_W = 400
local TOPE_PINTAR, TOPE_CREAR = 48, 40

local CC = C_Container
local ventanas = {}  -- "bolsas" | "banco" -> marco
local recientes = {} -- bolsa * 1000 + casilla -> id: lo nuevo desde que abriste las bolsas

local function vaciar(t) for k in pairs(t) do t[k] = nil end return t end

---------------------------------------------------------------------------
-- Qué muestra cada ventana
---------------------------------------------------------------------------

local function llaveroVisible()
	local f = C_ActionBar and C_ActionBar.ShouldShowKeyring
	if type(f) ~= "function" then return false end
	return M.Leer(M.Llamar(f)) and true or false
end

local function contenedores(f)
	if f.tipo == "banco" then return D.BANCO end
	local t = {}
	for _, b in ipairs(D.BOLSAS) do t[#t + 1] = b end
	if M.Get("llavero") and llaveroVisible() then t[#t + 1] = D.LLAVERO end
	return t
end

local function propia(f) return f.clave == nil or D.EsActual(f.clave) end
V.Propia = propia

-- En vivo: tus bolsas siempre; tu banco solo mientras lo tienes abierto.
local function enVivo(f)
	if not propia(f) then return false end
	if f.tipo == "banco" then return D.BancoAbierto() end
	return true
end

local function esMejora(link)
	local G = A.Gear
	local Bg = G and G.Bags
	if not (Bg and Bg.IsUpgrade) then return false end
	return M.Leer(M.Llamar(Bg.IsUpgrade, link)) and true or false
end

local function esChatarraMarcada(id)
	local Q = A.QoL
	local Mk = Q and Q.Marks
	return Mk and Mk.Junk and M.Leer(M.Llamar(Mk.Junk, id)) and true or false
end

-- Cuántas casillas del llavero se muestran (como el llavero de Blizzard).
local function tamLlavero(n)
	if type(GetKeyRingSize) == "function" then
		local k = M.Num(M.Llamar(GetKeyRingSize))
		if k and k > 0 then return min(n, k) end
	end
	return n
end

---------------------------------------------------------------------------
-- Lectura en vivo
---------------------------------------------------------------------------

local function leerCasilla(f, bolsa, s)
	local info = M.Llamar(CC and CC.GetContainerItemInfo, bolsa, s)
	local clave = bolsa * 1000 + s
	if type(info) ~= "table" then
		if f.tipo == "bolsas" then recientes[clave] = nil end
		return nil
	end
	local id = M.Num(info.itemID)
	if not id then return nil end
	local rec = {
		i = id, c = M.Num(info.stackCount) or 1, l = M.Texto(info.hyperlink), q = M.Num(info.quality),
		icono = M.Leer(info.iconFileID), bloq = M.Leer(info.isLocked) and true or false,
		sinValor = M.Leer(info.hasNoValue) and true or false, basura = esChatarraMarcada(id),
	}
	local q = M.Llamar(CC and CC.GetContainerItemQuestInfo, bolsa, s)
	if type(q) == "table" then
		local qid = M.Num(q.questID)
		rec.mision = (M.Leer(q.isQuestItem) or qid) and true or false
		rec.bang = qid ~= nil and not M.Leer(q.isActive)
	end
	if f.tipo == "bolsas" then
		if recientes[clave] and recientes[clave] ~= id then recientes[clave] = nil end
		local nuevo = C_NewItems and M.Leer(M.Llamar(C_NewItems.IsNewItem, bolsa, s))
		if nuevo then recientes[clave] = id end
		rec.nuevo = recientes[clave] ~= nil
	end
	return rec
end

local function escanearVivo(f, bolsa)
	local n = M.Num(M.Llamar(CC and CC.GetContainerNumSlots, bolsa)) or 0
	local t = f.vivo[bolsa]
	if not t then
		t = {}
		f.vivo[bolsa] = t
	end
	for s = n + 1, tonumber(t.n) or 0 do t[s] = nil end
	t.n = n
	for s = 1, n do t[s] = leerCasilla(f, bolsa, s) end
end

---------------------------------------------------------------------------
-- Botones de cada casilla
---------------------------------------------------------------------------

local function porta(f, bolsa)
	local h = f.portas[bolsa]
	if h then return h end
	h = CreateFrame("Frame", nil, f.Contenido)
	h:SetID(bolsa)
	h:SetAllPoints(f.Contenido)
	h:SetFrameLevel(f.Contenido:GetFrameLevel() + 1)
	f.portas[bolsa] = h
	return h
end

-- Crea los botones en vivo que faltan, a lo sumo TOPE_CREAR. -> true si ya están todos.
local function crearLote(f)
	local hechos = 0
	for _, bolsa in ipairs(contenedores(f)) do
		local t = f.vivo[bolsa]
		local n = t and tonumber(t.n) or 0
		local fila = f.vivos[bolsa]
		if not fila then
			fila = {}
			f.vivos[bolsa] = fila
		end
		for s = 1, n do
			if fila[s] == nil then
				if hechos >= TOPE_CREAR then return false end
				local b = B.Vivo(porta(f, bolsa))
				if b then
					b:SetID(s)
					b:Hide()
					fila[s] = b
				else
					fila[s] = false
				end
				hechos = hechos + 1
			end
		end
	end
	return true
end

local function botonFoto(f, i)
	local b = f.fotos[i]
	if not b then
		b = B.Foto(f.Contenido)
		f.fotos[i] = b
	end
	return b
end

---------------------------------------------------------------------------
-- Entradas: lo que se pinta en cada casilla
---------------------------------------------------------------------------

local function entrada(bolsa, s, rec, propio)
	local ent = { bolsa = bolsa, casilla = s, rec = rec, orden = (bolsa + 2) * 1000 + s }
	if rec then
		local e = O.Info(rec.i, rec.l)
		ent.e = e
		if O.EsEquipo(e) then
			ent.nivel = O.Nivel(rec.l) or e.nivelBase
			if propio and rec.l and M.Get("marcaMejora") then ent.mejora = esMejora(rec.l) end
		end
		ent.cat = O.Categoria(rec, e, bolsa)
	end
	return ent
end

local function firma(ent)
	local r = ent.rec
	if not r then return "v" .. tostring(ent.libre or "") .. (ent.reagentes and "r" or "") end
	return r.i .. ":" .. (r.c or 1) .. ":" .. (r.l or "") .. ":" .. (r.bloq and 1 or 0) .. (r.nuevo and 1 or 0)
		.. (r.mision and 1 or 0) .. (r.bang and 1 or 0) .. (ent.mejora and 1 or 0) .. (r.basura and 1 or 0) .. ":" .. (ent.nivel or 0)
		.. ":" .. tostring(r.icono or 0) .. ((ent.e and ent.e.listo) and "+" or "-")
end

---------------------------------------------------------------------------
-- Encabezados de categoría o de bolsa (plegables)
---------------------------------------------------------------------------

local function despertar(f) end -- se define abajo

local function plegada(f, cat)
	return D.Raiz().ui.plegadas[f.tipo .. ":" .. cat] and true or false
end

local function cabecera(f, i)
	local h = f.cabs[i]
	if h then return h end
	h = CreateFrame("Button", nil, f.Contenido)
	h:SetHeight(CAB_CAT)
	h:SetFrameLevel(f.Contenido:GetFrameLevel() + 2)
	h.velo = K.Velo(h, K.CORTE.chico, 0.05)
	h.Flecha = K.Icono(h, "chevron-down", 10, "textoSuave")
	h.Flecha:SetPoint("LEFT", h, "LEFT", 4, 0)
	h.Bolsa = h:CreateTexture(nil, "ARTWORK")
	h.Bolsa:SetSize(18, 18)
	h.Bolsa:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	h.Simbolo = K.Icono(h, "ic-bolsas", 16, "textoSuave")
	h.Texto = K.Texto(h, "encabezado", "texto")
	h.Cuenta = K.Texto(h, "pequeno", "textoTenue")
	h.Linea = K.Linea(h, "linea")
	h:SetScript("OnClick", function(self)
		if not self.plegable then return end
		local d = D.Raiz().ui.plegadas
		local k = f.tipo .. ":" .. tostring(self.cat)
		d[k] = (not d[k]) or nil
		f.reacomodar, f.forzar = true, true
		despertar(f)
	end)
	h:SetScript("OnEnter", function(self) if self.plegable then self.velo:Show() end end)
	h:SetScript("OnLeave", function(self) self.velo:Hide() end)
	K.ConInfo(h, function(self) if self.plegable then return nil, L["Clic para plegar o desplegar"] end end)
	f.cabs[i] = h
	return h
end

---------------------------------------------------------------------------
-- Título y franja
---------------------------------------------------------------------------

local function titulo(f)
	local r = f.clave and D.Personaje(f.clave)
	local base = f.tipo == "banco" and L["Banco"] or L["Bolsas"]
	if propia(f) or not r then
		K.Escribir(f.Titulo, base)
	else
		local cr, cg, cb = M.ColorClase(r.clase)
		K.Escribir(f.Titulo, (f.tipo == "banco" and L["Banco de %s"] or L["Bolsas de %s"]):format(M.Pintado(r.nombre or f.clave, cr, cg, cb)))
	end
end

-- La vista elegida se ve como un segmento elevado (con el ícono en el acento).
local function pintarVistas(f)
	local v = M.Vista()
	for clave, b in pairs(f.Vistas) do
		b.alfaTipo = clave == v and "secundario" or "fantasma"
		b:SetMarcado(clave == v)
	end
end

local function textoDepositar(f)
	if not f.Depositar then return end
	local hechos, total = M.Lotes.Avance("depositar")
	if hechos then
		f.Depositar:SetTexto(format(L["Detener (%d/%d)"], hechos, total))
		f.Depositar:SetIcono("ic-cerrar")
	else
		f.Depositar:SetTexto(L["Depositar"])
		f.Depositar:SetIcono("chevron-down")
	end
end

-- La franja: búsqueda, y Ordenar / Depositar (en vivo) o la fecha de la foto y Volver.
local function franja(f)
	local vivo = f.esVivo
	local fr = f.Franja
	local combate = M.EnCombate()
	f.Ordenar:SetShown(vivo and M.Get("ordenar") and true or false)
	f.Ordenar:SetActivo(not combate)
	if f.Depositar then
		f.Depositar:SetShown(vivo and true or false)
		f.Depositar:SetActivo(not combate)
		textoDepositar(f)
	end
	f.Volver:SetShown(not propia(f))
	if not vivo then
		local r = D.Personaje(f.clave or D.Clave())
		local cuando = r and (f.tipo == "banco" and r.bancoVisto or r.visto)
		f.Foto:Set((L["Foto: %s"]):format(M.Hace(cuando)), "aviso", "ic-reloj")
	else
		f.Foto:Hide()
	end
	local x = -PAD
	for _, w in ipairs({ f.Depositar or false, f.Ordenar, f.Volver, f.Foto }) do
		if w and w:IsShown() then
			w:ClearAllPoints()
			w:SetPoint("RIGHT", fr, "RIGHT", x, 0)
			x = x - K.num(w:GetWidth(), 60) - ESP.s
		end
	end
	f.Busca:ClearAllPoints()
	f.Busca:SetPoint("LEFT", fr, "LEFT", PAD, 0)
	f.Busca:SetPoint("RIGHT", fr, "RIGHT", x, 0)
end

---------------------------------------------------------------------------
-- La sugerencia cuando las bolsas se llenan (solo tus bolsas, en vivo)
---------------------------------------------------------------------------

local function crearConsejo(f)
	local c = CreateFrame("Frame", nil, f)
	c.caja = K.Caja(c, { fondo = "panel", borde = "aviso", alfaBorde = 0.45, corte = K.CORTE.control })
	c.Franja = K.Plano(c, "aviso", "ARTWORK", 1)
	c.Franja:SetWidth(3)
	c.Franja:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -K.CORTE.control - 2)
	c.Franja:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, K.CORTE.control + 2)
	c.Icono = K.Icono(c, "ic-alerta", 18, "aviso")
	c.Icono:SetPoint("TOPLEFT", c, "TOPLEFT", ESP.m, -ESP.m)
	c.Titulo = K.Texto(c, "encabezado", "texto")
	c.Texto = K.Texto(c, "nota", "textoSuave")
	c.Cerrar = K.BotonIcono(c, "ic-cerrar", function()
		f.consejoCerrado = true
		f.reacomodar, f.forzar = true, true
		despertar(f)
	end, { tam = 20, icono = 10, ayuda = L["Ocultar hasta que vuelvan a llenarse"] })
	c.Cerrar:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -4)
	local S = M.Sugerencias
	c.Marcar = K.Boton(c, "", function() S.MarcarChatarra() end, { tipo = "acento", tam = "chico" })
	c.Vender = K.Boton(c, "", function() S.VenderChatarra() end, { tipo = "primario", tam = "chico" })
	c.Llevar = K.Boton(c, L["Llévame al comerciante"], function() S.LlevarComerciante() end, { tipo = "secundario", tam = "chico", icono = "ic-flecha" })
	c.Banco = K.Boton(c, L["Llévame al banco"], function() S.LlevarBanco() end, { tipo = "secundario", tam = "chico", icono = "ic-flecha" })
	K.ConInfo(c.Marcar, function()
		local est = S.Estado()
		local lista = {}
		for _, g in ipairs(est.vender) do if not g.chatarra then lista[#lista + 1] = g end end
		return L["Se marcan como chatarra"], S.Lineas(lista, 10)
	end)
	K.ConInfo(c.Vender, function()
		return L["Se vende ahora"], L["Lo gris y lo que marcaste como chatarra. Nunca lo que marcaste para conservar ni lo que pide una misión."]
	end)
	c:EnableMouse(true)
	K.ConInfo(c, function()
		local est = S.Estado()
		local lineas = {}
		if #est.vender > 0 then
			lineas[#lineas + 1] = K.Tenir("texto", L["Para vender"])
			for _, l in ipairs(S.Lineas(est.vender, 8)) do lineas[#lineas + 1] = l end
		end
		if #est.conservar > 0 then
			if #lineas > 0 then lineas[#lineas + 1] = " " end
			lineas[#lineas + 1] = K.Tenir("texto", L["Para conservar"])
			for _, l in ipairs(S.Lineas(est.conservar, 6)) do lineas[#lineas + 1] = l end
		end
		return L["Lo que sugiere Alfa"], lineas
	end)
	c:Hide()
	return c
end

-- -> alto (0: no se muestra)
local function acomodarConsejo(f, ancho)
	local c = f.Consejo
	local S = M.Sugerencias
	local est = f.tipo == "bolsas" and f.esVivo and M.Get("avisoLleno") and S.Estado() or nil
	if est and not est.lleno then f.consejoCerrado = nil end
	if not (est and est.lleno) or f.consejoCerrado then
		c:Hide()
		return 0
	end
	local w = ancho - 2 * PAD
	local x = ESP.m + 18 + ESP.s
	local tw = w - x - 28
	K.Escribir(c.Titulo, est.libres == 1 and L["Tus bolsas se están llenando: queda 1 casilla."]
		or format(L["Tus bolsas se están llenando: quedan %d casillas."], est.libres))
	c.Titulo:ClearAllPoints()
	c.Titulo:SetPoint("TOPLEFT", c, "TOPLEFT", x, -ESP.m)
	c.Titulo:SetWidth(tw)
	local y = ESP.m + K.AltoTexto(c.Titulo) + 3
	local texto
	if #est.vender > 0 then
		texto = format(L["Puedes vender %s (unos %s)."], S.Nombres(est.vender, 3), N.Dinero(est.valorVenta, true))
	else
		texto = L["No llevas nada que convenga vender: guarda algo en el banco."]
	end
	if #est.conservar > 0 then
		texto = texto .. " " .. format(L["Conserva %s: vale más de otra forma."], S.Nombres(est.conservar, 2))
	end
	K.Escribir(c.Texto, texto)
	c.Texto:ClearAllPoints()
	c.Texto:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)
	y = y + K.Parrafo(c.Texto, tw, 3) + ESP.s
	-- Los botones, en una fila.
	local enComerciante = S.ComercianteAbierto()
	local chatarra = enComerciante and #S.ChatarraAhora() or 0
	local botones = {}
	c.Vender:SetShown(chatarra > 0 or S.Vendiendo())
	if c.Vender:IsShown() then
		c.Vender:SetTexto(S.Vendiendo() and L["Detener"] or format(L["Vender la chatarra (%d)"], chatarra))
		botones[#botones + 1] = c.Vender
	end
	c.Marcar:SetShown(est.sinMarcar > 0)
	if c.Marcar:IsShown() then
		c.Marcar:SetTexto(format(L["Marcar como chatarra (%d)"], est.sinMarcar))
		botones[#botones + 1] = c.Marcar
	end
	c.Llevar:SetShown(#est.vender > 0 and not enComerciante)
	if c.Llevar:IsShown() then botones[#botones + 1] = c.Llevar end
	c.Banco:SetShown(#est.vender == 0)
	if c.Banco:IsShown() then botones[#botones + 1] = c.Banco end
	local bx, by = x, y
	for _, b in ipairs(botones) do
		local bw = b:AnchoNatural()
		if bx > x and bx + bw > w - ESP.s then bx, by = x, by + K.ALTO.botonChico + ESP.xs end
		b:SetAncho(nil)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", c, "TOPLEFT", bx, -by)
		bx = bx + bw + ESP.s
	end
	if #botones > 0 then y = by + K.ALTO.botonChico end
	local alto = y + ESP.m
	c:SetSize(w, alto)
	c:Show()
	return alto
end

---------------------------------------------------------------------------
-- Acomodo
---------------------------------------------------------------------------

local function datosDe(f, vivo)
	if vivo then return f.vivo end
	local r = D.Personaje(f.clave or D.Clave())
	if not r then return nil end
	if f.tipo == "banco" then
		if not r.bancoVisto then return nil end
		return r.banco
	end
	return r.bolsas
end

local function infoDe(f, bolsa, datos)
	if f.esVivo then return D.InfoBolsa(bolsa) end
	return D.InfoGuardada(bolsa, datos and datos[bolsa])
end

local function acomodar(f)
	local tam = M.Numero("tamIcono", 26, 52)
	local cols = M.Numero("columnas", 4, 24)
	local paso = tam + GAP
	local gridW = cols * tam + (cols - 1) * GAP
	local ancho = max(gridW + 2 * PAD, MIN_W)
	local x0 = floor((ancho - gridW) / 2)
	local vivo = enVivo(f)
	f.esVivo = vivo
	local propio = propia(f)
	local datos = datosDe(f, vivo)
	local vista = M.Vista()
	local filtro = f.filtro
	local lista = contenedores(f)
	f.Contenido:SetWidth(ancho)

	local usados = {}
	local colocados = {}
	local puestos = {}
	local cola = vaciar(f.cola)
	f.colaI = 1
	local nFoto, nCab = 0, 0
	local coinciden = 0
	local libres, total, libresR, totalR = 0, 0, 0, 0
	local y = ESP.s

	local function boton(bolsa, s)
		if vivo then
			local fila = f.vivos[bolsa]
			local b = fila and fila[s]
			if b then return b, true end
			if b == nil then return nil end -- aún no creado: llega en el próximo lote
		end
		nFoto = nFoto + 1
		return botonFoto(f, nFoto), false
	end

	local function poner(ent, col, yFila)
		local b, esVivo = boton(ent.bolsa, ent.casilla)
		if not b then return end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", f.Contenido, "TOPLEFT", x0 + col * paso, -yFila)
		B.Medir(b, tam)
		b:Show()
		usados[b] = true
		puestos[b] = ent
		if esVivo then colocados[b] = ent end
		if filtro then
			ent.coincide = ent.rec and O.Coincide(filtro, ent) or false
			if ent.coincide then coinciden = coinciden + 1 end
		end
		local estado = V.Estado(f, ent)
		local fi = firma(ent)
		local p = B.Partes[b]
		if p and p.firma == fi then
			p.ent = ent
			B.Buscar(b, estado)
		else
			cola[#cola + 1] = { b = b, ent = ent, fi = fi, vivo = esVivo, estado = estado }
		end
	end

	-- Una cuadrícula de entradas desde y. -> nueva y
	local function cuadricula(ents)
		local n = #ents
		for i = 1, n do
			local idx = i - 1
			poner(ents[i], idx % cols, y + floor(idx / cols) * paso)
		end
		if n > 0 then y = y + (floor((n - 1) / cols) + 1) * paso end
		return y
	end

	-- opts = { plegable, icono (de la bolsa), simbolo (ícono de Alfa) }
	local function encabezado(cat, texto, cuenta, o)
		o = o or {}
		nCab = nCab + 1
		local h = cabecera(f, nCab)
		h.cat, h.plegable = cat, o.plegable and true or false
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", f.Contenido, "TOPLEFT", x0, -y)
		h:SetWidth(gridW)
		local cerrada = o.plegable and plegada(f, cat) and not filtro
		K.SetIcono(h.Flecha, cerrada and "chevron-right" or "chevron-down", "textoSuave")
		h.Flecha:SetShown(h.plegable)
		local ancla, ax = h.Flecha, 6
		if not h.plegable then ancla, ax = nil, 2 end
		h.Bolsa:ClearAllPoints()
		h.Simbolo:ClearAllPoints()
		if o.icono then
			h.Bolsa:SetTexture(o.icono)
			h.Bolsa:Show()
			h.Simbolo:Hide()
			if ancla then h.Bolsa:SetPoint("LEFT", ancla, "RIGHT", ax, 0) else h.Bolsa:SetPoint("LEFT", h, "LEFT", ax, 0) end
			ancla, ax = h.Bolsa, 7
		elseif o.simbolo then
			K.SetIcono(h.Simbolo, o.simbolo, "textoSuave")
			h.Simbolo:Show()
			h.Bolsa:Hide()
			if ancla then h.Simbolo:SetPoint("LEFT", ancla, "RIGHT", ax, 0) else h.Simbolo:SetPoint("LEFT", h, "LEFT", ax, 0) end
			ancla, ax = h.Simbolo, 7
		else
			h.Bolsa:Hide()
			h.Simbolo:Hide()
		end
		h.Texto:ClearAllPoints()
		if ancla then h.Texto:SetPoint("LEFT", ancla, "RIGHT", ax, 0) else h.Texto:SetPoint("LEFT", h, "LEFT", ax, 0) end
		K.Escribir(h.Texto, texto)
		K.Ajustar(h.Texto, gridW - 120)
		K.Escribir(h.Cuenta, cuenta or "")
		h.Cuenta:ClearAllPoints()
		h.Cuenta:SetPoint("LEFT", h.Texto, "RIGHT", ESP.s, 0)
		h.Linea:ClearAllPoints()
		h.Linea:SetPoint("LEFT", (cuenta and cuenta ~= "") and h.Cuenta or h.Texto, "RIGHT", ESP.m, 0)
		h.Linea:SetPoint("RIGHT", h, "RIGHT", -2, 0)
		h:EnableMouse(h.plegable)
		h:Show()
		y = y + CAB_CAT + 2
		return cerrada
	end

	-- Cuenta libres y totales de una casilla.
	local function contar(bolsa, rec)
		if bolsa == D.LLAVERO then return end
		if bolsa == D.REAGENTES then
			totalR = totalR + 1
			if not rec then libresR = libresR + 1 end
		else
			total = total + 1
			if not rec then libres = libres + 1 end
		end
	end

	if not datos then
		f.Vacio:Set({
			lobo = "dormido",
			titulo = f.tipo == "banco" and L["Todavía no hay foto de este banco"] or L["Todavía no hay datos de este personaje"],
			texto = f.tipo == "banco" and L["Visita a un banquero con ese personaje y Alfa la guardará."] or L["Entra al juego con él una vez."],
		})
		local vh = f.Vacio:Acomodar(ancho - 2 * PAD)
		f.Vacio:ClearAllPoints()
		f.Vacio:SetPoint("TOP", f.Contenido, "TOP", 0, -ESP.l)
		f.Vacio:Show()
		y = ESP.l + vh + ESP.l
	else
		f.Vacio:Hide()
		if vista == "una" then
			local ents, llavero = {}, {}
			for _, bolsa in ipairs(lista) do
				local t = datos[bolsa]
				local n = type(t) == "table" and tonumber(t.n) or 0
				if bolsa == D.LLAVERO then n = tamLlavero(n) end
				for s = 1, n do
					local rec = type(t[s]) == "table" and t[s] or nil
					local ent = entrada(bolsa, s, rec, propio)
					if bolsa == D.LLAVERO then
						llavero[#llavero + 1] = ent
					else
						ents[#ents + 1] = ent
						if not rec then ent.reagentes = bolsa == D.REAGENTES end
						contar(bolsa, rec)
					end
				end
			end
			cuadricula(ents)
			if #llavero > 0 then
				y = y + ESP.s
				encabezado("llavero", L["Llavero"], nil, { icono = D.ICONO_LLAVERO })
				cuadricula(llavero)
			end
		elseif vista == "bolsa" then
			for _, bolsa in ipairs(lista) do
				local t = datos[bolsa]
				local n = type(t) == "table" and tonumber(t.n) or 0
				if bolsa == D.LLAVERO then n = tamLlavero(n) end
				if n > 0 then
					local ents, vacias = {}, 0
					for s = 1, n do
						local rec = type(t[s]) == "table" and t[s] or nil
						local ent = entrada(bolsa, s, rec, propio)
						if not rec then
							vacias = vacias + 1
							ent.reagentes = bolsa == D.REAGENTES
						end
						ents[#ents + 1] = ent
						contar(bolsa, rec)
					end
					local info = infoDe(f, bolsa, datos)
					local nombre = info.nombre or (bolsa == D.REAGENTES and L["Bolsa de componentes"]) or L["Bolsa"]
					local cuenta = (vacias == 0 and L["llena"]) or (vacias == 1 and L["1 libre"]) or format(L["%d libres de %d"], vacias, n)
					local cerrada = encabezado("bolsa" .. bolsa, nombre, cuenta,
						{ plegable = true, icono = info.icono, simbolo = not info.icono and "ic-bolsas" or nil })
					if not cerrada then cuadricula(ents) end
					y = y + GAP
				end
			end
		else
			local grupos = {}
			local primero, primeroR
			for _, bolsa in ipairs(lista) do
				local t = datos[bolsa]
				local n = type(t) == "table" and tonumber(t.n) or 0
				for s = 1, n do
					local rec = type(t[s]) == "table" and t[s] or nil
					if rec then
						local ent = entrada(bolsa, s, rec, propio)
						local g = grupos[ent.cat]
						if not g then
							g = {}
							grupos[ent.cat] = g
						end
						g[#g + 1] = ent
					end
					contar(bolsa, rec)
					if not rec then
						if bolsa == D.REAGENTES then primeroR = primeroR or s
						elseif bolsa ~= D.LLAVERO then primero = primero or { bolsa, s } end
					end
				end
			end
			for _, c in ipairs(O.CATEGORIAS) do
				local g = grupos[c.clave]
				if g and #g > 0 then
					table.sort(g, O.Antes)
					local cerrada = encabezado(c.clave, c.nombre, tostring(#g), { plegable = true })
					if not cerrada then cuadricula(g) end
					y = y + GAP
				end
			end
			local vacias = {}
			if primero then
				local ent = entrada(primero[1], primero[2], nil, propio)
				ent.libre = libres
				vacias[#vacias + 1] = ent
			end
			if primeroR then
				local ent = entrada(D.REAGENTES, primeroR, nil, propio)
				ent.libre, ent.reagentes = libresR, true
				vacias[#vacias + 1] = ent
			end
			if #vacias > 0 then
				encabezado("libre", O.NOMBRE.libre, tostring(libres + libresR), {})
				cuadricula(vacias)
			end
		end
	end

	-- Lo que no se usó, fuera.
	for _, fila in pairs(f.vivos) do
		for _, b in pairs(fila) do
			if b and not usados[b] then b:Hide() end
		end
	end
	for i = 1, #f.fotos do
		local b = f.fotos[i]
		if not usados[b] then b:Hide() end
	end
	for i = nCab + 1, #f.cabs do f.cabs[i]:Hide() end

	-- La parte de arriba: cabecera, franja, barra de bolsas y sugerencia.
	local arriba = CAB_H + FRANJA_H
	local hb = 0
	if M.Get("barra") then
		hb = M.Barra.Llenar(f.Barra, M.Barra.Datos(f, datos, lista, vivo, propio), ancho, x0)
	end
	f.Barra:SetShown(hb > 0)
	if hb > 0 then
		f.Barra:ClearAllPoints()
		f.Barra:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -arriba)
		arriba = arriba + hb
	end
	local hc = acomodarConsejo(f, ancho)
	if hc > 0 then
		f.Consejo:ClearAllPoints()
		f.Consejo:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(arriba + ESP.xs))
		arriba = arriba + hc + ESP.s
	end

	-- Tamaño de la ventana.
	local alto = y + ESP.s
	local pantalla = (UIParent and tonumber(UIParent:GetHeight())) or 768
	local maxCuerpo = max(140, floor(pantalla * 0.78) - arriba - PIE_H)
	local cuerpo = min(alto, maxCuerpo)
	f:SetSize(ancho, arriba + cuerpo + PIE_H)
	f.Desp:ClearAllPoints()
	f.Desp:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -arriba)
	f.Desp:Acomodar(ancho - 2, cuerpo)
	f.Contenido:SetWidth(ancho)
	f.Desp:SetAltoContenido(alto)
	f.ancho = ancho
	f.colocados, f.puestos, f.vistaCat = colocados, puestos, vista == "categorias"

	-- Pie y búsqueda.
	f.libres, f.total, f.libresR, f.totalR = libres, total, libresR, totalR
	V.Pie(f)
	if filtro then
		K.Escribir(f.Coinciden, coinciden > 0 and (L["%d coinciden"]):format(coinciden) or L["Ninguno coincide"])
		f.Coinciden:Show()
	else
		f.Coinciden:Hide()
	end
	pintarVistas(f)
	franja(f)
end

local function pintarLote(f)
	local cola, i, n = f.cola, f.colaI, 0
	while i <= #cola and n < TOPE_PINTAR do
		local q = cola[i]
		B.Pintar(q.b, q.ent)
		local p = B.Partes[q.b]
		if p then p.firma = q.fi end
		B.Buscar(q.b, q.estado)
		if q.vivo then B.Enfriar(q.b, q.ent.bolsa, q.ent.casilla) end
		i = i + 1
		n = n + 1
	end
	f.colaI = i
end

-- Con el ratón sobre la ventana (vendiendo, usando), las casillas no cambian
-- de lugar: cada botón se repinta donde está y el acomodo espera a que el
-- ratón salga (en las vistas por categorías y por bolsa).
local function enSitio(f)
	local propio = propia(f)
	local cola = f.cola
	for b, viejo in pairs(f.colocados) do
		local t = f.vivo[viejo.bolsa]
		local rec = t and t[viejo.casilla]
		local ent = entrada(viejo.bolsa, viejo.casilla, rec, propio)
		if not rec then ent.libre, ent.reagentes = viejo.libre, viejo.reagentes end
		if f.filtro then ent.coincide = rec and O.Coincide(f.filtro, ent) or false end
		local fi = firma(ent)
		local p = B.Partes[b]
		if p and p.firma == fi then
			p.ent = ent
		else
			cola[#cola + 1] = { b = b, ent = ent, fi = fi, vivo = true, estado = V.Estado(f, ent) }
		end
		f.colocados[b] = ent
		f.puestos[b] = ent
	end
end

local function trabajar(f)
	if not f:IsShown() then
		f:SetScript("OnUpdate", nil)
		return
	end
	local vivo = enVivo(f)
	local completos = true
	if vivo then
		if next(f.porEscanear) then
			for bolsa in pairs(f.porEscanear) do escanearVivo(f, bolsa) end
			vaciar(f.porEscanear)
			f.reacomodar, f.cambio = true, true
		end
		completos = crearLote(f)
		if not completos then f.reacomodar = true end
	end
	if f.reacomodar or f.esVivo ~= vivo then
		local esperar = vivo and f.esVivo == vivo and completos and not f.forzar and f.vistaCat
			and f.colocados ~= nil and f:IsMouseOver()
		if esperar then
			if f.cambio then
				f.cambio = false
				enSitio(f)
			end
		else
			f.reacomodar, f.forzar, f.cambio = false, false, false
			acomodar(f)
			if not completos then f.reacomodar = true end
		end
	end
	pintarLote(f)
	if f.colaI > #f.cola and not f.reacomodar and not next(f.porEscanear) then
		f:SetScript("OnUpdate", nil)
	end
end

despertar = function(f)
	if f and f:IsShown() then f:SetScript("OnUpdate", trabajar) end
end

-- Todo de nuevo: cada contenedor por leer y cada casilla por pintar
-- (forzar: ya, aunque el ratón esté encima).
local function todo(f, forzar)
	for _, bolsa in ipairs(contenedores(f)) do f.porEscanear[bolsa] = true end
	f.reacomodar = true
	if forzar then f.forzar = true end
	despertar(f)
end

-- Acomodar ya (una búsqueda, un ajuste, un clic en un encabezado).
local function ya(f)
	f.reacomodar, f.forzar = true, true
	despertar(f)
end

---------------------------------------------------------------------------
-- Resaltar lo que lleva una bolsa (desde la barra de bolsas)
---------------------------------------------------------------------------

-- Cómo se ve una casilla: nil (normal), true (resaltada) o false (atenuada),
-- según la bolsa resaltada o, si no hay, la búsqueda.
function V.Estado(f, ent)
	if f.resaltada ~= nil then return ent.bolsa == f.resaltada end
	if f.filtro then return ent.coincide and true or false end
	return nil
end

function V.Resaltar(f, bolsa)
	if not f then return end
	f.resaltada = bolsa
	for b, ent in pairs(f.puestos or {}) do
		if b:IsShown() then B.Buscar(b, V.Estado(f, ent)) end
	end
	if f.Barra then M.Barra.Repintar(f.Barra) end
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------

local function guardarPos(f)
	local ui = D.Raiz().ui
	local ancho, alto = UIParent:GetWidth(), UIParent:GetHeight()
	if f.tipo == "banco" then
		local x, y = f:GetLeft(), f:GetTop()
		if x and y then ui.posBanco = { x = floor(x + 0.5), y = floor(y - alto + 0.5) } end
	else
		local x, y = f:GetRight(), f:GetBottom()
		if x and y then ui.posBolsas = { x = floor(x - ancho + 0.5), y = floor(y + 0.5) } end
	end
end

local function ponerPos(f)
	local ui = D.Raiz().ui
	f:ClearAllPoints()
	if f.tipo == "banco" then
		local p = type(ui.posBanco) == "table" and ui.posBanco
		f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", p and tonumber(p.x) or 40, p and tonumber(p.y) or -110)
	else
		local p = type(ui.posBolsas) == "table" and ui.posBolsas
		f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", p and tonumber(p.x) or -64, p and tonumber(p.y) or 108)
	end
end

local function sonido(abrir)
	local SK = SOUNDKIT
	local id = SK and (abrir and SK.IG_BACKPACK_OPEN or SK.IG_BACKPACK_CLOSE)
	if id and PlaySound then pcall(PlaySound, id) end
end

function V.Pie(f)
	if not f.Dinero then return end
	local dinero
	if propia(f) then
		dinero = M.Num(GetMoney and GetMoney())
	else
		local r = D.Personaje(f.clave)
		dinero = r and tonumber(r.dinero)
	end
	K.Escribir(f.Dinero, N.Dinero(dinero or 0, true))
	K.Escribir(f.Cuenta, L["Cuenta:"] .. " " .. N.Dinero(D.DineroCuenta(), true))
	K.Escribir(f.Libre, (L["Libre: %d de %d"]):format(f.libres or 0, f.total or 0))
	local poco = (f.total or 0) > 0 and (f.libres or 0) <= 2
	K.ColorTexto(f.Libre, poco and "aviso" or "textoSuave")
end

local function infoPie(self)
	local f = self:GetParent()
	local lineas = { (L["Bolsas: %d de %d libres"]):format(f.libres or 0, f.total or 0) }
	if (f.totalR or 0) > 0 then
		lineas[#lineas + 1] = (L["Bolsa de componentes: %d de %d libres"]):format(f.libresR or 0, f.totalR or 0)
	end
	lineas[#lineas + 1] = " "
	lineas[#lineas + 1] = K.Tenir("texto", L["Dinero de tus personajes"])
	local actual = D.Clave()
	for _, p in ipairs(D.Lista()) do
		local r, g, b = M.ColorClase(p.r.clase)
		local d = (p.clave == actual and M.Num(GetMoney and GetMoney())) or tonumber(p.r.dinero) or 0
		lineas[#lineas + 1] = M.Pintado(p.r.nombre or p.clave, r, g, b) .. "  ·  " .. N.Dinero(d, true)
	end
	lineas[#lineas + 1] = " "
	lineas[#lineas + 1] = K.Tenir("acento", L["Toda la cuenta"]) .. "  ·  " .. N.Dinero(D.DineroCuenta(), true)
	return L["Espacio y dinero"], lineas
end

local function menuPersonajes(f, ancla)
	local ops = {}
	local actual = D.Clave()
	for _, p in ipairs(D.Lista()) do
		local r, g, b = M.ColorClase(p.r.clase)
		local nombre = M.Pintado(p.r.nombre or p.clave, r, g, b)
		if p.clave == actual then nombre = nombre .. " " .. L["(tú)"] end
		ops[#ops + 1] = { valor = p.clave, texto = nombre }
	end
	if #ops == 0 then ops[1] = { valor = "", texto = L["Aún no hay personajes guardados"] } end
	K.Menu(ancla, ops, f.clave or actual, function(clave)
		if clave == "" then return end
		V.Ver(f, clave ~= actual and clave or nil)
	end, 220)
end

local function menuDepositar(f, ancla)
	local Bc = M.Banco
	if Bc.Depositando() then
		Bc.Depositar()
		return
	end
	if M.EnCombate() then N.Imprimir(L["No se puede en combate."]) return end
	local cuentas, cats = Bc.Cuentas()
	local ops = {}
	for _, o in ipairs(Bc.OPCIONES) do
		local n = cuentas[o.clave] or 0
		if n > 0 then ops[#ops + 1] = { valor = o.clave, texto = format("%s  ·  %d", o.texto, n) } end
	end
	if #ops == 0 then ops[1] = { valor = "", texto = L["No llevas nada que depositar"] } end
	K.Menu(ancla, ops, M.Get("deposito"), function(clave)
		if clave == "" then return end
		if clave ~= "categoria" then
			Bc.Depositar(clave)
			return
		end
		local cops = {}
		for _, c in ipairs(cats) do cops[#cops + 1] = { valor = c.clave, texto = format("%s  ·  %d", c.nombre, c.n) } end
		M.Luego(0, function() K.Menu(ancla, cops, nil, function(cat) Bc.Depositar("categoria", cat) end, 240) end)
	end, 260)
end

local function crear(tipo)
	local nombre = tipo == "banco" and "AlfaBolsasBanco" or "AlfaBolsas"
	local f = CreateFrame("Frame", nombre, UIParent)
	f.tipo = tipo
	f:SetFrameStrata("HIGH")
	f:SetFrameLevel(10)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetSize(MIN_W, 300)
	f:Hide()
	f.caja = K.Caja(f, { fondo = "fondo", borde = "linea", corte = K.CORTE.ventana })
	f.Marca = K.Marca(f, K.CORTE.ventana, "acento", 44)
	f.vivo, f.vivos, f.portas, f.fotos, f.cabs = {}, {}, {}, {}, {}
	f.porEscanear, f.cola, f.colaI, f.puestos = {}, {}, 1, {}

	-- Cabecera: el ícono, el título, las vistas y los botones; se arrastra desde aquí.
	local cab = CreateFrame("Frame", nil, f)
	cab:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	cab:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	cab:SetHeight(CAB_H)
	cab:EnableMouse(true)
	cab:RegisterForDrag("LeftButton")
	cab:SetScript("OnDragStart", function() f:StartMoving() end)
	cab:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		if f.SetUserPlaced then f:SetUserPlaced(false) end
		guardarPos(f)
		ponerPos(f)
	end)
	f.Cabeza = cab
	cab.Linea = K.Linea(cab, "linea")
	cab.Linea:SetPoint("BOTTOMLEFT", cab, "BOTTOMLEFT", 0, 0)
	cab.Linea:SetPoint("BOTTOMRIGHT", cab, "BOTTOMRIGHT", 0, 0)
	f.Icono = K.Icono(cab, "ic-bolsas", 18, "acento")
	f.Icono:SetPoint("LEFT", cab, "LEFT", PAD + 2, 0)

	f.Cerrar = K.BotonIcono(cab, "ic-cerrar", function() f:Hide() end, { tam = 28, icono = 14, ayuda = L["Cerrar"] })
	f.Cerrar:SetPoint("RIGHT", cab, "RIGHT", -ESP.s, 0)
	f.Ajustes = K.BotonIcono(cab, "ic-ajustes", function() N.Abrir(M.ID) end, { tam = 28, ayuda = L["Ajustes de Bolsas"] })
	f.Ajustes:SetPoint("RIGHT", f.Cerrar, "LEFT", -2, 0)
	f.Personajes = K.BotonIcono(cab, "ic-personajes", function(self) menuPersonajes(f, self) end, { tam = 28, ayuda = L["Tus personajes"],
		ayudaTexto = L["Mira las bolsas o el banco de otro de tus personajes."] })
	f.Personajes:SetPoint("RIGHT", f.Ajustes, "LEFT", -2, 0)
	local ultimo = f.Personajes
	if tipo == "bolsas" then
		f.BotonBanco = K.Boton(cab, L["Banco"], function() V.MostrarBanco(f.clave) end, { tipo = "fantasma", tam = "chico" })
		K.ConInfo(f.BotonBanco, L["Tu banco"], L["En vivo si estás con un banquero; si no, la última foto."])
		f.BotonBanco:SetPoint("RIGHT", ultimo, "LEFT", -ESP.xs, 0)
		ultimo = f.BotonBanco
	end
	-- Las tres vistas, como un grupo de segmentos de ícono.
	local grupo = CreateFrame("Frame", nil, cab)
	grupo.caja = K.Caja(grupo, { fondo = "hundido", borde = "linea", corte = K.CORTE.control })
	grupo:SetSize(3 * 26 + 2 * 2 + 6, 32)
	grupo:SetPoint("RIGHT", ultimo, "LEFT", -ESP.s, 0)
	f.Vistas = {}
	local VISTAS = {
		{ "una", "ic-rejilla", L["Todo junto"], L["Cada casilla en su lugar, como en tus bolsas."] },
		{ "categorias", "ic-lista", L["Por categorías"], L["Equipo, consumibles, misiones, materiales... con encabezados que se pliegan."] },
		{ "bolsa", "ic-bolsas", L["Por bolsa"], L["Cada bolsa en su bloque, con su nombre y su espacio."] },
	}
	for i, v in ipairs(VISTAS) do
		local b = K.BotonIcono(grupo, v[2], function() M.Set("vista", v[1]) end, { tam = 26, icono = 14, ayuda = v[3], ayudaTexto = v[4] })
		b:SetPoint("LEFT", grupo, "LEFT", 3 + (i - 1) * 28, 0)
		f.Vistas[v[1]] = b
	end
	f.Titulo = K.Texto(cab, "subtitulo", "texto")
	f.Titulo:SetPoint("LEFT", f.Icono, "RIGHT", ESP.s, 0)
	f.Titulo:SetPoint("RIGHT", grupo, "LEFT", -ESP.s, 0)

	-- La franja: buscar, ordenar y depositar.
	local fr = CreateFrame("Frame", nil, f)
	fr:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -CAB_H)
	fr:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -CAB_H)
	fr:SetHeight(FRANJA_H)
	f.Franja = fr
	f.Busca = K.Buscador(fr, { ayuda = L["Buscar"], alCambiar = function(texto) V.Buscar(f, texto) end })
	K.ConInfo(f.Busca, L["Buscar"], L["Por nombre, tipo o calidad (verde, azul...) y por nivel de objeto: 20, >20, 20-30. Lo que coincide se resalta."])
	f.Coinciden = K.Texto(f.Busca, "pequeno", "textoTenue")
	f.Coinciden:SetPoint("RIGHT", f.Busca, "RIGHT", -30, 0)
	f.Coinciden:SetJustifyH("RIGHT")
	f.Coinciden:Hide()
	f.Ordenar = K.Boton(fr, L["Ordenar"], function() V.Ordenar(f) end, { tipo = "secundario" })
	K.ConInfo(f.Ordenar, L["Ordenar"], L["Junta los montones y acomoda tus objetos. No funciona en combate."])
	if tipo == "banco" then
		f.Depositar = K.Boton(fr, L["Depositar"], function(self) menuDepositar(f, self) end, { tipo = "primario", icono = "chevron-down" })
		K.ConInfo(f.Depositar, L["Depositar rápido"], L["Elige qué guardar: lo que ya tienes en el banco, los materiales, una categoría o todo lo que no sea equipo. Se mueve de una vez, fuera de combate."])
	end
	f.Volver = K.Boton(fr, L["Volver"], function() V.Ver(f, nil) end, { tipo = "fantasma" })
	K.ConInfo(f.Volver, nil, L["Volver a tus propias cosas"])
	f.Foto = K.Insignia(fr, "", "aviso")

	-- La barra de bolsas y la sugerencia.
	f.Barra = M.Barra.Crear(f)
	f.Barra:Hide()
	f.Consejo = crearConsejo(f)

	-- El cuerpo.
	f.Desp = K.Desplazable(f)
	f.Contenido = f.Desp.Contenido
	f.Contenido:SetFrameLevel(f.Desp:GetFrameLevel() + 1)
	f.Vacio = K.Vacio(f.Contenido, { lobo = "dormido" })
	f.Vacio:Hide()

	-- El pie: dinero (con el de la cuenta al pasar el ratón) y espacio libre.
	local pie = CreateFrame("Frame", nil, f)
	pie:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	pie:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	pie:SetHeight(PIE_H)
	pie.Fondo = K.Forma(pie, 0, "BACKGROUND", -4)
	K.Pintar(pie.Fondo, function(x) x:Color("pie") end)
	pie.Fondo:Corte(0, K.CORTE.ventana)
	pie.Linea = K.Linea(pie, "linea")
	pie.Linea:SetPoint("TOPLEFT", pie, "TOPLEFT", 0, 0)
	pie.Linea:SetPoint("TOPRIGHT", pie, "TOPRIGHT", 0, 0)
	f.Dinero = K.Texto(pie, "numero", "texto")
	f.Dinero:SetPoint("LEFT", pie, "LEFT", PAD + 2, 0)
	f.Cuenta = K.Texto(pie, "pequeno", "textoTenue")
	f.Cuenta:SetPoint("LEFT", f.Dinero, "RIGHT", ESP.m, 0)
	f.Libre = K.Texto(pie, "pequeno", "textoSuave")
	f.Libre:SetPoint("RIGHT", pie, "RIGHT", -(PAD + 2), 0)
	f.Libre:SetJustifyH("RIGHT")
	pie:EnableMouse(true)
	K.ConInfo(pie, infoPie)
	f.Pie = pie

	f:SetScript("OnShow", function(self)
		titulo(self)
		todo(self, true)
		trabajar(self)
		franja(self)
		sonido(true)
		if A.Anim and A.Anim.To then A.Anim.To(self, "alpha", 0, 1, A.Anim.FAST, "out") end
	end)
	f:SetScript("OnHide", function(self)
		self:SetScript("OnUpdate", nil)
		K.CerrarMenu()
		K.OcultarInfo()
		if self.Busca:Texto() ~= "" then self.Busca:SetTexto("", true) end
		self.filtro, self.fijada, self.resaltada = nil, nil, nil
		if self.tipo == "bolsas" then
			-- Lo nuevo deja de serlo al cerrar, como en las bolsas de Blizzard.
			for k in pairs(recientes) do
				local bolsa = floor((k + 500) / 1000)
				local s = k - bolsa * 1000
				if C_NewItems and C_NewItems.RemoveNewItem then pcall(C_NewItems.RemoveNewItem, bolsa, s) end
			end
			vaciar(recientes)
		elseif self.esVivo and D.BancoAbierto() and C_Bank and C_Bank.CloseBankFrame then
			-- Cerrar la ventana termina la visita al banco, como el de Blizzard.
			pcall(C_Bank.CloseBankFrame)
		end
		self.clave = nil
		sonido(false)
		M.Avisar("VENTANA_CERRADA", self.tipo)
	end)
	ponerPos(f)
	if A.CloseOnEscape then A.CloseOnEscape(nombre) end
	ventanas[tipo] = f
	return f
end

local function ventana(tipo)
	return ventanas[tipo] or crear(tipo)
end
V.Ventana = ventana

---------------------------------------------------------------------------
-- Uso desde fuera
---------------------------------------------------------------------------

function V.Ver(f, clave)
	if clave ~= nil and D.EsActual(clave) then clave = nil end
	f.clave = clave
	f.fijada, f.resaltada = nil, nil
	if f.Busca:Texto() ~= "" then f.Busca:SetTexto("", true) f.filtro = nil end
	titulo(f)
	if f:IsShown() then
		todo(f, true)
		trabajar(f)
		franja(f)
	else
		f:Show()
	end
end

function V.BolsasVisibles()
	local f = ventanas.bolsas
	return f and f:IsShown() or false
end

function V.MostrarBolsas(si)
	if si then
		local f = ventana("bolsas")
		if not f:IsShown() then
			f.clave = nil
			f:Show()
		end
	else
		local f = ventanas.bolsas
		if f and f:IsShown() then f:Hide() end
	end
end

function V.AlternarBolsas()
	V.MostrarBolsas(not V.BolsasVisibles())
end

-- El banco de un personaje (nil: el tuyo, en vivo si está abierto).
function V.MostrarBanco(clave)
	V.Ver(ventana("banco"), clave)
end

function V.CerrarBanco()
	local f = ventanas.banco
	if f and f:IsShown() then f:Hide() end
end

function V.BancoVisible()
	local f = ventanas.banco
	return f and f:IsShown() or false
end

function V.Buscar(f, texto)
	f.filtro = O.Compilar(texto)
	ya(f)
end

function V.Ordenar(f)
	if M.EnCombate() then
		N.Imprimir(L["No se puede ordenar en combate."])
		return
	end
	if not CC then return end
	if CC.SetSortBagsRightToLeft then pcall(CC.SetSortBagsRightToLeft, not M.Get("ordenarInverso")) end
	if f.tipo == "banco" then
		local tipo = D.TIPO_BANCO
		if CC.SortBank and tipo then
			pcall(CC.SortBank, tipo)
		elseif CC.SortBankBags then
			pcall(CC.SortBankBags)
		end
	elseif CC.SortBags then
		pcall(CC.SortBags)
	end
end

-- Un ajuste de Bolsas cambió.
function V.Ajuste(clave)
	if clave == "vista" or clave == "tamIcono" or clave == "columnas" or clave == "llavero" or clave == "barra"
		or clave == "avisoLleno" or clave == "avisoLibres" or clave == nil then
		for _, f in pairs(ventanas) do
			if clave == "llavero" or clave == nil then todo(f, true) else ya(f) end
		end
	end
	if clave == nil or clave:find("^marca") then V.RepintarTodo() end
	if clave == "ordenar" or clave == nil then
		for _, f in pairs(ventanas) do if f:IsShown() then franja(f) end end
	end
end

function V.RepintarTodo()
	for _, p in pairs(B.Partes) do p.firma = nil end
	for _, f in pairs(ventanas) do ya(f) end
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

local function enCada(fn)
	for _, f in pairs(ventanas) do
		if f:IsShown() then fn(f) end
	end
end

A.RegisterEvent("BAG_UPDATE", function(_, bolsa)
	bolsa = M.Num(bolsa)
	if not bolsa then return end
	enCada(function(f)
		if not f.esVivo then return end
		if (f.tipo == "bolsas" and D.EsBolsa[bolsa]) or (f.tipo == "banco" and D.EsBanco[bolsa]) then
			f.porEscanear[bolsa] = true
			despertar(f)
		end
	end)
end)

A.RegisterEvent("BAG_CONTAINER_UPDATE", function() enCada(todo) end)
A.RegisterEvent("PLAYERBANKSLOTS_CHANGED", function(_, pestana)
	local f = ventanas.banco
	if not (f and f:IsShown() and f.esVivo) then return end
	pestana = M.Num(pestana)
	local bolsa = pestana and D.BANCO[pestana]
	if bolsa then
		f.porEscanear[bolsa] = true
		despertar(f)
	else
		todo(f)
	end
end)
A.RegisterEvent("BAG_NEW_ITEMS_UPDATED", function()
	local f = ventanas.bolsas
	if f and f:IsShown() and f.esVivo then todo(f) end
end)

A.RegisterEvent("ITEM_LOCK_CHANGED", function(_, bolsa, s)
	bolsa, s = M.Num(bolsa), M.Num(s)
	if not (bolsa and s) then return end
	enCada(function(f)
		if not f.esVivo then return end
		local fila = f.vivos[bolsa]
		local b = fila and fila[s]
		local t = f.vivo[bolsa]
		local rec = t and t[s]
		if not (b and rec) then return end
		local info = M.Llamar(CC and CC.GetContainerItemInfo, bolsa, s)
		rec.bloq = type(info) == "table" and M.Leer(info.isLocked) and true or false
		B.Bloqueo(b, rec.bloq)
	end)
end)

A.RegisterEvent("BAG_UPDATE_COOLDOWN", function()
	enCada(function(f)
		if not f.esVivo then return end
		for bolsa, fila in pairs(f.vivos) do
			for s, b in pairs(fila) do
				if b and b:IsShown() then B.Enfriar(b, bolsa, s) end
			end
		end
	end)
end)

A.RegisterEvent("PLAYER_MONEY", function() enCada(V.Pie) end)
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() enCada(franja) end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() enCada(franja) end)

A.RegisterEvent("BANKFRAME_OPENED", function()
	local f = ventanas.banco
	if f and f:IsShown() and propia(f) then
		todo(f, true)
		franja(f)
	end
end)
A.RegisterEvent("BANKFRAME_CLOSED", function()
	local f = ventanas.banco
	if f and f:IsShown() and f.esVivo then f:Hide() end
end)
A.RegisterEvent("BANK_TABS_CHANGED", function()
	local f = ventanas.banco
	if f and f:IsShown() and f.esVivo then todo(f, true) end
end)

A.On("GEAR_UPDATED", function()
	enCada(function(f)
		f.reacomodar = true
		despertar(f)
	end)
end)

A.On("ITEM_MARKS", function()
	enCada(function(f) if f.esVivo then todo(f) end end)
end)

A.On("SETTING_CHANGED", function(ruta)
	if type(ruta) ~= "string" then return end
	if ruta == "" or ruta == M.ID then V.Ajuste(nil) return end
	local clave = ruta:match("^" .. M.ID .. "%.(.+)$")
	if clave then V.Ajuste(clave) end
end)

M.Escuchar("ITEM", function()
	enCada(function(f)
		f.reacomodar = true
		despertar(f)
	end)
end)

M.Escuchar("DATOS", function()
	enCada(function(f)
		if not f.esVivo then
			f.reacomodar = true
			despertar(f)
		end
	end)
end)

-- La sugerencia y la compra del banco cambiaron: la parte de arriba otra vez.
local function arriba(f) f.reacomodar = true despertar(f) end
M.Escuchar("SUGERENCIAS", function() enCada(arriba) end)
M.Escuchar("COMPRA", function() enCada(arriba) end)
M.Escuchar("LOTE", function() enCada(function(f) textoDepositar(f) if f.Consejo:IsShown() then arriba(f) end end) end)
A.RegisterEvent("MERCHANT_SHOW", function() enCada(arriba) end)
A.RegisterEvent("MERCHANT_CLOSED", function() enCada(arriba) end)

M.Escuchar("DINERO", function() enCada(V.Pie) end)

K.AlRepintar(function()
	B.Tema()
	enCada(ya)
end)
