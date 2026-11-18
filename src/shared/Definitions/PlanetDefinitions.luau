-- PlanetDefinitions: catalogo de planetas (datos, no scripts).
-- Los 15 planetas del manual conservan nombre, rareza, tipo y produccion de referencia.
-- Se añaden 10 mundos complementarios (lunas y planetas de sistemas avanzados) para dar contenido
-- a las colecciones de Nebula, Void, Celestial e Infinity.
--
-- Campos: Id, Name, Description, Rarity, Elements (lista), TypeLabel, System (coleccion a la que pertenece),
-- Base (BaseEnergyPerSecond), CollectionValue, ModelKey, Scale, RotationSpeed (grados/s), OrbitSpeed (factor),
-- Visual (parametros para Shared/PlanetVisual), VariantRules (variantes permitidas), Secret (pista).
local Planets = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local ALL_VARIANTS = { "shiny", "golden", "rainbow", "cosmic" }

local LIST = {
	---------------------------------------------------------------- SOLAR
	{
		Id = "terra", Name = "Terra", Rarity = "common", Elements = { "rocky" }, TypeLabel = "Rocoso / terrestre",
		System = "solar", Base = 10, Scale = 1.0, RotationSpeed = 14, OrbitSpeed = 1.0,
		Description = "Mundo terrestre azul y verde, con océanos, continentes y nubes. Tu primer hogar.",
		Visual = { Texture = "terra", Color = rgb(52, 120, 200), Material = "Grass", Atmosphere = rgb(110, 190, 255),
			Clouds = true },
	},
	{
		Id = "rocanox", Name = "Rocanox", Rarity = "common", Elements = { "rocky" }, TypeLabel = "Rocoso",
		System = "solar", Base = 12, Scale = 0.9, RotationSpeed = 10, OrbitSpeed = 1.15,
		Description = "Planeta rocoso gris de cráteres, montañas fracturadas y superficie mineral.",
		Visual = { Texture = "rocanox", Color = rgb(120, 120, 128), Material = "Slate", Bumps = 9 },
	},
	{
		Id = "dunaris", Name = "Dunaris", Rarity = "uncommon", Elements = { "desert" }, TypeLabel = "Desértico",
		System = "solar", Base = 20, Scale = 1.0, RotationSpeed = 12, OrbitSpeed = 0.95,
		Description = "Mundo árido ocre con dunas, cañones y tormentas de polvo.",
		Visual = { Texture = "dunaris", Color = rgb(214, 150, 72), Material = "Sandstone", Atmosphere = rgb(255, 190, 120) },
	},
	{
		Id = "glaciera", Name = "Glaciera", Rarity = "uncommon", Elements = { "ice" }, TypeLabel = "Hielo",
		System = "solar", Base = 22, Scale = 1.0, RotationSpeed = 9, OrbitSpeed = 0.9,
		Description = "Planeta helado azul con placas de hielo, grietas luminosas y escarcha.",
		Visual = { Texture = "glaciera", Color = rgb(130, 205, 255), Material = "Glacier", Atmosphere = rgb(150, 230, 255),
			Glow = rgb(120, 210, 255), Particles = "frost" },
	},
	{
		Id = "jovian", Name = "Jovian", Rarity = "rare", Elements = { "gas" }, TypeLabel = "Gas gigante",
		System = "solar", Base = 35, Scale = 1.45, RotationSpeed = 22, OrbitSpeed = 0.7,
		Description = "Gigante gaseoso con bandas atmosféricas crema y marrón.",
		Visual = { Texture = "jovian", Color = rgb(214, 180, 140), Material = "Sand", Atmosphere = rgb(255, 225, 190) },
	},
	{
		Id = "inferno", Name = "Inferno", Rarity = "rare", Elements = { "fire" }, TypeLabel = "Fuego",
		System = "solar", Base = 40, Scale = 1.05, RotationSpeed = 12, OrbitSpeed = 1.1,
		Description = "Mundo volcánico oscuro con ríos de lava naranja y actividad térmica.",
		Visual = { Texture = "inferno", Color = rgb(255, 110, 30), Material = "CrackedLava", Atmosphere = rgb(255, 120, 40),
			Glow = rgb(255, 120, 40), Particles = "embers" },
	},
	---------------------------------------------------------------- NEBULA
	{
		Id = "lunaris", Name = "Lunaris", Rarity = "uncommon", Elements = { "moon", "rocky" }, TypeLabel = "Luna",
		System = "nebula", Base = 26, Scale = 0.7, RotationSpeed = 8, OrbitSpeed = 1.3,
		Description = "Luna plateada de polvo fino que refleja la luz de la nebulosa.",
		Visual = { Texture = "moon", Color = rgb(190, 195, 210), Material = "Slate", Atmosphere = rgb(200, 210, 255) },
	},
	{
		Id = "amethyst", Name = "Amethyst", Rarity = "rare", Elements = { "crystal" }, TypeLabel = "Cristal",
		System = "nebula", Base = 42, Scale = 1.0, RotationSpeed = 11, OrbitSpeed = 1.0,
		Description = "Planeta cristalino violeta con grandes formaciones minerales facetadas.",
		Visual = { Texture = "amethyst", Color = rgb(150, 80, 230), Material = "Glass", Atmosphere = rgb(190, 120, 255),
			Glow = rgb(170, 90, 255), Shards = { Count = 16, Color = rgb(185, 110, 255), Length = 0.55 } },
	},
	{
		Id = "selene", Name = "Selene", Rarity = "rare", Elements = { "moon", "crystal" }, TypeLabel = "Luna cristalina",
		System = "nebula", Base = 46, Scale = 0.75, RotationSpeed = 10, OrbitSpeed = 1.25,
		Description = "Luna de cuarzo azulado con vetas brillantes que resuenan con otros cristales.",
		Visual = { Texture = "moon", Tint = rgb(150, 190, 255), Color = rgb(140, 180, 255), Material = "Ice",
			Atmosphere = rgb(150, 200, 255), Shards = { Count = 7, Color = rgb(170, 220, 255), Length = 0.4 } },
	},
	{
		Id = "aureon", Name = "Aureon", Rarity = "epic", Elements = { "celestial", "gas" }, TypeLabel = "Dorado / celestial",
		System = "nebula", Base = 60, Scale = 1.3, RotationSpeed = 18, OrbitSpeed = 0.8,
		Description = "Planeta dorado con atmósfera cálida y anillos finos luminosos.",
		Visual = { Texture = "aureon", Color = rgb(240, 180, 70), Material = "Sand", Atmosphere = rgb(255, 210, 110),
			Glow = rgb(255, 200, 90),
			Rings = { { Inner = 1.35, Outer = 2.25, Color = rgb(255, 215, 130), Tilt = 18, Alpha = 0.25 } } },
	},
	{
		Id = "nebulon", Name = "Nebulon", Rarity = "epic", Elements = { "cosmic", "gas" }, TypeLabel = "Cósmico",
		System = "nebula", Base = 70, Scale = 1.25, RotationSpeed = 20, OrbitSpeed = 0.85,
		Description = "Mundo cósmico azul-violeta con bandas de nebulosa y anillos energéticos.",
		Visual = { Texture = "nebulon", Color = rgb(80, 90, 240), Material = "Glass", Atmosphere = rgb(120, 110, 255),
			Glow = rgb(110, 100, 255), Particles = "stardust",
			Rings = { { Inner = 1.4, Outer = 1.5, Color = rgb(120, 170, 255), Tilt = 24, Alpha = 0.1, Line = true },
				{ Inner = 1.75, Outer = 1.83, Color = rgb(190, 120, 255), Tilt = 24, Alpha = 0.15, Line = true } } },
	},
	---------------------------------------------------------------- VOID
	{
		Id = "noctis", Name = "Noctis", Rarity = "rare", Elements = { "dark" }, TypeLabel = "Oscuro",
		System = "void", Base = 52, Scale = 0.95, RotationSpeed = 7, OrbitSpeed = 1.05,
		Description = "Mundo de obsidiana que absorbe la luz; solo su borde delata su presencia.",
		Visual = { Texture = "rocanox", Tint = rgb(60, 55, 90), Color = rgb(30, 28, 48), Material = "Basalt",
			Atmosphere = rgb(120, 80, 255), Glow = rgb(110, 70, 255) },
	},
	{
		Id = "umbra", Name = "Umbra", Rarity = "epic", Elements = { "dark", "gas" }, TypeLabel = "Oscuro / gaseoso",
		System = "void", Base = 85, Scale = 1.3, RotationSpeed = 16, OrbitSpeed = 0.8,
		Description = "Gigante de sombras con tormentas púrpuras que giran en silencio.",
		Visual = { Texture = "nebulon", Tint = rgb(120, 70, 170), Color = rgb(50, 25, 85), Material = "Glass",
			Atmosphere = rgb(160, 70, 255), Glow = rgb(140, 60, 240),
			Rings = { { Inner = 1.45, Outer = 1.52, Color = rgb(170, 90, 255), Tilt = -20, Alpha = 0.1, Line = true } } },
	},
	{
		Id = "shadowra", Name = "Shadowra", Rarity = "legendary", Elements = { "dark", "fire" }, TypeLabel = "Oscuro / fuego",
		System = "void", Base = 100, Scale = 1.1, RotationSpeed = 12, OrbitSpeed = 0.95,
		Description = "Planeta oscuro y volcánico con anillos dorados y grietas incandescentes.",
		Visual = { Texture = "shadowra", Color = rgb(60, 30, 25), Material = "CrackedLava", Atmosphere = rgb(255, 150, 60),
			Glow = rgb(255, 140, 50), Particles = "embers",
			Rings = { { Inner = 1.4, Outer = 2.1, Color = rgb(255, 190, 90), Tilt = 14, Alpha = 0.3 } } },
	},
	{
		Id = "eclipsa", Name = "Eclipsa", Rarity = "legendary", Elements = { "dark", "moon" }, TypeLabel = "Luna oscura",
		System = "void", Base = 120, Scale = 0.85, RotationSpeed = 9, OrbitSpeed = 1.2,
		Description = "Luna en eclipse perpetuo, coronada por un halo de luz blanca.",
		Visual = { Texture = "moon", Tint = rgb(45, 45, 60), Color = rgb(18, 18, 28), Material = "Basalt",
			Atmosphere = rgb(255, 255, 255), Glow = rgb(235, 235, 255),
			Rings = { { Inner = 1.2, Outer = 1.28, Color = rgb(255, 255, 255), Tilt = 90, Alpha = 0.05, Line = true } } },
	},
	{
		Id = "singularity", Name = "Singularity", Rarity = "mythic", Elements = { "gravity", "dark" }, TypeLabel = "Gravitacional",
		System = "void", Base = 150, Scale = 1.15, RotationSpeed = 40, OrbitSpeed = 0.75,
		Description = "Mundo de gravedad extrema con núcleo de vórtice violeta y distorsión espacial.",
		Visual = { Texture = "singularity", Color = rgb(70, 20, 140), Material = "Neon", Atmosphere = rgb(170, 80, 255),
			Glow = rgb(170, 70, 255), Particles = "vortex",
			Rings = { { Inner = 1.3, Outer = 2.3, Color = rgb(190, 100, 255), Tilt = 10, Alpha = 0.35 },
				{ Inner = 2.45, Outer = 2.52, Color = rgb(255, 160, 255), Tilt = 10, Alpha = 0.1, Line = true } } },
	},
	---------------------------------------------------------------- CELESTIAL
	{
		Id = "solara", Name = "Solara", Rarity = "epic", Elements = { "celestial", "fire" }, TypeLabel = "Celestial",
		System = "celestial", Base = 95, Scale = 1.1, RotationSpeed = 15, OrbitSpeed = 1.0,
		Description = "Pequeña estrella domesticada: un mundo de luz blanca-dorada.",
		Visual = { Texture = "sun", Color = rgb(255, 215, 120), Material = "Neon", Atmosphere = rgb(255, 235, 170),
			Glow = rgb(255, 220, 130), Particles = "embers", Emissive = true },
	},
	{
		Id = "quantum", Name = "Quantum", Rarity = "legendary", Elements = { "quantum" }, TypeLabel = "Cuántico",
		System = "celestial", Base = 110, Scale = 1.15, RotationSpeed = 26, OrbitSpeed = 0.9,
		Description = "Planeta turquesa y magenta con anillos energéticos y apariencia cuántica.",
		Visual = { Texture = "quantum", Color = rgb(40, 200, 200), Material = "Glass", Atmosphere = rgb(90, 255, 240),
			Glow = rgb(255, 90, 220), Particles = "energy",
			Rings = { { Inner = 1.45, Outer = 1.53, Color = rgb(90, 255, 240), Tilt = 22, Alpha = 0.05, Line = true },
				{ Inner = 1.8, Outer = 1.9, Color = rgb(255, 100, 230), Tilt = 22, Alpha = 0.1, Line = true } } },
	},
	{
		Id = "seraphim", Name = "Seraphim", Rarity = "legendary", Elements = { "celestial" }, TypeLabel = "Celestial",
		System = "celestial", Base = 135, Scale = 1.2, RotationSpeed = 14, OrbitSpeed = 0.85,
		Description = "Mundo de mármol blanco y oro, rodeado por tres anillos ornamentales.",
		Visual = { Texture = "aureon", Tint = rgb(255, 245, 225), Color = rgb(250, 240, 215), Material = "Marble",
			Atmosphere = rgb(255, 240, 190), Glow = rgb(255, 230, 160),
			Rings = { { Inner = 1.4, Outer = 1.47, Color = rgb(255, 215, 120), Tilt = 0, Alpha = 0.05, Line = true },
				{ Inner = 1.65, Outer = 1.72, Color = rgb(255, 215, 120), Tilt = 55, Alpha = 0.05, Line = true },
				{ Inner = 1.9, Outer = 1.97, Color = rgb(255, 215, 120), Tilt = -55, Alpha = 0.05, Line = true } } },
	},
	{
		Id = "aurelia", Name = "Aurelia", Rarity = "mythic", Elements = { "celestial", "energy" }, TypeLabel = "Celestial / energía",
		System = "celestial", Base = 165, Scale = 1.25, RotationSpeed = 18, OrbitSpeed = 0.8,
		Description = "Corona viviente de oro líquido cuyo resplandor alimenta sistemas enteros.",
		Visual = { Texture = "sun", Tint = rgb(255, 190, 90), Color = rgb(255, 180, 60), Material = "Neon",
			Atmosphere = rgb(255, 215, 120), Glow = rgb(255, 200, 80), Particles = "energy", Emissive = true,
			Rings = { { Inner = 1.5, Outer = 2.4, Color = rgb(255, 225, 150), Tilt = 30, Alpha = 0.3 } } },
	},
	---------------------------------------------------------------- INFINITY
	{
		Id = "paradox", Name = "Paradox", Rarity = "mythic", Elements = { "quantum", "cosmic" }, TypeLabel = "Cuántico / cósmico",
		System = "infinity", Base = 185, Scale = 1.15, RotationSpeed = 30, OrbitSpeed = 1.1,
		Description = "Planeta que existe en dos dimensiones a la vez; sus anillos giran en sentidos imposibles.",
		Visual = { Texture = "quantum", Tint = rgb(190, 150, 255), Color = rgb(120, 80, 255), Material = "Glass",
			Atmosphere = rgb(120, 255, 255), Glow = rgb(150, 110, 255), Particles = "energy",
			Rings = { { Inner = 1.5, Outer = 1.58, Color = rgb(120, 255, 255), Tilt = 70, Alpha = 0.05, Line = true },
				{ Inner = 1.5, Outer = 1.58, Color = rgb(255, 110, 255), Tilt = -70, Alpha = 0.05, Line = true },
				{ Inner = 1.9, Outer = 1.98, Color = rgb(255, 255, 255), Tilt = 0, Alpha = 0.05, Line = true } } },
	},
	{
		Id = "infinitum", Name = "Infinitum", Rarity = "mythic", Elements = { "cosmic" }, TypeLabel = "Cósmico",
		System = "infinity", Base = 210, Scale = 1.35, RotationSpeed = 16, OrbitSpeed = 0.7,
		Description = "Una galaxia entera comprimida en un mundo: el premio de los coleccionistas pacientes.",
		Visual = { Texture = "singularity", Tint = rgb(170, 210, 255), Color = rgb(60, 90, 220), Material = "Neon",
			Atmosphere = rgb(160, 200, 255), Glow = rgb(140, 180, 255), Particles = "stardust",
			Rings = { { Inner = 1.4, Outer = 2.5, Color = rgb(170, 200, 255), Tilt = 12, Alpha = 0.35 } } },
	},
	{
		Id = "cryostar", Name = "Cryostar", Rarity = "secret", Elements = { "crystal", "ice" }, TypeLabel = "Cristal / hielo",
		System = "infinity", Base = 200, Scale = 1.1, RotationSpeed = 12, OrbitSpeed = 0.9,
		Description = "Planeta de cristal azul y blanco con fragmentos helados y brillo interno.",
		Visual = { Texture = "cryostar", Color = rgb(170, 225, 255), Material = "Ice", Atmosphere = rgb(200, 240, 255),
			Glow = rgb(170, 225, 255), Particles = "frost",
			Shards = { Count = 20, Color = rgb(205, 240, 255), Length = 0.7 },
			Rings = { { Inner = 1.7, Outer = 1.78, Color = rgb(210, 240, 255), Tilt = 16, Alpha = 0.1, Line = true } } },
		Secret = { Hint = "Tres mundos de hielo o cristal girando juntos en un mismo sistema despiertan algo frío...",
			Condition = { Type = "ElementsInSystem", Elements = { "ice", "crystal" }, Count = 3 } },
	},
	{
		Id = "volcanis", Name = "Volcanis", Rarity = "secret", Elements = { "fire" }, TypeLabel = "Volcánico",
		System = "infinity", Base = 220, Scale = 1.15, RotationSpeed = 14, OrbitSpeed = 1.0,
		Description = "Mundo volcánico avanzado con anillos ardientes y actividad extrema.",
		Visual = { Texture = "volcanis", Color = rgb(255, 90, 20), Material = "CrackedLava", Atmosphere = rgb(255, 110, 30),
			Glow = rgb(255, 100, 30), Particles = "embers",
			Rings = { { Inner = 1.45, Outer = 2.05, Color = rgb(255, 140, 50), Tilt = -16, Alpha = 0.3 } } },
		Secret = { Hint = "El fuego llama al fuego: reúne tres mundos de fuego en un mismo sistema, uno de ellos evolucionado.",
			Condition = { Type = "ElementsInSystem", Elements = { "fire" }, Count = 3, RequireEvolved = true } },
	},
	{
		Id = "zenith", Name = "Zenith", Rarity = "secret", Elements = { "energy" }, TypeLabel = "Energía",
		System = "infinity", Base = 250, Scale = 1.2, RotationSpeed = 20, OrbitSpeed = 0.85,
		Description = "Planeta cian de energía pura, atmósfera brillante y anillos delicados.",
		Visual = { Texture = "zenith", Color = rgb(60, 240, 220), Material = "Neon", Atmosphere = rgb(120, 255, 235),
			Glow = rgb(90, 255, 230), Particles = "energy", Emissive = true,
			Rings = { { Inner = 1.5, Outer = 1.57, Color = rgb(170, 255, 240), Tilt = 20, Alpha = 0.05, Line = true } } },
		Secret = { Hint = "Solo quien haya catalogado todos los mundos conocidos verá el cénit.",
			Condition = { Type = "DiscoverAllNonSecret" } },
	},
}

Planets.List = LIST
Planets.ById = {}
Planets.BySystem = {}
Planets.ByRarity = {}

for index, def in ipairs(LIST) do
	def.Order = index
	def.ModelKey = def.ModelKey or def.Id
	def.CollectionValue = def.CollectionValue or def.Base * 10
	def.VariantRules = def.VariantRules or ALL_VARIANTS
	Planets.ById[def.Id] = def
	if not Planets.BySystem[def.System] then Planets.BySystem[def.System] = {} end
	table.insert(Planets.BySystem[def.System], def)
	if not Planets.ByRarity[def.Rarity] then Planets.ByRarity[def.Rarity] = {} end
	table.insert(Planets.ByRarity[def.Rarity], def)
end

function Planets.get(id)
	return Planets.ById[id]
end

function Planets.hasElement(def, element)
	for _, e in ipairs(def.Elements) do
		if e == element then return true end
	end
	return false
end

-- Nombre visible de una instancia (evolucion y variante incluidas)
function Planets.displayName(def, evolved)
	if evolved then return def.Name .. " Prime" end
	return def.Name
end

-- Planetas no secretos de un sistema (los que cuentan para "completar la coleccion")
function Planets.collectionOf(systemId)
	local out = {}
	for _, def in ipairs(Planets.BySystem[systemId] or {}) do
		if def.Rarity ~= "secret" then table.insert(out, def) end
	end
	return out
end

Planets.ElementNames = {
	rocky = "Rocoso", desert = "Desértico", ice = "Hielo", gas = "Gaseoso", fire = "Fuego", crystal = "Cristal",
	celestial = "Celestial", cosmic = "Cósmico", dark = "Oscuro", quantum = "Cuántico", gravity = "Gravitacional",
	energy = "Energía", moon = "Luna",
}

return Planets
