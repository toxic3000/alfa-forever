-- Alfa - Bolsas: las ventanas de bolsas y de banco. GPL-3.0.
--
-- Hechas con el Kit de Alfa (docs/KIT.md): la caja con sus esquinas
-- cortadas y la marca de acento; una cabecera con el título, las tres vistas
-- y sus botones; una franja con la búsqueda, Ordenar y, en el banco,
-- Depositar; la barra de las bolsas equipadas (Barra.lua); cuando las bolsas
-- se llenan, la sugerencia de qué vender (Sugerencias.lua); el cuerpo con
-- las casillas (se desplaza si no cabe) y un pie con tu dinero, las monedas
-- de «Tu oro» (Oro.lua) y el espacio libre. Vive en UIParent (no en la capa de Alfa): tus
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

local CC = M.CC
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
	local fam = n > 0 and D.Familia(bolsa) or 0
	t.f = fam ~= 0 and fam or nil
	for s = 1, n do t[s] = leerCasilla(f, bolsa, s) end
end

---------------------------------------------------------------------------
-- Botones de cada casilla
---------------------------------------------------------------------------

local function porta(f, bolsa)
	local h = f.portas[bolsa]
	if h then return h end
	h = CreateFrame("Frame", nil, f.Contenido)
	if h.SetID then h:SetID(bolsa) end -- (siempre en el juego; el banco de pruebas no lo trae)
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
					if b.SetID then b:SetID(s) end
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
	return D.Plegadas()[f.tipo .. ":" .. cat] and true or false
end

-- 1.4.0 (22): arrastrar un objeto a la cabecera de una sección lo cambia de
-- sección (O.PonerSeccion). Solo tus bolsas en vivo, vista por secciones.
local function cursorObjeto()
	local f = rawget(_G, "GetCursorInfo")
	if type(f) ~= "function" then return nil end
	local ok, tipo, id, link = pcall(f)
	if not ok or M.Leer(tipo) ~= "item" then return nil end
	return M.Num(id), M.Texto(link)
end

function V.PuedeSoltar(f, cat)
	return f.esVivo and M.Vista() == "categorias" and O.SECCION_LIBRE[cat] and true or false
end

-- -> true si soltó un objeto
function V.SoltarEnSeccion(f, cat)
	if not V.PuedeSoltar(f, cat) then return false end
	local id, link = cursorObjeto()
	if not id then return false end
	local e = O.Info(id, link) or {}
	local _, _, q = M.Llamar(C_Item and C_Item.GetItemInfo, link or id)
	local base = O.CategoriaBase({ i = id, q = M.Num(q), l = link }, e, nil)
	-- Soltarlo otra vez en la que ya le elegiste lo devuelve a la suya.
	if O.SeccionPropia(id) == cat then cat = base end
	O.PonerSeccion(id, base ~= cat and cat or nil)
	if ClearCursor then ClearCursor() end
	local nombre = O.NombreEnlace(link) or e.nombre or L["Ese objeto"]
	if base ~= cat then
		N.Imprimir(format(L["%s saldrá siempre en «%s». Suéltalo otra vez ahí para devolverlo a «%s»."], nombre, O.NOMBRE[cat] or cat, O.NOMBRE[base] or base))
	else
		N.Imprimir(format(L["%s volvió a su sección de siempre."], nombre))
	end
	for _, x in pairs(ventanas) do x.reacomodar, x.forzar = true, true despertar(x) end
	return true
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
		-- 1.4.0 (22): con un objeto en el cursor, se suelta en esta sección.
		if V.SoltarEnSeccion(f, self.cat) then return end
		if not self.plegable then return end
		local d = D.Plegadas() -- 1.4.0 (21): por personaje
		local k = f.tipo .. ":" .. tostring(self.cat)
		d[k] = (not d[k]) or nil
		f.reacomodar, f.forzar = true, true
		despertar(f)
	end)
	h:SetScript("OnEnter", function(self) if self.plegable then self.velo:Show() end end)
	h:SetScript("OnLeave", function(self) self.velo:Hide() end)
	h:SetScript("OnReceiveDrag", function(self) V.SoltarEnSeccion(f, self.cat) end)
	K.ConInfo(h, function(self)
		if not self.plegable then return nil end
		if V.PuedeSoltar(f, self.cat) then
			return nil, L["Clic para plegar o desplegar"] .. "\n" .. L["Suelta aquí un objeto para que siempre salga en esta sección."]
		end
		return nil, L["Clic para plegar o desplegar"]
	end)
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

-- 1.3.2: «Acomodar» mientras trabaja: «Detener (x/y)» con el ícono de parar,
-- como Depositar. -> true si cambió de forma (la franja se vuelve a acomodar)
local function textoAcomodar(f)
	if not f.Acomodar then return false end
	local Ac = M.Acomodar
	local nombre, hechos, total = nil, nil, nil
	if Ac and Ac.Avance then nombre, hechos, total = Ac.Avance() end
	local trabajando = nombre ~= nil and hechos ~= nil
	if trabajando then
		f.Acomodar:SetTexto(format(L["Detener (%d/%d)"], hechos, total))
	else
		f.Acomodar:SetTexto(L["Acomodar"])
	end
	if trabajando ~= (f.acomodando or false) then
		f.acomodando = trabajando
		f.Acomodar:SetIcono(trabajando and "ic-cerrar" or nil)
		return true
	end
	return false
end

-- La franja: búsqueda, y Ordenar / Depositar (en vivo) o la fecha de la foto y Volver.
local function franja(f)
	local vivo = f.esVivo
	local fr = f.Franja
	local combate = M.EnCombate()
	f.Ordenar:SetShown(vivo and M.Get("ordenar") and true or false)
	f.Ordenar:SetActivo(not combate)
	-- 1.3.9: mientras Alfa ordena (Ordenar.lua), el botón lo detiene.
	local ordenando = f.tipo == "bolsas" and M.Ordenar and M.Ordenar.Activo()
	if f.ordenando ~= (ordenando and true or false) then
		f.ordenando = ordenando and true or false
		f.Ordenar:SetTexto(ordenando and L["Detener"] or L["Ordenar"])
		f.Ordenar:SetIcono(ordenando and "ic-cerrar" or nil)
	end
	if f.Depositar then
		f.Depositar:SetShown(vivo and true or false)
		f.Depositar:SetActivo(not combate)
		textoDepositar(f)
	end
	if f.Acomodar then
		local Ac = M.Acomodar
		local hay = vivo and Ac and (Ac.Activo() or Ac.Que() ~= nil)
		f.Acomodar:SetShown(hay and true or false)
		f.Acomodar:SetActivo(not combate)
		textoAcomodar(f)
	end
	if f.Conjuntos then f.Conjuntos:SetShown(propia(f) and M.Get("conjuntos") ~= false) end
	-- 1.3.8: «Separar» (Separar.lua): su botón, y «Marcar» lo del comerciante.
	if f.Separar then
		local Sp = M.Separar
		f.Separar:SetShown(vivo and propia(f) and M.Get("separar") ~= false and true or false)
		f.Separar:SetMarcado(Sp and Sp.Activo() or false)
		local c = Sp and Sp.Activo() and Sp.Cuentas()
		local n = c and c.sinMarcar or 0
		if n > 0 then f.SepMarcar:SetTexto(format(L["Marcar %d para vender"], n)) end
		f.SepMarcar:SetShown(vivo and n > 0 and true or false)
	end
	-- 1.3.9: «Lo que me sobra» (Sobra.lua): tus bolsas, en vivo.
	-- (en el pie; con «Separar» prendido su texto va al centro del pie y este se esconde)
	if f.Sobra then
		f.Sobra:SetShown(vivo and propia(f) and M.Sobra and M.Sobra.Encendido() and not (M.Separar and M.Separar.Activo()) and true or false)
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
	for _, w in ipairs({ f.Depositar or false, f.Ordenar, f.Acomodar or false, f.SepMarcar or false, f.Volver, f.Foto }) do
		if w and w:IsShown() then
			w:ClearAllPoints()
			w:SetPoint("RIGHT", fr, "RIGHT", x, 0)
			x = x - K.num(w:GetWidth(), 60) - ESP.s
		end
	end
	f.Busca:ClearAllPoints()
	f.Busca:SetPoint("LEFT", fr, "LEFT", PAD, 0)
	f.Busca:SetPoint("RIGHT", fr, "RIGHT", x, 0)
	-- 1.3.7: «3 nuevos» y «1 mejora» dentro de la búsqueda (Atajos.lua).
	if M.Atajos then K.Llamar(M.Atajos.Pintar, f, propia(f) and f.tipo == "bolsas" and vivo) end
	V.Cabecera(f)
end

-- 1.3.9 (83): la cabecera de las dos ventanas, igual para tus bolsas, tu banco
-- y los de tus otros personajes: los botones que se ven, uno junto al otro
-- desde la derecha (sin huecos de los que no aplican), luego las vistas y el
-- título con todo el espacio que queda.
function V.Cabecera(f)
	if not f.Cabeza then return end
	local cab = f.Cabeza
	local ultimo = f.Personajes
	for _, w in ipairs({ f.Conjuntos or false, f.Separar or false }) do
		if w and w:IsShown() then
			w:ClearAllPoints()
			w:SetPoint("RIGHT", ultimo, "LEFT", -2, 0)
			ultimo = w
		end
	end
	local otro = f.BotonBanco or f.BotonBolsas
	if otro then
		otro:ClearAllPoints()
		otro:SetPoint("RIGHT", ultimo, "LEFT", -ESP.xs, 0)
		ultimo = otro
	end
	-- Lo que necesita: los botones (con sus huecos de verdad), las vistas, el
	-- ícono y el título entero.
	local necesita = ESP.s + (PAD + 2) + 18 + ESP.s + K.num(f.Titulo:GetStringWidth(), 60) + ESP.s
	local iconos = { f.Cerrar, f.Ajustes, f.Personajes, f.Conjuntos or false, f.Separar or false }
	for _, w in ipairs(iconos) do
		if w and w:IsShown() then necesita = necesita + K.num(w:GetWidth(), 28) + 2 end
	end
	if otro and otro:IsShown() then necesita = necesita + K.num(otro:GetWidth(), 60) + ESP.xs end
	if f.GrupoVistas then necesita = necesita + K.num(f.GrupoVistas:GetWidth(), 88) + ESP.s end
	necesita = math.ceil(necesita)
	if f.anchoCabecera ~= necesita then
		local antes = f.anchoCabecera
		f.anchoCabecera = necesita
		-- Solo si ya no cabe (o sobraba): la ventana se vuelve a medir.
		if f:IsShown() and (necesita > K.num(f.ancho, MIN_W) or (antes and antes > MIN_W)) then V.Ya(f) end
	end
	if f.GrupoVistas then
		f.GrupoVistas:ClearAllPoints()
		f.GrupoVistas:SetPoint("RIGHT", ultimo, "LEFT", -ESP.s, 0)
		f.Titulo:ClearAllPoints()
		f.Titulo:SetPoint("LEFT", f.Icono, "RIGHT", ESP.s, 0)
		f.Titulo:SetPoint("RIGHT", f.GrupoVistas, "LEFT", -ESP.s, 0)
	end
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
	-- 1.4.0 (20): compacta, una línea con «Ver»; abierta, lo de siempre.
	c.Ver = K.Boton(c, L["Ver"], function()
		f.consejoAbierto = not f.consejoAbierto
		f.reacomodar, f.forzar = true, true
		despertar(f)
	end, { tipo = "fantasma", tam = "chico" })
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
	local enComerciante = S.ComercianteAbierto()
	local chatarra = enComerciante and #S.ChatarraAhora() or 0
	-- 1.4.0 (20): compacta (de fábrica): una línea, «Ver» y, con un comerciante, «Vender».
	if not f.consejoAbierto then
		c.Texto:Hide()
		c.Marcar:Hide()
		c.Llevar:Hide()
		c.Banco:Hide()
		c.Ver:SetTexto(L["Ver"])
		c.Ver:SetAncho(nil)
		local verW = c.Ver:AnchoNatural()
		local alto = ESP.s * 2 + max(K.ALTO.botonChico, 20)
		c.Ver:ClearAllPoints()
		c.Ver:SetPoint("RIGHT", c, "TOPRIGHT", -28, -alto / 2)
		c.Cerrar:ClearAllPoints()
		c.Cerrar:SetPoint("RIGHT", c, "TOPRIGHT", -4, -alto / 2)
		local derecha = verW + 28 + ESP.s
		c.Vender:SetShown(chatarra > 0 or S.Vendiendo())
		if c.Vender:IsShown() then
			c.Vender:SetTexto(S.Vendiendo() and L["Detener"] or format(L["Vender (%d)"], chatarra))
			c.Vender:SetAncho(nil)
			c.Vender:ClearAllPoints()
			c.Vender:SetPoint("RIGHT", c.Ver, "LEFT", -ESP.xs, 0)
			derecha = derecha + c.Vender:AnchoNatural() + ESP.xs
		end
		c.Icono:ClearAllPoints()
		c.Icono:SetPoint("LEFT", c, "TOPLEFT", ESP.m, -alto / 2)
		K.Escribir(c.Titulo, est.libres == 1 and L["Queda 1 casilla libre."]
			or format(L["Quedan %d casillas libres."], est.libres))
		c.Titulo:ClearAllPoints()
		c.Titulo:SetPoint("LEFT", c, "TOPLEFT", x, -alto / 2)
		K.Ajustar(c.Titulo, max(40, w - x - derecha))
		c:SetSize(w, alto)
		c:Show()
		return alto
	end
	c.Ver:SetTexto(L["Menos"])
	c.Ver:SetAncho(nil)
	c.Cerrar:ClearAllPoints()
	c.Cerrar:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -4)
	c.Icono:ClearAllPoints()
	c.Icono:SetPoint("TOPLEFT", c, "TOPLEFT", ESP.m, -ESP.m)
	tw = tw - c.Ver:AnchoNatural() - ESP.xs
	c.Ver:ClearAllPoints()
	c.Ver:SetPoint("TOPRIGHT", c, "TOPRIGHT", -28, -ESP.s)
	K.Escribir(c.Titulo, est.libres == 1 and L["Tus bolsas se están llenando: queda 1 casilla."]
		or format(L["Tus bolsas se están llenando: quedan %d casillas."], est.libres))
	c.Titulo:ClearAllPoints()
	c.Titulo:SetPoint("TOPLEFT", c, "TOPLEFT", x, -ESP.m)
	K.Parrafo(c.Titulo, tw, 2)
	c.Texto:Show()
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
	-- 1.4.0 (20): abierta, el texto entero (antes se cortaba en 3 líneas).
	y = y + K.Parrafo(c.Texto, w - x - 28, 8) + ESP.s
	-- Los botones, en una fila.
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
	-- 1.3.9: nunca más angosta que su cabecera (el título no se corta).
	local ancho = max(gridW + 2 * PAD, MIN_W, f.anchoCabecera or 0)
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
	local nuevos, mejoras = 0, 0
	local libres, total, libresR, totalR = 0, 0, 0, 0
	local libresE, totalE = 0, 0 -- 1.3.0: bolsas especiales (carcaj, almas, hierbas...)
	local familias = {} -- 1.4.0 (23): fam -> { libres, total }
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
		if esVivo then
			colocados[b] = ent
			-- 1.3.7: lo nuevo y las mejoras, para sus atajos (Atajos.lua).
			if ent.rec and ent.rec.nuevo then nuevos = nuevos + 1 end
			if ent.mejora then mejoras = mejoras + 1 end
		end
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

	-- Una bolsa especial: su espacio solo sirve para lo suyo (1.3.0).
	local function especial(bolsa)
		local t = datos and datos[bolsa]
		return type(t) == "table" and (tonumber(t.f) or 0) ~= 0
	end

	-- Cuenta libres y totales de una casilla. 1.3.0: el espacio de un carcaj
	-- o una bolsa de almas ya no cuenta como libre para cualquier objeto.
	local function contar(bolsa, rec)
		if bolsa == D.LLAVERO then return end
		if especial(bolsa) then
			totalE = totalE + 1
			if not rec then libresE = libresE + 1 end
			-- 1.4.0 (23): y por tipo de bolsa (carcaj, hierbas, almas...).
			local fam = tonumber(datos[bolsa].f) or 0
			local t = familias[fam]
			if not t then t = { libres = 0, total = 0 } familias[fam] = t end
			t.total = t.total + 1
			if not rec then t.libres = t.libres + 1 end
		elseif bolsa == D.REAGENTES then
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
						elseif bolsa ~= D.LLAVERO and not especial(bolsa) then primero = primero or { bolsa, s } end
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
	f.libresE, f.totalE = libresE, totalE
	f.familias = familias
	f.alfaNuevos, f.alfaMejoras = nuevos, mejoras
	V.Pie(f)
	if filtro then
		K.Escribir(f.Coinciden, coinciden > 0 and (L["%d coinciden"]):format(coinciden) or L["Ninguno coincide"])
		f.Coinciden:Show()
	else
		f.Coinciden:Hide()
	end
	-- 1.3.8: «Separar»: cuántos van a la subasta y cuántos al comerciante, en el pie.
	if f.SepTexto then
		local on = f.tipo == "bolsas" and M.Separar and M.Separar.Activo() and propia(f)
		if on then K.Escribir(f.SepTexto, M.Separar.TextoCorto()) end
		f.SepTexto:SetShown(on and true or false)
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
	-- Por A.Safe: un error aquí se avisa una vez, no en cada cuadro (1.2.0).
	if f and f:IsShown() then f:SetScript("OnUpdate", A.Safe(trabajar)) end
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
V.Ya = ya -- (1.3.9: la cabecera, V.Cabecera, la pide si ya no cabe)

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

---------------------------------------------------------------------------
-- 1.4.0 (23): el espacio libre por tipo de bolsa. La familia de una bolsa
-- especial (C_Container.GetContainerNumFreeSlots) es un juego de bits; se
-- nombra por el primero que se conoce.
---------------------------------------------------------------------------
V.FAMILIAS = {
	{ 1, L["Carcaj"] }, { 2, L["Bolsa de munición"] }, { 4, L["Bolsa de almas"] }, { 8, L["Peletería"] },
	{ 16, L["Inscripción"] }, { 32, L["Hierbas"] }, { 64, L["Encantamiento"] }, { 128, L["Ingeniería"] },
	{ 256, L["Llaves"] }, { 512, L["Gemas"] }, { 1024, L["Minería"] },
}
function V.NombreFamilia(fam)
	fam = tonumber(fam) or 0
	for _, x in ipairs(V.FAMILIAS) do
		if floor(fam / x[1]) % 2 == 1 then return x[2] end
	end
	return L["Bolsa especial"]
end

-- -> { { nombre, libres, total } } (juntos los del mismo nombre, en orden de bits)
function V.Familias(f)
	local por, lista = {}, {}
	local claves = {}
	for fam in pairs(f.familias or {}) do claves[#claves + 1] = fam end
	table.sort(claves)
	for _, fam in ipairs(claves) do
		local t = f.familias[fam]
		local nombre = V.NombreFamilia(fam)
		local x = por[nombre]
		if not x then x = { nombre = nombre, libres = 0, total = 0 } por[nombre] = x lista[#lista + 1] = x end
		x.libres, x.total = x.libres + t.libres, x.total + t.total
	end
	return lista
end

-- 1.3.7: el pie enseña solo el oro del personaje que miras (antes salía
-- también «Cuenta: …», el oro dos veces); el de todos va en «Tu oro», el
-- botón de monedas (Oro.lua). De otro personaje, también de cuándo es.
function V.Pie(f)
	if not f.Dinero then return end
	local dinero, cuando
	if propia(f) then
		dinero = M.Num(GetMoney and GetMoney())
	else
		local r = D.Personaje(f.clave)
		dinero = r and tonumber(r.dinero)
		cuando = r and M.Hace(r.visto)
	end
	local base = (L["Libre: %d de %d"]):format(f.libres or 0, f.total or 0)
	K.Escribir(f.Libre, base)
	local poco = (f.total or 0) > 0 and (f.libres or 0) <= 2
	K.ColorTexto(f.Libre, poco and "aviso" or "textoSuave")
	-- Lo de la izquierda no pisa el espacio libre de la derecha.
	local ancho = K.num(f.ancho or f:GetWidth(), MIN_W)
	local libreW = K.Ajustar(f.Libre)
	local monW = f.Monedas and (f.Monedas:IsShown() and K.num(f.Monedas:GetWidth(), 24) + ESP.xs) or 0
	-- 1.4.0 (23): con una bolsa especial, su espacio también («· Carcaj: 12»), si cabe.
	local fams = V.Familias(f)
	if #fams > 0 then
		local partes = {}
		for _, x in ipairs(fams) do partes[#partes + 1] = (L["%s: %d"]):format(x.nombre, x.libres) end
		K.Escribir(f.Libre, base .. "  \194\183  " .. table.concat(partes, "  \194\183  "))
		local w = K.Ajustar(f.Libre)
		K.Escribir(f.Dinero, N.Dinero(dinero or 0, true))
		local izq = K.AnchoTexto(f.Dinero) + monW
		if f.Sobra and f.Sobra:IsShown() then izq = izq + K.num(f.Sobra:GetWidth(), 0) + ESP.s end
		if w + izq + 2 * (PAD + 2) + ESP.m * 2 > ancho then
			K.Escribir(f.Libre, base)
			w = K.Ajustar(f.Libre)
		end
		libreW = w
	end
	local tope = max(40, ancho - 2 * (PAD + 2) - libreW - ESP.m - monW)
	K.Escribir(f.Dinero, N.Dinero(dinero or 0, true))
	local dw = K.Ajustar(f.Dinero, tope)
	if f.Cuando then
		K.Escribir(f.Cuando, cuando or "")
		f.Cuando:SetShown(cuando ~= nil)
		if cuando then K.Ajustar(f.Cuando, max(0, tope - dw - ESP.s)) end
	end
end

-- 1.3.7: el cuadro del pie solo habla del espacio (el oro va en «Tu oro»).
local function infoPie(self)
	local f = self:GetParent()
	local lineas = { (L["Bolsas: %d de %d libres"]):format(f.libres or 0, f.total or 0) }
	if (f.totalR or 0) > 0 then
		lineas[#lineas + 1] = (L["Bolsa de componentes: %d de %d libres"]):format(f.libresR or 0, f.totalR or 0)
	end
	-- 1.4.0 (23): cada tipo de bolsa con lo suyo.
	for _, x in ipairs(V.Familias(f)) do
		lineas[#lineas + 1] = (L["%s: %d de %d libres"]):format(x.nombre, x.libres, x.total)
	end
	return L["Espacio"], lineas
end

local function menuPersonajes(f, ancla)
	local ops = {}
	local actual = D.Clave()
	for _, p in ipairs(D.Lista()) do
		local r, g, b = M.ColorClase(p.r.clase)
		local nombre = M.Pintado(p.r.nombre or p.clave, r, g, b)
		if p.clave == actual then nombre = nombre .. " " .. L["(tú)"] end
		if p.otraFaccion then nombre = nombre .. " (" .. (p.r.faccion == "Alliance" and L["Alianza"] or L["Horda"]) .. ")" end -- 1.3.8
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
	-- "AlfaBolsas" no: ese nombre global es la tabla para otros módulos (Reemplazo.lua).
	local nombre = tipo == "banco" and "AlfaBolsasBanco" or "AlfaBolsasVentana"
	local f = CreateFrame("Frame", nombre, UIParent)
	f.tipo = tipo
	f:SetFrameStrata("HIGH")
	f:SetFrameLevel(10)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetSize(MIN_W, 300)
	f:Hide()
	-- 1.4.0 (62): con el tamaño de las ventanas de Alfa (nucleo.escalaVentanas).
	if K.ConEscala then K.ConEscala(f) end
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
		-- 1.3.0: tus conjuntos de equipo (Conjuntos.lua).
		f.Conjuntos = K.BotonIcono(cab, "ic-personaje", function(self) if M.Conjuntos then M.Conjuntos.Menu(self) end end,
			{ tam = 28, ayuda = L["Conjuntos de equipo"], ayudaTexto = L["Ponte un conjunto guardado o guarda lo que llevas puesto."] })
		f.Conjuntos:SetPoint("RIGHT", ultimo, "LEFT", -2, 0)
		ultimo = f.Conjuntos
		-- 1.3.8: «Separar»: subasta o comerciante (Separar.lua).
		f.Separar = K.BotonIcono(cab, "ic-comercio", function() if M.Separar then M.Separar.Alternar(f) franja(f) end end,
			{ tam = 28, ayuda = L["Separar: subasta o comerciante"],
				ayudaTexto = L["Marca lo que vale la pena subastar (el martillo) y lo que conviene vender al comerciante (la moneda); lo demás se atenúa. Otro clic lo quita."] })
		f.Separar:SetPoint("RIGHT", ultimo, "LEFT", -2, 0)
		ultimo = f.Separar
		f.BotonBanco = K.Boton(cab, L["Banco"], function() V.MostrarBanco(f.clave) end, { tipo = "fantasma", tam = "chico" })
		K.ConInfo(f.BotonBanco, L["Tu banco"], L["En vivo si estás con un banquero; si no, la última foto."])
		f.BotonBanco:SetPoint("RIGHT", ultimo, "LEFT", -ESP.xs, 0)
		ultimo = f.BotonBanco
	else
		-- 1.3.9 (83): el banco también tiene su botón a las bolsas del mismo personaje.
		f.BotonBolsas = K.Boton(cab, L["Bolsas"], function() V.Ver(V.Ventana("bolsas"), f.clave) end, { tipo = "fantasma", tam = "chico" })
		K.ConInfo(f.BotonBolsas, L["Bolsas"], L["Las bolsas del mismo personaje, en la ventana de bolsas."])
		f.BotonBolsas:SetPoint("RIGHT", ultimo, "LEFT", -ESP.xs, 0)
		ultimo = f.BotonBolsas
	end
	-- Las tres vistas, como un grupo de segmentos de ícono.
	local grupo = CreateFrame("Frame", nil, cab)
	grupo.caja = K.Caja(grupo, { fondo = "hundido", borde = "linea", corte = K.CORTE.control })
	grupo:SetSize(3 * 26 + 2 * 2 + 6, 32)
	grupo:SetPoint("RIGHT", ultimo, "LEFT", -ESP.s, 0)
	f.GrupoVistas = grupo
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
	-- 1.3.9: también lo que es (arma, material, comida...) y lo que Alfa sabe (candado, sin usar, sobra, subasta).
	K.ConInfo(f.Busca, L["Buscar"], L["Por nombre, tipo o calidad (verde, azul...) y por nivel de objeto: 20, >20, 20-30. También por lo que es (arma, material, comida...) y por lo que Alfa sabe: mejora, nuevo, candado, sin usar, sobra, subasta. Con «-» delante quitas: -gris. Lo que coincide se resalta."])
	f.Coinciden = K.Texto(f.Busca, "pequeno", "textoTenue")
	f.Coinciden:SetPoint("RIGHT", f.Busca, "RIGHT", -30, 0)
	f.Coinciden:SetJustifyH("RIGHT")
	f.Coinciden:Hide()
	f.Ordenar = K.Boton(fr, L["Ordenar"], function() V.Ordenar(f) end, { tipo = "secundario" })
	K.ConInfo(f.Ordenar, L["Ordenar"], L["Junta los montones y acomoda tus objetos. No funciona en combate."])
	-- 1.4.0 (19): al pasar el ratón, cómo quedarán (Previa.lua).
	if M.Previa then M.Previa.Enganchar(f, f.Ordenar) end
	if tipo == "banco" then
		f.Depositar = K.Boton(fr, L["Depositar"], function(self) menuDepositar(f, self) end, { tipo = "primario", icono = "chevron-down" })
		K.ConInfo(f.Depositar, L["Depositar rápido"], L["Elige qué guardar: lo que ya tienes en el banco, los materiales, una categoría o todo lo que no sea equipo. Se mueve de una vez, fuera de combate."])
	end
	if tipo == "bolsas" then
		-- 1.3.0: «Acomodar»: vende la chatarra o guarda los materiales (Acomodar.lua).
		f.Acomodar = K.Boton(fr, L["Acomodar"], function() M.Acomodar.Hacer() end, { tipo = "secundario" })
		K.ConInfo(f.Acomodar, function() return L["Acomodar"], M.Acomodar.Ayuda() end)
		-- 1.3.8: con «Separar», marcar como chatarra lo del comerciante (Separar.lua).
		f.SepMarcar = K.Boton(fr, L["Marcar para vender"], function() if M.Separar then M.Separar.MarcarVendedor() franja(f) end end, { tipo = "fantasma" })
		K.ConInfo(f.SepMarcar, function() return L["Marcar para vender"], (M.Separar and M.Separar.Texto() or "") .. " " .. L["Lo del comerciante queda como chatarra: se vende sola al hablar con un comerciante (o con «Acomodar»)."] end)
		f.SepMarcar:Hide()
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

	-- El pie: tu dinero, las monedas de «Tu oro» y el espacio libre.
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
	-- 1.3.7: las monedas abren «Tu oro» (Oro.lua); de otro personaje, de cuándo es su oro.
	if tipo == "bolsas" then
		f.Monedas = K.BotonIcono(pie, "ic-oro", function() if M.Oro then M.Oro.Alternar(f) end end,
			{ tam = 24, icono = 14, ayuda = L["Tu oro"], ayudaTexto = L["Lo que tiene cada uno de tus personajes y lo de esta sesión."] })
		f.Monedas:SetPoint("LEFT", f.Dinero, "RIGHT", ESP.xs, 0)
	end
	-- 1.3.9: «Lo que me sobra» (Sobra.lua), en el pie junto a tu oro: la
	-- cabecera y la franja ya van llenas (los atajos de la búsqueda necesitan su espacio).
	if tipo == "bolsas" then
		f.Sobra = K.Boton(pie, L["Lo que me sobra"], function(self) if M.Sobra then M.Sobra.Menu(self) end end, { tipo = "fantasma", tam = "chico" })
		K.ConInfo(f.Sobra, L["Lo que me sobra"], L["Lo que te sobra, para venderlo de un clic con un comerciante o mandárselo a otro de tus personajes desde el buzón. Lo que tiene candado no se toca."])
		f.Sobra:SetPoint("LEFT", f.Monedas, "RIGHT", ESP.s, 0)
		f.Sobra:Hide()
	end
	f.Cuando = K.Texto(pie, "pequeno", "textoTenue")
	f.Cuando:SetPoint("LEFT", f.Monedas or f.Dinero, "RIGHT", ESP.s, 0)
	f.Cuando:Hide()
	-- 1.3.8: lo de «Separar» (Separar.lua), al centro del pie.
	if tipo == "bolsas" then
		f.SepTexto = K.Texto(pie, "pequeno", "acento")
		f.SepTexto:SetPoint("CENTER", pie, "CENTER", 0, 0)
		f.SepTexto:Hide()
	end
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
		-- 1.4.0 (bug 1): los números de las casillas otra vez, un instante después
		-- de abrir (Forever deja algunos con la medida de antes).
		if N.Una then N.Una("bolsas.letras", 0.1, B.OtraVezTodo) end
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
		if self.tipo == "bolsas" and M.Oro then M.Oro.Cerrar() end
		-- 1.3.8: «Separar» se apaga al cerrar tus bolsas.
		if self.tipo == "bolsas" and M.Separar and M.Separar.Activo() then M.Separar.Alternar(self, false) end
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
	-- 1.3.7: «Tu oro» marca a quién miras.
	local Or = M.Oro
	if Or and Or.Visible() and Or.Panel().win == f then Or.Pintar() end
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
	-- 1.3.9: tu orden, o lo que tiene candado en su lugar: ordena Alfa (Ordenar.lua).
	local Ord = M.Ordenar
	if f.tipo == "bolsas" and Ord and (Ord.Activo() or Ord.Usar()) then
		Ord.Empezar()
		return
	end
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
	if clave == nil or clave:find("^marca") or clave == "brilloMision" then V.RepintarTodo() end
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

-- Aceptar o terminar una misión cambia qué objetos son de misión o la
-- empiezan: las bolsas a la vista se vuelven a leer (una vez por ráfaga).
local misionPendiente = false
local function porMisiones()
	if misionPendiente then return end
	misionPendiente = true
	M.Luego(0.5, function()
		misionPendiente = false
		enCada(function(f) if f.esVivo then todo(f) end end)
	end)
end
A.RegisterEvent("QUEST_ACCEPTED", porMisiones)
A.RegisterEvent("QUEST_REMOVED", porMisiones)
A.RegisterEvent("QUEST_TURNED_IN", porMisiones)
AlfaNucleo.DeUnidad("UNIT_QUEST_LOG_CHANGED", "player", function(_, u) if not (issecretvalue and issecretvalue(u)) and u == "player" then porMisiones() end end)
A.RegisterEvent("PLAYERBANKSLOTS_CHANGED", function(_, slot)
	local f = ventanas.banco
	if not (f and f:IsShown() and f.esVivo) then return end
	local lista = D.CambioBanco(slot)
	if lista then
		for _, bolsa in ipairs(lista) do f.porEscanear[bolsa] = true end
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
	-- 1.3.0: «Acomodar» de la ventana de bolsas depende del banco.
	local b = ventanas.bolsas
	if b and b:IsShown() then franja(b) end
end)
A.RegisterEvent("BANKFRAME_OPENED", function()
	local b = ventanas.bolsas
	if b and b:IsShown() then franja(b) end
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
-- 1.3.9: «Ordenar» / «Detener» mientras ordena Alfa.
M.Escuchar("ORDENAR", function() enCada(franja) end)
M.Escuchar("COMPRA", function() enCada(arriba) end)
M.Escuchar("LOTE", function() enCada(function(f)
	textoDepositar(f)
	-- 1.3.2: «Acomodar» dice su avance; al empezar o terminar, la franja se acomoda.
	if textoAcomodar(f) then franja(f) end
	if f.Consejo:IsShown() then arriba(f) end
end) end)
A.RegisterEvent("MERCHANT_SHOW", function() enCada(arriba) end)
A.RegisterEvent("MERCHANT_CLOSED", function() enCada(arriba) end)

M.Escuchar("DINERO", function() enCada(V.Pie) end)

K.AlRepintar(function()
	B.Tema()
	enCada(ya)
end)
