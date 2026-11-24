-- Alfa - Inicio: cómo se acomoda Hoy (1.3.9). toxic3000 / La Jauría. GPL-3.0.
--
-- Mejoras 75 y 76 de la 1.3.9:
--   * Hoy por lo que pasa ahora (75): en la ciudad sube lo que se hace ahí
--     (alertas y «Buscar cerca»: reparar, banco, entrenador); dentro de una
--     mazmorra, tu mazmorra y tus misiones primero, y lo de tu clase; en
--     combate, solo lo urgente arriba. Con «inicio.contexto» apagado, Hoy
--     queda siempre en tu orden.
--   * Tarjetas que ocultas o reordenas (76): «Acomodar Hoy» abre una ventanita
--     con cada parte de Hoy, sus flechas para subirla o bajarla y su
--     interruptor para verla. Se guarda en los ajustes (inicio.orden,
--     inicio.ocultas): «Restablecer página» y los perfiles la incluyen.
--
--   Ac.BLOQUES                lista { id, nombre, icono }
--   Ac.Contexto() -> "combate" | "mazmorra" | "ciudad" | "campo"
--   Ac.Orden(contexto) -> { id, ... }   el orden de las partes de abajo
--   Ac.Oculta(id) -> bool
--   Ac.Mover(id, paso)  Ac.Ver(id, si)  Ac.Restablecer()
--   Ac.Abrir()                la ventana «Acomodar Hoy»

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local ESP = K.ESP

local ipairs, pairs, type, pcall = ipairs, pairs, type, pcall

local Ac = {}
M.Acomodo = Ac

if A and A.RegisterDefaults then
	A.RegisterDefaults("inicio", { contexto = true })
end

-- Las partes de abajo de Hoy, en su orden de fábrica (los ajustes de tus
-- avisos van siempre al final y no se ocultan: ahí se vuelve a prender todo).
Ac.BLOQUES = {
	{ id = "alEntrar", nombre = "Mientras entrabas", icono = "ic-hoy" },
	{ id = "alertas", nombre = "Alertas", icono = "ic-alerta" },
	{ id = "cerca", nombre = "Buscar cerca", icono = "ic-mapa" },
	{ id = "clase", nombre = "Lo de tu clase", icono = "ic-talentos" },
	{ id = "numeros", nombre = "Hoy en números", icono = "ic-nivel" },
	{ id = "camino", nombre = "Camino al 60", icono = "ic-ruta" },
	{ id = "revision", nombre = "Lo demás, de un vistazo", icono = "ic-info" },
	{ id = "diario", nombre = "Tu diario", icono = "ic-reloj" },
}
local POR_ID = {}
for i, b in ipairs(Ac.BLOQUES) do POR_ID[b.id] = i end

-- Lo que sube según dónde estás (75), en este orden y antes que lo demás.
Ac.SUBEN = {
	combate = { "alertas" },
	mazmorra = { "alertas", "clase" },
	ciudad = { "alertas", "cerca", "alEntrar" },
	campo = {},
}

function Ac.Contexto()
	if InCombatLockdown and InCombatLockdown() then return "combate" end
	if IsInInstance then
		local ok, dentro, tipo = pcall(IsInInstance)
		tipo = ok and N.Leer(tipo, nil) or nil
		if ok and N.Si(dentro) and (tipo == "party" or tipo == "raid") then return "mazmorra" end
	end
	if IsResting then
		local ok, r = pcall(IsResting)
		if ok and N.Si(r) then return "ciudad" end
	end
	return "campo"
end

local function guardado()
	local o = A.Get("inicio.orden")
	if type(o) ~= "table" then return nil end
	local lista, ya = {}, {}
	for _, id in ipairs(o) do
		if type(id) == "string" and POR_ID[id] and not ya[id] then lista[#lista + 1] = id ya[id] = true end
	end
	-- Una parte nueva de Hoy (de una versión más nueva) entra en su lugar de fábrica.
	for _, b in ipairs(Ac.BLOQUES) do
		if not ya[b.id] then
			local pos = #lista + 1
			for j, id in ipairs(lista) do if POR_ID[id] > POR_ID[b.id] then pos = j break end end
			table.insert(lista, pos, b.id)
			ya[b.id] = true
		end
	end
	return lista
end

-- Tu orden (sin lo que sube por el lugar).
function Ac.TuOrden()
	local o = guardado()
	if o then return o end
	local lista = {}
	for i, b in ipairs(Ac.BLOQUES) do lista[i] = b.id end
	return lista
end

function Ac.Orden(contexto)
	local base = Ac.TuOrden()
	if A.Get("inicio.contexto") == false then return base end
	local sube = Ac.SUBEN[contexto or Ac.Contexto()] or {}
	if #sube == 0 then return base end
	local lista, ya = {}, {}
	for _, id in ipairs(sube) do
		if POR_ID[id] and not ya[id] then lista[#lista + 1] = id ya[id] = true end
	end
	for _, id in ipairs(base) do
		if not ya[id] then lista[#lista + 1] = id ya[id] = true end
	end
	return lista
end

function Ac.Oculta(id)
	local o = A.Get("inicio.ocultas")
	return type(o) == "table" and o[id] == true or false
end

function Ac.Ver(id, si)
	if not POR_ID[id] then return end
	local o = {}
	local antes = A.Get("inicio.ocultas")
	if type(antes) == "table" then for k, v in pairs(antes) do if v == true and POR_ID[k] then o[k] = true end end end
	o[id] = (not si) and true or nil
	if next(o) == nil then o = nil end
	A.Set("inicio.ocultas", o)
end

function Ac.Mover(id, paso)
	local lista = Ac.TuOrden()
	local i
	for k, x in ipairs(lista) do if x == id then i = k end end
	if not i then return end
	local j = i + paso
	if j < 1 or j > #lista then return end
	lista[i], lista[j] = lista[j], lista[i]
	A.Set("inicio.orden", lista)
end

function Ac.Restablecer()
	A.Set("inicio.orden", nil)
	A.Set("inicio.ocultas", nil)
end

-- ¿Cambió algo de lo de fábrica? (para «Volver al orden de fábrica»)
function Ac.Cambiado()
	return type(A.Get("inicio.orden")) == "table" or type(A.Get("inicio.ocultas")) == "table"
end

---------------------------------------------------------------------------
-- La ventana «Acomodar Hoy»
---------------------------------------------------------------------------
local v, ui = nil, {}

local function nombre(b) return L[b.nombre] end

local function fila(padre)
	local f = CreateFrame("Frame", nil, padre)
	f:SetHeight(K.MEDIDA and K.MEDIDA.fila.alto or 48)
	f.caja = K.Caja(f, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
	f.Icono = K.Icono(f, "ic-hoy", 16, "acento")
	f.Icono:SetPoint("LEFT", f, "LEFT", ESP.m, 0)
	f.Nombre = K.Texto(f, "cuerpo", "texto")
	f.Nombre:SetPoint("LEFT", f.Icono, "RIGHT", ESP.m, 0)
	f.Ver = K.Interruptor(f, { get = function() return not Ac.Oculta(f.alfaId) end,
		set = function(si) Ac.Ver(f.alfaId, si) end, alCambiar = function() ui.Pintar() end })
	f.Ver:SetPoint("RIGHT", f, "RIGHT", -ESP.m, 0)
	f.Bajar = K.BotonIcono(f, "chevron-down", function() Ac.Mover(f.alfaId, 1) ui.Pintar() end, { tam = 24, ayuda = L["Bajar"] })
	f.Bajar:SetPoint("RIGHT", f.Ver, "LEFT", -ESP.base, 0)
	f.Subir = K.BotonIcono(f, "chevron-up", function() Ac.Mover(f.alfaId, -1) ui.Pintar() end, { tam = 24, ayuda = L["Subir"] })
	f.Subir:SetPoint("RIGHT", f.Bajar, "LEFT", -ESP.xs, 0)
	return f
end

function ui.Pintar()
	if not (v and v:IsShown()) then return end
	local orden = Ac.TuOrden()
	local ancho = v:AnchoCuerpo()
	local y = ESP.base
	K.Escribir(ui.Nota, L["Sube, baja u oculta las partes de Hoy. Lo urgente sigue subiendo solo según dónde estés (en la ciudad, en una mazmorra)."])
	ui.Nota:ClearAllPoints()
	ui.Nota:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -y)
	y = y + K.Parrafo(ui.Nota, ancho) + ESP.base
	for i, id in ipairs(orden) do
		local b = Ac.BLOQUES[POR_ID[id]]
		local f = ui.filas[i] or fila(v.Cuerpo)
		ui.filas[i] = f
		f.alfaId = id
		K.SetIcono(f.Icono, b.icono, Ac.Oculta(id) and "textoTenue" or "acento")
		K.Escribir(f.Nombre, nombre(b))
		K.ColorTexto(f.Nombre, Ac.Oculta(id) and "textoTenue" or "texto")
		f.Ver:Leer()
		f.Subir:SetShown(i > 1)
		f.Bajar:SetShown(i < #orden)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -y)
		f:SetWidth(ancho)
		K.Ajustar(f.Nombre, ancho - 16 - 3 * ESP.m - 36 - 2 * 24 - ESP.base - ESP.xs - ESP.m)
		f:Show()
		y = y + f:GetHeight() + ESP.s
	end
	for i = #orden + 1, #ui.filas do ui.filas[i]:Hide() end
	ui.Contexto:Leer()
	ui.LineaCtx:ClearAllPoints()
	ui.LineaCtx:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -(y + ESP.s))
	ui.LineaCtx:SetWidth(ancho)
	y = y + ESP.s + ui.LineaCtx:Acomodar(ancho) + ESP.base
	ui.Fabrica:SetActivo(Ac.Cambiado())
	v:SetAltoContenido(y)
end

local function armar()
	v = K.Ventana({ nombre = "AlfaHoyAcomodo", titulo = L["Acomodar Hoy"], subtitulo = L["Tu orden y lo que quieres ver"],
		icono = "ic-hoy", ancho = 440, alto = 720, desplazar = true })
	ui.filas = {}
	ui.Nota = K.Texto(v.Cuerpo, "nota", "textoSuave")
	-- «Según dónde estés»: el interruptor del orden por lugar, como una fila de ajuste.
	ui.LineaCtx = K.FilaAjuste(v.Cuerpo, { titulo = L["Subir lo urgente según dónde estés"],
		texto = L["En la ciudad, lo que se hace ahí; en una mazmorra, tu mazmorra y tu clase."],
		control = function(f) return K.Interruptor(f, { clave = "inicio.contexto" }) end })
	ui.Contexto = ui.LineaCtx.Control
	ui.Fabrica = K.Boton(v, L["Volver al orden de fábrica"], function() Ac.Restablecer() ui.Pintar() end, { tipo = "fantasma", icono = "reset" })
	ui.Listo = K.Boton(v, L["Listo"], function() v:Cerrar() end, { tipo = "primario" })
	v:SetPie({ ui.Listo }, { ui.Fabrica })
	v.alAcomodar = function() ui.Pintar() end
end

function Ac.Abrir()
	if not v then armar() end
	v:Abrir()
	ui.Pintar()
end

-- Cualquier cambio de orden u ocultas rehace Hoy (Inicio.lua escucha SETTING_CHANGED).
A.On("SETTING_CHANGED", function(path)
	if path == "inicio.orden" or path == "inicio.ocultas" or path == "inicio.contexto" or path == "inicio" or path == "" then
		if ui.Pintar then ui.Pintar() end
	end
end)
