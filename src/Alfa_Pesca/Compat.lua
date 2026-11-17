-- Alfa - Pesca (toxic3000 / La Jauría). GPL-3.0.
--
-- Addons de terceros con los que evitamos chocar. Son datos técnicos: el
-- nombre de su carpeta, el de sus ajustes guardados y el de su acción de
-- tecla. Si uno está cargado, la pesca de Alfa queda en pausa; sus ajustes
-- solo se leen, una vez, como punto de partida, y su tecla se recuerda para
-- tomarla cuando lo desactives. Ningún texto visible los nombra.

local ADDON, M = ...

M.OTROS = {
	pesca = {
		{
			carpeta = "BetterFishing",
			guardado = "BetterFishingDB",
			accion = "BETTERFISHINGKEY",
			-- sus opciones (verdadero o falso) -> las de Alfa
			opciones = {
				{ "autoLoot", "autobotin" }, { "hideNamePlates", "ocultarNombres" }, { "enhanceSounds", "sonido" },
				{ "doubleClickEnabled", "dobleClic" }, { "doubleClickForce", "montado" }, { "recastOnDoubleClick", "relanzar" },
			},
			volumen = "enhanceSoundsScale",  -- número de 0 a 1
			velocidad = "doubleClickSpeed",  -- segundos entre los dos clics
			sinIcono = "objectIconDisabled", -- verdadero: sin ícono sobre el corcho
		},
	},
}
