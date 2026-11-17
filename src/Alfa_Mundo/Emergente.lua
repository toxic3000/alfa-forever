-- Alfa - Mundo: la base de los paneles que se abren desde un botón (las
-- capas y los marcadores) (Toxic / La Jauría). GPL-3.0.
--
-- Un panel del Kit: la caja con su marca de acento, el ícono, el título, una
-- cuenta y la X arriba; debajo, el cuerpo que arma cada panel. Se abre junto
-- a su botón (otro clic en el mismo botón lo cierra) y solo hay uno abierto a
-- la vez. Esc lo cierra. No es un marco protegido: se abre también en combate.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)

local ESP = K.ESP
local CABECERA = 48

local abiertos = {}

-- o = { nombre (global, para Esc), titulo, icono, ancho, alCerrar = fn }
-- -> panel: panel.Cuerpo (debajo de la cabecera), panel.arriba (su alto),
--    panel:SetCuenta(n), panel:Alternar(ancla, opts), panel:Abrir(ancla, opts)
function M.Emergente(o)
	local f = CreateFrame("Frame", o.nombre, K.Raiz())
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	f:SetSize(o.ancho or 320, 240)
	f:Hide()
	f.caja = K.Caja(f, { fondo = "fondo", borde = "lineaFuerte", corte = K.CORTE.panel })
	f.Marca = K.Marca(f, K.CORTE.panel, "acento", 28)
	f.Icono = K.Icono(f, o.icono or "ic-mundo", 16, "acento")
	f.Icono:SetPoint("LEFT", f, "TOPLEFT", ESP.base, -CABECERA / 2)
	f.Titulo = K.Texto(f, "encabezado", "texto")
	f.Titulo:SetPoint("LEFT", f.Icono, "RIGHT", ESP.s, 0)
	K.Escribir(f.Titulo, o.titulo or "")
	f.Cuenta = K.Texto(f, "numero", "textoTenue")
	f.Cuenta:SetPoint("LEFT", f.Titulo, "RIGHT", ESP.s, 0)
	f.Cerrar = K.BotonIcono(f, "ic-cerrar", function() f:Hide() end, { tam = 24, icono = 11, ayuda = L["Cerrar"] })
	f.Cerrar:SetPoint("RIGHT", f, "TOPRIGHT", -ESP.m, -CABECERA / 2)
	f.Linea = K.Linea(f, "linea")
	f.Linea:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -CABECERA)
	f.Linea:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -CABECERA)
	f.Cuerpo = CreateFrame("Frame", nil, f)
	f.Cuerpo:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -CABECERA)
	f.Cuerpo:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	f.arriba = CABECERA

	function f:SetCuenta(n) self.Cuenta:SetText(n and tostring(n) or "") end

	-- Junto a `ancla` (debajo y alineado a su derecha), o en el centro.
	-- opts = { punto, relativo, x, y }
	function f:Abrir(ancla, opts)
		opts = opts or {}
		for p in pairs(abiertos) do if p ~= self and p:IsShown() then p:Hide() end end
		self.alfaAncla = ancla
		self:ClearAllPoints()
		if ancla then
			self:SetPoint(opts.punto or "TOPRIGHT", ancla, opts.relativo or "BOTTOMRIGHT", opts.x or 0, opts.y or -6)
		else
			self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		end
		self:Show()
		self:Raise()
	end

	function f:Alternar(ancla, opts)
		if self:IsShown() and self.alfaAncla == ancla then
			self:Hide()
			return false
		end
		self:Abrir(ancla, opts)
		return true
	end

	f:SetScript("OnHide", function(self)
		K.OcultarInfo()
		K.CerrarMenu()
		if o.alCerrar then K.Llamar(o.alCerrar, self) end
	end)
	if o.nombre and A.CloseOnEscape then A.CloseOnEscape(o.nombre) end
	abiertos[f] = true
	return f
end

-- Cierra todos los paneles (al cerrar el mapa que los abrió).
function M.CerrarEmergentes()
	for p in pairs(abiertos) do if p:IsShown() then p:Hide() end end
end
