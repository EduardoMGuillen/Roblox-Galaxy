-- Dos clientes: trading por la interfaz (invitar, aceptar, ofrecer, listo, confirmar), visita de solo
-- lectura, ascension, tienda, misiones, desbloqueo de sistema y evento, todo pulsando botones reales.
local SIM = ...
SIM.loadProject()
SIM.quiet = true
SIM.start()
SIM.advance(1)
local a = SIM.addPlayer(71, "Ana")
local b = SIM.addPlayer(72, "Beto")
SIM.advance(3)
SIM.assertNoErrors("arranque")

local require = SIM.G.require
local SSS = SIM.getService("ServerScriptService")
local RS = SIM.getService("ReplicatedStorage")
local PlayerService, Inventory, Economy, Production
SIM.run("server", function()
	PlayerService = require(SSS.Server.Services.PlayerService)
	Inventory = require(SSS.Server.Services.InventoryService)
	Economy = require(SSS.Server.Services.EconomyService)
	Production = require(SSS.Server.Services.ProductionService)
end)
local function server(fn) return SIM.run("server", fn) end
local function ui(p) return p.PlayerGui.MainHUD.Root, p.PlayerGui.Panels.Root, p.PlayerGui.Overlay.Root end
local function find(container, name)
	local inst = container:FindFirstChild(name, true)
	assert(inst, "no existe el elemento de UI: " .. name)
	return inst
end
local function click(container, name, wait)
	local btn = find(container, name)
	assert(SIM.isVisible(btn), "boton no visible: " .. name)
	assert(not btn:GetAttribute("Disabled"), "boton deshabilitado: " .. name)
	SIM.click(btn)
	SIM.advance(wait or 0.7)
	SIM.assertNoErrors("click " .. name)
	return btn
end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local pa, pb = PlayerService.profile(a), PlayerService.profile(b)
local rootA, panelsA, overlayA = ui(a)
local rootB, panelsB, overlayB = ui(b)
for _, p in ipairs({ a, b }) do
	SIM.run(p, function() RS.Remotes.SkipTutorial:InvokeServer() end)
end
SIM.advance(1)

---------------------------------------------------------------- trading por UI
local ta, tb
server(function()
	ta = Inventory.add(a, "jovian", "shiny", "test")
	tb = Inventory.add(b, "inferno", "none", "test")
	Inventory.add(a, "terra", "none", "test")
end)
SIM.advance(0.5)
click(rootA, "Trading")
local tradeA = panelsA.TradingUI
click(tradeA, "Invite", 1.5)
local tradeB = panelsB:FindFirstChild("TradingUI")
assert(tradeB and tradeB.Visible, "la invitacion no abrio el panel de trading de B")
click(tradeB, "Accept", 1.5)
assert(find(tradeA, "Confirm"), "A no ve la ventana de intercambio")
click(tradeA, "Mine_" .. ta, 1)
click(tradeB, "Mine_" .. tb, 1)
assert(tradeA:FindFirstChild("Offer_" .. ta, true) and tradeA:FindFirstChild("Offer_" .. tb, true), "A no ve ambas ofertas")
assert(find(tradeA, "Confirm"):GetAttribute("Disabled"), "confirmar deberia estar deshabilitado antes de Listo")
click(tradeA, "Ready", 1)
click(tradeB, "Ready", 1)
SIM.advance(1)
assert(find(tradeA, "Confirm"):GetAttribute("Disabled"), "confirmar deberia esperar el periodo de revision")
SIM.advance(6)
click(tradeA, "Confirm", 1)
assert(pa.Planets[ta], "transferido con una sola confirmacion")
click(tradeB, "Confirm", 2)
assert(pa.Planets[ta] == nil and pb.Planets[tb] == nil, "el intercambio no se ejecuto")
assert(tradeA:FindFirstChild("Confirm", true) == nil, "la ventana de intercambio no volvio al lobby")
click(tradeA, "Close")
click(tradeB, "Close")
-- cancelar por UI
click(rootA, "Trading")
click(tradeA, "Invite", 1.5)
click(tradeB, "Accept", 1.5)
click(tradeB, "Cancel", 1.5)
assert(tradeA:FindFirstChild("Confirm", true) == nil, "A sigue en un trade cancelado")
click(tradeA, "Close")
if tradeB.Visible then click(tradeB, "Close") end

---------------------------------------------------------------- visita de solo lectura
local ua
server(function() ua = Inventory.add(a, "aureon", "golden", "test") end)
SIM.run(a, function()
	local R = RS.Remotes
	assert(R.Teleport:InvokeServer("universe").Ok)
	task.wait(0.3)
	assert(R.EquipPlanet:InvokeServer(ua, "solar", 1).Ok)
end)
SIM.advance(2)
click(rootB, "Teleport")
local teleB = panelsB.TeleportUI
click(find(teleB, "Universe_71"), "Visit", 2)
local ws = SIM.getService("Workspace")
assert(rootB.VisitBanner.Visible, "B no ve el aviso de visita")
local orbitsB = rootB.OrbitsPanel
assert(orbitsB.Visible)
click(orbitsB, "Slot1", 1)
local inspectB = panelsB:FindFirstChild("PlanetInspectUI")
assert(inspectB and inspectB.Visible, "B no puede inspeccionar el planeta ajeno (solo lectura)")
click(inspectB, "Close")
assert(find(orbitsB, "Slot2"):GetAttribute("Disabled"), "un visitante no debe poder colocar")
-- el propietario se va: el visitante vuelve al Hub
SIM.removePlayer(a)
SIM.advance(2)
SIM.assertNoErrors("salida del propietario")
assert(not rootB.VisitBanner.Visible and not orbitsB.Visible, "B deberia haber vuelto al Hub")

---------------------------------------------------------------- B: sistema, tienda, misiones, ascension
server(function()
	Economy.add(b, "Energy", 400000, "test")
	Economy.add(b, "Stardust", 2000, "test")
	for _, id in ipairs({ "terra", "rocanox", "dunaris", "glaciera" }) do Inventory.add(b, id, "none", "test") end
	for _ = 1, 8 do Inventory.add(b, "rocanox", "none", "test") end
	pb.RunEnergy = 600000
	pb.Missions.Daily[1].Progress = pb.Missions.Daily[1].Goal
	PlayerService.sync(b, "Missions")
	PlayerService.sync(b, "RunEnergy")
end)
SIM.advance(1)
click(rootB, "UniverseCard", 2) -- viaja a su universo
click(rootB, "UniverseCard", 1) -- abre Sistemas
local galaxyB = panelsB.GalaxyUI
click(find(galaxyB, "System_nebula"), "Unlock", 1.5)
assert(pb.Systems.nebula, "nebula no se desbloqueo desde la UI")
click(find(galaxyB, "System_nebula"), "Travel", 2.5)
assert(pb.ActiveSystem == "nebula")
SIM.assertNoErrors("render nebula")
-- (en el simulador los dos clientes comparten Workspace: se busca la carpeta del cliente activo)
local function star()
	for _, f in ipairs(ws:GetChildren()) do
		if f.Name == "ClientUniverse" and f:FindFirstChild("Static") then return f.Static:FindFirstChild("Star") end
	end
	return nil
end
assert(star(), "no se redibujo el sistema Nebula")
-- recorrer los 5 temas de sistema (incluye agujero negro, adornos y portales)
for _, sysId in ipairs({ "void", "celestial", "infinity", "solar" }) do
	server(function()
		pb.Systems[sysId] = true
		pb.Placed[sysId] = pb.Placed[sysId] or {}
		pb.Slots[sysId] = pb.Slots[sysId] or 3
		PlayerService.sync(b, "Systems") PlayerService.sync(b, "Placed") PlayerService.sync(b, "Slots")
	end)
	SIM.run(b, function() assert(RS.Remotes.SetActiveSystem:InvokeServer(sysId).Ok) end)
	SIM.advance(2)
	SIM.assertNoErrors("tema de sistema " .. sysId)
	assert(star(), "sin estrella en " .. sysId)
end
-- tienda: comprar y equipar cosmeticos de las dos categorias
click(rootB, "Shop")
local shopB = panelsB.ShopUI
click(find(shopB, "Cosmetic_orbit_gold"), "Action", 1.5)
assert(pb.Cosmetics.Equipped.OrbitColor == "orbit_gold", "cosmetico no equipado")
for _, tab in ipairs(SIM.findAll(shopB, function(i) return rawget(i, "__class") == "TextButton" and rawget(i, "__props").Text == "Aura de la estrella" end)) do
	SIM.click(tab)
end
SIM.advance(0.5)
for _, id in ipairs({ "aura_pulse", "aura_flare", "aura_halo" }) do
	click(find(shopB, "Cosmetic_" .. id), "Action", 2)
	SIM.assertNoErrors("aura " .. id)
end
click(shopB, "Close")
-- misiones: reclamar
click(rootB, "Missions")
local missionsB = panelsB.MissionUI
for _, t in ipairs(SIM.findAll(missionsB, function(i) return rawget(i, "__class") == "TextButton" and rawget(i, "__props").Text == "Diarias" end)) do
	SIM.click(t)
end
SIM.advance(0.5)
local sd = pb.Stardust
click(find(missionsB, "Mission1"), "Claim", 1)
assert(pb.Stardust > sd, "la mision no dio recompensa")
click(missionsB, "Close")
-- coleccion: seleccionar entradas descubiertas, no descubiertas y secretas
click(rootB, "Collection")
local collB = panelsB.CollectionUI
for _, id in ipairs({ "terra", "singularity", "zenith" }) do
	SIM.click(find(collB, "Entry_" .. id))
	SIM.advance(0.3)
	SIM.assertNoErrors("coleccion " .. id)
end
click(collB, "Close")
-- ascension completa por UI (doble confirmacion + animacion)
click(rootB, "Rebirth")
local rebirthB = panelsB.RebirthUI
click(rebirthB, "Ascend", 0.5)
local confirm = overlayB:FindFirstChild("Confirm")
assert(confirm, "no aparecio la segunda confirmacion")
assert(pb.Ascensions == 0, "ascendio sin confirmar")
click(confirm, "ConfirmButton", 1.5)
assert(pb.Ascensions == 1 and pb.Systems.nebula == nil, "la ascension no se aplico")
assert(overlayB:FindFirstChild("Ascension"), "no se mostro la animacion de ascension")
SIM.advance(6)
assert(overlayB:FindFirstChild("Ascension") == nil, "la animacion de ascension no termino")
SIM.assertNoErrors("ascension")
-- meteoritos: el cliente los muestra y se recogen
local Events
server(function() Events = require(SSS.Server.Services.EventService) end)
SIM.frameStep = 1
for _ = 1, 6 do
	local now = SIM.epoch + SIM.now
	SIM.advance((math.floor(now / 1800) + 1) * 1800 - now + 9)
	if Events.active() and Events.active().Id == "meteor_shower" then break end
end
SIM.frameStep = 1 / 20
SIM.advance(2)
SIM.assertNoErrors("evento")
local meteors = SIM.findAll(ws.EventEnvironment, function(i) return i.Name == "Meteor" end)
assert(#meteors > 0, "el cliente no mostro meteoritos")
local detector = meteors[1]:FindFirstChildOfClass("ClickDetector")
sd = pb.Stardust
SIM.spawnIn("client:72", function() SIM.fireIf(detector, "MouseClick", b) end)
SIM.advance(1)
assert(pb.Stardust > sd, "el meteorito no dio Stardust")
click(rootB, "EventChip")
SIM.advance(1)
click(panelsB.EventUI, "Close")
SIM.assertNoErrors("fin")
SIM.shutdown()
SIM.assertNoErrors("cierre")
print("OK client social")
