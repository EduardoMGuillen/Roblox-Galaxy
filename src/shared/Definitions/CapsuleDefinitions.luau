-- CapsuleDefinitions: capsulas, precios, requisitos y tablas de probabilidad REALES.
-- Odds: probabilidad por rareza (suma exacta 100). Pools: planetas posibles por rareza (reparto uniforme).
-- Las capsulas solo se compran con Energy ganada jugando.
local Capsules = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local LIST = {
	{
		Id = "starter", Name = "Starter Capsule", Price = 100, RequiresSystem = "solar",
		Description = "Cápsula inicial: colección común y poco común.",
		Color = rgb(60, 220, 255), CoreColor = rgb(80, 160, 255),
		Odds = { common = 70, uncommon = 30 },
		Pools = { common = { "terra", "rocanox" }, uncommon = { "dunaris", "glaciera" } },
	},
	{
		Id = "solar", Name = "Solar Capsule", Price = 1000, RequiresSystem = "solar",
		Description = "Sistema Solar: comunes, poco comunes y raros.",
		Color = rgb(70, 130, 255), CoreColor = rgb(120, 180, 255),
		Odds = { common = 40, uncommon = 38, rare = 22 },
		Pools = { common = { "terra", "rocanox" }, uncommon = { "dunaris", "glaciera" }, rare = { "jovian", "inferno" } },
	},
	{
		Id = "nebula", Name = "Nebula Capsule", Price = 10000, RequiresSystem = "nebula",
		Description = "Nebula: lunas, raros y épicos.",
		Color = rgb(170, 90, 255), CoreColor = rgb(210, 140, 255),
		Odds = { uncommon = 25, rare = 50, epic = 25 },
		Pools = { uncommon = { "lunaris" }, rare = { "amethyst", "selene" }, epic = { "aureon", "nebulon" } },
	},
	{
		Id = "galaxy", Name = "Galaxy Capsule", Price = 100000, RequiresSystem = "void",
		Description = "Sistemas avanzados: épicos y legendarios del Void.",
		Color = rgb(110, 100, 255), CoreColor = rgb(160, 120, 255),
		Odds = { rare = 33, epic = 45, legendary = 20, mythic = 2 },
		Pools = { rare = { "noctis" }, epic = { "umbra" }, legendary = { "shadowra", "eclipsa" }, mythic = { "singularity" } },
	},
	{
		Id = "cosmic", Name = "Cosmic Capsule", Price = 1000000, RequiresSystem = "celestial",
		Description = "Contenido avanzado: legendarios y míticos celestiales.",
		Color = rgb(255, 80, 200), CoreColor = rgb(255, 200, 90),
		Odds = { epic = 45, legendary = 45, mythic = 10 },
		Pools = { epic = { "solara" }, legendary = { "quantum", "seraphim" }, mythic = { "aurelia", "singularity" } },
	},
	{
		Id = "infinity", Name = "Infinity Capsule", Price = 100000000, RequiresSystem = "infinity",
		Description = "Endgame: míticos y descubrimientos secretos.",
		Color = rgb(230, 220, 255), CoreColor = rgb(190, 150, 255),
		Odds = { legendary = 50, mythic = 47, secret = 3 },
		Pools = { legendary = { "quantum", "seraphim", "shadowra", "eclipsa" },
			mythic = { "paradox", "infinitum", "aurelia", "singularity" },
			secret = { "cryostar", "volcanis", "zenith" } },
	},
}

Capsules.List = LIST
Capsules.ById = {}
for index, def in ipairs(LIST) do
	def.Order = index
	Capsules.ById[def.Id] = def
end

function Capsules.get(id)
	return Capsules.ById[id]
end

-- Lista ordenada de { Rarity, Chance (0-1), Planets } para mostrar en la UI y para tirar en servidor.
function Capsules.oddsList(def, rarityOrder)
	local out = {}
	for _, rarityId in ipairs(rarityOrder) do
		local pct = def.Odds[rarityId]
		if pct then
			table.insert(out, { Rarity = rarityId, Chance = pct / 100, Planets = def.Pools[rarityId] })
		end
	end
	return out
end

-- Elige rareza y planeta con dos numeros aleatorios uniformes en [0,1) generados por el SERVIDOR.
function Capsules.roll(def, rarityOrder, randomRarity, randomPlanet)
	local list = Capsules.oddsList(def, rarityOrder)
	local acc = 0
	local chosen = list[#list]
	for _, entry in ipairs(list) do
		acc = acc + entry.Chance
		if randomRarity < acc then
			chosen = entry
			break
		end
	end
	local pool = chosen.Planets
	local index = math.min(#pool, math.floor(randomPlanet * #pool) + 1)
	return pool[index], chosen.Rarity
end

return Capsules
