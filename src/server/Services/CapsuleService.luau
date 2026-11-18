-- CapsuleService: compra y apertura de capsulas. La tirada aleatoria ocurre SOLO en el servidor.
-- El cliente pide abrir una capsula por id; el servidor valida precio, saldo, desbloqueo, cooldown e
-- inventario, descuenta Energy, genera el resultado y entrega el planeta. El cliente solo anima.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Progression = require(Shared.Progression)
local Net = require(script.Parent.Parent.Net)
local Config = Defs.Config

local CapsuleService = {}
local S = nil
local rng = Random.new()

local function batchAllowed(profile, count)
	if count > Progression.maxBatch(profile) then return false end
	for _, size in ipairs(Config.Capsules.BatchSizes) do
		if size == count then return true end
	end
	return false
end

local function open(player, capsuleId, count)
	local session = S.PlayerService.get(player)
	local profile = session.Profile
	local def = Defs.Capsules.ById[capsuleId]
	if not def then return false, "Cápsula desconocida." end
	if not profile.Systems[def.RequiresSystem] then
		return false, "Desbloquea " .. Defs.Galaxy.ById[def.RequiresSystem].Name .. " para usar esta cápsula."
	end
	if not batchAllowed(profile, count) then return false, "Cantidad no permitida." end
	local now = os.clock()
	if now - session.LastCapsule < Config.Capsules.CooldownSeconds then
		return false, "La máquina se está recargando."
	end
	if not S.InventoryService.hasSpace(player, count) then
		return false, "Inventario lleno. Vende planetas o mejora el Hangar Orbital."
	end
	local price = Progression.capsulePrice(profile, def, S.EventService.capsuleDiscount()) * count
	if not S.EconomyService.spend(player, "Energy", price, "capsule:" .. capsuleId) then
		return false, "No tienes suficiente Energy."
	end
	session.LastCapsule = now

	local luck = Progression.variantLuck(profile, S.EventService.variantLuck())
	local results = {}
	local rares, epics = 0, 0
	for _ = 1, count do
		local planetId, rarity = Defs.Capsules.roll(def, Defs.Rarities.Order, rng:NextNumber(), rng:NextNumber())
		local variant = Defs.Variants.roll(rng:NextNumber(), luck)
		local uid, discovery = S.InventoryService.add(player, planetId, variant, "capsule:" .. capsuleId)
		table.insert(results, { Uid = uid, Id = planetId, V = variant, Rarity = rarity,
			New = discovery.NewPlanet, NewVariant = discovery.NewVariant })
		if Defs.Rarities.atLeast(rarity, "rare") then rares = rares + 1 end
		if Defs.Rarities.atLeast(rarity, "epic") then epics = epics + 1 end
	end
	profile.Stats.CapsulesOpened = profile.Stats.CapsulesOpened + count
	S.PlayerService.sync(player, "Stats", "CapsulesOpened")
	S.MissionService.progress(player, "OpenCapsules", count)
	if rares > 0 then S.MissionService.progress(player, "ObtainRare", rares) end
	if epics > 0 then S.MissionService.progress(player, "ObtainEpic", epics) end
	S.PlayerService.tutorialEvent(player, "open_capsule")
	S.DiscoveryService.checkSecrets(player)
	return true, { Results = results, Spent = price, Capsule = capsuleId }
end

function CapsuleService.Init(services)
	S = services
	Net.handle("OpenCapsule", { Args = { { "string", Max = 24 }, { "integer", Min = 1, Max = 10 } }, Cooldown = 0.25 }, open)
end

function CapsuleService.Start() end

return CapsuleService
