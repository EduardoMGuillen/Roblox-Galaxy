-- Cliente completo: arranque, HUD, todos los paneles, y flujo real de juego pulsando botones
-- (abrir capsula, viajar, colocar, mejorar, vender). Cualquier error de API de Roblox en la
-- interfaz (propiedad inexistente, tipo incorrecto, enum mal escrito) hace fallar esta prueba.
local SIM = ...
SIM.loadProject()
SIM.quiet = true
SIM.start()
SIM.advance(1)
local p = SIM.addPlayer(501, "Lola")
SIM.advance(3)
SIM.assertNoErrors("arranque del cliente")

local gui = p.PlayerGui
local hudGui = gui:FindFirstChild("MainHUD")
local panels = gui:FindFirstChild("Panels") and gui.Panels.Root
local overlay = gui:FindFirstChild("Overlay") and gui.Overlay.Root
assert(hudGui and panels and overlay, "no se crearon las ScreenGui")
local root = hudGui.Root

local function find(container, name)
	local inst = container:FindFirstChild(name, true)
	assert(inst, "no existe el elemento de UI: " .. name)
	return inst
end
local function click(container, name)
	local b = find(container, name)
	assert(SIM.isVisible(b), "el boton no es visible: " .. name)
	SIM.click(b)
	SIM.advance(0.6)
	SIM.assertNoErrors("click " .. name)
	return b
end
local function panel(name)
	local f = panels:FindFirstChild(name)
	assert(f and f.Visible, "panel no abierto: " .. name)
	return f
end
local function text(label) return rawget(label, "__props").Text end

-- HUD inicial
assert(text(find(root, "Energy"):FindFirstChildOfClass("TextLabel")) ~= nil)
assert(find(root, "Tutorial").Visible, "el tutorial deberia estar visible para un jugador nuevo")
click(root, "Continue") -- bienvenida
SIM.advance(0.5)

-- abrir todos los paneles desde el HUD
local hudButtons = { Inventory = "InventoryUI", Collection = "CollectionUI", Missions = "MissionUI", Trading = "TradingUI", Settings = "SettingsUI",
	Upgrades = "UpgradeUI", Teleport = "TeleportUI", Shop = "ShopUI", Stats = "StatsUI", Leaderboard = "LeaderboardUI", Rebirth = "RebirthUI",
	EventChip = "EventUI", OpenCapsule = "CapsuleUI" }
for button, panelName in pairs(hudButtons) do
	click(root, button)
	local f = panel(panelName)
	-- pulsar todas las pestañas / filtros del panel
	for _, b in ipairs(SIM.findAll(f, function(i) return SIM.isA(rawget(i, "__class"), "TextButton") and i.Name ~= "Close" end)) do
		local n = b.Name
		if (n == "TextButton" or n == "StateFilter" or n == "RarityFilter" or n == "SellMode") and SIM.isVisible(b) and b.Parent ~= nil then
			SIM.click(b)
			SIM.advance(0.2)
			SIM.assertNoErrors("pestaña en " .. panelName)
		end
	end
	click(f, "Close")
	assert(not f.Visible, "el panel no se cerro: " .. panelName)
end

-- flujo: abrir capsula con los botones reales
click(root, "OpenCapsule")
local capsuleUI = panel("CapsuleUI")
for _, def in ipairs({ "solar", "nebula", "galaxy", "cosmic", "infinity", "starter" }) do
	click(capsuleUI, "Capsule_" .. def)
end
click(capsuleUI, "Open1")
SIM.advance(4)
SIM.assertNoErrors("animacion de capsula")
local opening = overlay:FindFirstChild("CapsuleOpening")
assert(opening, "no aparecio la animacion de apertura")
click(opening, "Keep")
SIM.advance(1)
assert(overlay:FindFirstChild("CapsuleOpening") == nil, "la animacion no se cerro")
-- segunda capsula: saltar animacion tocando y elegir Colocar
click(capsuleUI, "Open1")
SIM.advance(0.2)
opening = overlay:FindFirstChild("CapsuleOpening")
local skip = opening and opening:FindFirstChild("Skip")
if skip then SIM.click(skip) end
SIM.advance(3)
SIM.assertNoErrors("saltar animacion")
opening = overlay:FindFirstChild("CapsuleOpening")
click(opening, "Place")
SIM.advance(1)
local inventory = panel("InventoryUI")
local picker = inventory:FindFirstChild("SlotPicker")
assert(picker, "no se abrio el selector de orbita")
click(picker, "Slot1")
SIM.advance(1)
SIM.assertNoErrors("colocar desde la UI")

-- viajar al universo y comprobar el render del sistema
if inventory.Visible then click(inventory, "Close") end
click(root, "UniverseCard")
SIM.advance(2)
SIM.assertNoErrors("viaje al universo")
local ws = SIM.getService("Workspace")
local cu = ws:FindFirstChild("ClientUniverse")
assert(cu and cu:FindFirstChild("Static") and cu.Static:FindFirstChild("Star"), "no se dibujo la estrella")
local planetsFolder = cu:FindFirstChild("Planets")
local planetModels = SIM.findAll(planetsFolder, function(i) return rawget(i, "__class") == "Model" end)
assert(#planetModels == 1, "deberia haber 1 planeta en orbita, hay " .. #planetModels)
local orbitsPanel = find(root, "OrbitsPanel")
assert(orbitsPanel.Visible, "el panel de orbitas deberia verse en el universo")
SIM.advance(2) -- frames de orbita
SIM.assertNoErrors("animacion orbital")
-- el planeta se mueve
local body = planetModels[1].PrimaryPart
local pos1 = body.Position
SIM.advance(3)
assert((body.Position - pos1).Magnitude > 0.5, "el planeta no orbita")
-- colocar el segundo planeta desde el panel de orbitas
click(orbitsPanel, "Slot2")
inventory = panel("InventoryUI")
local cards = SIM.findAll(inventory, function(i) return i.Name:match("^Card_") ~= nil end)
assert(#cards >= 1, "no hay planetas libres en el inventario")
SIM.click(cards[1])
SIM.advance(0.5)
click(inventory, "Equip")
SIM.advance(1.5)
SIM.assertNoErrors("colocar segundo planeta")
planetModels = SIM.findAll(cu:FindFirstChild("Planets"), function(i) return rawget(i, "__class") == "Model" end)
assert(#planetModels == 2, "deberia haber 2 planetas en orbita, hay " .. #planetModels)
-- vista orbital
click(orbitsPanel, "CameraToggle")
SIM.advance(1)
click(orbitsPanel, "CameraToggle")
click(orbitsPanel, "CameraToggle")
click(orbitsPanel, "CameraToggle")
SIM.assertNoErrors("vista orbital")
-- clic en un planeta (raycast simulado)
SIM.raycastHandler = function() return { Instance = planetModels[1].PrimaryPart, Position = planetModels[1].PrimaryPart.Position } end
local uis = SIM.getService("UserInputService")
SIM.spawnIn("client:501", function()
	SIM.fireIf(uis, "InputBegan", { UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.E }, false)
end)
SIM.advance(1)
SIM.assertNoErrors("clic en planeta")
inventory = panel("InventoryUI")
click(inventory, "Unequip")
SIM.advance(1)
click(inventory, "Lock")
click(inventory, "Lock")
click(inventory, "Close")
SIM.raycastHandler = nil

-- mejoras: esperar energia y comprar
SIM.frameStep = 0.5
SIM.advance(240)
SIM.frameStep = 1 / 20
SIM.assertNoErrors("tiempo de juego")
click(root, "Upgrades")
local upgrades = panel("UpgradeUI")
for _, b in ipairs(SIM.findAll(upgrades, function(i) return rawget(i, "__class") == "TextButton" and text(i):find("Con Energy") ~= nil end)) do
	SIM.click(b)
	SIM.advance(0.3)
end
local reactor = find(upgrades, "Upgrade_reactor")
click(reactor, "Buy")
SIM.advance(1)
click(upgrades, "Close")
assert(not find(root, "Tutorial").Visible, "el tutorial deberia haber terminado")

-- ajustes: alternar todo
click(root, "Settings")
local settings = panel("SettingsUI")
for _, row in ipairs(SIM.findAll(settings, function(i) return i.Name:match("^Setting_") ~= nil end)) do
	local toggle = row:FindFirstChildOfClass("TextButton")
	SIM.click(toggle)
	SIM.advance(0.4)
	SIM.assertNoErrors("ajuste " .. row.Name)
	SIM.click(toggle)
	SIM.advance(0.4)
end
click(settings, "Close")

-- prompts del mundo
local pps = SIM.getService("ProximityPromptService")
for _, prompt in ipairs(SIM.findAll(ws, function(i) return rawget(i, "__class") == "ProximityPrompt" end)) do
	SIM.spawnIn("client:501", function() SIM.fireIf(pps, "PromptTriggered", prompt, p) end)
	SIM.advance(1.2)
	SIM.assertNoErrors("prompt " .. tostring(prompt:GetAttribute("Action")))
end
SIM.advance(2)

-- volver al hub y cerrar
SIM.run(p, function()
	local r = SIM.getService("ReplicatedStorage").Remotes.Teleport:InvokeServer("hub")
	assert(r.Ok)
end)
SIM.advance(3)
assert(cu:FindFirstChild("Static") == nil, "el universo deberia dejar de dibujarse en el Hub")
SIM.assertNoErrors("fin")
print("OK client")
