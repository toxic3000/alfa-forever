-- Alfa - Rutas: la banda de color de los títulos (toxic3000 / La Jauría).
-- GPL-3.0. 1.4.0 (70)
--
-- Antes, el título del rastreador (y de sus tarjetas y de «Buscar cerca»)
-- llevaba una rayita de acento de 28 px arriba a la izquierda, que se veía
-- corta y fuera de lugar junto a la barra de avance. Toxic prefiere una banda
-- completa: todo el ancho, con el título y sus datos adentro y alineados.
--   * fondo del color de acento muy suave, con el mismo corte de esquina que
--     la ventana arriba a la izquierda (abajo, recta);
--   * una línea de acento de 2 px arriba, de lado a lado;
--   * una línea fina abajo que la separa del resto.
-- En Clásico WoW (K.SoloCasa) la línea de arriba se vuelve transparente.
--
--   M.Banda(marco, corte, opts) -> banda   opts = { alfa = 0.14, linea = true, abajo = true }
--   banda:Acomodar(alto)   pegada arriba del marco, de lado a lado (1 px adentro del borde)

local ADDON, M = ...
local K = M.K

function M.Banda(marco, corte, opts)
	opts = opts or {}
	corte = corte or K.CORTE.panel
	local b = CreateFrame("Frame", nil, marco)
	b:SetPoint("TOPLEFT", marco, "TOPLEFT", 1, -1)
	b:SetPoint("TOPRIGHT", marco, "TOPRIGHT", -1, -1)
	b:SetHeight(opts.alto or 40)
	b:EnableMouse(false)
	-- (las texturas son del marco, ancladas a la banda: así el título del
	-- marco queda encima y no bajo un velo)
	b.Fondo = K.Forma(b, corte, "BACKGROUND", -4, marco)
	b.Fondo:Corte(math.max(0, corte - 1), 0)
	K.Pintar(b.Fondo, function(f) f:Color("acento", opts.alfa or 0.14) end)
	if opts.linea ~= false then
		b.Arriba = K.Plano(marco, "acento", "ARTWORK", 3)
		b.Arriba:SetHeight(2)
		b.Arriba:SetPoint("TOPLEFT", b, "TOPLEFT", math.max(0, corte - 1), 0)
		b.Arriba:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
		K.SoloCasa(b.Arriba)
	end
	if opts.abajo ~= false then
		b.Abajo = K.Linea(marco, "linea")
		b.Abajo:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
		b.Abajo:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	end
	function b:Acomodar(alto)
		self:SetHeight(math.max(1, (alto or self:GetHeight()) - 1))
	end
	return b
end
