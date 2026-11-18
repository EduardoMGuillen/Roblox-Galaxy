-- GalaxyDefinitions: los cinco sistemas, su tematica, multiplicador, slots y requisitos de desbloqueo.
-- Fuente de verdad para desbloqueos. Unlock es una lista de requisitos evaluados por Shared/Progression.
local Galaxy = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Coste de cada slot orbital (los 3 primeros son gratis al desbloquear el sistema)
local BASE_SLOT_COSTS = { 0, 0, 0, 2500, 12000, 60000, 250000, 1000000 }

local function slotCosts(factor)
	local out = {}
	for i, c in ipairs(BASE_SLOT_COSTS) do
		out[i] = c * factor
	end
	return out
end

local LIST = {
	{
		Id = "solar", Name = "Solar System", Subtitle = "Sistema inicial", Multiplier = 1,
		Description = "Estrella cálida, planetas rocosos y gigantes gaseosos. Aquí aprendes el bucle principal.",
		Introduces = "Tutorial, cápsulas Starter y Solar, planetas iniciales.",
		SlotCosts = slotCosts(1), FreeSlots = 3, Unlock = {},
		Theme = { Star = rgb(255, 214, 120), StarGlow = rgb(255, 190, 90), Orbit = rgb(90, 200, 255),
			Nebula = { rgb(40, 90, 200), rgb(30, 60, 160) }, Ambient = rgb(120, 130, 160), Accent = rgb(90, 200, 255) },
		Reward = { Stardust = 50, ProductionBonus = 0.05 },
	},
	{
		Id = "nebula", Name = "Nebula System", Subtitle = "Primer sistema avanzado", Multiplier = 4,
		Description = "Nebulosas azules y violetas, polvo estelar, cristales y lunas.",
		Introduces = "Cápsula Nebula, cristales, lunas y sinergias de elementos.",
		SlotCosts = slotCosts(15), FreeSlots = 3,
		Unlock = {
			{ Type = "Energy", Amount = 150000 },
			{ Type = "Collection", System = "solar", Count = 4 },
		},
		Theme = { Star = rgb(190, 150, 255), StarGlow = rgb(150, 110, 255), Orbit = rgb(170, 120, 255),
			Nebula = { rgb(120, 60, 220), rgb(60, 80, 230) }, Ambient = rgb(130, 115, 170), Accent = rgb(180, 120, 255) },
		Reward = { Stardust = 120, ProductionBonus = 0.05 },
	},
	{
		Id = "void", Name = "Void System", Subtitle = "Sistema oscuro", Multiplier = 20,
		Description = "Negros azulados, púrpuras profundos y un núcleo de gravedad en lugar de estrella.",
		Introduces = "Cápsula Galaxy, mundos oscuros, singularidades y combinaciones avanzadas.",
		SlotCosts = slotCosts(300), FreeSlots = 3,
		Unlock = {
			{ Type = "Energy", Amount = 30000000 },
			{ Type = "Collection", System = "nebula", Count = 4 },
			{ Type = "Placed", System = "nebula", Count = 5 },
		},
		Theme = { Star = rgb(25, 10, 45), StarGlow = rgb(150, 70, 255), Orbit = rgb(140, 80, 255),
			Nebula = { rgb(50, 20, 110), rgb(20, 20, 70) }, Ambient = rgb(95, 85, 135), Accent = rgb(150, 80, 255),
			BlackHole = true },
		Reward = { Stardust = 250, ProductionBonus = 0.05 },
	},
	{
		Id = "celestial", Name = "Celestial System", Subtitle = "Sistema de alta rareza", Multiplier = 100,
		Description = "Arquitectura dorada, estrella blanca-dorada, anillos elegantes y atmósferas luminosas.",
		Introduces = "Cápsula Cosmic, coleccionables dorados y efectos visuales premium.",
		SlotCosts = slotCosts(8000), FreeSlots = 3,
		Unlock = {
			{ Type = "Energy", Amount = 3000000000 },
			{ Type = "Collection", System = "void", Count = 4 },
			{ Type = "Production", Amount = 50000 },
		},
		Theme = { Star = rgb(255, 245, 215), StarGlow = rgb(255, 215, 120), Orbit = rgb(255, 215, 120),
			Nebula = { rgb(200, 150, 60), rgb(120, 90, 170) }, Ambient = rgb(165, 150, 125), Accent = rgb(255, 210, 110),
			Ornaments = true },
		Reward = { Stardust = 500, ProductionBonus = 0.05 },
	},
	{
		Id = "infinity", Name = "Infinity System", Subtitle = "Endgame", Multiplier = 500,
		Description = "Dimensiones superpuestas, portales múltiples y geometrías cósmicas imposibles pero legibles.",
		Introduces = "Cápsula Infinity, secretos y objetivos finales.",
		SlotCosts = slotCosts(300000), FreeSlots = 3,
		Unlock = {
			{ Type = "Energy", Amount = 250000000000 },
			{ Type = "Ascensions", Count = 3 },
			{ Type = "Discoveries", Count = 18 },
		},
		Theme = { Star = rgb(235, 225, 255), StarGlow = rgb(120, 255, 255), Orbit = rgb(120, 255, 255),
			Nebula = { rgb(40, 160, 200), rgb(140, 60, 220) }, Ambient = rgb(125, 145, 175), Accent = rgb(120, 255, 255),
			Portals = true },
		Reward = { Stardust = 1000, ProductionBonus = 0.1 },
	},
}

Galaxy.List = LIST
Galaxy.ById = {}
Galaxy.Order = {}
for index, def in ipairs(LIST) do
	def.Order = index
	Galaxy.ById[def.Id] = def
	Galaxy.Order[index] = def.Id
end

function Galaxy.get(id)
	return Galaxy.ById[id]
end

function Galaxy.slotKey(index)
	return "s" .. tostring(index)
end

return Galaxy
