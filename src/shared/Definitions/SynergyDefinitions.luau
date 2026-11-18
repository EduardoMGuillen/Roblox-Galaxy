-- SynergyDefinitions: condiciones y bonificaciones declarativas.
-- Regla: las sinergias se evaluan POR SISTEMA sobre los planetas colocados en el; sus bonos se suman
-- entre si (aditivo) y multiplican la produccion de ese sistema. Sin acumulaciones ambiguas: cada
-- sinergia se aplica como maximo una vez por sistema.
local Synergies = {}

Synergies.List = {
	{ Id = "fire_duo", Name = "Dúo de Fuego", Bonus = 0.10, Description = "2 planetas de fuego en el mismo sistema.",
		Condition = { Type = "Element", Element = "fire", Count = 2 } },
	{ Id = "ice_trio", Name = "Trío Glacial", Bonus = 0.15, Description = "3 planetas de hielo o cristal en el mismo sistema.",
		Condition = { Type = "AnyElement", Elements = { "ice", "crystal" }, Count = 3 } },
	{ Id = "rocky_trio", Name = "Cinturón Rocoso", Bonus = 0.10, Description = "3 planetas rocosos o desérticos.",
		Condition = { Type = "AnyElement", Elements = { "rocky", "desert" }, Count = 3 } },
	{ Id = "gas_duo", Name = "Gigantes Gemelos", Bonus = 0.10, Description = "2 gigantes gaseosos.",
		Condition = { Type = "Element", Element = "gas", Count = 2 } },
	{ Id = "legend_moons", Name = "Corte Lunar", Bonus = 0.20, Description = "1 planeta Legendario (o superior) con 2 lunas.",
		Condition = { Type = "RarityWithElement", Rarity = "legendary", Element = "moon", Count = 2 } },
	{ Id = "dark_trio", Name = "Eclipse Total", Bonus = 0.18, Description = "3 mundos oscuros.",
		Condition = { Type = "Element", Element = "dark", Count = 3 } },
	{ Id = "celestial_trio", Name = "Coro Celestial", Bonus = 0.20, Description = "3 mundos celestiales.",
		Condition = { Type = "Element", Element = "celestial", Count = 3 } },
	{ Id = "quantum_link", Name = "Entrelazamiento", Bonus = 0.15, Description = "2 mundos cuánticos o cósmicos.",
		Condition = { Type = "AnyElement", Elements = { "quantum", "cosmic" }, Count = 2 } },
	{ Id = "diversity", Name = "Biodiversidad Cósmica", Bonus = 0.15, Description = "5 elementos distintos en el mismo sistema.",
		Condition = { Type = "DistinctElements", Count = 5 } },
	{ Id = "full_orbit", Name = "Órbitas Completas", Bonus = 0.25, Description = "Los 8 slots del sistema ocupados.",
		Condition = { Type = "FullOrbit" } },
	{ Id = "variant_trio", Name = "Constelación Brillante", Bonus = 0.15, Description = "3 planetas con variante (Shiny, Golden, Rainbow o Cosmic).",
		Condition = { Type = "Variants", Count = 3 } },
	{ Id = "prime_duo", Name = "Linaje Prime", Bonus = 0.20, Description = "2 planetas evolucionados (Prime).",
		Condition = { Type = "Evolved", Count = 2 } },
}

Synergies.ById = {}
for _, s in ipairs(Synergies.List) do
	Synergies.ById[s.Id] = s
end

return Synergies
