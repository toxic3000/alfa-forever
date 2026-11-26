-- Alfa - Kit: todo lo de Alfa en pantalla se mueve (1.4.0, n.º 78). toxic3000 / La Jauría. GPL-3.0.
--
-- Pedido de Toxic: «que todo lo visual en pantalla se pueda mover sin
-- necesidad de que te lo diga, para que cada quien lo acomode a su
-- necesidad». Un solo registro para todo lo que Alfa pone en pantalla:
--
--   K.Movible(marco | "NombreGlobal", clave, op) -> e
--     op.nombre    el nombre que se ve en «Acomodar la pantalla» (ya traducido)
--     op.guardar   fn(f, pos): el marco ya quedó en su lugar nuevo; quien lo
--                  registra guarda a su manera (su ajuste de siempre). Sin
--                  guardar, el Kit lo guarda en AlfaNucleoDB.movibles[clave]
--                  (o AlfaNucleoCharDB, con acomodar.porPersonaje), lo pone al
--                  registrarse y cada vez que el marco se muestra.
--     op.volver    fn(f): «Volver a su lugar» a su manera. Sin volver, el Kit
--                  borra lo guardado y lo regresa a los puntos que tenía al
--                  registrarse (o a op.ancla = { punto, rel, relPunto, x, y }).
--     op.muestra   texto (o fn -> texto) que sale dentro del recuadro cuando
--                  no está a la vista (un anuncio, un aviso).
--     op.vista     fn -> el marco que se ve (si el registrado es un ancla
--                  invisible); nil = nada a la vista.
--     op.escala    true: la rueda del ratón lo agranda o lo achica (lo guarda el
--                  Kit); o { get = fn -> n, set = fn(n) }.
--     op.porPersonaje  true/false: manda sobre el ajuste general.
--     op.alMover   fn(f) después de moverlo o devolverlo.
--     op.orden     para la lista (de menor a mayor).
--     op.mayus = false: sin Mayús+arrastre directo (ya se arrastra solo).
--     op.alEmpezar fn() al empezar a arrastrarlo (las placas se separan de la flecha).
--     op.tam       { ancho, alto } del recuadro cuando el marco no mide nada.
--     op.asa       fn -> el marco que toma el ratón con Mayús (1.4.0): la placa
--                  o el anuncio que se ven, no su ancla invisible; sus botones
--                  siguen sirviendo. Sin asa, el registrado.
--     op.mayusOtro fn -> otro marco que se arrastra con su propio
--                  OnDragStart/OnDragStop en vez de este (la flecha, cuando
--                  las placas van con ella); nil = este.
--   pos = { punto, x, y, cx, cy, escala } — punto es el de UIParent más
--   cercano (TOPLEFT, TOP, ... CENTER ...); x, y en unidades de UIParent
--   desde ese mismo punto; cx, cy: el centro del marco menos el de UIParent.
--
--   K.MovibleSoltar(e | clave, izq, abajo, ancho, alto) -> pos
--       lo pone ahí (con imán, si está prendido) y lo guarda: lo que hace el
--       modo Acomodar al soltar (y el banco para probarlo)
--   K.MovibleVolver(e | clave)   «Volver a su lugar»
--   K.MovibleVolverTodo()
--   K.MovibleLista() -> { e, ... } en orden    K.MovibleDe(clave) -> e
--   K.MovibleRect(e) -> izq, abajo, ancho, alto (unidades de UIParent) | nil
--   K.MovibleVisible(e) -> el marco a la vista | nil
--   K.MovibleIman(izq, abajo, ancho, alto) -> izq, abajo, guiaX, guiaY
--   K.MovibleReaplicar()   lo guardado otra vez (cambio de escala, Dos pantallas)
--   K.MovibleGuardado(clave) -> pos | nil
--
-- Nunca se mueve un marco protegido en combate (queda para después, con
-- N.FueraDeCombate). Mayús+arrastre directo sobre lo que está a la vista
-- (fuera de combate, con acomodar.conMayus): solo mientras Mayús está
-- abajo sale un tirador propio encima de lo que se ve; al soltar Mayús se
-- esconde. Nunca se engancha nada al ratón del marco registrado (1.4.1).
-- Sin Mayús, nada atrapa clics.

local _, N = ...
local K = N.Kit
local A = N.A

local type, pairs, ipairs, pcall, rawget, tonumber, floor, max, min, abs, sort =
	type, pairs, ipairs, pcall, rawget, tonumber, math.floor, math.max, math.min, math.abs, table.sort

if A and A.RegisterDefaults then
	A.RegisterDefaults("acomodar", { conMayus = true, iman = true, porPersonaje = false })
end

local REG, LISTA = {}, {}
local contador = 0
K.MOVIBLES = REG

local IMAN = 12   -- a cuántos puntos se pega a un borde, al centro o a otro
local REJILLA = 8 -- el paso de la rejilla con imán

local function opcion(ruta)
	return A and A.Get and A.Get(ruta)
end

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function raiz() return UIParent end

-- Unidades de UIParent: por cuánto se multiplica una medida del marco.
local function escalaRel(f)
	local ok, fs = pcall(f.GetEffectiveScale, f)
	local us = raiz():GetEffectiveScale()
	fs = ok and tonumber(fs) or 1
	us = tonumber(us) or 1
	if fs <= 0 or us <= 0 then return 1 end
	return fs / us
end

local function pantalla()
	local U = raiz()
	return tonumber(U:GetLeft()) or 0, tonumber(U:GetBottom()) or 0,
		tonumber(U:GetWidth()) or 1920, tonumber(U:GetHeight()) or 1080
end

---------------------------------------------------------------------------
-- Lo guardado
---------------------------------------------------------------------------

local function porPersonaje(e)
	if e.op.porPersonaje ~= nil then return e.op.porPersonaje and true or false end
	return opcion("acomodar.porPersonaje") and true or false
end

local function leer(e)
	if porPersonaje(e) then
		local p = N.DatosPersonaje("movibles")[e.clave]
		if type(p) == "table" then
			if p.fabrica then return nil end
			return p
		end
	end
	local p = N.Datos("movibles")[e.clave]
	return type(p) == "table" and not p.fabrica and p or nil
end

local function escribir(e, pos)
	if porPersonaje(e) then
		N.DatosPersonaje("movibles")[e.clave] = pos or { fabrica = true }
	else
		N.Datos("movibles")[e.clave] = pos
	end
end

function K.MovibleGuardado(clave)
	local e = REG[clave]
	return e and leer(e) or nil
end

---------------------------------------------------------------------------
-- Dónde está y dónde ponerlo
---------------------------------------------------------------------------

-- Un ancla invisible (sin nada dibujado ni hijos a la vista: la de los
-- avisos, la de los anuncios) no cuenta como «a la vista».
local function conAlgo(f)
	if f.GetRegions then
		for _, r in ipairs({ f:GetRegions() }) do
			if r.IsShown and r:IsShown() then return true end
		end
	end
	if f.GetChildren then
		for _, c in ipairs({ f:GetChildren() }) do
			if c.IsShown and c:IsShown() then return true end
		end
	end
	return false
end

-- El marco a la vista: el registrado, o lo que op.vista diga.
function K.MovibleVisible(e)
	if type(e) == "string" then e = REG[e] end
	if not e then return nil end
	if e.op.vista then
		local ok, v = pcall(e.op.vista)
		if ok and type(v) == "table" and v.IsVisible and v:IsVisible() then return v end
		return nil
	end
	local f = e.marco
	if f and f.IsVisible and f:IsVisible() and (f.GetAlpha and (tonumber(f:GetAlpha()) or 1) > 0.05) and conAlgo(f) then return f end
	return nil
end

local function rectDe(f)
	if not (f and f.GetRect) then return nil end
	local ok, l, b, w, h = pcall(f.GetRect, f)
	if not ok then return nil end
	l, b, w, h = tonumber(l), tonumber(b), tonumber(w), tonumber(h)
	if not (l and b and w and h) then return nil end
	local k = escalaRel(f)
	local ul, ub = pantalla()
	return l * k - ul, b * k - ub, w * k, h * k
end

-- En unidades de UIParent, desde su esquina de abajo a la izquierda.
function K.MovibleRect(e)
	if type(e) == "string" then e = REG[e] end
	if not (e and e.marco) then return nil end
	local l, b, w, h = rectDe(e.marco)
	if not l then return nil end
	if (w or 0) < 1 or (h or 0) < 1 then
		local t = e.op.tam
		w = type(t) == "table" and tonumber(t[1]) or max(w or 0, 200)
		h = type(t) == "table" and tonumber(t[2]) or max(h or 0, 48)
	end
	return l, b, w, h
end

local PUNTOS = {
	{ "TOPLEFT", "TOP", "TOPRIGHT" },
	{ "LEFT", "CENTER", "RIGHT" },
	{ "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" },
}

-- El punto de la pantalla más cercano (por tercios) y la distancia desde él.
local function posDe(l, b, w, h)
	local _, _, W, H = pantalla()
	local cx, cy = l + w / 2, b + h / 2
	local col = cx < W / 3 and 1 or (cx > W * 2 / 3 and 3 or 2)
	local fila = cy > H * 2 / 3 and 1 or (cy < H / 3 and 3 or 2)
	local x = col == 1 and l or (col == 3 and (l + w - W) or (cx - W / 2))
	local y = fila == 3 and b or (fila == 1 and (b + h - H) or (cy - H / 2))
	return { PUNTOS[fila][col], floor(x + 0.5), floor(y + 0.5), cx = floor(cx - W / 2 + 0.5), cy = floor(cy - H / 2 + 0.5) }
end

-- Lo pone en pos (unidades de UIParent): en las del marco, dividido entre su escala.
local function poner(f, pos)
	local k = escalaRel(f)
	f:ClearAllPoints()
	f:SetPoint(pos[1], raiz(), pos[1], (tonumber(pos[2]) or 0) / k, (tonumber(pos[3]) or 0) / k)
end

local function protegidoEnCombate(f)
	return enCombate() and f.IsProtected and f:IsProtected() and true or false
end

-- Que nunca quede fuera de la pantalla (tras cambiar la escala o la ventana).
local function adentro(e)
	local f = e.marco
	local l, b, w, h = rectDe(f)
	if not l then return end
	local _, _, W, H = pantalla()
	local nl = max(0, min(l, W - w))
	local nb = max(0, min(b, H - h))
	if abs(nl - l) > 1 or abs(nb - b) > 1 then poner(f, posDe(nl, nb, w, h)) end
end
-- 1.4.0: para quien guarda a su manera y pone el marco él mismo (la barra de
-- conjuntos): que quepa en la pantalla (sin guardar nada).
function K.MovibleAdentro(e)
	if type(e) == "string" then e = REG[e] end
	if not (e and e.marco) or protegidoEnCombate(e.marco) then return false end
	adentro(e)
	return true
end

local function aplicar(e)
	local f = e.marco
	if not f or e.op.guardar or e.arrastrando then return end
	local pos = leer(e)
	if not pos then return end
	if protegidoEnCombate(f) then
		N.FueraDeCombate("movible." .. e.clave, function() aplicar(e) end)
		return
	end
	if e.op.escala == true and tonumber(pos.escala) then f:SetScale(pos.escala) end
	poner(f, pos)
	adentro(e)
end

-- El imán: a los bordes, al centro y a la rejilla.
function K.MovibleIman(l, b, w, h)
	if not opcion("acomodar.iman") then return l, b end
	local _, _, W, H = pantalla()
	local gx, gy
	local function pegar(v, tam, total)
		-- borde inicial, centro, borde final
		if abs(v) <= IMAN then return 0, 0 end
		if abs(v + tam - total) <= IMAN then return total - tam, total end
		local c = v + tam / 2
		if abs(c - total / 2) <= IMAN then return total / 2 - tam / 2, total / 2 end
		return floor(v / REJILLA + 0.5) * REJILLA, nil
	end
	l, gx = pegar(l, w, W)
	b, gy = pegar(b, h, H)
	return l, b, gx, gy
end

---------------------------------------------------------------------------
-- Mayús+arrastre directo
---------------------------------------------------------------------------

local function fallo(err)
	local h = geterrorhandler and geterrorhandler()
	if h then h(err) end
end

-- 1.4.1 (bug de Toxic: «no le puedo picar a un enemigo lejos, la cámara no
-- se mueve, no puedo clicar las pestañas de profesiones ni el volumen»): en
-- el juego, enganchar OnMouseDown/OnMouseUp a un marco le PRENDE el ratón. La
-- 1.4.0 enganchaba esos scripts a las anclas invisibles (la de los anuncios,
-- 560x150 arriba del centro; la de las placas de la flecha) y se volvían una
-- pared que se tragaba el clic al mundo, el arrastre de la cámara y los clics
-- de las ventanas del juego que caían debajo. Ahora el Kit NUNCA engancha
-- nada al marco registrado ni a su asa: con Mayús abajo pone un «tirador»
-- propio encima de lo que se ve, y al soltar Mayús lo esconde. Un marco
-- escondido no toma el ratón: sin Mayús, Alfa no pone nada entre tú y el mundo.
local tiradores = {} -- e -> su tirador (se crea la primera vez que hace falta)
local empezarMayus, soltarMayus

local function devolverRaton(e)
	local t = tiradores[e]
	if not t or e.arrastrando then return end
	t:Hide()
	t:ClearAllPoints()
end

local function conMayus()
	return opcion("acomodar.conMayus") and not enCombate() and not (K.AcomodarActivo and K.AcomodarActivo())
end
K.MovibleConMayus = conMayus

-- Quién se ve y se toma con Mayús: op.asa (lo que se ve) o el registrado.
local function asaDe(e)
	if not e.op.asa then return e.marco end
	local ok, a = pcall(e.op.asa)
	if ok and type(a) == "table" and a.IsVisible and a:IsVisible() then return a end
	return nil
end
K.MovibleAsa = asaDe -- (para el banco)

local function tiradorDe(e)
	local t = tiradores[e]
	if t then return t end
	t = CreateFrame("Frame", nil, UIParent)
	t:Hide()
	t:SetFrameStrata("TOOLTIP")
	t:SetFrameLevel(1)
	-- Un borde fino: se ve qué se puede mover mientras tienes Mayús abajo.
	local r, g, b = 0.55, 0.88, 0.31
	if K.Color then
		local ok, cr, cg, cb = pcall(K.Color, "acento")
		if ok and tonumber(cr) then r, g, b = cr, cg, cb end
	end
	t.Fondo = t:CreateTexture(nil, "BACKGROUND")
	t.Fondo:SetAllPoints()
	t.Fondo:SetColorTexture(r, g, b, 0.10)
	t.Bordes = {}
	for i, lado in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
		local x = t:CreateTexture(nil, "BORDER")
		x:SetColorTexture(r, g, b, 0.85)
		x:SetPoint(lado[1])
		x:SetPoint(lado[2])
		if lado[3] == 1 then x:SetWidth(1) else x:SetHeight(1) end
		t.Bordes[i] = x
	end
	t.alfaTirador = e.clave
	t:SetScript("OnMouseDown", function(_, boton) empezarMayus(e, boton) end)
	t:SetScript("OnMouseUp", function() soltarMayus(e) end)
	t:SetScript("OnHide", function() if e.arrastrando then soltarMayus(e) end end)
	-- Solo mientras se ve (Mayús abajo): si soltaste Mayús sin que llegara el
	-- aviso (Alt+Tab) o lo de abajo se fue (un anuncio que terminó), se va.
	t.alfaCuenta = 0
	t:SetScript("OnUpdate", function(self, dt)
		self.alfaCuenta = self.alfaCuenta + (dt or 0)
		if self.alfaCuenta < 0.1 then return end
		self.alfaCuenta = 0
		if e.arrastrando then return end
		local a = asaDe(e)
		if not (IsShiftKeyDown and IsShiftKeyDown()) or not conMayus() or not (a and a:IsVisible()) or not K.MovibleVisible(e) then
			devolverRaton(e)
		end
	end)
	t:EnableMouse(true)
	tiradores[e] = t
	return t
end
K.MovibleTirador = function(e) if type(e) == "string" then e = REG[e] end return e and tiradores[e] or nil end -- (para el banco)

local function prestarRaton()
	local abajo = IsShiftKeyDown and IsShiftKeyDown() and conMayus()
	if abajo and K.MovibleBuscar then K.MovibleBuscar() end
	for _, e in ipairs(LISTA) do
		if abajo then
			local a = e.mayus and e.marco and K.MovibleVisible(e) and asaDe(e) or nil
			if a and not (a.IsProtected and a:IsProtected()) then
				local t = tiradorDe(e)
				if not t:IsShown() then
					t:ClearAllPoints()
					t:SetAllPoints(a)
					t:Show()
				end
			else
				devolverRaton(e)
			end
		else
			devolverRaton(e)
		end
	end
end
K.MoviblePrestarRaton = prestarRaton

function empezarMayus(e, boton)
	if boton ~= "LeftButton" or not (IsShiftKeyDown and IsShiftKeyDown()) or not conMayus() then return end
	local f = e.marco
	if not f or e.arrastrando then return end
	-- Otro marco que se arrastra a su manera (la flecha con sus placas).
	if e.op.mayusOtro then
		local ok, otro = pcall(e.op.mayusOtro)
		if ok and type(otro) == "table" and otro.GetScript then
			local ini = otro:GetScript("OnDragStart")
			if not ini or (otro.IsProtected and otro:IsProtected()) then return end
			e.arrastrando = otro
			local bien, err = pcall(ini, otro, "LeftButton")
			if not bien then e.arrastrando = false fallo(err) end
			return
		end
	end
	e.arrastrando = true
	if e.op.alEmpezar then pcall(e.op.alEmpezar) end
	if f.SetMovable then f:SetMovable(true) end
	if f.StartMoving then f:StartMoving() end
end

function soltarMayus(e)
	if not e.arrastrando then return end
	if type(e.arrastrando) == "table" then
		local otro = e.arrastrando
		e.arrastrando = false
		local fin = otro.GetScript and otro:GetScript("OnDragStop")
		if fin then
			local bien, err = pcall(fin, otro)
			if not bien then fallo(err) end
		end
		if not (IsShiftKeyDown and IsShiftKeyDown()) then devolverRaton(e) end
		return
	end
	local f = e.marco
	if f.StopMovingOrSizing then f:StopMovingOrSizing() end
	if f.SetUserPlaced then pcall(f.SetUserPlaced, f, false) end
	e.arrastrando = false
	local l, b, w, h = rectDe(f)
	if l then K.MovibleSoltar(e, l, b, w, h) end
	if not (IsShiftKeyDown and IsShiftKeyDown()) then devolverRaton(e) end
end
K.MovibleMayus = { empezar = empezarMayus, soltar = soltarMayus } -- (para el banco)

---------------------------------------------------------------------------
-- Registro
---------------------------------------------------------------------------

local function unir(e, f)
	if e.marco or type(f) ~= "table" then return end
	e.marco = f
	-- Su lugar de fábrica: los puntos que tenía al registrarse.
	if not e.fabrica then
		local pts = {}
		local n = f.GetNumPoints and f:GetNumPoints() or 0
		for i = 1, n do pts[#pts + 1] = { f:GetPoint(i) } end
		e.fabrica = pts
	end
	if not e.op.guardar then
		if f.SetClampedToScreen and not e.op.sinClamp then f:SetClampedToScreen(true) end
		if f.HookScript then f:HookScript("OnShow", function() aplicar(e) end) end
		aplicar(e)
	end
	-- Mayús+arrastre: solo a lo que no se arrastra ya por su cuenta.
	-- (1.4.1: sin ganchos de ratón en el marco: lo toma su tirador, con Mayús)
	e.mayus = e.op.mayus ~= false and not (f.GetScript and f:GetScript("OnDragStart"))
end

local function resolver(e)
	if e.marco then return true end
	local f = type(e.nombreGlobal) == "string" and rawget(_G, e.nombreGlobal) or nil
	if type(f) == "table" and f.GetObjectType then unir(e, f) end
	return e.marco ~= nil
end

local function buscarPendientes()
	local faltan = false
	for _, e in ipairs(LISTA) do
		if not resolver(e) then faltan = true end
	end
	if not faltan and N.Quitar then N.Quitar("kit.movibles") end
	return faltan
end
K.MovibleBuscar = buscarPendientes

-- 1.4.0: el reloj busca un rato (BUSCAR_VECES) y se va: quien no pesca o no
-- cura nunca tiene AlfaPescaBarra ni AlfaCuracionListos, y antes corría cada
-- 3 s toda la sesión. Lo que aparezca después lo encuentran los eventos
-- (ADDON_LOADED, PLAYER_ENTERING_WORLD), Mayús al bajar y «Acomodar».
local BUSCAR_CADA, BUSCAR_VECES = 3, 10
K.MOVIBLE_BUSCAR = { cada = BUSCAR_CADA, veces = BUSCAR_VECES } -- (para el banco)
local vueltas = 0
local function buscarConReloj()
	vueltas = vueltas + 1
	local faltan = buscarPendientes()
	if faltan and vueltas >= BUSCAR_VECES and N.Quitar then N.Quitar("kit.movibles") end
	return faltan
end
local function relojBuscar()
	if not N.Cada then return end
	vueltas = 0
	N.Cada("kit.movibles", BUSCAR_CADA, buscarConReloj)
end

local function ordenar()
	sort(LISTA, function(a, b)
		local oa, ob = tonumber(a.op.orden) or 50, tonumber(b.op.orden) or 50
		if oa ~= ob then return oa < ob end
		return a.n < b.n
	end)
end

function K.Movible(marco, clave, op)
	if type(clave) ~= "string" or clave == "" then return nil end
	op = type(op) == "table" and op or {}
	local e = REG[clave]
	if e then
		-- Otra vez: se queda con lo nuevo (opciones o marco).
		e.op = op
		if type(marco) == "table" and e.marco ~= marco then e.marco, e.fabrica = nil, nil unir(e, marco) end
		return e
	end
	contador = contador + 1
	e = { clave = clave, op = op, n = contador }
	if type(op.ancla) == "table" then e.fabrica = { op.ancla } end
	REG[clave] = e
	LISTA[#LISTA + 1] = e
	ordenar()
	if type(marco) == "string" then
		e.nombreGlobal = marco
		if not resolver(e) then relojBuscar() end
	else
		unir(e, marco)
	end
	return e
end

function K.MovibleDe(clave) return REG[clave] end

function K.MovibleLista()
	buscarPendientes()
	local t = {}
	for i, e in ipairs(LISTA) do t[i] = e end
	return t
end

function K.MovibleNombre(e)
	if type(e) == "string" then e = REG[e] end
	if not e then return "" end
	local n = e.op.nombre
	if type(n) == "function" then local ok, v = pcall(n) n = ok and v or nil end
	return type(n) == "string" and n or e.clave
end

function K.MovibleMuestra(e)
	local m = e and e.op.muestra
	if type(m) == "function" then local ok, v = pcall(m) m = ok and v or nil end
	return type(m) == "string" and m or nil
end

---------------------------------------------------------------------------
-- Mover y volver
---------------------------------------------------------------------------

local function despues(e)
	if e.op.alMover then pcall(e.op.alMover, e.marco) end
end

function K.MovibleSoltar(e, l, b, w, h)
	if type(e) == "string" then e = REG[e] end
	if not e then return nil end
	resolver(e)
	local f = e.marco
	if not f then return nil end
	if protegidoEnCombate(f) then return nil end
	if not (w and h) then
		local _, _, rw, rh = K.MovibleRect(e)
		w, h = w or rw or 200, h or rh or 48
	end
	local _, _, W, H = pantalla()
	l = max(0, min(tonumber(l) or 0, W - w))
	b = max(0, min(tonumber(b) or 0, H - h))
	l, b = K.MovibleIman(l, b, w, h)
	local pos = posDe(l, b, w, h)
	poner(f, pos)
	if e.op.guardar then
		local ok, err = pcall(e.op.guardar, f, pos)
		if not ok then fallo(err) end
	else
		local viejo = leer(e)
		if viejo and tonumber(viejo.escala) then pos.escala = viejo.escala end
		escribir(e, pos)
	end
	despues(e)
	return pos
end

function K.MovibleVolver(e)
	if type(e) == "string" then e = REG[e] end
	if not e then return false end
	resolver(e)
	local f = e.marco
	if f and protegidoEnCombate(f) then return false end
	if e.op.volver then
		local ok, err = pcall(e.op.volver, f)
		if not ok then fallo(err) end
	else
		escribir(e, nil)
		if f then
			if e.op.escala == true then f:SetScale(1) end
			if e.fabrica and #e.fabrica > 0 then
				f:ClearAllPoints()
				for _, p in ipairs(e.fabrica) do pcall(f.SetPoint, f, p[1], p[2], p[3], p[4], p[5]) end
			end
		end
	end
	despues(e)
	return true
end

function K.MovibleVolverTodo()
	local n = 0
	for _, e in ipairs(LISTA) do if K.MovibleVolver(e) then n = n + 1 end end
	return n
end

-- La rueda del ratón: un poco más grande o más chico.
function K.MovibleEscala(e, paso)
	if type(e) == "string" then e = REG[e] end
	if not (e and e.marco and e.op.escala) or protegidoEnCombate(e.marco) then return nil end
	local f, es = e.marco, e.op.escala
	local actual
	if type(es) == "table" then
		local ok, v = pcall(es.get)
		actual = ok and tonumber(v) or 1
	else
		actual = tonumber(f:GetScale()) or 1
	end
	local nueva = floor((max(0.6, min(1.6, actual + (paso or 0))) * 100) + 0.5) / 100
	if type(es) == "table" then
		pcall(es.set, nueva)
	else
		f:SetScale(nueva)
		local l, b, w, h = rectDe(f)
		local pos = l and posDe(l, b, w, h) or leer(e) or {}
		pos.escala = nueva
		if l then poner(f, pos) end
		escribir(e, pos)
	end
	despues(e)
	return nueva
end

function K.MovibleReaplicar()
	for _, e in ipairs(LISTA) do
		if e.marco then
			aplicar(e)
			if e.op.guardar == nil and leer(e) then adentro(e) end
		end
	end
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

if A and A.RegisterEvent then
	A.RegisterEvent("MODIFIER_STATE_CHANGED", function() prestarRaton() end)
	-- La pelea: nadie se queda con el ratón prestado.
	A.RegisterEvent("PLAYER_REGEN_DISABLED", function()
		for _, e in ipairs(LISTA) do
			if e.arrastrando then soltarMayus(e) end
			devolverRaton(e)
		end
	end)
	A.RegisterEvent("PLAYER_ENTERING_WORLD", function() buscarPendientes() end)
	-- (un módulo que carga tarde arma sus marcos al cargar: se buscan en un momento)
	A.RegisterEvent("ADDON_LOADED", function()
		if N.Una then N.Una("kit.movibles.cargo", 1, buscarPendientes) else buscarPendientes() end
	end)
	A.RegisterEvent("UI_SCALE_CHANGED", function() K.MovibleReaplicar() end)
	A.RegisterEvent("DISPLAY_SIZE_CHANGED", function() K.MovibleReaplicar() end)
end
if A and A.On then
	-- Las piezas que guardan con su ajuste de siempre se ponen solas; las del Kit, aquí.
	A.On("SETTING_CHANGED", function(ruta)
		if ruta == "acomodar.porPersonaje" or ruta == "acomodar" or ruta == "" then K.MovibleReaplicar() end
	end)
end
