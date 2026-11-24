-- Alfa - Mundo: buscar un lugar por su nombre y la leyenda de las capas
-- (1.3.9, mejora 78). toxic3000 / La Jauría. GPL-3.0.
--
-- Un panel del mapa de Alfa (el botón de la lupa de la cabecera):
--   * Sin escribir nada, la leyenda: cada capa del mapa con su ícono en su
--     color, su nombre y un ejemplo de lo que pinta (su ayuda), por grupos,
--     y si está prendida o apagada. Clic en una: se prende o se apaga.
--   * Al escribir, los lugares que coinciden: continentes, zonas y ciudades
--     (los nombres del juego, en tu idioma) y tus marcadores (por nombre o
--     nota). Sin importar tildes ni mayúsculas. Clic: el mapa va hasta ahí.
--   Bu.Buscar(texto) -> { { tipo = "zona" | "continente" | "marcador", nombre, sub, mapa, m }, ... }
--   Bu.Leyenda() -> { { grupo, capa, nombre, ejemplo, icono, color, prendida }, ... }
--   Bu.Alternar(ancla)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local Geo, Capas = M.Geo, M.Capas

local type, ipairs, min, max, format = type, ipairs, math.min, math.max, string.format
local ESP = K.ESP

local Bu = {}
M.Buscar = Bu

local ANCHO, FILA, ALTO_LISTA, MAX_RESULTADOS = 380, 66, 396, 40

-- Minúsculas y sin tildes (español, francés, alemán, portugués).
local TILDES = {
	["á"] = "a", ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["ã"] = "a", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
	["í"] = "i", ["ì"] = "i", ["î"] = "i", ["ï"] = "i", ["ó"] = "o", ["ò"] = "o", ["ô"] = "o", ["ö"] = "o", ["õ"] = "o",
	["ú"] = "u", ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["ñ"] = "n", ["ç"] = "c", ["ß"] = "ss",
	["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ú"] = "u", ["Ñ"] = "n", ["Ü"] = "u", ["Ö"] = "o", ["Ä"] = "a",
}
function Bu.Simple(t)
	if type(t) ~= "string" or (issecretvalue and issecretvalue(t)) then return "" end
	t = t:gsub("[\195][\128-\191]", function(c) return TILDES[c] or c end)
	return (t:lower():gsub("[%p]", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

---------------------------------------------------------------------------
-- Los lugares
---------------------------------------------------------------------------
local lugares -- la lista de continentes y zonas, armada una vez
local function armarLugares()
	if lugares then return lugares end
	lugares = {}
	for _, c in ipairs(Geo.Continentes() or {}) do
		local nc = Geo.Nombre(c)
		if nc then lugares[#lugares + 1] = { tipo = "continente", nombre = nc, mapa = c, clave = Bu.Simple(nc) } end
		for _, z in ipairs(Geo.Zonas(c) or {}) do
			local nz = Geo.Nombre(z.id)
			if nz then
				lugares[#lugares + 1] = { tipo = z.ciudad and "ciudad" or "zona", nombre = nz, mapa = z.id, sub = nc, clave = Bu.Simple(nz),
					lo = select(1, Geo.Niveles(z.id)), hi = select(2, Geo.Niveles(z.id)) }
			end
		end
	end
	return lugares
end
function Bu.Olvidar() lugares = nil end

function Bu.Buscar(texto)
	local q = Bu.Simple(texto)
	local out = {}
	if q == "" then return out end
	-- Primero lo que empieza así, después lo que lo tiene en medio.
	local empieza, medio = {}, {}
	for _, l in ipairs(armarLugares()) do
		local i = l.clave:find(q, 1, true)
		if i == 1 then empieza[#empieza + 1] = l elseif i then medio[#medio + 1] = l end
	end
	local Mk = M.Marcadores
	for _, m in ipairs(Mk and Mk.Lista and Mk.Lista() or {}) do
		local clave = Bu.Simple(m.nombre) .. " " .. Bu.Simple(m.nota or "")
		if clave:find(q, 1, true) then
			medio[#medio + 1] = { tipo = "marcador", nombre = m.nombre, sub = m.nota or Mk.NombreLugar(m), mapa = m.mapa, m = m }
		end
	end
	for _, l in ipairs(empieza) do if #out < MAX_RESULTADOS then out[#out + 1] = l end end
	for _, l in ipairs(medio) do if #out < MAX_RESULTADOS then out[#out + 1] = l end end
	return out
end

function Bu.Ir(r)
	if not (r and M.Ventana) then return end
	if r.m then M.Ventana.IrAMarcador(r.m) return end
	if M.Ventana.IrAZona then M.Ventana.IrAZona(r.mapa) end
end

---------------------------------------------------------------------------
-- La leyenda
---------------------------------------------------------------------------
function Bu.Leyenda()
	local out = {}
	for _, g in ipairs(Capas.Grupos() or {}) do
		for i, e in ipairs(g.capas) do
			out[#out + 1] = { grupo = i == 1 and g.nombre or nil, capa = e, nombre = e.nombre, ejemplo = e.ayuda,
				icono = e.icono, color = e.color, prendida = Capas.Valor(e) and true or false }
		end
	end
	return out
end

---------------------------------------------------------------------------
-- El panel
---------------------------------------------------------------------------
local F
local filtro = ""

local function colorDe(e)
	local T = A.Theme
	if e.color and T and T.Color then
		local r, g, b = T.Color(e.color)
		if type(r) == "number" then return r, g, b end
	end
	return K.Color("textoSuave")
end

local TIPO = { continente = "Continente", zona = "Zona", ciudad = "Ciudad", marcador = "Tu marcador" }
local ICONO = { continente = "ic-mundo", zona = "ic-mapa", ciudad = "ic-hoy", marcador = "ic-huella" }

local function crearFila(f)
	f.Icono = f:CreateTexture(nil, "ARTWORK")
	f.Icono:SetSize(18, 18)
	f.Icono:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.m, -9)
	f.Nombre = K.Texto(f, "cuerpo", "texto")
	f.Nombre:SetPoint("TOPLEFT", f, "TOPLEFT", 36, -6)
	f.Nombre:SetPoint("RIGHT", f, "RIGHT", -80, 0)
	f.Nombre:SetWordWrap(false)
	f.Sub = K.Texto(f, "pequeno", "textoTenue")
	f.Sub:SetPoint("TOPLEFT", f.Nombre, "BOTTOMLEFT", 0, -2)
	f.Sub:SetPoint("RIGHT", f, "RIGHT", -ESP.m, 0)
	f.Sub:SetJustifyH("LEFT")
	f.Sub:SetWordWrap(true)
	if f.Sub.SetMaxLines then f.Sub:SetMaxLines(3) end
	f.Etiqueta = K.Texto(f, "insignia", "textoTenue")
	f.Etiqueta:SetPoint("TOPRIGHT", f, "TOPRIGHT", -ESP.m, -7)
	f.Etiqueta:SetJustifyH("RIGHT")
end

local function pintarFila(f, d)
	f.alfaD = d
	f.Sub:SetWidth(ANCHO - ESP.s * 2 - 36 - ESP.m)
	if d.capa then
		-- Leyenda: el ícono de la capa en su color, su nombre, su ejemplo.
		local e = d.capa
		if type(e.icono) == "string" or type(e.icono) == "number" then
			f.Icono:SetTexture(e.icono)
			f.Icono:SetVertexColor(colorDe(e))
			f.Icono:Show()
		else
			f.Icono:Hide()
		end
		K.Escribir(f.Nombre, d.nombre or "")
		K.ColorTexto(f.Nombre, d.prendida and "texto" or "textoTenue")
		K.Escribir(f.Sub, d.ejemplo or "")
		K.Escribir(f.Etiqueta, K.Mayus(d.prendida and L["Se ve"] or L["Oculta"]))
		K.ColorTexto(f.Etiqueta, d.prendida and "exito" or "textoTenue")
		return
	end
	f.Icono:SetTexture(K.Ruta(ICONO[d.tipo] or "ic-mapa"))
	if d.m and M.Marcadores then
		f.Icono:SetTexture(M.Marcadores.Textura(d.m.icono))
		f.Icono:SetVertexColor(M.Marcadores.Color(d.m))
	else
		f.Icono:SetVertexColor(K.Color(d.tipo == "ciudad" and "pnj" or "lugar"))
	end
	f.Icono:Show()
	K.Escribir(f.Nombre, d.nombre or "")
	K.ColorTexto(f.Nombre, "texto")
	local sub = d.sub or ""
	if d.lo and Geo.TextoNiveles then
		local nv = Geo.TextoNiveles(d.lo, d.hi)
		if nv and nv ~= "" then sub = sub ~= "" and (sub .. "  \194\183  " .. nv) or nv end
	end
	K.Escribir(f.Sub, sub)
	K.Escribir(f.Etiqueta, K.Mayus(L[TIPO[d.tipo] or "Zona"]))
	K.ColorTexto(f.Etiqueta, "textoTenue")
end

function Bu.Refrescar()
	if not (F and F:IsShown()) then return end
	local leyenda = filtro == ""
	local lista = leyenda and Bu.Leyenda() or Bu.Buscar(filtro)
	F.alfaLista = lista
	local w = ANCHO - ESP.base * 2
	local y = ESP.m
	F.Buscador:ClearAllPoints()
	F.Buscador:SetPoint("TOPLEFT", F.Cuerpo, "TOPLEFT", ESP.base, -y)
	F.Buscador:SetWidth(w)
	y = y + K.ALTO.control + ESP.s
	K.Escribir(F.Sobre, K.Mayus(leyenda and L["Leyenda del mapa"] or (N.Plural and N.Plural(#lista, L["%d lugar"], L["%d lugares"]) or format(L["%d lugares"], #lista))))
	F.Sobre:ClearAllPoints()
	F.Sobre:SetPoint("TOPLEFT", F.Cuerpo, "TOPLEFT", ESP.base, -y)
	y = y + 14 + ESP.s
	local lh = min(ALTO_LISTA, max(FILA * 2, #lista * FILA))
	F.Lista:ClearAllPoints()
	F.Lista:SetPoint("TOPLEFT", F.Cuerpo, "TOPLEFT", ESP.s, -y)
	F.Lista:Acomodar(ANCHO - ESP.s * 2, lh)
	F.Lista:SetDatos(lista, true)
	F:SetCuenta(not leyenda and #lista or nil)
	F:SetHeight(F.arriba + y + lh + ESP.m)
end

local function construir()
	F = M.Emergente({ nombre = "AlfaMundoBuscar", titulo = L["Buscar un lugar"], icono = "ic-buscar", ancho = ANCHO })
	F.Buscador = K.Buscador(F.Cuerpo, { ayuda = L["Una zona, una ciudad o un marcador"], alCambiar = function(t)
		filtro = t or ""
		Bu.Refrescar()
	end, alEnter = function()
		local r = F.alfaLista and F.alfaLista[1]
		if r and not r.capa then Bu.Ir(r) end
	end })
	F.Sobre = K.Texto(F.Cuerpo, "mayus", "textoTenue")
	F.Lista = K.Lista(F.Cuerpo, {
		alto = FILA, elegir = false,
		crear = crearFila,
		pintar = pintarFila,
		alClic = function(d)
			if not d then return end
			if d.capa then
				local libre = Capas.Disponible(d.capa)
				if libre then Capas.Poner(d.capa, not Capas.Valor(d.capa)) end
				Bu.Refrescar()
				return
			end
			Bu.Ir(d)
		end,
		vacio = { lobo = "vacio", titulo = L["Ningún lugar con ese nombre"], texto = L["Prueba con otra palabra o con parte del nombre."] },
	})
	F:HookScript("OnShow", Bu.Refrescar)
	if Capas.AlCambiar then Capas.AlCambiar(Bu.Refrescar) end
end

function Bu.Alternar(ancla)
	if not F then construir() end
	F:Alternar(ancla, { punto = "TOPRIGHT", relativo = "BOTTOMRIGHT", x = 0, y = -6 })
end
function Bu.Abrir(ancla, texto)
	if not F then construir() end
	F:Abrir(ancla, { punto = "TOPRIGHT", relativo = "BOTTOMRIGHT", x = 0, y = -6 })
	if texto then F.Buscador:SetTexto(texto) filtro = texto Bu.Refrescar() end
end
function Bu.Visible() return F and F:IsShown() or false end
function Bu.Marco() return F end
