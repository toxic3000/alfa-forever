-- Alfa - Comercio (Toxic / La Jauría). GPL-3.0.
--
-- Addons de subastas de terceros de los que se leen precios, solo cuando Alfa
-- no tiene uno y solo por su API pública. Son datos técnicos: la ruta de su
-- tabla global y el nombre de sus funciones, que reciben ("Alfa", objeto).
-- Ningún texto visible los nombra.

local _, M = ...

M.OTROS = {
	precios = {
		{
			api = { "Auctionator", "API", "v1" },
			porEnlace = "GetAuctionPriceByItemLink", -- precio por enlace del objeto
			porId = "GetAuctionPriceByItemID",       -- precio por ID del objeto
			edad = "GetAuctionAgeByItemID",          -- días desde que vio ese precio
		},
	},
}
