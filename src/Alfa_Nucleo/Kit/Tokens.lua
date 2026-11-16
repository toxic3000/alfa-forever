-- Alfa - Kit: tokens del diseño A (Toxic / La Jauría). GPL-3.0.
--
-- El Kit de Alfa son las piezas propias de la interfaz (docs/KIT.md): se
-- escribió desde cero para Alfa 1.0 y no deriva de los Widgets del motor.
--   local K = AlfaNucleo.Kit
-- Este archivo: medidas (rejilla de 8 px), cortes, colores, letra, íconos y
-- el repintado cuando cambia el aspecto (Ajustes > Apariencia).

local _, N = ...
local A = N.A
local T = A and A.Theme

local K = {}
N.Kit = K
K.L = N.Textos(N.EN)

local type, pairs, pcall, floor, ceil, max, min = type, pairs, pcall, math.floor, math.ceil, math.max, math.min

---------------------------------------------------------------------------
-- Medidas: todo cae en una rejilla de 8 px (4 para los ajustes finos).
---------------------------------------------------------------------------
K.ESP = { xs = 4, s = 8, m = 12, base = 16, l = 24, xl = 32, xxl = 48 }

-- Las esquinas cortadas del diseño A (arriba a la izquierda y abajo a la
-- derecha). Alfa no usa radios redondos: el "radio" de cada pieza es su corte.
K.CORTE = { ventana = 10, panel = 8, tarjeta = 8, control = 6, chico = 4, casilla = 3 }

-- Alturas fijas de las piezas, para que todo alinee en la rejilla.
K.ALTO = {
	boton = 32, botonGrande = 40, botonChico = 24, control = 32, insignia = 20,
	fila = 36, filaCompacta = 28, seccion = 32, interruptor = 20, pildora = 28,
	cabecera = 56, pie = 56, compacta = 48,
}

-- Anchos de referencia.
K.ANCHO = { tarjeta = 256, ficha = 340, lista = 320, dialogo = 420, aviso = 360, info = 280 }

---------------------------------------------------------------------------
-- Colores: los nombres del Kit y su token del tema. El tema resuelve el
-- esquema (Grafito, Noche, Pizarra), el acento propio y la legibilidad; sin
-- tema (pruebas) se usan los valores del diseño A.
---------------------------------------------------------------------------
local function hex(s, a)
	local r, g, b = s:match("(%x%x)(%x%x)(%x%x)")
	return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, a or 1 }
end

local DEL_TEMA = {
	fondo = "bg", panel = "panel", elevado = "panelAlt", hundido = "sidebar", pie = "footer",
	linea = "line", lineaFuerte = "lineStrong",
	texto = "text", textoSuave = "textDim", textoTenue = "textMuted",
	acento = "accent", sobreAcento = "onAccent",
	exito = "success", aviso = "warning", peligro = "danger", peligroRelleno = "dangerFill",
	oro = "gold", mision = "quest", pnj = "npc", objeto = "item", lugar = "place",
	mazmorra = "dungeon", raro = "rare", clase = "class", claseTexto = "classText", velo = "scrim",
}
K.DEL_TEMA = DEL_TEMA

local DISENO_A = {
	fondo = hex("101412", 0.97), panel = hex("18201b", 0.98), elevado = hex("1f2a23"), hundido = hex("0d110f"),
	pie = hex("141a16"), linea = hex("26302a"), lineaFuerte = hex("34423a"),
	texto = hex("e6efe4"), textoSuave = hex("a3b1a4"), textoTenue = hex("8a998b"),
	acento = hex("8be04e"), sobreAcento = hex("0d1a08"),
	exito = { 0.42, 0.85, 0.6, 1 }, aviso = hex("f0b34a"), peligro = hex("e86b5a"), peligroRelleno = hex("e05a4f"),
	oro = hex("f2d06b"), mision = hex("f2d06b"), pnj = { 0.58, 0.79, 1, 1 }, objeto = { 0.78, 0.68, 1, 1 },
	lugar = { 0.96, 0.68, 0.52, 1 }, mazmorra = { 0.64, 0.52, 1, 1 }, raro = { 1, 0.5, 0.32, 1 },
	clase = hex("8be04e"), claseTexto = hex("8be04e"), velo = hex("0b0e0c"),
}
K.DISENO_A = DISENO_A

-- token (nombre del Kit, del tema, o { r, g, b, a }) -> r, g, b, a
function K.Color(token)
	if type(token) == "table" then return token[1] or 1, token[2] or 1, token[3] or 1, token[4] or 1 end
	if T and T.Color then
		local r, g, b, a = T.Color(DEL_TEMA[token] or token)
		if type(r) == "number" then return r, g, b, a or 1 end
	end
	local c = DISENO_A[token] or DISENO_A.texto
	return c[1], c[2], c[3], c[4] or 1
end

-- El mismo color con otra opacidad.
function K.ConAlfa(token, alfa)
	local r, g, b = K.Color(token)
	return r, g, b, alfa
end

-- "ffrrggbb" para |c...|r.
function K.Hex(token)
	local r, g, b = K.Color(token)
	return ("ff%02x%02x%02x"):format(floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

-- Texto en un color: K.Tenir("acento", "Seguir").
function K.Tenir(token, texto) return "|c" .. K.Hex(token) .. tostring(texto) .. "|r" end

-- La clase del jugador (el segundo acento): { archivo, nombre, r, g, b, hex, texto = { r, g, b } }.
function K.Clase()
	if T and T.Clase then
		local ok, c = pcall(T.Clase)
		if ok and type(c) == "table" and type(c.r) == "number" then return c end
	end
	local r, g, b = K.Color("acento")
	return { archivo = nil, nombre = "", r = r, g = g, b = b, hex = K.Hex("acento"), texto = { r, g, b } }
end

-- Los tonos de las piezas (insignias, tarjetas de estado, avisos): su color
-- de relleno y el de su texto.
K.TONOS = {
	acento = { "acento", "acento" }, clase = { "clase", "claseTexto" }, exito = { "exito", "exito" },
	aviso = { "aviso", "aviso" }, peligro = { "peligroRelleno", "peligro" }, neutro = { "textoTenue", "textoSuave" },
	oro = { "oro", "oro" }, mazmorra = { "mazmorra", "mazmorra" }, raro = { "raro", "raro" },
}
function K.Tono(tono)
	local t = K.TONOS[tono or "neutro"] or K.TONOS.neutro
	return t[1], t[2]
end

---------------------------------------------------------------------------
-- Repintado: cada pieza registra cómo se pinta; un cambio de aspecto (tema,
-- acento, letra, tamaño de texto) las repinta todas.
---------------------------------------------------------------------------
local pintores = setmetatable({}, { __mode = "k" })

function K.Pintar(obj, fn)
	pintores[obj] = fn
	fn(obj)
	return obj
end

function K.Repintar()
	for obj, fn in pairs(pintores) do
		local ok, err = pcall(fn, obj)
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end
	if K.alRepintar then
		for i = 1, #K.alRepintar do pcall(K.alRepintar[i]) end
	end
end

-- Algo que se rehace tras un cambio de aspecto (una plantilla que mide de nuevo).
function K.AlRepintar(fn)
	K.alRepintar = K.alRepintar or {}
	K.alRepintar[#K.alRepintar + 1] = fn
end

if T and type(T.OnChanged) == "function" then T.OnChanged(K.Repintar) end

---------------------------------------------------------------------------
-- Letra: Inter (Alfa/Media/Fonts), con la escala de texto del jugador.
-- Coreano y chino usan la letra del juego; el ruso, Fira Sans cuando el
-- jugador eligió la letra del juego (la del juego no tiene el punto medio).
---------------------------------------------------------------------------
local FUENTES = "Interface\\AddOns\\Alfa\\Media\\Fonts\\"
local FAMILIAS = {
	inter = { regular = "Inter-Regular.ttf", medium = "Inter-Medium.ttf", semibold = "Inter-SemiBold.ttf" },
	fira = { regular = "FiraSans-Regular.ttf", medium = "FiraSans-Medium.ttf", semibold = "FiraSans-SemiBold.ttf" },
	opensans = { regular = "OpenSans-Regular.ttf", medium = "OpenSans-Regular.ttf", semibold = "OpenSans-Bold.ttf" },
}
local CJK = { zhCN = true, zhTW = true, koKR = true }

-- La escala tipográfica: { peso, tamaño }.
K.TIPO = {
	portada = { "semibold", 26 },    -- el título de una portada ("¿Qué hacemos hoy?")
	titulo = { "semibold", 18 },     -- título de ventana, de la acción recomendada
	subtitulo = { "semibold", 15 },  -- título de tarjeta
	encabezado = { "semibold", 13 }, -- encabezado de sección
	cuerpo = { "medium", 13 },       -- texto principal de filas
	texto = { "regular", 13 },       -- párrafos
	etiqueta = { "medium", 12 },     -- controles
	boton = { "semibold", 12 },      -- botones
	botonGrande = { "semibold", 14 },
	nota = { "regular", 12 },        -- descripciones
	pequeno = { "medium", 11 },      -- líneas secundarias
	insignia = { "semibold", 11 },   -- insignias y píldoras
	mayus = { "semibold", 10 },      -- sobretítulos en mayúsculas ("RECOMENDADO")
	numero = { "semibold", 13 },     -- contadores
	cifra = { "semibold", 22 },      -- números grandes
}

local function letraDelJuego() return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end

function K.Cara(peso)
	local loc = GetLocale and GetLocale()
	if CJK[loc] then return letraDelJuego() end
	local clave = (T and T.FontKey and T.FontKey()) or "inter"
	if clave == "game" then
		if loc ~= "ruRU" then return letraDelJuego() end
		clave = "fira"
	end
	local fam = FAMILIAS[clave] or FAMILIAS.inter
	return FUENTES .. (fam[peso] or fam.medium)
end

local function escalaTexto()
	local v = T and T.TextScale and T.TextScale()
	return type(v) == "number" and v or 1
end

-- El tamaño en pantalla de un rol (con la escala de texto del jugador).
function K.Tamano(rol)
	local spec = K.TIPO[rol] or K.TIPO.cuerpo
	return floor(spec[2] * escalaTexto() * 2 + 0.5) / 2
end

function K.Fuente(fs, rol)
	rol = rol or fs.alfaRol or "cuerpo"
	fs.alfaRol = rol
	local spec = K.TIPO[rol] or K.TIPO.cuerpo
	local tam = K.Tamano(rol)
	local ruta = fs.alfaEscritura or K.Cara(spec[1])
	local ok, cargo = pcall(fs.SetFont, fs, ruta, tam, "")
	if not (ok and cargo) then fs:SetFont(letraDelJuego(), tam, "") end
	fs:SetShadowOffset(0, 0)
end

local function pintarTexto(fs)
	K.Fuente(fs)
	fs:SetTextColor(K.Color(fs.alfaColor or "texto"))
end

-- Un texto del Kit: rol de K.TIPO y color (token). Una línea por omisión.
function K.Texto(padre, rol, color, capa)
	local fs = padre:CreateFontString(nil, capa or "OVERLAY")
	fs.alfaRol, fs.alfaColor = rol or "cuerpo", color or "texto"
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	K.Pintar(fs, pintarTexto)
	return fs
end

function K.ColorTexto(fs, color)
	fs.alfaColor = color
	fs:SetTextColor(K.Color(color))
end

-- Pone el texto; un nombre en coreano o chino en un cliente latino toma la
-- letra del juego para esa escritura (sin ella saldrían cuadros).
function K.Escribir(fs, texto)
	texto = texto ~= nil and tostring(texto) or ""
	local otra = T and T.ScriptFont and T.ScriptFont(texto) or nil
	if type(otra) ~= "string" then otra = nil end
	if otra ~= fs.alfaEscritura then
		fs.alfaEscritura = otra
		K.Fuente(fs)
	end
	fs:SetText(texto)
end

---------------------------------------------------------------------------
-- Medir. El cliente puede devolver nada antes del primer dibujo: siempre
-- un número.
---------------------------------------------------------------------------
local function num(v, d) return type(v) == "number" and v or (d or 0) end
K.num = num

function K.AnchoTexto(fs)
	local w = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
	return ceil(num(w))
end

function K.AltoTexto(fs)
	if (fs:GetText() or "") == "" then return 0 end
	return ceil(num(fs:GetStringHeight()))
end

-- Un párrafo de `ancho`: lo envuelve y devuelve su alto.
function K.Parrafo(fs, ancho, lineas)
	fs:SetWidth(max(1, floor(ancho)))
	fs:SetWordWrap(true)
	if lineas then fs:SetMaxLines(lineas) end
	fs:SetJustifyV("TOP")
	return K.AltoTexto(fs)
end

-- Ajusta el ancho de un texto de una línea a lo que mide, sin pasar de `tope`.
function K.Ajustar(fs, tope)
	fs:SetWidth(0)
	local w = K.AnchoTexto(fs)
	if tope and w > tope then w = tope end
	fs:SetWidth(max(1, w + 1))
	return w
end

function K.Pixel(region)
	if T and T.Pixel then
		local ok, v = pcall(T.Pixel, region)
		if ok and type(v) == "number" and v > 0 then return v end
	end
	return 1
end

---------------------------------------------------------------------------
-- Íconos: los nombres son texturas de Alfa/Media/UI (ic-*, sec-*, lobo-*);
-- un número (fileID) o una ruta completa pasan tal cual.
---------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\Alfa\\Media\\UI\\"

function K.Ruta(nombre)
	if type(nombre) ~= "string" then return nombre end
	if nombre:find("\\", 1, true) or nombre:find("/", 1, true) then return nombre end
	return MEDIA .. nombre
end

-- Las variantes del lobo (tools/iconos.py): normal, atento, aullando, dormido, vacio.
function K.Lobo(variante) return MEDIA .. "lobo-" .. (variante or "normal") end

local function pintarIcono(t)
	if t.alfaColor then t:SetVertexColor(K.Color(t.alfaColor)) else t:SetVertexColor(1, 1, 1, 1) end
end

function K.SetIcono(t, nombre, color)
	t:SetTexture(K.Ruta(nombre))
	t.alfaColor = color
	K.Pintar(t, pintarIcono)
end

function K.Icono(padre, nombre, tam, color, capa)
	local t = padre:CreateTexture(nil, capa or "ARTWORK")
	t:SetSize(tam or 16, tam or 16)
	K.SetIcono(t, nombre, color)
	return t
end

-- Un rectángulo de color (líneas, rellenos planos).
function K.Plano(padre, color, capa, sub)
	local t = padre:CreateTexture(nil, capa or "BACKGROUND", nil, sub or 0)
	t:SetColorTexture(1, 1, 1, 1)
	t.alfaColor = color
	K.Pintar(t, pintarIcono)
	return t
end

function K.ColorPlano(t, color)
	t.alfaColor = color
	pintarIcono(t)
end

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------

-- Llama fn sin dejar que un error rompa la pieza (lo reporta).
function K.Llamar(fn, ...)
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok and geterrorhandler then geterrorhandler()(err) end
	return ok
end

-- Un temporizador que se puede cancelar (para búsquedas mientras escribes).
function K.Despues(seg, fn)
	if C_Timer and C_Timer.NewTimer then return C_Timer.NewTimer(seg, fn) end
	local vivo = { cancelado = false }
	function vivo:Cancel() self.cancelado = true end
	if C_Timer and C_Timer.After then C_Timer.After(seg, function() if not vivo.cancelado then fn() end end) end
	return vivo
end

-- La capa de Alfa (se oculta con "Ocultar Alfa"); sin motor, UIParent.
function K.Raiz()
	return (A and A.UIParent) or UIParent
end
