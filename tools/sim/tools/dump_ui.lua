-- Vuelca el arbol de interfaz de un cliente (HUD y cada panel abierto) a JSON para dibujarlo con
-- tools/sim/preview_ui.py.  Uso: python3 tools/sim/run.py tools/sim/tools/dump_ui.lua
local SIM = ...
SIM.loadProject()
SIM.quiet = true
SIM.start()
SIM.advance(1)
-- tamaño de pantalla simulado: VIEWPORT=844x390 para un movil apaisado
local vw, vh = (os.getenv("VIEWPORT") or "1920x1080"):match("(%d+)x(%d+)")
SIM.setInternal(SIM.getService("Workspace").CurrentCamera, "ViewportSize", SIM.D.Vector2.new(tonumber(vw), tonumber(vh)))
local p = SIM.addPlayer(301, "Preview")
local q = SIM.addPlayer(302, "Astro")
SIM.advance(3)
local require = SIM.G.require
local SSS = SIM.getService("ServerScriptService")
local RS = SIM.getService("ReplicatedStorage")
local PlayerService, Inventory, Economy
SIM.run("server", function()
	PlayerService = require(SSS.Server.Services.PlayerService)
	Inventory = require(SSS.Server.Services.InventoryService)
	Economy = require(SSS.Server.Services.EconomyService)
	local list = { { "terra", "none" }, { "rocanox", "none" }, { "dunaris", "shiny" }, { "glaciera", "none" }, { "jovian", "golden" },
		{ "inferno", "none" }, { "amethyst", "none" }, { "aureon", "rainbow" }, { "nebulon", "none" }, { "shadowra", "none" },
		{ "quantum", "cosmic" }, { "singularity", "none" }, { "terra", "none" }, { "terra", "none" }, { "lunaris", "none" } }
	for _, item in ipairs(list) do Inventory.add(p, item[1], item[2], "preview") end
	Economy.add(p, "Energy", 1240000, "preview")
	Economy.add(p, "Stardust", 320, "preview")
	Economy.add(p, "Cores", 7, "preview")
	local profile = PlayerService.profile(p)
	profile.Upgrades.reactor = 6
	profile.Tutorial = 7
	PlayerService.sync(p, "Upgrades") PlayerService.sync(p, "Tutorial")
	Inventory.add(q, "terra", "none", "preview")
end)
SIM.run(p, function()
	local R = RS.Remotes
	R.Teleport:InvokeServer("universe")
	local n = 0
	for uid in pairs(PlayerService.profile(p).Planets) do
		n = n + 1
		if n <= 3 then task.wait(0.2) R.EquipPlanet:InvokeServer(uid, "solar", n) end
	end
end)
SIM.advance(3)
SIM.assertNoErrors("preparacion")

local function color(c) return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) } end
local function udim2(u) return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset } end
local function dump(inst)
	local cls = rawget(inst, "__class")
	local node = { class = cls, name = inst.Name, children = {} }
	if SIM.isA(cls, "GuiObject") then
		node.size = udim2(inst.Size)
		node.pos = udim2(inst.Position)
		node.anchor = { inst.AnchorPoint.X, inst.AnchorPoint.Y }
		node.visible = inst.Visible
		node.bg = color(inst.BackgroundColor3)
		node.bgT = inst.BackgroundTransparency
		node.z = inst.ZIndex
		node.order = inst.LayoutOrder
		if cls == "TextLabel" or cls == "TextButton" or cls == "TextBox" then
			node.text = inst.Text
			node.textSize = inst.TextSize
			node.textColor = color(inst.TextColor3)
			node.textT = inst.TextTransparency
			node.ax = inst.TextXAlignment.Name
			node.ay = inst.TextYAlignment.Name
			node.wrap = inst.TextWrapped
			node.scaled = inst.TextScaled
		end
		if cls == "ScrollingFrame" then node.clip = true end
		if cls == "ViewportFrame" then node.viewport = true end
	elseif cls == "ScreenGui" then
		node.enabled = inst.Enabled
		node.inset = not inst.IgnoreGuiInset
		node.displayOrder = inst.DisplayOrder
	elseif cls == "UIListLayout" then
		node.dir = inst.FillDirection.Name
		node.padding = inst.Padding.Offset
		node.ha = inst.HorizontalAlignment.Name
		node.va = inst.VerticalAlignment.Name
	elseif cls == "UIGridLayout" then
		node.cell = udim2(inst.CellSize)
		node.cellPad = udim2(inst.CellPadding)
	elseif cls == "UIPadding" then
		node.pad = { inst.PaddingLeft.Offset, inst.PaddingTop.Offset, inst.PaddingRight.Offset, inst.PaddingBottom.Offset }
	elseif cls == "UIScale" then
		node.scale = inst.Scale
	elseif cls == "UICorner" then
		node.radius = inst.CornerRadius.Offset
	elseif cls == "UIStroke" then
		node.strokeColor = color(inst.Color)
		node.thickness = inst.Thickness
		node.strokeT = inst.Transparency
		node.border = inst.ApplyStrokeMode == Enum.ApplyStrokeMode.Border
	elseif cls == "UIGradient" then
		local k = inst.Color.Keypoints
		node.g0 = color(k[1].Value)
		node.g1 = color(k[#k].Value)
		node.rot = inst.Rotation
	end
	for _, c in ipairs(inst:GetChildren()) do
		local ccls = rawget(c, "__class")
		if SIM.isA(ccls, "GuiBase2d") or ccls:sub(1, 2) == "UI" then
			table.insert(node.children, dump(c))
		end
	end
	if #node.children == 0 then node.children = nil end
	return node
end

local gui = p.PlayerGui
local shots = {}
local function shot(name)
	local screens = {}
	for _, sg in ipairs(gui:GetChildren()) do
		if rawget(sg, "__class") == "ScreenGui" then table.insert(screens, dump(sg)) end
	end
	table.insert(shots, { name = name, screens = screens })
end
local root = gui.MainHUD.Root
shot("hud_universe")
local order = { "Inventory", "OpenCapsule", "Upgrades", "Rebirth", "Collection", "Missions", "Stats", "Shop", "Teleport", "Leaderboard",
	"EventChip", "Settings", "Trading" }
for _, name in ipairs(order) do
	SIM.click(root:FindFirstChild(name, true))
	SIM.advance(0.6)
	if name == "Inventory" then
		local card = gui.Panels.Root.InventoryUI:FindFirstChild("PlanetCard", true)
		for _, c in ipairs(SIM.findAll(gui.Panels.Root.InventoryUI, function(i) return i.Name:match("^Card_") ~= nil end)) do card = c break end
		if card then SIM.click(card) SIM.advance(0.3) end
	end
	shot(name)
end
SIM.click(root:FindFirstChild("UniverseCard", true))
SIM.advance(0.6)
shot("Galaxy")
local close = gui.Panels.Root.GalaxyUI:FindFirstChild("Close", true)
SIM.click(close)
SIM.advance(0.3)
-- capsula abierta (resultado)
SIM.click(root:FindFirstChild("OpenCapsule", true))
SIM.advance(0.5)
SIM.click(gui.Panels.Root.CapsuleUI:FindFirstChild("Open1", true))
SIM.advance(4)
shot("capsule_result")
SIM.assertNoErrors("volcado")
local f = assert(io.open(SIM_ROOT .. "/tools/sim/data/ui_dump.json", "w"))
f:write(SIM.jsonEncode(shots))
f:close()
print("capturas de UI volcadas: " .. #shots)
