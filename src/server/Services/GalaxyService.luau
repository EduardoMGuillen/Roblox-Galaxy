-- GalaxyService: desbloqueo de sistemas y cambio de sistema activo (validados en servidor).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Progression = require(Shared.Progression)
local Net = require(script.Parent.Parent.Net)
local Galaxy = Defs.Galaxy

local GalaxyService = {}
local S = nil

local function unlockSystem(player, systemId)
	local profile = S.PlayerService.profile(player)
	local def = Galaxy.ById[systemId]
	if not def then return false, "Sistema desconocido." end
	if profile.Systems[systemId] then return false, "Ya tienes ese sistema." end
	local state = Progression.systemState(profile, systemId, S.ProductionService.rate(player))
	if state ~= "ready" then return false, "Aún no cumples los requisitos." end
	local cost = Progression.systemEnergyCost(systemId)
	if cost > 0 and not S.EconomyService.spend(player, "Energy", cost, "system:" .. systemId) then
		return false, "No tienes suficiente Energy."
	end
	profile.Systems[systemId] = true
	profile.Placed[systemId] = {}
	profile.Slots[systemId] = def.FreeSlots
	S.PlayerService.sync(player, "Systems", systemId)
	S.PlayerService.sync(player, "Placed", systemId)
	S.PlayerService.sync(player, "Slots", systemId)
	S.MissionService.refresh(player)
	S.ProductionService.recalc(player)
	S.PlayerService.notify(player, "system", "¡" .. def.Name .. " desbloqueado! " .. def.Introduces)
	return true, { System = systemId }
end

local function setActiveSystem(player, systemId)
	local profile = S.PlayerService.profile(player)
	if not Galaxy.ById[systemId] or not profile.Systems[systemId] then
		return false, "Ese sistema no está desbloqueado."
	end
	if profile.ActiveSystem ~= systemId then
		profile.ActiveSystem = systemId
		S.PlayerService.sync(player, "ActiveSystem")
		S.UniverseService.publish(player)
	end
	return true, { System = systemId }
end

function GalaxyService.Init(services)
	S = services
	Net.handle("UnlockSystem", { Args = { { "string", Max = 16 } }, Cooldown = 0.5 }, unlockSystem)
	Net.handle("SetActiveSystem", { Args = { { "string", Max = 16 } }, Cooldown = 0.3 }, setActiveSystem)
end

function GalaxyService.Start() end

return GalaxyService
