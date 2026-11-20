-- Alfa - Bienvenida: tus atajos de Alfa (1.3.0). toxic3000 / La Jauría. GPL-3.0.
--
-- Una ventana con todos los atajos de Alfa (los del motor y los de cada
-- módulo, de sus Bindings.xml) para cambiarlos ahí mismo: clic y pulsa la
-- tecla (K.Atajo, que guarda con SetBinding y SaveBindings fuera de combate).
--   M.Teclas.Lista() -> { { accion, nombre }, ... }
--   M.Teclas.Abrir()
-- La lista sale del juego: cada atajo de Alfa tiene su BINDING_NAME_ALFA_* (o
-- BINDING_NAME_CLICK Alfa*); también se leen los de la categoría «Alfa»
-- (GetBinding). Un módulo nuevo con su Bindings.xml sale solo.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ESP = K.ESP

local type, ipairs, pairs, pcall, rawget = type, ipairs, pairs, pcall, rawget

local Tc = {}
M.Teclas = Tc

-- Los de uso diario primero; luego los demás, por su acción.
local ORDEN = {
	"ALFA_OPTIONS", "ALFA_TOGGLE", "ALFA_HIDE", "ALFA_PANTALLA_LIMPIA", "ALFA_AYUDA", "ALFA_MUNDO_MAPA",
	"ALFA_LYA_GUIA", "ALFA_LYA_BOTON", "ALFA_RUTAS_CERCA", "ALFA_NEXT", "ALFA_PREV",
}

local function esDeAlfa(accion)
	return type(accion) == "string" and (accion:find("^ALFA_") or accion:find("^CLICK Alfa")) and true or false
end

function Tc.Lista()
	local vistos, lista = {}, {}
	local function poner(accion)
		if vistos[accion] then return end
		local nombre = rawget(_G, "BINDING_NAME_" .. accion)
		if type(nombre) ~= "string" or nombre == "" then return end
		vistos[accion] = true
		lista[#lista + 1] = { accion = accion, nombre = nombre }
	end
	for _, a in ipairs(ORDEN) do poner(a) end
	local extra, ya = {}, {}
	local function anotar(a) if not ya[a] then ya[a] = true extra[#extra + 1] = a end end
	if type(GetNumBindings) == "function" and type(GetBinding) == "function" then
		local ok, n = pcall(GetNumBindings)
		for i = 1, (ok and type(n) == "number") and n or 0 do
			local bien, accion, categoria = pcall(GetBinding, i)
			if bien and type(accion) == "string" and (categoria == "Alfa" or esDeAlfa(accion)) then anotar(accion) end
		end
	end
	for k in pairs(_G) do
		if type(k) == "string" and k:sub(1, 13) == "BINDING_NAME_" and esDeAlfa(k:sub(14)) then anotar(k:sub(14)) end
	end
	table.sort(extra)
	for _, a in ipairs(extra) do poner(a) end
	return lista
end

local v, ui = nil, {}

local function acomodar()
	if not (v and v:IsShown()) then return end
	local ancho = v:AnchoCuerpo()
	ui.pila:ClearAllPoints()
	ui.pila:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -ESP.base)
	local h = ui.pila:Acomodar(ancho)
	v:SetAltoContenido(h + 2 * ESP.base)
end

local function llenar()
	local p = ui.pila
	p:Vaciar()
	local nota = CreateFrame("Frame", nil, p)
	nota.Texto = K.Texto(nota, "texto", "textoSuave")
	nota.Texto:SetPoint("TOPLEFT", nota, "TOPLEFT", 0, 0)
	K.Escribir(nota.Texto, L["Haz clic en un atajo y pulsa la tecla que quieras; Esc cancela y el clic derecho lo quita. Se guardan fuera de combate."])
	function nota:Acomodar(ancho)
		local h = K.Parrafo(self.Texto, ancho)
		self:SetHeight(h)
		return h
	end
	p:Agregar(nota)
	local g = K.GrupoAjustes(p, { titulo = L["Tus atajos"] })
	ui.filas = {}
	for _, t in ipairs(Tc.Lista()) do
		ui.filas[#ui.filas + 1] = g:Fila({ titulo = t.nombre,
			control = function(fila) return K.Atajo(fila, { accion = t.accion, titulo = t.nombre, ancho = 150 }) end })
	end
	p:Agregar(g, { espacio = ESP.l })
	g:Refrescar()
	ui.grupo = g
end

local function armar()
	v = K.Ventana({ nombre = "AlfaTeclas", titulo = L["Tus atajos de Alfa"],
		subtitulo = L["Todas las teclas de Alfa en un lugar"], icono = "ic-ajustes", ancho = 600, alto = 540, desplazar = true })
	v.alAcomodar = acomodar
	ui.pila = K.Pila(v.Cuerpo, { espacio = ESP.m })
	v:SetPie({ K.Boton(v, L["Cerrar"], function() v:Cerrar() end, { tipo = "secundario" }) })
end

function Tc.Abrir()
	-- Las teclas solo cambian fuera de combate.
	if InCombatLockdown and InCombatLockdown() then
		N.Imprimir(L["Tus atajos se abren al terminar el combate."])
		N.FueraDeCombate("alfa.teclas", Tc.Abrir)
		return
	end
	if not v then armar() end
	v:Abrir()
	llenar()
	if v.Desplazable then v.Desplazable:IrArriba() end
	acomodar()
	K.Despues(0.05, acomodar)
end
function Tc.Visible() return v ~= nil and v:IsShown() end
function Tc.Filas() return ui.filas or {} end

A.RegisterCommand("teclas", function() Tc.Abrir() end, L["tus atajos de Alfa, para cambiarlos"])

-- 1.3.6: para el botón de Lya («¿Puedo llamarte con una tecla?», Alfa_Lya/Guia.lua).
AlfaBienvenida = type(AlfaBienvenida) == "table" and AlfaBienvenida or {}
function AlfaBienvenida.Teclas() return Tc.Abrir() end
