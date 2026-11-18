-- EventDefinitions: eventos cosmicos globales. El calendario se calcula con el tiempo del servidor:
-- cada ciclo de CycleSeconds empieza con un evento activo durante ActiveSeconds; el resto es descanso.
local Events = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Events.CycleSeconds = 1800
Events.ActiveSeconds = 600

Events.List = {
	{ Id = "meteor_shower", Name = "Meteor Shower", Icon = "☄️", Color = rgb(255, 170, 80),
		Description = "Caen meteoritos por todo el Hub y tu universo: tócalos para recoger Stardust.",
		Effects = { Meteors = true },
		Objective = { Type = "CollectMeteors", Goal = 15, Text = "Recoge %s meteoritos" }, RewardStardust = 40 },
	{ Id = "solar_eclipse", Name = "Solar Eclipse", Icon = "🌑", Color = rgb(170, 120, 255),
		Description = "La oscuridad favorece lo extraño: probabilidad de variantes x2.",
		Effects = { VariantLuck = 2 },
		Objective = { Type = "OpenCapsules", Goal = 15, Text = "Abre %s cápsulas durante el eclipse" }, RewardStardust = 40 },
	{ Id = "supernova", Name = "Supernova", Icon = "💥", Color = rgb(255, 230, 140),
		Description = "Una onda de energía recorre la galaxia: producción de Energy x2.",
		Effects = { Production = 2 },
		Objective = { Type = "PlacePlanets", Goal = 3, Text = "Coloca %s planetas durante la supernova" }, RewardStardust = 40 },
	{ Id = "cosmic_storm", Name = "Cosmic Storm", Icon = "🌩️", Color = rgb(90, 220, 255),
		Description = "La tormenta abarata la tecnología: todas las cápsulas cuestan un 25% menos.",
		Effects = { CapsuleDiscount = 0.75 },
		Objective = { Type = "OpenCapsules", Goal = 20, Text = "Abre %s cápsulas durante la tormenta" }, RewardStardust = 40 },
}

Events.ById = {}
for _, e in ipairs(Events.List) do
	Events.ById[e.Id] = e
end

-- Estado del calendario para un instante (segundos unix del servidor).
-- Devuelve { Active = def|nil, EndsAt, Next = def, NextStartsAt, CycleIndex }
function Events.schedule(now)
	local cycle = math.floor(now / Events.CycleSeconds)
	local start = cycle * Events.CycleSeconds
	local count = #Events.List
	local current = Events.List[(cycle % count) + 1]
	local nextDef = Events.List[((cycle + 1) % count) + 1]
	local out = { CycleIndex = cycle, Next = nextDef, NextStartsAt = start + Events.CycleSeconds }
	if now < start + Events.ActiveSeconds then
		out.Active = current
		out.EndsAt = start + Events.ActiveSeconds
	end
	return out
end

return Events
