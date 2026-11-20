-- Alfa - Rutas: una ventana sencilla con una línea de arriba y una lista
-- (toxic3000 / La Jauría). GPL-3.0.
-- 1.3.0: la usan las misiones grises, la cadena completa y «Llévame a…».
--
--   M.VentanaSimple(opts) -> ventana
--     opts = { nombre, titulo, icono, ancho, alto, altoFila, crear(fila), pintar(fila, dato, i),
--              alClic(dato, i, boton), vacio = { titulo, texto, lobo }, buscador = { ayuda, alCambiar } }
--   ventana:Llenar(datos, titulo, subtitulo, linea)   abre (si no está) y pone la lista
--   ventana.Linea: el texto de arriba (lo que explica la lista)

local ADDON, M = ...
local K = M.K

local max = math.max

function M.VentanaSimple(opts)
	local v = K.Ventana({ nombre = opts.nombre, titulo = opts.titulo, icono = opts.icono, ancho = opts.ancho or 440, alto = opts.alto or 520 })
	local cuerpo = v.Cuerpo
	v.Linea = K.Texto(cuerpo, "nota", "textoSuave")
	v.Linea:SetWordWrap(true)
	if opts.buscador then
		v.Buscador = K.Buscador(cuerpo, { ayuda = opts.buscador.ayuda, alCambiar = opts.buscador.alCambiar })
	end
	v.Lista = K.Lista(cuerpo, {
		alto = opts.altoFila or K.ALTO.fila, crear = opts.crear, pintar = opts.pintar,
		alClic = opts.alClic, elegir = false, vacio = opts.vacio,
	})
	function v:Acomodar()
		local m = self.margen
		local ancho = self:AnchoCuerpo()
		local y = K.ESP.m
		if self.Buscador then
			self.Buscador:ClearAllPoints()
			self.Buscador:SetPoint("TOPLEFT", self.Cuerpo, "TOPLEFT", m, -y)
			self.Buscador:SetWidth(ancho)
			y = y + K.ALTO.control + K.ESP.s
		end
		local texto = self.Linea:GetText()
		if texto and texto ~= "" then
			self.Linea:ClearAllPoints()
			self.Linea:SetPoint("TOPLEFT", self.Cuerpo, "TOPLEFT", m, -y)
			y = y + K.Parrafo(self.Linea, ancho, 4) + K.ESP.s
			self.Linea:Show()
		else
			self.Linea:Hide()
		end
		self.Lista:ClearAllPoints()
		self.Lista:SetPoint("TOPLEFT", self.Cuerpo, "TOPLEFT", m - 4, -y)
		self.Lista:Acomodar(ancho + 8, max(80, self:AltoCuerpo() - y - K.ESP.s))
	end
	v.alAcomodar = function(self) self:Acomodar() end
	function v:Llenar(datos, titulo, subtitulo, linea)
		if titulo then self:SetTitulo(titulo, subtitulo, opts.icono) end
		K.Escribir(self.Linea, linea or "")
		if not self:IsShown() then self:Abrir() end
		self:Acomodar()
		self.Lista:SetDatos(datos or {})
	end
	return v
end
