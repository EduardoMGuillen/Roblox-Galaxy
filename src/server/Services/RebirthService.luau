-- RebirthService: Galactic Ascension. Valida el requisito del siguiente hito, reinicia la progresion
-- seleccionada y entrega multiplicador permanente + Cosmic Cores. El reinicio se hace en memoria sin
-- esperas intermedias (atomico) y se guarda inmediatamente despues.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Progression = require(Shared.Progression)
local Net = require(script.Parent.Parent.Net)

local RebirthService = {}
local S = nil

local function rebirth(player, confirmed)
	if not confirmed then return false, "La ascensión requiere confirmación." end
	local session = S.PlayerService.get(player)
	local profile = session.Profile
	if S.TradingService.isTrading(player) then return false, "Termina tu intercambio antes de ascender." end
	local milestone = Defs.Ascension.next(profile.Ascensions)
	for _, requirement in ipairs(milestone.Requirements) do
		local check = Progression.checkRequirement(profile, requirement, S.ProductionService.rate(player))
		if not check.Ok then return false, "Aún no cumples el requisito: " .. check.Text end
	end

	-- reinicio atomico (sin yields)
	profile.Ascensions = milestone.Index
	profile.Cores = profile.Cores + milestone.Cores
	profile.RunEnergy = 0
	for id, _ in pairs(profile.Upgrades) do
		if Defs.Upgrades.ById[id].Currency == "Energy" then
			profile.Upgrades[id] = nil
		end
	end
	profile.Energy = Progression.startingEnergy(profile)
	profile.Systems = { solar = true }
	profile.Placed = { solar = {} }
	profile.Slots = { solar = Defs.Galaxy.ById.solar.FreeSlots }
	profile.ActiveSystem = "solar"

	for _, key in ipairs({ "Ascensions", "Cores", "RunEnergy", "Upgrades", "Energy", "Systems", "Placed", "Slots", "ActiveSystem" }) do
		S.PlayerService.sync(player, key)
	end
	S.MissionService.refresh(player)
	S.ProductionService.recalc(player)
	S.UniverseService.publish(player)
	S.PlayerService.updateLeaderstats(player)
	task.spawn(S.DataService.save, player, false)
	return true, { Ascensions = milestone.Index, Multiplier = milestone.Multiplier, Cores = milestone.Cores }
end

function RebirthService.Init(services)
	S = services
	Net.handle("Rebirth", { Args = { { "boolean" } }, Cooldown = 2 }, rebirth)
end

function RebirthService.Start() end

return RebirthService
