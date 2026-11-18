-- PlanetPlacementService: valida slots y colocacion orbital. El cliente solo solicita; el servidor
-- comprueba propiedad, sistema activo, slot desbloqueado y estado, y replica la colocacion autorizada.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Progression = require(Shared.Progression)
local Net = require(script.Parent.Parent.Net)
local Config = Defs.Config
local Galaxy = Defs.Galaxy

local PlanetPlacementService = {}
local S = nil

local function afterChange(player, systemId)
	S.PlayerService.sync(player, "Placed", systemId)
	S.ProductionService.recalc(player)
	S.UniverseService.publish(player)
	S.DiscoveryService.checkSecrets(player)
end

local function equip(player, uid, systemId, slotIndex)
	local profile = S.PlayerService.profile(player)
	if not Galaxy.ById[systemId] or not profile.Systems[systemId] then return false, "Ese sistema no está desbloqueado." end
	if systemId ~= profile.ActiveSystem then return false, "Viaja a ese sistema antes de colocar planetas en él." end
	if slotIndex > (profile.Slots[systemId] or 0) then return false, "Ese slot orbital está bloqueado." end
	local inst = profile.Planets[uid]
	if not inst then return false, "Ese planeta no es tuyo." end
	if S.InventoryService.isBusy(player, uid) then return false, "Ese planeta está en un intercambio." end
	local slotKey = Galaxy.slotKey(slotIndex)
	local slots = profile.Placed[systemId]
	if slots[slotKey] == uid then return true, { Slot = slotIndex } end
	-- si ya estaba colocado en otro sitio, se mueve (una instancia nunca ocupa dos slots)
	local oldSystem, oldSlot = Progression.findPlaced(profile, uid)
	if oldSystem then
		profile.Placed[oldSystem][oldSlot] = nil
		if oldSystem ~= systemId then S.PlayerService.sync(player, "Placed", oldSystem) end
	end
	local replaced = slots[slotKey]
	slots[slotKey] = uid
	S.MissionService.progress(player, "PlacePlanets", 1)
	S.PlayerService.tutorialEvent(player, "place_planet")
	afterChange(player, systemId)
	return true, { Slot = slotIndex, Replaced = replaced }
end

local function unequip(player, systemId, slotIndex)
	local profile = S.PlayerService.profile(player)
	if not Galaxy.ById[systemId] or not profile.Systems[systemId] then return false, "Ese sistema no está desbloqueado." end
	local slotKey = Galaxy.slotKey(slotIndex)
	local slots = profile.Placed[systemId]
	if not slots[slotKey] then return false, "Ese slot ya está vacío." end
	slots[slotKey] = nil
	afterChange(player, systemId)
	return true
end

local function unlockSlot(player, systemId)
	local profile = S.PlayerService.profile(player)
	if not Galaxy.ById[systemId] or not profile.Systems[systemId] then return false, "Ese sistema no está desbloqueado." end
	local cost = Progression.nextSlotCost(profile, systemId)
	if not cost then return false, "Ya tienes los " .. Config.Economy.SlotsPerSystem .. " slots de este sistema." end
	if not S.EconomyService.spend(player, "Energy", cost, "slot:" .. systemId) then
		return false, "No tienes suficiente Energy."
	end
	profile.Slots[systemId] = profile.Slots[systemId] + 1
	S.PlayerService.sync(player, "Slots", systemId)
	S.UniverseService.publish(player)
	return true, { Slots = profile.Slots[systemId] }
end

-- Retira todos los planetas (usado por la ascension)
function PlanetPlacementService.clearAll(player)
	local profile = S.PlayerService.profile(player)
	for sysId in pairs(profile.Placed) do
		profile.Placed[sysId] = {}
	end
end

function PlanetPlacementService.Init(services)
	S = services
	local slotArg = { "integer", Min = 1, Max = Config.Economy.SlotsPerSystem }
	Net.handle("EquipPlanet", { Args = { { "string", Max = 16 }, { "string", Max = 16 }, slotArg }, Cooldown = 0.1 }, equip)
	Net.handle("UnequipPlanet", { Args = { { "string", Max = 16 }, slotArg }, Cooldown = 0.1 }, unequip)
	Net.handle("UnlockSlot", { Args = { { "string", Max = 16 } }, Cooldown = 0.2 }, unlockSlot)
end

function PlanetPlacementService.Start() end

return PlanetPlacementService
