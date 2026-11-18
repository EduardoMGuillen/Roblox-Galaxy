-- ProductionService: calcula y cachea la produccion agregada de cada jugador (con desglose).
-- Solo se recalcula cuando cambia algo relevante (colocacion, mejoras, ascension, evento...).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Progression)

local ProductionService = {}
local S = nil

function ProductionService.recalc(player)
	local session = S.PlayerService.get(player)
	if not session then return nil end
	local production = Progression.production(session.Profile, S.EventService.productionMultiplier())
	S.PlayerService.setDerived(player, "_Production", production)
	return production
end

function ProductionService.rate(player)
	local session = S.PlayerService.get(player)
	local production = session and session.Derived._Production
	return production and production.Total or 0
end

function ProductionService.recalcAll()
	for player in pairs(S.PlayerService.all()) do
		ProductionService.recalc(player)
	end
end

function ProductionService.Init(services)
	S = services
	S.PlayerService.onLoaded(function(player)
		ProductionService.recalc(player)
	end)
end

function ProductionService.Start() end

return ProductionService
