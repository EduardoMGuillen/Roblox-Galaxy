-- AssetCheck: comprueba al arrancar que las texturas/mallas del Creator Store cargan en este cliente.
-- Las que fallen se desactivan (Assets.disable) y el juego usa su alternativa con materiales integrados.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage:WaitForChild("Shared").Assets)

local AssetCheck = {}

AssetCheck.Failed = {} -- conjunto de URLs que no cargaron

function AssetCheck.run(timeout)
	local urls = { Assets.url(Assets.SphereMesh) }
	for _, group in ipairs({ Assets.Textures, Assets.Images }) do
		for _, id in pairs(group) do
			local url = Assets.url(id)
			if url ~= "" then table.insert(urls, url) end
		end
	end
	local done = false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(urls, function(contentId, status)
				if status == Enum.AssetFetchStatus.Failure then
					AssetCheck.Failed[contentId] = true
				end
			end)
		end)
		done = true
	end)
	local waited = 0
	while not done and waited < (timeout or 8) do
		waited = waited + task.wait(0.1)
	end
	local disabled = Assets.disable(AssetCheck.Failed)
	if disabled > 0 then
		warn("[PlanetCollector] " .. disabled .. " assets no cargaron; se usan materiales integrados en su lugar.")
	end
	return disabled
end

-- Oculta las superficies texturizadas (construidas por el servidor) cuyo asset fallo, para que se vea
-- la esfera de material que hay debajo.
function AssetCheck.fixModels(root)
	if next(AssetCheck.Failed) == nil then return end
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("SpecialMesh") and (AssetCheck.Failed[inst.TextureId] or AssetCheck.Failed[inst.MeshId]) then
			local part = inst.Parent
			if part and part:IsA("BasePart") then part.Transparency = 1 end
		elseif inst:IsA("Decal") and AssetCheck.Failed[inst.Texture] then
			inst.Transparency = 1
		end
	end
end

return AssetCheck
