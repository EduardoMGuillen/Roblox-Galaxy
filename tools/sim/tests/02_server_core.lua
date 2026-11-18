-- Flujo principal del servidor: jugador nuevo, capsulas, inventario, colocacion, produccion,
-- mejoras, guardado/carga, spam de remotes y validaciones.
local SIM = ...
SIM.loadProject()
SIM.quiet = true
SIM.start()
SIM.advance(1)
SIM.assertNoErrors("arranque")

local RS = SIM.getService("ReplicatedStorage")
local Remotes = RS:FindFirstChild("Remotes")
assert(Remotes, "no se creo la carpeta Remotes")

local function call(player, name, ...)
	local args = table.pack(...)
	return SIM.run(player, function()
		return Remotes:FindFirstChild(name):InvokeServer(table.unpack(args, 1, args.n))
	end)
end
local function state(player)
	SIM.advance(0.3)
	local r = call(player, "GetState")
	assert(r.Ok, "GetState fallo: " .. tostring(r.Error))
	return r.Data.Profile, r.Data.Derived
end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

local p1 = SIM.addPlayer(1001, "Ana")
SIM.advance(1)
SIM.assertNoErrors("join")
local profile, derived = state(p1)
assert(profile.Energy == 250 and profile.Tutorial == 1, "perfil inicial incorrecto")
assert(derived._Session.Location == "hub" and derived._Event and derived._Production.Total == 0)
assert(rawget(p1, "__props").Character ~= nil, "no se genero el personaje")
assert(#profile.Missions.Daily == 3 and #profile.Missions.Weekly == 3, "misiones no generadas")

-- argumentos invalidos y remotes desconocidos
SIM.advance(1)
assert(call(p1, "OpenCapsule", "starter", 2).Ok == false, "lote 2 no permitido")
SIM.advance(1)
assert(call(p1, "OpenCapsule", 5, 1).Ok == false)
SIM.advance(1)
assert(call(p1, "OpenCapsule", "starter", 1.5).Ok == false)
SIM.advance(1)
assert(call(p1, "OpenCapsule", "nebula", 1).Ok == false, "capsula de sistema bloqueado")
SIM.advance(1)
assert(call(p1, "OpenCapsule", "starter", 1, "extra").Ok == false, "argumento extra aceptado")
SIM.advance(1)

-- abrir capsulas: 250 Energy -> 2 capsulas starter (100 c/u), la tercera falla
local r = call(p1, "OpenCapsule", "starter", 1)
assert(r.Ok, "abrir capsula: " .. tostring(r.Error))
local first = r.Data.Results[1]
assert(first.Uid and first.New == true, "primer planeta deberia ser descubrimiento nuevo")
SIM.advance(1)
r = call(p1, "OpenCapsule", "starter", 1)
assert(r.Ok)
SIM.advance(1)
r = call(p1, "OpenCapsule", "starter", 1)
assert(not r.Ok, "no deberia poder pagar la tercera capsula")
profile = state(p1)
assert(profile.Energy == 50 and count(profile.Planets) == 2 and profile.Tutorial == 3, "estado tras capsulas: E=" .. profile.Energy .. " tut=" .. profile.Tutorial)
assert(profile.Stats.CapsulesOpened == 2)

-- spam: 30 peticiones en el mismo instante -> solo 1 pasa el cooldown
SIM.run(p1, function()
	for _ = 1, 30 do
		task.spawn(function() Remotes.OpenCapsule:InvokeServer("starter", 1) end)
	end
end)
SIM.advance(1)
profile = state(p1)
assert(profile.Energy == 50 and count(profile.Planets) == 2, "el spam genero recompensas o gasto")

-- viajar al universo y colocar
SIM.advance(1)
r = call(p1, "Teleport", "universe")
assert(r.Ok and r.Data.Location == "u:1001")
local uid = first.Uid
r = call(p1, "EquipPlanet", uid, "solar", 5)
assert(not r.Ok, "slot 5 esta bloqueado")
SIM.advance(0.5)
r = call(p1, "EquipPlanet", "p999", "solar", 1)
assert(not r.Ok, "planeta ajeno/inexistente")
SIM.advance(0.5)
r = call(p1, "EquipPlanet", uid, "nebula", 1)
assert(not r.Ok, "sistema bloqueado")
SIM.advance(0.5)
r = call(p1, "EquipPlanet", uid, "solar", 1)
assert(r.Ok, "colocar: " .. tostring(r.Error))
SIM.advance(0.5)
-- mover la misma instancia a otro slot: no se duplica
r = call(p1, "EquipPlanet", uid, "solar", 2)
assert(r.Ok)
profile, derived = state(p1)
assert(profile.Placed.solar.s1 == nil and profile.Placed.solar.s2 == uid, "la instancia quedo en dos slots")
assert(derived._Production.Total > 0 and profile.Tutorial == 5, "tutorial=" .. profile.Tutorial)
local rate = derived._Production.Total

-- produccion pasiva
local before = profile.Energy
SIM.advance(10)
profile = state(p1)
local gained = profile.Energy - before
assert(math.abs(gained - rate * 10) <= rate * 1.5, ("produccion: esperado ~%s, ganado %s"):format(rate * 10, gained))

-- vender un planeta colocado: prohibido; vender el otro: ok
r = call(p1, "SellPlanets", { uid })
assert(not r.Ok)
SIM.advance(0.5)
local other
for id in pairs(profile.Planets) do if id ~= uid then other = id end end
r = call(p1, "LockPlanet", other, true)
assert(r.Ok)
SIM.advance(0.5)
r = call(p1, "SellPlanets", { other })
assert(not r.Ok, "planeta bloqueado vendido")
SIM.advance(0.5)
call(p1, "LockPlanet", other, false)
SIM.advance(0.5)
r = call(p1, "SellPlanets", { other, other })
assert(not r.Ok, "seleccion duplicada aceptada")
SIM.advance(0.5)
r = call(p1, "SellPlanets", { other })
assert(r.Ok and r.Data.Energy > 0, "venta fallo")
profile = state(p1)
assert(count(profile.Planets) == 1)

-- mejora: sin saldo falla; con saldo sube de nivel y aumenta la produccion
SIM.frameStep = 1
SIM.advance(120)
SIM.frameStep = 1 / 20
profile = state(p1)
local energyBefore = profile.Energy
assert(energyBefore >= 400, "no acumulo energia: " .. energyBefore)
r = call(p1, "PurchaseUpgrade", "reactor")
assert(r.Ok and r.Data.Level == 1 and r.Data.Spent == 400, "mejora: " .. tostring(r.Error))
SIM.advance(0.2)
r = call(p1, "PurchaseUpgrade", "noexiste")
assert(not r.Ok)
SIM.advance(0.2)
r = call(p1, "PurchaseUpgrade", "core_power")
assert(not r.Ok, "mejora de nucleo sin cores")
profile, derived = state(p1)
assert(profile.Upgrades.reactor == 1 and math.abs(derived._Production.Total - rate * 1.1) < 1e-6)
assert(profile.Tutorial == 7 and profile.Stardust == 25, "tutorial deberia completarse al comprar la mejora: " .. profile.Tutorial)
call(p1, "TutorialAck", "watch_production")
SIM.advance(0.5)
profile = state(p1)
assert(profile.Tutorial == 7 and profile.Stardust == 25, "el tutorial no debe retroceder ni duplicar recompensa")

-- slot: comprar el 4o cuesta 2500
local canBuySlot = profile.Energy >= 2500
r = call(p1, "UnlockSlot", "solar")
assert(r.Ok == canBuySlot, "compra de slot inconsistente con el saldo")
profile = state(p1)
assert(profile.Slots.solar == (canBuySlot and 4 or 3))

-- guardar y volver a entrar: no se pierde nada
local snapshotEnergy = profile.Energy
SIM.removePlayer(p1)
SIM.advance(2)
SIM.assertNoErrors("salida")
local stored = SIM.datastores["PlanetCollector_Profiles_v1"]["u_1001"]
assert(stored and stored.Data and stored.Lock == nil, "no se guardo o no se libero el candado")
assert(stored.Data.Upgrades.reactor == 1 and stored.Data.Placed.solar.s2 == uid)

p1 = SIM.addPlayer(1001, "Ana")
SIM.advance(1)
profile, derived = state(p1)
assert(profile.Upgrades.reactor == 1 and profile.Placed.solar.s2 == uid and count(profile.Planets) == 1, "datos perdidos al volver")
assert(profile.Energy >= snapshotEnergy, "energia perdida")
assert(derived._Session.Offline == nil, "no deberia haber ganancias offline tras 2 segundos")
SIM.assertNoErrors("rejoin")

-- ganancias offline: 1 hora fuera
SIM.removePlayer(p1)
SIM.advance(2)
SIM.epoch = SIM.epoch + 3600
p1 = SIM.addPlayer(1001, "Ana")
SIM.advance(1)
profile, derived = state(p1)
assert(derived._Session.Offline and derived._Session.Offline.Energy > 0, "sin ganancias offline")
local expected = math.floor(rate * 1.1 * 3600 * 0.5)
assert(math.abs(derived._Session.Offline.Energy - expected) <= expected * 0.01, "offline esperado " .. expected .. " fue " .. derived._Session.Offline.Energy)

-- carga fallida: no se crea perfil por defecto ni se sobrescribe
SIM.isStudio = false
SIM.dsFail = function(op, store, key) return key == "u_2002" end
local p2 = SIM.addPlayer(2002, "Beto")
SIM.frameStep = 0.5
SIM.advance(30)
SIM.frameStep = 1 / 20
assert(rawget(p2, "__kicked"), "el jugador con carga fallida no fue expulsado")
assert(SIM.datastores["PlanetCollector_Profiles_v1"]["u_2002"] == nil, "se escribio un perfil tras fallo de carga")
SIM.dsFail = nil

-- candado de otra sesion: no se carga
SIM.datastores["PlanetCollector_Profiles_v1"]["u_3003"] = { Data = { Energy = 777, Version = 1 }, Lock = { JobId = "otro-servidor", Time = SIM.epoch + SIM.now } }
local p3 = SIM.addPlayer(3003, "Caro")
SIM.frameStep = 0.5
SIM.advance(30)
SIM.frameStep = 1 / 20
assert(rawget(p3, "__kicked"), "se cargo un perfil bloqueado por otro servidor")
assert(SIM.datastores["PlanetCollector_Profiles_v1"]["u_3003"].Data.Energy == 777, "perfil bloqueado modificado")
SIM.isStudio = true

SIM.clearErrors()
SIM.shutdown()
SIM.assertNoErrors("cierre")
assert(SIM.datastores["PlanetCollector_Profiles_v1"]["u_1001"].Lock == nil, "candado sin liberar al cerrar")
print("OK server core")
