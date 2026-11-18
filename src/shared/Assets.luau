-- Assets: ids de assets GRATUITOS del Creator Store de Roblox usados por el juego (ver assets/manifest.json
-- para autor y alternativas de cada uno, y assets/preview/ para verlos).
-- Un id en 0 significa "sin asset": el juego usa entonces su alternativa construida con piezas y
-- materiales integrados. Ademas, el cliente comprueba al arrancar que cada textura carga
-- (AssetCheck) y, si alguna falla, la desactiva: nunca quedan planetas invisibles ni referencias rotas.
local Assets = {}

-- Esfera con UV equirectangular ("RenderMesh", pack oficial de Roblox "Beyond the Dark")
Assets.SphereMesh = 6441034336
Assets.SphereMeshRadius = 8.00446 -- radio de la malla en unidades de malla

-- Mapas de superficie (equirectangulares 2:1) por clave de textura (PlanetDefinitions.Visual.Texture)
Assets.Textures = {
	terra = 14113088653,
	rocanox = 5184963957,
	dunaris = 8637912772,
	glaciera = 109017797659108,
	jovian = 78908883189888,
	inferno = 17886692408,
	amethyst = 9848378750,
	aureon = 106225721938856,
	nebulon = 110852519379669,
	shadowra = 137143678008653,
	quantum = 103941792770202,
	singularity = 9856964100,
	cryostar = 123306104411190,
	volcanis = 91528305407533,
	zenith = 10685296286,
	moon = 8159103611,
	sun = 133964586422832,
	cosmic = 14113890780, -- capa de la variante Cosmic
	clouds = 11025160997, -- capa de nubes con transparencia
}

-- Imagenes con transparencia
Assets.Images = {
	ring = 127544228287826, -- anillos blancos vistos desde arriba (se tiñen)
	ring_saturn = 5450454604,
	glow = 290434402, -- degradado radial blanco
	flare = 15049808173, -- destello de 4 puntas
	smoke = 6835347835, -- nube suave (nebulosas)
	galaxy = 125791123364516, -- galaxia espiral
	nebula = 14135223682, -- nebulosa rosa/azul
}

-- Skybox de nebulosa azul-violeta para el espacio profundo
Assets.Skybox = {
	Bk = 95984003307249,
	Dn = 135816775316034,
	Ft = 134724161702610,
	Lf = 96690603990248,
	Rt = 129021469699942,
	Up = 90271986476549,
}

-- Sonidos (efectos de la cuenta oficial Roblox; musica de la biblioteca con licencia del Creator Store)
Assets.Sounds = {
	click = 15675059323,
	hover = 10066931761,
	success = 10066947742,
	error = 17208353912,
	charge = 16480578036,
	reveal = 17208327798,
	fanfare = 17208372272,
	portal = 15674975792,
	collect = 17208319162,
	notify = 17208361335,
	music_hub = 103700934283247,
	music_universe = 140533822783920,
}

function Assets.url(id)
	if type(id) == "number" and id > 0 then
		return "rbxassetid://" .. tostring(id)
	end
	return ""
end

function Assets.texture(key)
	return Assets.url(Assets.Textures[key])
end

function Assets.image(key)
	return Assets.url(Assets.Images[key])
end

function Assets.sound(key)
	return Assets.url(Assets.Sounds[key])
end

-- Marca como no disponible cualquier asset cuya URL este en `failed` (conjunto de URLs).
-- Devuelve cuantos se desactivaron.
function Assets.disable(failed)
	local n = 0
	for _, group in ipairs({ Assets.Textures, Assets.Images, Assets.Sounds }) do
		for key, id in pairs(group) do
			if failed[Assets.url(id)] then
				group[key] = 0
				n = n + 1
			end
		end
	end
	if failed[Assets.url(Assets.SphereMesh)] then
		Assets.SphereMesh = 0
		n = n + 1
	end
	return n
end

return Assets
