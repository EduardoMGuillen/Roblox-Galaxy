local UniverseBuilder = {}
function UniverseBuilder.build(index, center, ownerName)
	local model = Instance.new("Model")
	model.Name = "Universe_" .. tostring(index)
	model.Parent = workspace:FindFirstChild("PlayerUniverseZones")
	return model
end
return UniverseBuilder
