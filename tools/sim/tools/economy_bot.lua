-- Simulacion de ritmo economico: un jugador "bot" juega de forma razonable usando los servicios
-- reales del servidor, y se imprime cuando alcanza cada hito. Sirve para ajustar Config/Definitions.
-- Uso: python3 tools/sim/run.py tools/sim/tools/economy_bot.lua
local SIM = ...
SIM.loadProject()
SIM.quiet = true
SIM.noClient = true
SIM.start()
SIM.advance(1)
local p = SIM.addPlayer(9001, "Bot")
SIM.advance(2)
local require = SIM.G.require
local SSS = SIM.getService("ServerScriptService")
local RS = SIM.getService("ReplicatedStorage")
local Remotes = RS.Remotes
local PlayerService, Production, Defs, Progression, Format
SIM.run("server", function()
	PlayerService = require(SSS.Server.Services.PlayerService)
	Production = require(SSS.Server.Services.ProductionService)
	Defs = require(RS.Shared.Defs)
	Progression = require(RS.Shared.Progression)
	Format = require(RS.Shared.Util.Format)
end)
local profile = PlayerService.profile(p)
SIM.frameStep = 0.5
local HOURS = tonumber(os.getenv("BOT_HOURS") or "8")

local function call(name, ...)
	local args = table.pack(...)
	local r = SIM.run(p, function() return Remotes[name]:InvokeServer(table.unpack(args, 1, args.n)) end)
	SIM.advance(0.6)
	return r
end
local start = SIM.now
local function stamp() return Format.duration(SIM.now - start) end
local function log(msg) print(string.format("[%8s] %-46s  E=%-8s  %s/s  planetas=%d", stamp(), msg, Format.number(profile.Energy),
	Format.number(Production.rate(p)), Progression.inventoryCount(profile))) end
local function value(inst) return Progression.planetRate(inst) end
local function bestUnplaced(exclude)
	local best, bestV
	for uid, inst in pairs(profile.Planets) do
		if not Progression.findPlaced(profile, uid) and uid ~= exclude then
			local v = value(inst)
			if not best or v > bestV then best, bestV = uid, v end
		end
	end
	return best, bestV
end
local function topSystem()
	local top = "solar"
	for _, id in ipairs(Defs.Galaxy.Order) do if profile.Systems[id] then top = id end end
	return top
end
local seen = {}
local function milestone(key, msg) if not seen[key] then seen[key] = true log(msg) end end

log("inicio")
local lastSell = 0
while SIM.now - start < HOURS * 3600 do
	SIM.advance(3)
	-- ascender
	local m = Defs.Ascension.next(profile.Ascensions)
	local ok = true
	for _, req in ipairs(m.Requirements) do
		if not Progression.checkRequirement(profile, req, Production.rate(p)).Ok then ok = false end
	end
	if ok and topSystem() ~= "solar" then
		if call("Rebirth", true).Ok then log("ASCENSION " .. profile.Ascensions) seen = {} end
	end
	-- desbloquear sistemas
	for _, id in ipairs(Defs.Galaxy.Order) do
		if not profile.Systems[id] and Progression.systemState(profile, id, Production.rate(p)) == "ready" then
			if call("UnlockSystem", id).Ok then log("sistema desbloqueado: " .. id) end
		end
	end
	-- colocar: de mayor a menor sistema, llenar huecos y sustituir peores
	local order = {}
	for _, id in ipairs(Defs.Galaxy.Order) do if profile.Systems[id] then table.insert(order, 1, id) end end
	for _, sysId in ipairs(order) do
		for slot = 1, profile.Slots[sysId] do
			local key = Defs.Galaxy.slotKey(slot)
			local current = profile.Placed[sysId][key]
			local uid, v = bestUnplaced()
			if uid and (not current or v > value(profile.Planets[current]) * 1.01) then
				if profile.ActiveSystem ~= sysId then call("SetActiveSystem", sysId) end
				call("EquipPlanet", uid, sysId, slot)
			end
		end
		local cost = Progression.nextSlotCost(profile, sysId)
		if cost and profile.Energy >= cost * 1.2 then
			if call("UnlockSlot", sysId).Ok then milestone("slot" .. sysId .. profile.Slots[sysId], "slot " .. profile.Slots[sysId] .. " de " .. sysId) end
		end
	end
	-- mejoras
	for _ = 1, 6 do
		local lvl = Defs.Upgrades.level(profile, "reactor")
		if lvl < 100 and Defs.Upgrades.ById.reactor.Cost(lvl) <= profile.Energy * 0.35 then call("PurchaseUpgrade", "reactor") else break end
	end
	for _, id in ipairs({ "core_power", "core_luck", "core_multi" }) do
		local def = Defs.Upgrades.ById[id]
		local lvl = Defs.Upgrades.level(profile, id)
		if lvl < def.MaxLevel and def.Cost(lvl) <= profile.Cores then call("PurchaseUpgrade", id) end
	end
	-- capsulas: la mejor disponible si cuesta < 25% de la energia
	local best
	for _, def in ipairs(Defs.Capsules.List) do
		if profile.Systems[def.RequiresSystem] and Progression.capsulePrice(profile, def, 1) <= profile.Energy * 0.25 then best = def end
	end
	if not best and Progression.inventoryCount(profile) < 4 and profile.Energy >= 100 then best = Defs.Capsules.ById.starter end
	if best and Progression.inventoryCount(profile) < Progression.inventoryCapacity(profile) - 12 then
		call("OpenCapsule", best.Id, Progression.maxBatch(profile))
	end
	-- vender sobrantes
	if Progression.inventoryCount(profile) > 60 and SIM.now - lastSell > 30 then
		lastSell = SIM.now
		local list = {}
		for uid, inst in pairs(profile.Planets) do
			if not Progression.findPlaced(profile, uid) and inst.V == "none" and not inst.E then table.insert(list, { uid, value(inst) }) end
		end
		table.sort(list, function(x, y) return x[2] < y[2] end)
		local uids = {}
		for i = 1, math.min(#list - 10, 40) do uids[#uids + 1] = list[i][1] end
		if #uids > 0 then call("SellPlanets", uids) end
	end
	local found = Progression.discoveryTotals(profile)
	for _, n in ipairs({ 6, 12, 18, 22, 25 }) do if found >= n then milestone("disc" .. n, n .. " planetas descubiertos") end end
	for _, r in ipairs({ 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10 }) do
		if Production.rate(p) >= r then milestone("rate" .. r, "produccion >= " .. Format.number(r) .. "/s") end
	end
end
log("fin de la simulacion (" .. HOURS .. " h)")
print("secretos: " .. table.concat((function() local t = {} for k in pairs(profile.SecretsFound) do t[#t + 1] = k end return t end)(), ", "))
print("errores del simulador: " .. #SIM.errors)
