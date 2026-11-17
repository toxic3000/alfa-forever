-- Alfa - Bolsas: la seccion "Personajes" del motor se abre aqui (toxic3000 / La Jauria). GPL-3.0.
-- La pagina de Bolsas ya muestra a tus personajes con lo que lleva cada uno,
-- asi que el centro de guias del motor no se vuelve a mostrar para eso.
local N = AlfaNucleo
if N and N.Reemplazar then
	N.Reemplazar("SHOW_ALTS", function() N.Abrir("bolsas") end)
end
