-- MissionDefinitions: plantillas de misiones diarias y semanales. Las metas escalan con el progreso (tier).
-- Goal(tier, production) y Reward(tier, production) devuelven numeros; el servidor los fija al generar la mision.
local Missions = {}

Missions.DailyCount = 3
Missions.WeeklyCount = 3

Missions.Templates = {
	{ Id = "open_capsules", Type = "OpenCapsules", Scope = "daily", Text = "Abre %s cápsulas",
		Goal = function(tier) return 10 + 5 * tier end, Stardust = function(tier) return 10 + 3 * tier end },
	{ Id = "obtain_rare", Type = "ObtainRare", Scope = "daily", Text = "Consigue %s planetas Raros o superiores",
		Goal = function(tier) return 3 + tier end, Stardust = function(tier) return 12 + 3 * tier end },
	{ Id = "earn_energy", Type = "EarnEnergy", Scope = "daily", Text = "Genera %s de Energy",
		Goal = function(tier, production) return math.max(2000, math.floor(production * 600)) end,
		Stardust = function(tier) return 10 + 3 * tier end },
	{ Id = "place_planets", Type = "PlacePlanets", Scope = "daily", Text = "Coloca %s planetas en órbita",
		Goal = function(tier) return 3 + tier end, Stardust = function(tier) return 8 + 2 * tier end },
	{ Id = "buy_upgrades", Type = "BuyUpgrades", Scope = "daily", Text = "Compra %s mejoras",
		Goal = function(tier) return 3 + tier end, Stardust = function(tier) return 8 + 2 * tier end },
	{ Id = "visit_universe", Type = "VisitUniverse", Scope = "daily", Text = "Visita %s universo de otro jugador",
		Goal = function() return 1 end, Stardust = function(tier) return 10 + 2 * tier end },
	{ Id = "sell_planets", Type = "SellPlanets", Scope = "daily", Text = "Vende %s planetas duplicados",
		Goal = function(tier) return 5 + 2 * tier end, Stardust = function(tier) return 8 + 2 * tier end },
	{ Id = "w_open_capsules", Type = "OpenCapsules", Scope = "weekly", Text = "Abre %s cápsulas esta semana",
		Goal = function(tier) return 100 + 50 * tier end, Stardust = function(tier) return 60 + 15 * tier end },
	{ Id = "w_earn_energy", Type = "EarnEnergy", Scope = "weekly", Text = "Genera %s de Energy esta semana",
		Goal = function(tier, production) return math.max(50000, math.floor(production * 7200)) end,
		Stardust = function(tier) return 60 + 15 * tier end },
	{ Id = "w_evolve", Type = "EvolvePlanet", Scope = "weekly", Text = "Evoluciona %s planeta a su forma Prime",
		Goal = function() return 1 end, Stardust = function(tier) return 80 + 15 * tier end },
	{ Id = "w_trade", Type = "CompleteTrade", Scope = "weekly", Text = "Completa %s intercambio en el Galactic Market",
		Goal = function() return 1 end, Stardust = function(tier) return 50 + 10 * tier end },
	{ Id = "w_event", Type = "EventParticipation", Scope = "weekly", Text = "Completa %s objetivo de evento cósmico",
		Goal = function() return 1 end, Stardust = function(tier) return 70 + 15 * tier end },
	{ Id = "w_obtain_epic", Type = "ObtainEpic", Scope = "weekly", Text = "Consigue %s planetas Épicos o superiores",
		Goal = function(tier) return 3 + 2 * tier end, Stardust = function(tier) return 70 + 15 * tier end },
}

Missions.ById = {}
Missions.ByScope = { daily = {}, weekly = {} }
for _, t in ipairs(Missions.Templates) do
	Missions.ById[t.Id] = t
	table.insert(Missions.ByScope[t.Scope], t)
end

-- Recompensa de Energy de una mision (segundos de produccion), para que escale con el progreso
Missions.EnergyRewardSeconds = { daily = 120, weekly = 900 }

return Missions
