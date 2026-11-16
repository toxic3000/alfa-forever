-- Alfa - Recolección (Toxic / La Jauría, GPL-3.0).
--
-- Addons de recolección de terceros de los que se pueden importar los nodos
-- que recolectaste (una vez sola al entrar, o con el botón de la página). Son
-- datos técnicos: el nombre de sus datos guardados (solo se leen) y dónde
-- guardan cada nodo. Ningún texto visible los nombra.

local _, M = ...

M.OTROS = {
	recoleccion = {
		{
			guardado = "GatherLiteSettings",
			-- sus datos guardados -> lista de nodos por tipo: S.global.nodes[tipo]
			ruta = { "global", "nodes" },
			-- sus tipos de nodo que Alfa también muestra
			tipos = { mining = true, herbalism = true, containers = true, fishing = true },
			-- los campos de cada nodo
			objeto = "object", mapa = "mapID", x = "posX", y = "posY", fecha = "date",
		},
	},
}
