-- Environment: iluminacion, cielo y posprocesado del espacio profundo (azul noche, cian y violeta).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Assets = require(ReplicatedStorage:WaitForChild("Shared").Assets)

local Environment = {}

function Environment.apply()
	Lighting.ClockTime = 0
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromRGB(86, 92, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(96, 100, 150)
	Lighting.ColorShift_Top = Color3.fromRGB(120, 140, 255)
	Lighting.ColorShift_Bottom = Color3.fromRGB(90, 60, 160)
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.9
	Lighting.GlobalShadows = false
	Lighting.FogEnd = 100000
	Lighting.ExposureCompensation = 0.25

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") or child:IsA("PostEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end

	local sky = Instance.new("Sky")
	sky.Name = "DeepSpace"
	sky.CelestialBodiesShown = false
	sky.StarCount = 3000
	local box = Assets.Skybox
	if box then
		sky.SkyboxBk = Assets.url(box.Bk)
		sky.SkyboxDn = Assets.url(box.Dn)
		sky.SkyboxFt = Assets.url(box.Ft)
		sky.SkyboxLf = Assets.url(box.Lf)
		sky.SkyboxRt = Assets.url(box.Rt)
		sky.SkyboxUp = Assets.url(box.Up)
	end
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "Bloom"
	bloom.Intensity = 0.85
	bloom.Size = 30
	bloom.Threshold = 1.1
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "Grade"
	color.Contrast = 0.12
	color.Saturation = 0.18
	color.Brightness = 0.02
	color.TintColor = Color3.fromRGB(235, 238, 255)
	color.Parent = Lighting

	-- camara: permitir alejarse para contemplar el universo
	StarterPlayer.CameraMaxZoomDistance = 90
	StarterPlayer.CameraMinZoomDistance = 0.5
end

return Environment
