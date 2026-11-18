-- Progresion y sistemas sociales: desbloqueo de sistemas, ascension, evolucion, secretos, misiones,
-- eventos, trading (doble confirmacion, cancelaciones, desconexion), visitas y leaderboard.
local SIM = ...
SIM.loadProject()
SIM.quiet = true
SIM.start()
SIM.advance(1)

local RS = SIM.getService("ReplicatedStorage")
local SSS = SIM.getService("ServerScriptService")
local Remotes = RS:FindFirstChild("Remotes")
local require = SIM.G.require

local function call(player, name, ...)
	local args = table.pack(...)
	SIM.advance(2.1) -- respetar cooldowns
	return SIM.run(player, function()
		return Remotes:FindFirstChild(name):InvokeServer(table.unpack(args, 1, args.n))
	end)
end
local function server(fn, ...) return SIM.run("server", fn, ...) end
local Services = SSS.Server.Services
local PlayerService, Inventory, Production, Discovery, Economy
server(function()
	PlayerService = require(Services.PlayerService)
	Inventory = require(Services.InventoryService)
	Production = require(Services.ProductionService)
	Discovery = require(Services.DiscoveryService)
	Economy = require(Services.EconomyService)
end)
local Defs, Progression
server(function()
	Defs = require(RS.Shared.Defs)
	Progression = require(RS.Shared.Progression)
end)
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function give(player, id, variant) return server(function() return Inventory.add(player, id, variant or "none", "test") end) end
local function energy(player, amount) server(function() Economy.add(player, "Energy", amount, "test") end) end

local a = SIM.addPlayer(11, "Ana")
local b = SIM.addPlayer(22, "Beto")
SIM.advance(1)
SIM.assertNoErrors("joins")
local pa = PlayerService.profile(a)
local pb = PlayerService.profile(b)

---------------------------------------------------------------- desbloqueo de sistema
local r = call(a, "UnlockSystem", "nebula")
assert(not r.Ok, "nebula desbloqueada sin requisitos")
energy(a, 80000)
r = call(a, "UnlockSystem", "nebula")
assert(not r.Ok, "nebula desbloqueada sin coleccion")
for _, id in ipairs({ "terra", "rocanox", "dunaris", "glaciera" }) do give(a, id) end
r = call(a, "UnlockSystem", "void")
assert(not r.Ok, "void sin nebula")
r = call(a, "UnlockSystem", "nebula")
assert(r.Ok, "nebula: " .. tostring(r.Error))
assert(pa.Systems.nebula and pa.Slots.nebula == 3 and pa.Energy < 80000 + 250 - 74999)
r = call(a, "OpenCapsule", "nebula", 1)
assert(not r.Ok, "capsula nebula sin saldo") -- quedan ~5k
-- colocar en nebula requiere viajar (sistema activo)
local uid = give(a, "amethyst")
r = call(a, "EquipPlanet", uid, "nebula", 1)
assert(not r.Ok, "colocado en sistema no activo")
r = call(a, "SetActiveSystem", "nebula")
assert(r.Ok)
r = call(a, "EquipPlanet", uid, "nebula", 1)
assert(r.Ok)
SIM.advance(0.2)
assert(math.abs(Production.rate(a) - 42 * 6) < 1e-6, "multiplicador de sistema nebula: " .. Production.rate(a))

---------------------------------------------------------------- sinergias y secretos
r = call(a, "SetActiveSystem", "solar")
local g1, g2 = give(a, "glaciera"), give(a, "glaciera")
local g3 = give(a, "glaciera")
call(a, "EquipPlanet", g1, "solar", 1)
call(a, "EquipPlanet", g2, "solar", 2)
assert(not pa.SecretsFound.cryostar)
r = call(a, "EquipPlanet", g3, "solar", 3)
assert(r.Ok)
SIM.advance(0.5)
assert(pa.SecretsFound.cryostar, "secreto Cryostar no descubierto con 3 mundos de hielo")
local cryo = 0
for _, inst in pairs(pa.Planets) do if inst.Id == "cryostar" then cryo = cryo + 1 end end
assert(cryo == 1 and pa.Discovered.cryostar)
-- repetir la condicion no vuelve a entregar el secreto
call(a, "UnequipPlanet", "solar", 3)
call(a, "EquipPlanet", g3, "solar", 3)
cryo = 0
for _, inst in pairs(pa.Planets) do if inst.Id == "cryostar" then cryo = cryo + 1 end end
assert(cryo == 1, "secreto entregado dos veces")
local prod = Production.rate(a)
-- 3 glaciera (22) con trio glacial +15% + nebula 252
assert(math.abs(prod - (66 * 1.15 + 252)) < 1e-6, "sinergia: " .. prod)

---------------------------------------------------------------- evolucion
local t1 = give(a, "terra")
r = call(a, "EvolvePlanet", t1)
assert(not r.Ok, "evolucion sin copias") -- solo hay 1 terra extra (la del desbloqueo)
give(a, "terra")
server(function() Economy.add(a, "Stardust", 100, "test") end)
energy(a, 20000)
local before = count(pa.Planets)
r = call(a, "EvolvePlanet", t1)
assert(r.Ok, "evolucion: " .. tostring(r.Error))
assert(pa.Planets[t1].E == true and count(pa.Planets) == before - 2 and pa.Discovered["terra#evo"])
r = call(a, "EvolvePlanet", t1)
assert(not r.Ok, "doble evolucion")

---------------------------------------------------------------- misiones
local mission = pa.Missions.Daily[1]
r = call(a, "ClaimMission", "daily", 1)
assert(not r.Ok, "mision reclamada sin completar")
server(function() mission.Progress = mission.Goal end)
local sd = pa.Stardust
r = call(a, "ClaimMission", "daily", 1)
assert(r.Ok and pa.Stardust == sd + mission.Stardust)
r = call(a, "ClaimMission", "daily", 1)
assert(not r.Ok, "mision reclamada dos veces")
r = call(a, "ClaimMission", "daily", 9)
assert(not r.Ok)

---------------------------------------------------------------- trading
local ta = give(a, "jovian", "golden")
local tb = give(b, "inferno")
local tb2 = give(b, "terra")
r = call(a, "RequestTrade", 11)
assert(not r.Ok, "trade consigo mismo")
r = call(a, "RequestTrade", 22)
assert(r.Ok)
r = call(b, "RespondTrade", 11, false)
assert(r.Ok)
r = call(a, "TradeAction", "add", ta)
assert(not r.Ok, "accion sin trade activo")
call(a, "RequestTrade", 22)
r = call(b, "RespondTrade", 11, true)
assert(r.Ok, "aceptar trade: " .. tostring(r.Error))
r = call(a, "TradeAction", "add", g1)
assert(not r.Ok, "oferta de planeta colocado")
r = call(a, "TradeAction", "add", tb)
assert(not r.Ok, "oferta de planeta ajeno")
r = call(a, "TradeAction", "add", ta)
assert(r.Ok)
r = call(a, "TradeAction", "add", ta)
assert(not r.Ok, "planeta ofrecido dos veces")
-- mientras esta ofrecido no se puede vender ni colocar
r = call(a, "SellPlanets", { ta })
assert(not r.Ok, "venta de planeta en trade")
r = call(a, "EquipPlanet", ta, "solar", 1)
assert(not r.Ok, "colocacion de planeta en trade")
r = call(b, "TradeAction", "add", tb)
assert(r.Ok)
r = call(a, "ConfirmTrade")
assert(not r.Ok, "confirmar sin listo")
call(a, "TradeAction", "ready")
call(b, "TradeAction", "ready")
-- cambiar la oferta reinicia las confirmaciones
r = call(b, "TradeAction", "add", tb2)
assert(r.Ok)
r = call(a, "ConfirmTrade")
assert(not r.Ok, "confirmar tras oferta modificada")
call(a, "TradeAction", "ready")
call(b, "TradeAction", "ready")
r = SIM.run(a, function() return Remotes.ConfirmTrade:InvokeServer() end)
-- (call() espera 2.1s; aqui se prueba el periodo de revision inmediatamente tras "ready")
SIM.advance(6)
r = call(a, "ConfirmTrade")
assert(r.Ok, "confirmar A: " .. tostring(r.Error))
assert(pa.Planets[ta] ~= nil, "transferido con una sola confirmacion")
local countA, countB = count(pa.Planets), count(pb.Planets)
r = call(b, "ConfirmTrade")
assert(r.Ok)
assert(pa.Planets[ta] == nil and pb.Planets[tb] == nil and pb.Planets[tb2] == nil, "instancias no retiradas")
assert(count(pa.Planets) == countA + 1 and count(pb.Planets) == countB - 1, "conteo tras trade")
local gotGolden = false
for _, inst in pairs(pb.Planets) do if inst.Id == "jovian" and inst.V == "golden" then gotGolden = true end end
assert(gotGolden, "B no recibio el Jovian Golden")
assert(pa.Stats.Trades == 1 and pb.Stats.Trades == 1)
r = call(a, "ConfirmTrade")
assert(not r.Ok, "confirmar con trade cerrado")
-- desconexion durante un trade: se cancela y se liberan los bloqueos
local c = SIM.addPlayer(33, "Caro")
SIM.advance(1)
local tc = give(c, "terra")
local ta2 = give(a, "terra")
call(a, "RequestTrade", 33)
call(c, "RespondTrade", 11, true)
call(a, "TradeAction", "add", ta2)
call(c, "TradeAction", "add", tc)
SIM.removePlayer(c)
SIM.advance(1)
r = call(a, "SellPlanets", { ta2 })
assert(r.Ok, "el planeta siguio bloqueado tras desconexion del otro jugador: " .. tostring(r.Error))
assert(SIM.datastores["PlanetCollector_Profiles_v1"]["u_33"].Data.Planets[tc], "el jugador que se fue perdio su planeta")

---------------------------------------------------------------- visitas (solo lectura)
r = call(b, "VisitUniverse", 11)
assert(r.Ok and r.Data.Location == "u:11")
assert(pb.Stats.Visits == 1)
-- el visitante no puede modificar el universo del propietario: las acciones afectan solo a su perfil
r = call(b, "UnequipPlanet", "solar", 1)
assert(not r.Ok and pa.Placed.solar.s1 == g1, "un visitante modifico el universo ajeno")
r = call(b, "VisitUniverse", 999)
assert(not r.Ok)
r = call(b, "Teleport", "hub")
assert(r.Ok)
local list = call(b, "GetUniverses")
assert(list.Ok and #list.Data == 2, "universos publicados: " .. #list.Data)

---------------------------------------------------------------- ascension
energy(a, 5000)
server(function() pa.Upgrades.reactor = 3 pa.Upgrades.core_power = 1 end)
if count(pa.Planets) < 10 then
	r = call(a, "Rebirth", true)
	assert(not r.Ok, "ascension sin 10 planetas")
	while count(pa.Planets) < 10 do give(a, "rocanox") end
end
r = call(a, "Rebirth", false)
assert(not r.Ok, "ascension sin confirmar")
server(function() pa.RunEnergy = 100 end)
r = call(a, "Rebirth", true)
assert(not r.Ok, "ascension sin la Energy generada requerida")
server(function() pa.RunEnergy = 30000 end)
local planetsBefore = count(pa.Planets)
local discoveredBefore = count(pa.Discovered)
r = call(a, "Rebirth", true)
assert(r.Ok, "ascension: " .. tostring(r.Error))
assert(pa.RunEnergy < 100, "RunEnergy no se reinicio")
assert(pa.Ascensions == 1 and pa.Cores == 3)
assert(pa.Energy == 250 and pa.Upgrades.reactor == nil and pa.Upgrades.core_power == 1, "reinicio de mejoras incorrecto")
assert(pa.Systems.nebula == nil and count(pa.Placed.solar) == 0 and pa.Slots.solar == 3 and pa.ActiveSystem == "solar")
assert(count(pa.Planets) == planetsBefore and count(pa.Discovered) == discoveredBefore, "la ascension borro planetas o coleccion")
SIM.advance(0.5)
assert(Production.rate(a) == 0)
call(a, "EquipPlanet", g1, "solar", 1)
SIM.advance(0.5)
local cb = Progression.collectionBonus(pa)
assert(cb == 1.05 and pa.CollectionsClaimed.solar, "la coleccion Solar deberia estar completa y premiada")
assert(math.abs(Production.rate(a) - 22 * 2 * 1.25 * cb) < 1e-6, "multiplicador de ascension x2 y nucleo: " .. Production.rate(a))
-- hito 2: 1 planeta Legendario o superior (el secreto Cryostar cuenta) + Energy generada
r = call(a, "Rebirth", true)
assert(not r.Ok, "segunda ascension inmediata (sin generar Energy)")
r = call(a, "PurchaseUpgrade", "core_power")
assert(r.Ok and pa.Cores == 0 and pa.Upgrades.core_power == 2, "compra con cores")
---------------------------------------------------------------- eventos
local Events
server(function() Events = require(Services.EventService) end)
-- avanzar hasta el inicio del siguiente ciclo (evento activo)
local now = SIM.epoch + SIM.now
local nextStart = (math.floor(now / 1800) + 1) * 1800
SIM.frameStep = 1
SIM.advance(nextStart - now + 2)
local active = Events.active()
assert(active, "no hay evento activo al inicio del ciclo")
SIM.advance(601)
assert(Events.active() == nil, "el evento no termino a los 10 minutos")
-- recorrer ciclos hasta supernova y comprobar el x2
local found = false
for _ = 1, 5 do
	now = SIM.epoch + SIM.now
	SIM.advance((math.floor(now / 1800) + 1) * 1800 - now + 2)
	if Events.active() and Events.active().Id == "supernova" then
		found = true
		assert(math.abs(Production.rate(a) - 22 * 2 * 1.5 * cb * 2) < 1e-6, "supernova no duplico la produccion: " .. Production.rate(a))
		break
	end
end
assert(found, "no se encontro el evento supernova en el calendario")
-- meteor shower: recoger un meteorito valido y rechazar ids falsos
for _ = 1, 5 do
	now = SIM.epoch + SIM.now
	SIM.advance((math.floor(now / 1800) + 1) * 1800 - now + 6)
	if Events.active() and Events.active().Id == "meteor_shower" then break end
end
assert(Events.active() and Events.active().Id == "meteor_shower")
SIM.frameStep = 1 / 20
local session = PlayerService.get(a)
local meteorId = next(session.Meteors)
assert(meteorId, "no aparecieron meteoritos")
sd = pa.Stardust
r = call(a, "CollectMeteor", "m999999")
assert(not r.Ok)
r = call(a, "CollectMeteor", meteorId)
assert(r.Ok and pa.Stardust > sd, "meteorito no recogido: " .. tostring(r.Error))
r = call(a, "CollectMeteor", meteorId)
assert(not r.Ok, "meteorito recogido dos veces")

---------------------------------------------------------------- leaderboard
local LB
server(function() LB = require(Services.LeaderboardService) LB.refresh() end)
r = call(a, "GetLeaderboard")
assert(r.Ok and r.Data.Ascensions[1].UserId == 11 and r.Data.Ascensions[1].Value == 1, "leaderboard de ascensiones")
assert(r.Data.Rate[1].UserId == 11)

SIM.assertNoErrors("progresion")
SIM.shutdown()
SIM.assertNoErrors("cierre")
print("OK server progression")
