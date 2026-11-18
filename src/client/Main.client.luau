-- Main (cliente): arranca el estado replicado y los controladores de PLANET COLLECTOR.
-- El cliente gestiona interfaz, camara, entrada, efectos y animaciones no autoritativas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = script.Parent

local State = require(Client.ClientState)
local AssetCheck = require(Client.AssetCheck)
State.init()
AssetCheck.run(8)

local ctx = {
	State = State,
	Player = Players.LocalPlayer,
	Defs = require(Shared.Defs),
	Format = require(Shared.Util.Format),
	Progression = require(Shared.Progression),
	PlanetVisual = require(Shared.PlanetVisual),
	Layout = require(Shared.UniverseLayout),
	Kit = require(Client.UI.Kit),
	Theme = require(Client.UI.Theme),
}

-- El orden importa: la interfaz primero; el resto se apoya en ella.
local ORDER = { "UIController", "AudioController", "EffectsController", "CapsuleController", "TradeController", "CameraController",
	"UniverseController", "HubController", "TutorialController" }
for _, name in ipairs(ORDER) do
	local controller = require(Client.Controllers[name])
	local ok, err = pcall(controller.init, ctx)
	if not ok then
		warn("[PlanetCollector] error al iniciar " .. name .. ": " .. tostring(err))
	end
end

AssetCheck.fixModels(game:GetService("Workspace"))

-- la mochila clasica de Roblox no se usa en este juego
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- avisos de sesion
local session = State.Data._Session or {}
if session.Offline then
	ctx.Effects.offline(session.Offline)
end
if session.SessionOnly then
	ctx.UI.toast("Modo de prueba: el progreso no se guardará (activa «Enable Studio Access to API Services»).", "error")
end
