-- AscensionDefinitions: Galactic Ascension (prestigio). Hitos 1-5 segun el manual; despues, formula.
local Ascension = {}

-- Cada hito combina el requisito del manual con una cantidad de Energy generada en la ascension
-- actual (RunEnergy), para que entre ascensiones siempre haya una partida real.
Ascension.Milestones = {
	{ Requirements = { { Type = "PlanetsOwned", Count = 10 }, { Type = "RunEnergy", Amount = 500000 } }, Multiplier = 2, Cores = 3 },
	{ Requirements = { { Type = "RarityOwned", Rarity = "legendary", Count = 1 }, { Type = "RunEnergy", Amount = 150000000 } }, Multiplier = 3, Cores = 5 },
	{ Requirements = { { Type = "CollectionComplete", System = "solar" }, { Type = "RunEnergy", Amount = 10000000000 } }, Multiplier = 5, Cores = 8 },
	{ Requirements = { { Type = "RarityOwned", Rarity = "legendary", Count = 3 }, { Type = "RunEnergy", Amount = 400000000000 } }, Multiplier = 8, Cores = 12 },
	{ Requirements = { { Type = "CollectionComplete", System = "nebula" }, { Type = "RunEnergy", Amount = 20000000000000 } }, Multiplier = 12, Cores = 20 },
}

-- Datos del hito para pasar de `current` ascensiones a current + 1
function Ascension.next(current)
	local n = current + 1
	local m = Ascension.Milestones[n]
	if m then
		return { Index = n, Requirements = m.Requirements, Multiplier = m.Multiplier, Cores = m.Cores }
	end
	local extra = n - #Ascension.Milestones
	return {
		Index = n,
		Requirements = { { Type = "RunEnergy", Amount = 4e14 * 20 ^ (extra - 1) } },
		Multiplier = 12 + 5 * extra,
		Cores = 20 + 5 * extra,
	}
end

-- Multiplicador permanente de produccion con `count` ascensiones
function Ascension.multiplier(count)
	if count <= 0 then return 1 end
	local m = Ascension.Milestones[count]
	if m then return m.Multiplier end
	return 12 + 5 * (count - #Ascension.Milestones)
end

Ascension.Resets = {
	"Energy actual",
	"Mejoras compradas con Energy",
	"Sistemas desbloqueados (vuelves a Solar)",
	"Slots orbitales comprados",
	"Planetas colocados (vuelven al inventario)",
}

Ascension.Keeps = {
	"Todos tus planetas e inventario",
	"Collection Index y descubrimientos",
	"Stardust y Cosmic Cores",
	"Mejoras de núcleo permanentes",
	"Cosméticos, misiones y estadísticas",
}

return Ascension
