-- Alfa - Bolsas: las ventanas de bolsas y de banco. GPL-3.0.
--
-- Una ventana con el aspecto de Alfa (Theme.Skin "window", la banda con
-- estrellas, el borde dorado): cabecera con título y botones, una franja con
-- la búsqueda y Ordenar, el cuerpo con las casillas (se desplaza si no
-- cabe) y un pie con tu dinero, el de toda la cuenta y el espacio libre.
--
-- Dos vistas (ajuste "vista"): una sola bolsa (todas las casillas en su
-- orden) o por categorías (encabezados plegables, Espacio libre al final).
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
local W, T = A.Widgets, A.Theme

local type, pairs, ipairs, tonumber, tostring, next = type, pairs, ipairs, tonumber, tostring, next
local floor, max, min = math.floor, math.max, math.min

local V = {}
M.Ventana = V

local CAB_H, BUS_H, PIE_H = 44, 40, 34
local PAD, GAP, CAB_CAT = 14, 4, 26
local MIN_W = 392
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
		sinValor = M.Leer(info.hasNoValue) and true or false,
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
		.. (r.mision and 1 or 0) .. (r.bang and 1 or 0) .. (ent.mejora and 1 or 0) .. ":" .. (ent.nivel or 0)
		.. ":" .. tostring(r.icono or 0) .. ((ent.e and ent.e.listo) and "+" or "-")
end

---------------------------------------------------------------------------
-- Encabezados de categoría (plegables)
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
	W.Hover(h, 0.6)
	h.Flecha = h:CreateTexture(nil, "ARTWORK")
	h.Flecha:SetSize(10, 10)
	h.Flecha:SetPoint("LEFT", h, "LEFT", 4, 0)
	W.Color(h.Flecha, "textDim")
	h.Texto = W.Text(h, "heading", "text")
	h.Texto:SetPoint("LEFT", h.Flecha, "RIGHT", 7, 0)
	h.Cuenta = W.Text(h, "small", "textMuted")
	h.Cuenta:SetPoint("LEFT", h.Texto, "RIGHT", 7, 0)
	h.Linea = W.Divider(h)
	h.Linea:SetPoint("LEFT", h.Cuenta, "RIGHT", 10, 0)
	h.Linea:SetPoint("RIGHT", h, "RIGHT", -2, 0)
	h:SetScript("OnClick", function(self)
		local d = D.Raiz().ui.plegadas
		local k = f.tipo .. ":" .. tostring(self.cat)
		d[k] = (not d[k]) or nil
		f.reacomodar, f.forzar = true, true
		despertar(f)
	end)
	h.psTip = L["Clic para plegar o desplegar"]
	h:SetScript("OnEnter", W.SimpleTip)
	h:SetScript("OnLeave", W.HideTip)
	f.cabs[i] = h
	return h
end

---------------------------------------------------------------------------
-- Título y franja
---------------------------------------------------------------------------

local function titulo(f)
	local r = f.clave and D.Personaje(f.clave)
	local propio = propia(f)
	local base = f.tipo == "banco" and L["Banco"] or L["Bolsas"]
	if propio or not r then
		f.Titulo:SetText(base)
	else
		local cr, cg, cb = M.ColorClase(r.clase)
		f.Titulo:SetText((f.tipo == "banco" and L["Banco de %s"] or L["Bolsas de %s"]):format(M.Pintado(r.nombre or f.clave, cr, cg, cb)))
	end
end

-- La franja: búsqueda, y Ordenar (en vivo) o la fecha de la foto y Volver.
local function franja(f)
	local vivo = f.esVivo
	local derecha = f.Franja
	f.Ordenar:SetShown(vivo and M.Get("ordenar") and true or false)
	f.Volver:SetShown(not propia(f))
	local foto = not vivo
	if foto then
		local r = D.Personaje(f.clave or D.Clave())
		local cuando = r and (f.tipo == "banco" and r.bancoVisto or r.visto)
		W.SetChip(f.Chip, (L["Foto: %s"]):format(M.Hace(cuando)), "warning")
	else
		f.Chip:Hide()
	end
	local ancla = derecha
	for _, w in ipairs({ f.Ordenar, f.Volver, f.Chip }) do
		if w:IsShown() then
			w:ClearAllPoints()
			w:SetPoint("RIGHT", ancla, ancla == derecha and "RIGHT" or "LEFT", ancla == derecha and -PAD or -8, 0)
			ancla = w
		end
	end
	f.Busca:ClearAllPoints()
	f.Busca:SetPoint("LEFT", derecha, "LEFT", PAD, 0)
	if ancla == derecha then
		f.Busca:SetPoint("RIGHT", derecha, "RIGHT", -PAD, 0)
	else
		f.Busca:SetPoint("RIGHT", ancla, "LEFT", -8, 0)
	end
	f.Ordenar:SetAlpha(InCombatLockdown and InCombatLockdown() and 0.45 or 1)
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
	local porCategorias = M.Get("vista") ~= "una"
	local filtro = f.filtro
	local lista = contenedores(f)

	local usados = {}
	local colocados = {}
	local cola = vaciar(f.cola)
	f.colaI = 1
	local nFoto, nCab = 0, 0
	local coinciden = 0
	local libres, total, libresR, totalR = 0, 0, 0, 0
	local y = 6

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
		if esVivo then colocados[b] = ent end
		if filtro then
			ent.coincide = ent.rec and O.Coincide(filtro, ent) or false
			if ent.coincide then coinciden = coinciden + 1 end
		end
		local fi = firma(ent)
		local p = B.Partes[b]
		if p and p.firma == fi then
			p.ent = ent
			B.Buscar(b, ent.coincide)
		else
			cola[#cola + 1] = { b = b, ent = ent, fi = fi, vivo = esVivo }
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

	local function encabezado(cat, texto, cuenta, plegable)
		nCab = nCab + 1
		local h = cabecera(f, nCab)
		h.cat = cat
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", f.Contenido, "TOPLEFT", x0, -y)
		h:SetWidth(gridW)
		h.Texto:SetText(texto)
		h.Cuenta:SetText(cuenta and ("(" .. cuenta .. ")") or "")
		local cerrada = plegable and plegada(f, cat) and not filtro
		if T and T.Media then h.Flecha:SetTexture(T.Media(cerrada and "chevron-right" or "chevron-down")) end
		h.Flecha:SetShown(plegable and true or false)
		h:EnableMouse(plegable and true or false)
		h:Show()
		y = y + CAB_CAT + 2
		return cerrada
	end

	if not datos then
		f.Vacio:SetText(f.tipo == "banco"
			and L["Todavía no hay foto de este banco. Visita a un banquero con ese personaje y Alfa la guardará."]
			or L["Todavía no hay datos de este personaje. Entra al juego con él una vez."])
		f.Vacio:Show()
		y = 70
	else
		f.Vacio:Hide()
		if not porCategorias then
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
						if bolsa == D.REAGENTES then
							totalR = totalR + 1
							if not rec then libresR = libresR + 1 end
						else
							total = total + 1
							if not rec then libres = libres + 1 end
						end
					end
				end
			end
			cuadricula(ents)
			if #llavero > 0 then
				y = y + 8
				encabezado("llavero", L["Llavero"], nil, false)
				cuadricula(llavero)
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
					if bolsa == D.REAGENTES then
						totalR = totalR + 1
						if not rec then
							libresR = libresR + 1
							primeroR = primeroR or s
						end
					elseif bolsa ~= D.LLAVERO then
						total = total + 1
						if not rec then
							libres = libres + 1
							primero = primero or { bolsa, s }
						end
					end
				end
			end
			for _, c in ipairs(O.CATEGORIAS) do
				local g = grupos[c.clave]
				if g and #g > 0 then
					table.sort(g, O.Antes)
					local cerrada = encabezado(c.clave, c.nombre, #g, true)
					if not cerrada then cuadricula(g) end
					y = y + 4
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
				encabezado("libre", O.NOMBRE.libre, libres + libresR, false)
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

	-- Tamaño de la ventana.
	local alto = y + 8
	f.Contenido:SetWidth(ancho)
	local pantalla = (UIParent and tonumber(UIParent:GetHeight())) or 768
	local maxCuerpo = max(140, floor(pantalla * 0.78) - CAB_H - BUS_H - PIE_H)
	local cuerpo = min(alto, maxCuerpo)
	f:SetSize(ancho, CAB_H + BUS_H + cuerpo + PIE_H)
	W.SetScrollContent(f.Scroll, alto, cuerpo)
	if T and T.BandCoords then f.Banda:SetTexCoord(T.BandCoords(ancho - 2, CAB_H)) end
	f.ancho = ancho
	f.colocados, f.vistaCat = colocados, porCategorias

	-- Pie y búsqueda.
	f.libres, f.total, f.libresR, f.totalR = libres, total, libresR, totalR
	V.Pie(f)
	if filtro then
		f.Coinciden:SetText(coinciden > 0 and (L["%d coinciden"]):format(coinciden) or L["Ninguno coincide"])
		f.Coinciden:Show()
	else
		f.Coinciden:SetText("")
		f.Coinciden:Hide()
	end
	franja(f)
end

local function pintarLote(f)
	local cola, i, n = f.cola, f.colaI, 0
	while i <= #cola and n < TOPE_PINTAR do
		local q = cola[i]
		B.Pintar(q.b, q.ent)
		local p = B.Partes[q.b]
		if p then p.firma = q.fi end
		B.Buscar(q.b, q.ent.coincide)
		if q.vivo then B.Enfriar(q.b, q.ent.bolsa, q.ent.casilla) end
		i = i + 1
		n = n + 1
	end
	f.colaI = i
end

-- Por categorías, con el ratón sobre la ventana (vendiendo, usando), las
-- casillas no cambian de lugar: cada botón se repinta donde está y el
-- acomodo espera a que el ratón salga.
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
			cola[#cola + 1] = { b = b, ent = ent, fi = fi, vivo = true }
		end
		f.colocados[b] = ent
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
	local K = SOUNDKIT
	local id = K and (abrir and K.IG_BACKPACK_OPEN or K.IG_BACKPACK_CLOSE)
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
	f.Dinero:SetText(N.Dinero(dinero or 0, true))
	f.Cuenta:SetText(L["Cuenta:"] .. " " .. N.Dinero(D.DineroCuenta(), true))
	f.Libre:SetText((L["Libre: %d de %d"]):format(f.libres or 0, f.total or 0))
	local poco = (f.total or 0) > 0 and (f.libres or 0) <= 2
	W.Color(f.Libre, poco and "warning" or "textDim")
end

local function tooltipDinero(self)
	if not GameTooltip then return end
	local f = self:GetParent()
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(L["Espacio libre"], 1, 1, 1)
	local dr, dg, db = M.Color("textDim")
	GameTooltip:AddDoubleLine(L["Bolsas"], (L["%d de %d"]):format(f.libres or 0, f.total or 0), dr, dg, db, 1, 1, 1)
	if (f.totalR or 0) > 0 then
		GameTooltip:AddDoubleLine(L["Bolsa de componentes"], (L["%d de %d"]):format(f.libresR or 0, f.totalR or 0), dr, dg, db, 1, 1, 1)
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L["Dinero de tus personajes"], 1, 1, 1)
	local actual = D.Clave()
	for _, p in ipairs(D.Lista()) do
		local r, g, b = M.ColorClase(p.r.clase)
		local d = (p.clave == actual and M.Num(GetMoney and GetMoney())) or tonumber(p.r.dinero) or 0
		GameTooltip:AddDoubleLine(M.Pintado(p.r.nombre or p.clave, r, g, b), N.Dinero(d, true), 1, 1, 1, 1, 1, 1)
	end
	local ar, ag, ab = M.Acento()
	GameTooltip:AddLine(" ")
	GameTooltip:AddDoubleLine(L["Toda la cuenta"], N.Dinero(D.DineroCuenta(), true), ar, ag, ab, 1, 1, 1)
	GameTooltip:Show()
end

local function menuPersonajes(f, ancla)
	local items = {}
	local actual = D.Clave()
	for _, p in ipairs(D.Lista()) do
		local r, g, b = M.ColorClase(p.r.clase)
		local nombre = M.Pintado(p.r.nombre or p.clave, r, g, b)
		if p.clave == actual then nombre = nombre .. " " .. L["(tú)"] end
		local elegido = (f.clave or actual) == p.clave
		items[#items + 1] = { text = nombre, checked = elegido, onClick = function()
			V.Ver(f, p.clave ~= actual and p.clave or nil)
		end }
	end
	if #items == 0 then items[1] = { text = L["Aún no hay personajes guardados"], disabled = true } end
	W.ShowMenu(ancla, items, { minWidth = 200 })
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
	T.Skin(f, "window")
	f.vivo, f.vivos, f.portas, f.fotos, f.cabs = {}, {}, {}, {}, {}
	f.porEscanear, f.cola, f.colaI = {}, {}, 1

	-- Cabecera: la banda, el título y los botones; se arrastra desde aquí.
	local cab = CreateFrame("Frame", nil, f)
	cab:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	cab:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
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
	f.Banda = T.Band(cab, "BACKGROUND", -5)
	f.Banda:SetAllPoints(cab)
	W.Haze(cab, { height = CAB_H * 2 })
	W.Rim(f, { height = 60 })

	f.Icono = cab:CreateTexture(nil, "ARTWORK")
	f.Icono:SetTexture(T.Media(tipo == "banco" and "icon-treasure" or "icon-collect"))
	f.Icono:SetSize(18, 18)
	f.Icono:SetPoint("LEFT", cab, "LEFT", PAD, 0)
	W.Color(f.Icono, "accent")

	local function boton(icono, tip, fn)
		return W.IconButton(cab, icono, 26, tip, fn, 14)
	end
	f.Cerrar = boton("close", L["Cerrar"], function() f:Hide() end)
	f.Cerrar:SetPoint("RIGHT", cab, "RIGHT", -8, 0)
	f.Ajustes = boton("gear", L["Ajustes de Bolsas"], function() N.Abrir(M.ID) end)
	f.Ajustes:SetPoint("RIGHT", f.Cerrar, "LEFT", -2, 0)
	f.Personajes = boton("menu", L["Tus personajes"], function(self) menuPersonajes(f, self) end)
	f.Personajes:SetPoint("RIGHT", f.Ajustes, "LEFT", -2, 0)
	local ultimo = f.Personajes
	if tipo == "bolsas" then
		f.BotonBanco = boton("icon-treasure", L["Banco"], function() V.MostrarBanco(f.clave) end)
		f.BotonBanco.psTipLines = { L["Tu banco: en vivo si estás con un banquero, si no, la última foto."] }
		f.BotonBanco:SetPoint("RIGHT", ultimo, "LEFT", -2, 0)
		ultimo = f.BotonBanco
	end
	f.Vista = boton("layers", L["Cambiar la vista"], function()
		M.Set("vista", M.Get("vista") == "una" and "categorias" or "una")
	end)
	f.Vista:SetPoint("RIGHT", ultimo, "LEFT", -2, 0)

	f.Titulo = W.Text(cab, "title", "text")
	f.Titulo:SetPoint("LEFT", f.Icono, "RIGHT", 8, 0)
	f.Titulo:SetPoint("RIGHT", f.Vista, "LEFT", -8, 0)
	f.Titulo:SetJustifyH("LEFT")

	-- La franja: buscar y ordenar.
	local fr = CreateFrame("Frame", nil, f)
	fr:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -CAB_H)
	fr:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -CAB_H)
	fr:SetHeight(BUS_H)
	f.Franja = fr
	f.Busca = W.SearchBox(fr, { L["Buscar: nombre, tipo, calidad o nivel"], L["Buscar"] }, function(texto) V.Buscar(f, texto) end)
	f.Busca:SetHeight(28)
	f.Busca.psTip = L["Buscar"]
	f.Ordenar = W.Button(fr, L["Ordenar"], function() V.Ordenar(f) end, { height = 28 })
	f.Ordenar.psTip = L["Ordenar"]
	f.Ordenar.psTipLines = { L["Junta los montones y acomoda tus objetos. No funciona en combate."] }
	f.Volver = W.Button(fr, L["Volver"], function() V.Ver(f, nil) end, { height = 28, ghost = true })
	f.Volver.psTip = L["Volver a tus propias cosas"]
	f.Chip = W.Chip(fr)
	f.Chip:Hide()
	f.Coinciden = W.Text(f.Busca, "small", "textMuted")
	f.Coinciden:SetPoint("RIGHT", f.Busca, "RIGHT", -28, 0)
	f.Coinciden:SetJustifyH("RIGHT")

	-- El cuerpo.
	f.Scroll = W.Scroll(f)
	f.Scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(CAB_H + BUS_H))
	f.Scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, PIE_H)
	f.Contenido = f.Scroll.Child
	f.Contenido:SetFrameLevel(f.Scroll:GetFrameLevel() + 1)
	f.Vacio = W.Text(f.Contenido, "note", "textMuted")
	f.Vacio:SetWordWrap(true)
	f.Vacio:SetPoint("TOPLEFT", f.Contenido, "TOPLEFT", PAD + 4, -16)
	f.Vacio:SetPoint("RIGHT", f, "RIGHT", -PAD - 4, 0)
	f.Vacio:Hide()

	-- El pie: dinero (con el de la cuenta al pasar el ratón) y espacio libre.
	local pie = CreateFrame("Button", nil, f)
	pie:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
	pie:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	pie:SetHeight(PIE_H - 1)
	local fondo = pie:CreateTexture(nil, "BACKGROUND")
	fondo:SetAllPoints(pie)
	fondo:SetTexture(T.Media("white"))
	W.Color(fondo, "footer", 0.9)
	local linea = W.Divider(pie)
	linea:SetPoint("TOPLEFT", pie, "TOPLEFT", 0, 0)
	linea:SetPoint("TOPRIGHT", pie, "TOPRIGHT", 0, 0)
	f.Dinero = W.Text(pie, "number", "text")
	f.Dinero:SetPoint("LEFT", pie, "LEFT", PAD, 0)
	f.Cuenta = W.Text(pie, "small", "textMuted")
	f.Cuenta:SetPoint("LEFT", f.Dinero, "RIGHT", 12, 0)
	f.Libre = W.Text(pie, "small", "textDim")
	f.Libre:SetPoint("RIGHT", pie, "RIGHT", -PAD, 0)
	f.Libre:SetJustifyH("RIGHT")
	pie:SetScript("OnEnter", tooltipDinero)
	pie:SetScript("OnLeave", function(self) W.HideTooltip(self) end)
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
		if W.MenuShown and W.MenuShown(self.Personajes) then W.HideMenu() end
		if self.Busca:GetText() ~= "" then self.Busca:SetText("") end
		self.filtro = nil
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
	if f.Busca:GetText() ~= "" then f.Busca:SetText("") end
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
	if InCombatLockdown and InCombatLockdown() then
		N.Imprimir(L["No se puede ordenar en combate."])
		return
	end
	if not CC then return end
	if CC.SetSortBagsRightToLeft then pcall(CC.SetSortBagsRightToLeft, not M.Get("ordenarInverso")) end
	if f.tipo == "banco" then
		local tipo = Enum and Enum.BankType and Enum.BankType.Character
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
	if clave == "vista" or clave == "tamIcono" or clave == "columnas" or clave == "llavero" or clave == nil then
		for _, f in pairs(ventanas) do
			if clave == "llavero" or clave == nil then todo(f, true) else ya(f) end
		end
	end
	if clave == nil or clave:find("^marca") then V.RepintarTodo() end
	if clave == "ordenar" or clave == nil then
		for _, f in pairs(ventanas) do if f:IsShown() then franja(f) end end
	end
	for _, f in pairs(ventanas) do
		if f.Vista then
			f.Vista.psTip = M.Get("vista") == "una" and L["Vista: una sola bolsa"] or L["Vista: por categorías"]
			f.Vista.psTipLines = { L["Clic para cambiarla."] }
		end
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
A.RegisterEvent("BANK_TABS_CHANGED", function()
	local f = ventanas.banco
	if f and f:IsShown() and f.esVivo then todo(f) end
end)

A.On("GEAR_UPDATED", function()
	enCada(function(f)
		f.reacomodar = true
		despertar(f)
	end)
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

M.Escuchar("DATOS", function(clave)
	enCada(function(f)
		if not f.esVivo then
			f.reacomodar = true
			despertar(f)
		end
	end)
end)

M.Escuchar("DINERO", function() enCada(V.Pie) end)

if T and T.OnChanged then
	T.OnChanged(function()
		B.Tema()
		enCada(ya)
	end)
end
