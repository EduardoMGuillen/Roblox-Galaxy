-- CameraController: "vista orbital" opcional para contemplar el sistema completo desde arriba.
-- La camara normal del personaje se restaura al salir o al cambiar de lugar.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Camera = {}
local ctx = nil
local active = false
local angle = 0
local zoom = 1

local ZOOMS = { { 340, 190 }, { 230, 110 }, { 430, 330 } }

local function stop()
	if not active then return end
	active = false
	RunService:UnbindFromRenderStep("PlanetCollectorOverview")
	local camera = Workspace.CurrentCamera
	if camera then camera.CameraType = Enum.CameraType.Custom end
end

local function step(dt)
	local center = ctx.Universe and ctx.Universe.currentCenter()
	local camera = Workspace.CurrentCamera
	if not center or not camera then
		stop()
		return
	end
	angle = angle + dt * 0.06
	local z = ZOOMS[zoom]
	local pos = center + Vector3.new(math.sin(angle) * z[1], z[2], math.cos(angle) * z[1])
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(pos, center)
end

function Camera.isOverview()
	return active
end

-- Alterna: normal -> vista orbital -> zoom cercano -> zoom lejano -> normal
function Camera.toggleOverview()
	if not active then
		if not (ctx.Universe and ctx.Universe.currentCenter()) then return end
		active = true
		zoom = 1
		RunService:BindToRenderStep("PlanetCollectorOverview", Enum.RenderPriority.Camera.Value + 1, step)
		ctx.UI.toast("Vista orbital: pulsa otra vez para cambiar el zoom y salir.", "info")
	elseif zoom < #ZOOMS then
		zoom = zoom + 1
	else
		stop()
	end
end

function Camera.init(context)
	ctx = context
	ctx.Camera = Camera
	ctx.State.on("_Session", function()
		if not ctx.State.locationOwner() then stop() end
	end)
end

return Camera
