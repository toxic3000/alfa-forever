-- Alfa - Mundo: la lista de tus marcadores (Toxic / La Jauría). GPL-3.0.
--
-- La fila de un marcador (la misma en el panel del mapa de Alfa y en la
-- página Mundo): su ícono en su color, el nombre, dónde está (y quién te lo
-- mandó) y, a la derecha, seguir (la flecha y la ruta del motor), compartir
-- con el grupo y la ficha para cambiarlo o borrarlo. En el mapa, un clic en
-- la fila lleva la vista hasta el marcador.
--
-- El panel (Emergente.lua) se abre con el botón de la huella del mapa de
-- Alfa: un buscador cuando hay muchos, la lista virtual del Kit y, sin
-- marcadores, el lobo dormido con cómo poner el primero.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local Mk = M.Marcadores

local ipairs, max, min, format, lower = ipairs, math.max, math.min, string.format, string.lower
local ESP = K.ESP

local PM = {}
M.PanelMarcadores = PM

local ANCHO, FILA, ALTO_LISTA, BUSCAR_DESDE = 360, 44, 352, 7

---------------------------------------------------------------------------
-- La fila (K.Lista: crear una vez, pintar cada vez)
---------------------------------------------------------------------------

-- opts = { alClic = fn(m, fila) (clic en la fila), mapa = true (con "Ver en el mapa") }
function PM.CrearFila(f, opts)
	opts = opts or {}
	f.Baldosa = CreateFrame("Frame", nil, f)
	f.Baldosa:SetSize(28, 28)
	f.Baldosa:SetPoint("LEFT", f, "LEFT", ESP.m, 0)
	f.Baldosa.caja = K.Caja(f.Baldosa, { fondo = "elevado", borde = "linea", corte = K.CORTE.chico })
	f.Icono = K.Icono(f.Baldosa, "ic-huella", 16, "acento")
	f.Icono:SetPoint("CENTER")
	f.Ficha = K.BotonIcono(f, "ic-lista", function() if f.alfaM then M.Editor.Abrir({ marcador = f.alfaM, ancla = f }) end end,
		{ tam = 26, icono = 14, ayuda = L["Cambiar o borrar"] })
	f.Ficha:SetPoint("RIGHT", f, "RIGHT", -ESP.s, 0)
	f.Compartir = K.BotonIcono(f, "ic-manada", function() if f.alfaM then Mk.Compartir(f.alfaM.id) end end, { tam = 26, icono = 14 })
	f.Compartir:SetPoint("RIGHT", f.Ficha, "LEFT", -2, 0)
	K.ConInfo(f.Compartir, function()
		local puede, por = Mk.PuedeCompartir()
		return L["Compartir con el grupo"], puede and L["Quien use Alfa en tu grupo lo recibe y puede seguirlo."] or Mk.PorQueNo(por)
	end)
	local antes = f.Compartir
	if opts.mapa then
		f.Ver = K.BotonIcono(f, "ic-mundo", function()
			if f.alfaM and M.Ventana then M.Ventana.IrAMarcador(f.alfaM) end
		end, { tam = 26, icono = 14, ayuda = L["Ver en el mapa de Alfa"] })
		f.Ver:SetPoint("RIGHT", f.Compartir, "LEFT", -2, 0)
		antes = f.Ver
	end
	f.Seguir = K.Boton(f, L["Seguir"], function()
		if f.alfaM then Mk.AlternarSeguir(f.alfaM.id) end
	end, { tipo = "acento", tam = "chico", icono = "ic-seguir" })
	f.Seguir:SetPoint("RIGHT", antes, "LEFT", -ESP.s, 0)
	f.Nombre = K.Texto(f, "cuerpo", "texto")
	f.Nombre:SetPoint("TOPLEFT", f.Baldosa, "TOPRIGHT", ESP.m, 1)
	f.Nombre:SetPoint("RIGHT", f.Seguir, "LEFT", -ESP.s, 0)
	f.Nombre:SetWordWrap(false)
	f.Donde = K.Texto(f, "pequeno", "textoTenue")
	f.Donde:SetPoint("BOTTOMLEFT", f.Baldosa, "BOTTOMRIGHT", ESP.m, -1)
	f.Donde:SetPoint("RIGHT", f.Seguir, "LEFT", -ESP.s, 0)
	f.Donde:SetWordWrap(false)
end

function PM.PintarFila(f, m)
	f.alfaM = m
	K.SetIcono(f.Icono, Mk.Textura(m.icono), m.color or "acento")
	K.Escribir(f.Nombre, m.nombre)
	local donde = Mk.Donde(m)
	if m.de then donde = donde .. "  \194\183  " .. format(L["de %s"], m.de) end
	K.Escribir(f.Donde, donde)
	local siguiendo = Mk.Siguiendo(m.id)
	f.Seguir:SetTexto(siguiendo and L["Dejar"] or L["Seguir"])
	f.Seguir:SetIcono(siguiendo and "ic-cerrar" or "ic-seguir")
	f.Compartir:SetAlpha(Mk.PuedeCompartir() and 1 or 0.45)
	f.Baldosa.caja:Estilo({ fondo = "elevado", borde = siguiendo and "acento" or "linea" })
end

---------------------------------------------------------------------------
-- El panel del mapa de Alfa
---------------------------------------------------------------------------
local F
local filtro = ""

local function datos()
	local lista = Mk.Lista()
	if filtro == "" then return lista end
	local out = {}
	local q = lower(filtro)
	for _, m in ipairs(lista) do
		local texto = lower((m.nombre or "") .. " " .. Mk.NombreLugar(m) .. " " .. (m.de or ""))
		if texto:find(q, 1, true) then out[#out + 1] = m end
	end
	return out
end

function PM.Refrescar()
	if not (F and F:IsShown()) then return end
	local total = Mk.Cuantos()
	F:SetCuenta(total > 0 and total or nil)
	local conBuscar = total >= BUSCAR_DESDE
	K.Mostrar(F.Buscador, conBuscar)
	if not conBuscar and filtro ~= "" then
		filtro = ""
		F.Buscador:SetTexto("", true)
	end
	local lista = datos()
	local y = ESP.m
	local w = ANCHO - ESP.base * 2
	if conBuscar then
		F.Buscador:ClearAllPoints()
		F.Buscador:SetPoint("TOPLEFT", F.Cuerpo, "TOPLEFT", ESP.base, -y)
		F.Buscador:SetWidth(w)
		y = y + K.ALTO.control + ESP.s
	end
	local vacio = total == 0
	F.Lista:SetShown(not vacio)
	F.Vacio:SetShown(vacio)
	local alto
	if vacio then
		local vh = F.Vacio:Acomodar(w)
		F.Vacio:ClearAllPoints()
		F.Vacio:SetPoint("TOPLEFT", F.Cuerpo, "TOPLEFT", ESP.base, -(y + ESP.base))
		alto = y + ESP.base + vh + ESP.l
	else
		local lh = min(ALTO_LISTA, max(FILA, #lista * FILA))
		if #lista == 0 then lh = 140 end
		F.Lista:ClearAllPoints()
		F.Lista:SetPoint("TOPLEFT", F.Cuerpo, "TOPLEFT", ESP.s, -y)
		F.Lista:Acomodar(ANCHO - ESP.s * 2, lh)
		F.Lista:SetDatos(lista, true)
		alto = y + lh + ESP.s
	end
	-- Abajo, cómo se pone uno nuevo.
	F.Pista:ClearAllPoints()
	F.Pista:SetPoint("TOPLEFT", F.Cuerpo, "TOPLEFT", ESP.base, -(alto + ESP.s))
	F.Pista:SetWidth(w)
	F.Pista:SetShown(not vacio)
	if not vacio then alto = alto + ESP.s + K.Parrafo(F.Pista, w) + ESP.m end
	F:SetHeight(F.arriba + alto)
end

local function construir()
	F = M.Emergente({ nombre = "AlfaMundoMarcadores", titulo = L["Tus marcadores"], icono = "ic-huella", ancho = ANCHO })
	F.Buscador = K.Buscador(F.Cuerpo, { ayuda = L["Buscar por nombre, zona o quién lo mandó"], alCambiar = function(t)
		filtro = t or ""
		PM.Refrescar()
	end })
	F.Lista = K.Lista(F.Cuerpo, {
		alto = FILA, elegir = false,
		crear = function(f) PM.CrearFila(f) end,
		pintar = function(f, m) PM.PintarFila(f, m) end,
		alClic = function(m, i, boton)
			if not m then return end
			if M.Ventana then M.Ventana.IrAMarcador(m) end
			if boton == "RightButton" then
				local fila
				for _, x in ipairs(F.Lista.filas) do if x.alfaI == i then fila = x end end
				M.Editor.Abrir({ marcador = m, ancla = fila or F })
			end
		end,
		vacio = { lobo = "vacio", titulo = L["Ninguno coincide"], texto = L["Prueba con otra palabra."] },
	})
	F.Vacio = K.Vacio(F.Cuerpo, {
		lobo = "dormido", titulo = L["Todavía no tienes marcadores"],
		texto = L["Haz clic derecho (o Mayús+clic) en el mapa donde quieras uno: le pones nombre, ícono y color, y la flecha te lleva cuando quieras."],
	})
	F.Pista = K.Texto(F.Cuerpo, "pequeno", "textoTenue")
	K.Escribir(F.Pista, L["Clic en uno: el mapa va hasta él. Clic derecho en el mapa: uno nuevo."])
	F:HookScript("OnShow", PM.Refrescar)
	Mk.AlCambiar(PM.Refrescar)
end

function PM.Alternar(ancla)
	if not F then construir() end
	F:Alternar(ancla)
	PM.Refrescar()
end

function PM.Visible() return F and F:IsShown() or false end
function PM.Ocultar() if F then F:Hide() end end
