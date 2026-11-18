-- DiscoveryService: Collection Index, recompensas por completar colecciones y descubrimientos secretos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Progression = require(Shared.Progression)

local DiscoveryService = {}
local S = nil

-- Registra un planeta obtenido. Devuelve { NewPlanet, NewVariant }.
function DiscoveryService.register(player, planetId, variant, evolved)
	local profile = S.PlayerService.profile(player)
	local result = { NewPlanet = false, NewVariant = false }
	if not profile then return result end
	if not profile.Discovered[planetId] then
		profile.Discovered[planetId] = true
		result.NewPlanet = true
		S.PlayerService.sync(player, "Discovered", planetId)
	end
	local key = Progression.discoveryKey(planetId, variant, evolved)
	if key ~= planetId and not profile.Discovered[key] then
		profile.Discovered[key] = true
		result.NewVariant = true
		S.PlayerService.sync(player, "Discovered", key)
	end
	if result.NewPlanet then
		DiscoveryService.checkCollections(player)
	end
	return result
end

-- Entrega la recompensa de cada coleccion de sistema completada (una sola vez).
function DiscoveryService.checkCollections(player)
	local profile = S.PlayerService.profile(player)
	local changed = false
	for _, sysId in ipairs(Defs.Galaxy.Order) do
		if not profile.CollectionsClaimed[sysId] and Progression.collectionComplete(profile, sysId) then
			local def = Defs.Galaxy.ById[sysId]
			profile.CollectionsClaimed[sysId] = true
			S.PlayerService.sync(player, "CollectionsClaimed", sysId)
			S.EconomyService.add(player, "Stardust", def.Reward.Stardust, "collection:" .. sysId)
			S.PlayerService.notify(player, "collection", "¡Colección " .. def.Name .. " completada! +" .. def.Reward.Stardust
				.. " Stardust y +" .. math.floor(def.Reward.ProductionBonus * 100) .. "% de producción permanente")
			changed = true
		end
	end
	if changed then
		S.ProductionService.recalc(player)
	end
end

-- Comprueba las condiciones de los secretos y entrega el planeta la primera vez que se cumplen.
function DiscoveryService.checkSecrets(player)
	local profile = S.PlayerService.profile(player)
	if not profile then return end
	for _, def in ipairs(Defs.Planets.List) do
		if def.Secret and not profile.SecretsFound[def.Id] and Progression.secretConditionMet(profile, def.Secret.Condition) then
			profile.SecretsFound[def.Id] = true
			S.PlayerService.sync(player, "SecretsFound", def.Id)
			local uid = S.InventoryService.add(player, def.Id, "none", "secret", true)
			if uid then
				S.PlayerService.notify(player, "secret", "¡DESCUBRIMIENTO SECRETO! Has encontrado " .. def.Name,
					{ PlanetId = def.Id, Uid = uid })
			end
		end
	end
end

function DiscoveryService.Init(services)
	S = services
end

function DiscoveryService.Start() end

return DiscoveryService
