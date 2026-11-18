-- Progression: funciones puras sobre un perfil (produccion, sinergias, requisitos, costes).
-- Se usa en el servidor (autoridad) y en el cliente (solo para mostrar previsiones y progreso).
local Defs = require(script.Parent.Defs)
local Format = require(script.Parent.Util.Format)
local Config = Defs.Config
local Planets, Galaxy, Upgrades, Variants, Rarities = Defs.Planets, Defs.Galaxy, Defs.Upgrades, Defs.Variants, Defs.Rarities

local Progression = {}

---------------------------------------------------------------- inventario
function Progression.inventoryCount(profile)
	local n = 0
	for _ in pairs(profile.Planets) do
		n = n + 1
	end
	return n
end

function Progression.inventoryCapacity(profile)
	return Config.Economy.InventoryBaseCapacity + Upgrades.effect(profile, "hangar")
end

-- Devuelve systemId, slotKey si la instancia esta colocada
function Progression.findPlaced(profile, uid)
	for sysId, slots in pairs(profile.Placed) do
		for slotKey, placedUid in pairs(slots) do
			if placedUid == uid then return sysId, slotKey end
		end
	end
	return nil, nil
end

function Progression.placedCount(profile, systemId)
	local n = 0
	local slots = profile.Placed[systemId]
	if slots then
		for _ in pairs(slots) do
			n = n + 1
		end
	end
	return n
end

function Progression.countOwned(profile, predicate)
	local n = 0
	for _, inst in pairs(profile.Planets) do
		if predicate(inst, Planets.ById[inst.Id]) then n = n + 1 end
	end
	return n
end

---------------------------------------------------------------- descubrimientos
function Progression.discoveryKey(planetId, variant, evolved)
	if evolved then return planetId .. "#evo" end
	if variant and variant ~= "none" then return planetId .. "#" .. variant end
	return planetId
end

function Progression.discoveredInSystem(profile, systemId)
	local list = Planets.collectionOf(systemId)
	local n = 0
	for _, def in ipairs(list) do
		if profile.Discovered[def.Id] then n = n + 1 end
	end
	return n, #list
end

function Progression.collectionComplete(profile, systemId)
	local n, total = Progression.discoveredInSystem(profile, systemId)
	return n >= total
end

-- Planetas base descubiertos / total visible (los secretos solo cuentan cuando se descubren)
function Progression.discoveryTotals(profile)
	local found, total = 0, 0
	for _, def in ipairs(Planets.List) do
		if def.Rarity ~= "secret" then
			total = total + 1
			if profile.Discovered[def.Id] then found = found + 1 end
		elseif profile.Discovered[def.Id] then
			total = total + 1
			found = found + 1
		end
	end
	return found, total
end

function Progression.allNonSecretDiscovered(profile)
	for _, def in ipairs(Planets.List) do
		if def.Rarity ~= "secret" and not profile.Discovered[def.Id] then return false end
	end
	return true
end

---------------------------------------------------------------- produccion
function Progression.planetRate(inst)
	local def = Planets.ById[inst.Id]
	local rate = def.Base * Variants.get(inst.V).Multiplier
	if inst.E then rate = rate * Config.Evolution.ProductionMultiplier end
	return rate
end

-- Lista de { inst, def } colocados en un sistema
function Progression.placedIn(profile, systemId)
	local out = {}
	local slots = profile.Placed[systemId]
	if slots then
		for i = 1, Config.Economy.SlotsPerSystem do
			local uid = slots[Galaxy.slotKey(i)]
			local inst = uid and profile.Planets[uid]
			if inst then
				table.insert(out, { inst = inst, def = Planets.ById[inst.Id], uid = uid, slot = i })
			end
		end
	end
	return out
end

local function countWithElement(placed, elements)
	local n = 0
	for _, p in ipairs(placed) do
		for _, e in ipairs(elements) do
			if Planets.hasElement(p.def, e) then
				n = n + 1
				break
			end
		end
	end
	return n
end

local function synergyActive(cond, placed)
	local t = cond.Type
	if t == "Element" then
		return countWithElement(placed, { cond.Element }) >= cond.Count
	elseif t == "AnyElement" then
		return countWithElement(placed, cond.Elements) >= cond.Count
	elseif t == "RarityWithElement" then
		local hasRarity = false
		for _, p in ipairs(placed) do
			if Rarities.atLeast(p.def.Rarity, cond.Rarity) and not Planets.hasElement(p.def, cond.Element) then
				hasRarity = true
			end
		end
		return hasRarity and countWithElement(placed, { cond.Element }) >= cond.Count
	elseif t == "DistinctElements" then
		local seen, n = {}, 0
		for _, p in ipairs(placed) do
			for _, e in ipairs(p.def.Elements) do
				if not seen[e] then
					seen[e] = true
					n = n + 1
				end
			end
		end
		return n >= cond.Count
	elseif t == "FullOrbit" then
		return #placed >= Config.Economy.SlotsPerSystem
	elseif t == "Variants" then
		local n = 0
		for _, p in ipairs(placed) do
			if p.inst.V ~= "none" then n = n + 1 end
		end
		return n >= cond.Count
	elseif t == "Evolved" then
		local n = 0
		for _, p in ipairs(placed) do
			if p.inst.E then n = n + 1 end
		end
		return n >= cond.Count
	end
	return false
end

-- Sinergias activas para una lista de colocados. Devuelve lista de ids y bono total (sin amplificar)
function Progression.synergies(placed)
	local active, bonus = {}, 0
	for _, s in ipairs(Defs.Synergies.List) do
		if synergyActive(s.Condition, placed) then
			table.insert(active, s.Id)
			bonus = bonus + s.Bonus
		end
	end
	return active, bonus
end

function Progression.collectionBonus(profile)
	local bonus = 0
	for sysId in pairs(profile.CollectionsClaimed) do
		local def = Galaxy.ById[sysId]
		if def then bonus = bonus + def.Reward.ProductionBonus end
	end
	return 1 + bonus
end

-- Desglose completo de produccion. eventMultiplier viene del servidor (evento activo) o 1.
function Progression.production(profile, eventMultiplier)
	eventMultiplier = eventMultiplier or 1
	local resonance = Upgrades.effect(profile, "resonance")
	local systems = {}
	local subtotal = 0
	for _, sysId in ipairs(Galaxy.Order) do
		if profile.Systems[sysId] then
			local def = Galaxy.ById[sysId]
			local placed = Progression.placedIn(profile, sysId)
			local base = 0
			for _, p in ipairs(placed) do
				base = base + Progression.planetRate(p.inst)
			end
			local active, bonus = Progression.synergies(placed)
			local synergyMult = 1 + bonus * resonance
			local total = base * def.Multiplier * synergyMult
			systems[sysId] = { Base = base, Count = #placed, Multiplier = def.Multiplier, SynergyMult = synergyMult,
				Synergies = active, Total = total }
			subtotal = subtotal + total
		end
	end
	local mults = {
		Reactor = Upgrades.effect(profile, "reactor"),
		Cores = Upgrades.effect(profile, "core_power"),
		Ascension = Defs.Ascension.multiplier(profile.Ascensions),
		Collections = Progression.collectionBonus(profile),
		Event = eventMultiplier,
	}
	local total = subtotal * mults.Reactor * mults.Cores * mults.Ascension * mults.Collections * mults.Event
	return { Total = total, Subtotal = subtotal, Systems = systems, Mults = mults }
end

---------------------------------------------------------------- costes y limites
function Progression.capsulePrice(profile, capsuleDef, eventDiscount)
	local price = capsuleDef.Price * Upgrades.effect(profile, "efficiency") * (eventDiscount or 1)
	return math.max(1, math.floor(price + 0.5))
end

function Progression.variantLuck(profile, eventLuck)
	return Upgrades.effect(profile, "core_luck") * (eventLuck or 1)
end

function Progression.maxBatch(profile)
	local level = Upgrades.level(profile, "core_multi")
	return Config.Capsules.BatchSizes[level + 1] or 1
end

function Progression.offlineCapSeconds(profile)
	return (Config.Economy.OfflineBaseCapHours + Upgrades.effect(profile, "battery")) * 3600
end

function Progression.offlineRate(profile)
	return math.min(1, Config.Economy.OfflineBaseRate + Upgrades.effect(profile, "core_offline"))
end

function Progression.startingEnergy(profile)
	return Config.Economy.StartingEnergy * Upgrades.effect(profile, "core_start")
end

-- Coste del siguiente slot del sistema, o nil si ya estan todos
function Progression.nextSlotCost(profile, systemId)
	local owned = profile.Slots[systemId]
	if not owned or owned >= Config.Economy.SlotsPerSystem then return nil end
	return Galaxy.ById[systemId].SlotCosts[owned + 1]
end

-- Valor de venta base de cada planeta: una fraccion del precio de la capsula mas barata que lo
-- contiene, repartida de forma que el retorno esperado de abrir una capsula y vender todo sea
-- Config.Economy.SellReturn (15%) de su precio. Asi vender nunca es rentable frente a comprar.
local sellBase = nil
local function buildSellBase()
	sellBase = {}
	for _, capsule in ipairs(Defs.Capsules.List) do
		local rarities = 0
		for _ in pairs(capsule.Odds) do
			rarities = rarities + 1
		end
		for rarityId, pct in pairs(capsule.Odds) do
			local weight = math.min(8, (1 / rarities) / (pct / 100))
			for _, planetId in ipairs(capsule.Pools[rarityId]) do
				if sellBase[planetId] == nil then
					sellBase[planetId] = capsule.Price * Config.Economy.SellReturn * weight
				end
			end
		end
	end
end

function Progression.sellValue(inst)
	if not sellBase then buildSellBase() end
	local value = sellBase[inst.Id] or 1
	-- las variantes y la forma Prime valen algo mas, con tope para no crear bucles de dinero
	value = value * math.min(3, Variants.get(inst.V).Multiplier)
	if inst.E then value = value * 2 end
	return math.max(1, math.floor(value))
end

function Progression.evolutionCost(def)
	return {
		Energy = def.Base * Config.Evolution.EnergyCostPerBase * Galaxy.ById[def.System].Multiplier,
		Stardust = Config.Evolution.StardustPerRarityOrder * Rarities.ById[def.Rarity].Order,
		Copies = Config.Evolution.CopiesRequired,
	}
end

-- Copias que se pueden consumir para evolucionar `uid`: mismo planeta, sin variante, sin evolucionar,
-- sin bloquear y sin colocar. `busy` es un conjunto opcional de uids no disponibles (p. ej. en un trade).
function Progression.evolutionFodder(profile, uid, busy)
	local target = profile.Planets[uid]
	local out = {}
	if not target then return out end
	for otherUid, inst in pairs(profile.Planets) do
		if otherUid ~= uid and inst.Id == target.Id and inst.V == "none" and not inst.E and not inst.L
			and not (busy and busy[otherUid]) and not Progression.findPlaced(profile, otherUid) then
			table.insert(out, otherUid)
		end
	end
	table.sort(out)
	return out
end

-- Nivel de progreso usado para escalar misiones
function Progression.tier(profile)
	local systems = 0
	for _ in pairs(profile.Systems) do
		systems = systems + 1
	end
	return (systems - 1) + math.min(profile.Ascensions, 5)
end

---------------------------------------------------------------- requisitos
-- Evalua un requisito declarativo. Devuelve { Ok, Current, Goal, Text }.
-- `production` es opcional (se calcula si hace falta).
function Progression.checkRequirement(profile, req, production)
	local t = req.Type
	local current, goal, text = 0, 1, ""
	if t == "Energy" then
		current, goal = profile.Energy, req.Amount
		text = "Tener " .. Format.number(req.Amount) .. " de Energy (se gasta al desbloquear)"
	elseif t == "Collection" then
		current = Progression.discoveredInSystem(profile, req.System)
		goal = req.Count
		text = "Descubrir " .. req.Count .. " planetas de la colección " .. Galaxy.ById[req.System].Name
	elseif t == "CollectionComplete" then
		local n, total = Progression.discoveredInSystem(profile, req.System)
		current, goal = n, total
		text = "Completar la colección " .. Galaxy.ById[req.System].Name
	elseif t == "Placed" then
		current, goal = Progression.placedCount(profile, req.System), req.Count
		text = "Tener " .. req.Count .. " planetas en órbita en " .. Galaxy.ById[req.System].Name
	elseif t == "Production" then
		production = production or Progression.production(profile).Total
		current, goal = production, req.Amount
		text = "Producir " .. Format.rate(req.Amount)
	elseif t == "Ascensions" then
		current, goal = profile.Ascensions, req.Count
		text = "Alcanzar " .. req.Count .. " ascensiones"
	elseif t == "Discoveries" then
		current, goal = Progression.discoveryTotals(profile), req.Count
		text = "Descubrir " .. req.Count .. " planetas distintos"
	elseif t == "PlanetsOwned" then
		current, goal = Progression.inventoryCount(profile), req.Count
		text = "Tener " .. req.Count .. " planetas"
	elseif t == "RarityOwned" then
		current = Progression.countOwned(profile, function(_, def) return Rarities.atLeast(def.Rarity, req.Rarity) end)
		goal = req.Count
		text = "Tener " .. req.Count .. " planeta(s) " .. Rarities.ById[req.Rarity].Name .. " o superior"
	elseif t == "RunEnergy" then
		current, goal = profile.RunEnergy, req.Amount
		text = "Generar " .. Format.number(req.Amount) .. " de Energy en esta ascensión"
	end
	return { Ok = current >= goal, Current = math.min(current, goal), Goal = goal, Text = text }
end

-- Estado de un sistema: "unlocked", "ready" (cumple todo) o "locked". Devuelve estado y lista de requisitos.
function Progression.systemState(profile, systemId, production)
	local def = Galaxy.ById[systemId]
	if profile.Systems[systemId] then return "unlocked", {} end
	local checks = {}
	local allOk = true
	-- el sistema anterior debe estar desbloqueado
	local previous = Galaxy.Order[def.Order - 1]
	if previous and not profile.Systems[previous] then
		table.insert(checks, { Ok = false, Current = 0, Goal = 1, Text = "Desbloquear antes " .. Galaxy.ById[previous].Name })
		allOk = false
	end
	for _, req in ipairs(def.Unlock) do
		local check = Progression.checkRequirement(profile, req, production)
		if not check.Ok then allOk = false end
		table.insert(checks, check)
	end
	return allOk and "ready" or "locked", checks
end

-- Coste en Energy de desbloquear un sistema (0 si no tiene)
function Progression.systemEnergyCost(systemId)
	for _, req in ipairs(Galaxy.ById[systemId].Unlock) do
		if req.Type == "Energy" then return req.Amount end
	end
	return 0
end

-- Condicion de un descubrimiento secreto. Devuelve true si el perfil la cumple ahora mismo.
function Progression.secretConditionMet(profile, cond)
	if cond.Type == "ElementsInSystem" then
		for sysId in pairs(profile.Systems) do
			local placed = Progression.placedIn(profile, sysId)
			local n, evolved = 0, false
			for _, p in ipairs(placed) do
				for _, e in ipairs(cond.Elements) do
					if Planets.hasElement(p.def, e) then
						n = n + 1
						if p.inst.E then evolved = true end
						break
					end
				end
			end
			if n >= cond.Count and (not cond.RequireEvolved or evolved) then return true end
		end
		return false
	elseif cond.Type == "DiscoverAllNonSecret" then
		return Progression.allNonSecretDiscovered(profile)
	end
	return false
end

return Progression
