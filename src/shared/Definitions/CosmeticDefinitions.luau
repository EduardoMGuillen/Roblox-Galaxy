-- CosmeticDefinitions: personalizacion del universo comprada con Stardust. Nunca afecta a la economia.
local Cosmetics = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Cosmetics.Categories = {
	{ Id = "OrbitColor", Name = "Color de órbitas" },
	{ Id = "StarAura", Name = "Aura de la estrella" },
}

Cosmetics.List = {
	{ Id = "orbit_system", Category = "OrbitColor", Name = "Del sistema", Price = 0, Description = "Usa el color propio de cada sistema." },
	{ Id = "orbit_cyan", Category = "OrbitColor", Name = "Cian", Price = 40, Color = rgb(80, 220, 255) },
	{ Id = "orbit_violet", Category = "OrbitColor", Name = "Violeta", Price = 60, Color = rgb(180, 110, 255) },
	{ Id = "orbit_emerald", Category = "OrbitColor", Name = "Esmeralda", Price = 80, Color = rgb(90, 255, 160) },
	{ Id = "orbit_crimson", Category = "OrbitColor", Name = "Carmesí", Price = 80, Color = rgb(255, 80, 100) },
	{ Id = "orbit_gold", Category = "OrbitColor", Name = "Oro", Price = 150, Color = rgb(255, 205, 90) },
	{ Id = "orbit_white", Category = "OrbitColor", Name = "Blanco puro", Price = 200, Color = rgb(245, 245, 255) },
	{ Id = "aura_default", Category = "StarAura", Name = "Corona estándar", Price = 0, Description = "El halo natural de la estrella." },
	{ Id = "aura_pulse", Category = "StarAura", Name = "Pulso", Price = 120, Description = "Ondas de luz que laten lentamente.", Style = "pulse" },
	{ Id = "aura_flare", Category = "StarAura", Name = "Llamaradas", Price = 200, Description = "Lenguas de plasma alrededor de la estrella.", Style = "flare" },
	{ Id = "aura_halo", Category = "StarAura", Name = "Halo doble", Price = 300, Description = "Dos anillos de luz cruzados.", Style = "halo" },
}

Cosmetics.ById = {}
Cosmetics.ByCategory = {}
Cosmetics.Defaults = { OrbitColor = "orbit_system", StarAura = "aura_default" }
for _, c in ipairs(Cosmetics.List) do
	Cosmetics.ById[c.Id] = c
	if not Cosmetics.ByCategory[c.Category] then Cosmetics.ByCategory[c.Category] = {} end
	table.insert(Cosmetics.ByCategory[c.Category], c)
end

return Cosmetics
