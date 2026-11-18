-- InventoryService: propiedad de instancias de planetas, limites, venta, bloqueo, evolucion y transferencias.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Progression = require(Shared.Progression)
local Net = require(script.Parent.Parent.Net)
local Config = Defs.Config

local InventoryService = {}
local S = nil

function InventoryService.hasSpace(player, count)
	local profile = S.PlayerService.profile(player)
	return Progression.inventoryCount(profile) + (count or 1) <= Progression.inventoryCapacity(profile)
end

-- Crea una instancia nueva. ignoreCapacity se usa solo para recompensas garantizadas (secretos).
-- Devuelve uid, discovery  |  nil
function InventoryService.add(player, planetId, variant, source, ignoreCapacity, evolved)
	local profile = S.PlayerService.profile(player)
	local def = Defs.Planets.ById[planetId]
	if not profile or not def then return nil end
	variant = variant or "none"
	if not Defs.Variants.ById[variant] then variant = "none" end
	if not ignoreCapacity and not InventoryService.hasSpace(player, 1) then return nil end
	local uid = "p" .. tostring(profile.NextUid)
	profile.NextUid = profile.NextUid + 1
	profile.Planets[uid] = { Id = planetId, V = variant, E = evolved == true, L = false }
	S.PlayerService.sync(player, "Planets", uid)
	profile.Stats.PlanetsObtained = profile.Stats.PlanetsObtained + 1
	if Defs.Rarities.atLeast(def.Rarity, "rare") then
		profile.Stats.RaresObtained = profile.Stats.RaresObtained + 1
	end
	local discovery = S.DiscoveryService.register(player, planetId, variant, evolved == true)
	return uid, discovery
end

-- true si la instancia no se puede vender/mover/consumir ahora mismo
function InventoryService.isBusy(player, uid)
	local session = S.PlayerService.get(player)
	return session ~= nil and session.Busy[uid] == true
end

function InventoryService.remove(player, uid)
	local profile = S.PlayerService.profile(player)
	if not profile or not profile.Planets[uid] then return false end
	profile.Planets[uid] = nil
	S.PlayerService.sync(player, "Planets", uid)
	return true
end

local function sell(player, uids)
	local profile = S.PlayerService.profile(player)
	local seen = {}
	local total, count = 0, 0
	-- validar todo antes de modificar nada
	for _, uid in ipairs(uids) do
		local inst = profile.Planets[uid]
		if not inst then return false, "Uno de los planetas ya no existe." end
		if seen[uid] then return false, "Selección duplicada." end
		seen[uid] = true
		if inst.L then return false, "No puedes vender planetas bloqueados." end
		if InventoryService.isBusy(player, uid) then return false, "Ese planeta está en un intercambio." end
		if Progression.findPlaced(profile, uid) then return false, "Retira el planeta de su órbita antes de venderlo." end
		total = total + Progression.sellValue(inst)
		count = count + 1
	end
	if count == 0 then return false, "No hay nada que vender." end
	for uid in pairs(seen) do
		InventoryService.remove(player, uid)
	end
	S.EconomyService.add(player, "Energy", total, "sell", true)
	profile.Stats.PlanetsSold = profile.Stats.PlanetsSold + count
	S.MissionService.progress(player, "SellPlanets", count)
	return true, { Energy = total, Count = count }
end

local function lock(player, uid, value)
	local profile = S.PlayerService.profile(player)
	local inst = profile.Planets[uid]
	if not inst then return false, "Ese planeta no existe." end
	if InventoryService.isBusy(player, uid) then return false, "Ese planeta está en un intercambio." end
	inst.L = value
	S.PlayerService.sync(player, "Planets", uid)
	return true
end

local function evolve(player, uid)
	local session = S.PlayerService.get(player)
	local profile = session.Profile
	local inst = profile.Planets[uid]
	if not inst then return false, "Ese planeta no existe." end
	if inst.E then return false, "Ese planeta ya está evolucionado." end
	if InventoryService.isBusy(player, uid) then return false, "Ese planeta está en un intercambio." end
	local def = Defs.Planets.ById[inst.Id]
	local cost = Progression.evolutionCost(def)
	local fodder = Progression.evolutionFodder(profile, uid, session.Busy)
	if #fodder < cost.Copies then
		return false, "Necesitas " .. cost.Copies .. " copias normales de " .. def.Name .. " (sin variante, sin colocar y sin bloquear)."
	end
	if not S.EconomyService.canAfford(player, "Energy", cost.Energy) then return false, "No tienes suficiente Energy." end
	if not S.EconomyService.canAfford(player, "Stardust", cost.Stardust) then return false, "No tienes suficiente Stardust." end
	S.EconomyService.spend(player, "Energy", cost.Energy, "evolve")
	S.EconomyService.spend(player, "Stardust", cost.Stardust, "evolve")
	for i = 1, cost.Copies do
		InventoryService.remove(player, fodder[i])
	end
	inst.E = true
	S.PlayerService.sync(player, "Planets", uid)
	profile.Stats.Evolutions = profile.Stats.Evolutions + 1
	local discovery = S.DiscoveryService.register(player, inst.Id, inst.V, true)
	S.MissionService.progress(player, "EvolvePlanet", 1)
	if Progression.findPlaced(profile, uid) then
		S.ProductionService.recalc(player)
		S.UniverseService.publish(player)
	end
	S.DiscoveryService.checkSecrets(player)
	return true, { Uid = uid, New = discovery.NewVariant }
end

-- Transfiere instancias entre dos jugadores (usado por TradingService tras revalidar).
-- Devuelve la lista de uids nuevos en el receptor.
function InventoryService.transfer(fromPlayer, toPlayer, uids)
	local fromProfile = S.PlayerService.profile(fromPlayer)
	local created = {}
	for _, uid in ipairs(uids) do
		local inst = fromProfile.Planets[uid]
		InventoryService.remove(fromPlayer, uid)
		local newUid = InventoryService.add(toPlayer, inst.Id, inst.V, "trade", true, inst.E)
		table.insert(created, newUid)
	end
	return created
end

function InventoryService.Init(services)
	S = services
	Net.handle("SellPlanets", { Args = { { "stringList", Max = 200, MaxLength = 16 } }, Cooldown = 0.3 }, sell)
	Net.handle("LockPlanet", { Args = { { "string", Max = 16 }, { "boolean" } }, Cooldown = 0.1 }, lock)
	Net.handle("EvolvePlanet", { Args = { { "string", Max = 16 } }, Cooldown = 0.5 }, evolve)
end

function InventoryService.Start() end

return InventoryService
