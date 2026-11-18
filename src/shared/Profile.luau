-- Profile: plantilla del perfil persistente del jugador y reconciliacion/migracion de datos.
-- Solo usa claves string (compatibles con DataStore y RemoteEvents).
local Defs = require(script.Parent.Defs)
local Config = Defs.Config

local Profile = {}

local function deepCopy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do
		out[k] = deepCopy(v)
	end
	return out
end
Profile.deepCopy = deepCopy

function Profile.default(now)
	return {
		Version = Config.Data.Version,
		Energy = Config.Economy.StartingEnergy,
		Stardust = 0,
		Cores = 0,
		RunEnergy = 0,
		TotalEnergy = 0,
		Planets = {},
		NextUid = 1,
		Placed = { solar = {} },
		Slots = { solar = Defs.Galaxy.ById.solar.FreeSlots },
		Systems = { solar = true },
		ActiveSystem = "solar",
		Upgrades = {},
		Ascensions = 0,
		Discovered = {},
		CollectionsClaimed = {},
		SecretsFound = {},
		Missions = { DailyKey = 0, Daily = {}, WeeklyKey = 0, Weekly = {}, EventKey = 0, EventProgress = 0, EventClaimed = false },
		Stats = {
			CapsulesOpened = 0, PlanetsObtained = 0, RaresObtained = 0, Visits = 0, Evolutions = 0, Trades = 0,
			PlayTime = 0, MeteorsCollected = 0, PlanetsSold = 0, BestRate = 0, UpgradesBought = 0,
		},
		Settings = deepCopy(Config.DefaultSettings),
		Tutorial = 1,
		Cosmetics = {
			Owned = { orbit_system = true, aura_default = true },
			Equipped = deepCopy(Defs.Cosmetics.Defaults),
		},
		Created = now or 0,
		LastSave = 0,
	}
end

-- Rellena claves que falten (perfiles antiguos) sin tocar los valores existentes.
local function fill(target, template)
	for k, v in pairs(template) do
		if target[k] == nil then
			target[k] = deepCopy(v)
		elseif type(v) == "table" and type(target[k]) == "table" then
			-- solo se rellenan sub-tablas "de esquema"; las colecciones dinamicas se dejan como estan
			if k == "Stats" or k == "Settings" or k == "Missions" or k == "Cosmetics" or k == "Equipped" or k == "Owned" then
				fill(target[k], v)
			end
		end
	end
end

local function isFiniteNumber(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- Migraciones por version. migrations[n] convierte un perfil de la version n a la n+1.
local migrations = {}

-- Valida y repara un perfil cargado. Devuelve el perfil listo para usar.
function Profile.reconcile(data, now)
	if type(data) ~= "table" then
		return Profile.default(now)
	end
	local version = tonumber(data.Version) or 1
	while version < Config.Data.Version do
		local step = migrations[version]
		if step then step(data) end
		version = version + 1
	end
	data.Version = Config.Data.Version
	fill(data, Profile.default(now))

	-- monedas: numeros finitos, no negativos, con tope
	for _, key in ipairs({ "Energy", "Stardust", "Cores", "RunEnergy", "TotalEnergy" }) do
		local v = data[key]
		if not isFiniteNumber(v) or v < 0 then v = 0 end
		data[key] = math.min(v, Config.Economy.MaxCurrency)
	end
	if not isFiniteNumber(data.Ascensions) or data.Ascensions < 0 then data.Ascensions = 0 end
	data.Ascensions = math.floor(data.Ascensions)

	-- planetas: descartar instancias con definicion desconocida
	local maxUid = 0
	for uid, inst in pairs(data.Planets) do
		local def = type(inst) == "table" and Defs.Planets.ById[inst.Id]
		if not def then
			data.Planets[uid] = nil
		else
			if not Defs.Variants.ById[inst.V or "none"] then inst.V = "none" end
			inst.V = inst.V or "none"
			inst.E = inst.E == true
			inst.L = inst.L == true
			local n = tonumber(string.match(uid, "^p(%d+)$"))
			if n and n > maxUid then maxUid = n end
		end
	end
	if not isFiniteNumber(data.NextUid) or data.NextUid <= maxUid then data.NextUid = maxUid + 1 end

	-- sistemas y slots
	data.Systems.solar = true
	for _, sysId in ipairs(Defs.Galaxy.Order) do
		local def = Defs.Galaxy.ById[sysId]
		if data.Systems[sysId] then
			if type(data.Placed[sysId]) ~= "table" then data.Placed[sysId] = {} end
			local slots = tonumber(data.Slots[sysId]) or def.FreeSlots
			data.Slots[sysId] = math.max(def.FreeSlots, math.min(Config.Economy.SlotsPerSystem, math.floor(slots)))
		else
			data.Systems[sysId] = nil
			data.Placed[sysId] = nil
			data.Slots[sysId] = nil
		end
	end
	if not data.Systems[data.ActiveSystem] then data.ActiveSystem = "solar" end

	-- colocados: cada instancia existe, solo esta en un slot y el slot esta desbloqueado
	local seen = {}
	for sysId, slots in pairs(data.Placed) do
		for slotKey, uid in pairs(slots) do
			local index = tonumber(string.match(slotKey, "^s(%d+)$"))
			if not index or index < 1 or index > (data.Slots[sysId] or 0) or not data.Planets[uid] or seen[uid] then
				slots[slotKey] = nil
			else
				seen[uid] = true
			end
		end
	end

	-- mejoras: niveles validos
	for id, level in pairs(data.Upgrades) do
		local def = Defs.Upgrades.ById[id]
		if not def or not isFiniteNumber(level) then
			data.Upgrades[id] = nil
		else
			data.Upgrades[id] = math.max(0, math.min(def.MaxLevel, math.floor(level)))
		end
	end

	-- cosmeticos equipados validos
	for category, defaultId in pairs(Defs.Cosmetics.Defaults) do
		local id = data.Cosmetics.Equipped[category]
		if not id or not Defs.Cosmetics.ById[id] or not data.Cosmetics.Owned[id] then
			data.Cosmetics.Equipped[category] = defaultId
		end
	end

	if not isFiniteNumber(data.Tutorial) then data.Tutorial = 1 end
	return data
end

return Profile
