-- VariantDefinitions: variantes visuales. La variante es una dimension distinta de la rareza del planeta.
local Variants = {}

Variants.Order = { "none", "shiny", "golden", "rainbow", "cosmic" }

Variants.ById = {
	none = { Id = "none", Name = "Normal", Chance = 0, Multiplier = 1, Color = Color3.fromRGB(200, 215, 235), Icon = "" },
	shiny = { Id = "shiny", Name = "Shiny", Chance = 0.04, Multiplier = 1.5, Color = Color3.fromRGB(190, 240, 255), Icon = "✨",
		Description = "Brillo especial y reflejo marcado." },
	golden = { Id = "golden", Name = "Golden", Chance = 0.02, Multiplier = 2, Color = Color3.fromRGB(255, 205, 70), Icon = "🟡",
		Description = "Superficie dorada con partículas cálidas." },
	rainbow = { Id = "rainbow", Name = "Rainbow", Chance = 0.005, Multiplier = 3.5, Color = Color3.fromRGB(255, 120, 220), Icon = "🌈",
		Description = "Iridiscencia multicolor de transición suave." },
	cosmic = { Id = "cosmic", Name = "Cosmic", Chance = 0.001, Multiplier = 6, Color = Color3.fromRGB(150, 110, 255), Icon = "🌌",
		Description = "Textura galáctica con partículas cósmicas." },
}

function Variants.get(id)
	return Variants.ById[id or "none"] or Variants.ById.none
end

-- Probabilidades reales de variante dado un multiplicador de suerte (mejoras + evento).
-- Devuelve tabla { variantId = probabilidad }, incluyendo "none"; siempre suma 1.
function Variants.chances(luckMultiplier)
	luckMultiplier = luckMultiplier or 1
	local out = {}
	local total = 0
	for _, id in ipairs(Variants.Order) do
		if id ~= "none" then
			local c = math.min(Variants.ById[id].Chance * luckMultiplier, 0.25)
			out[id] = c
			total = total + c
		end
	end
	out.none = 1 - total
	return out
end

-- Elige una variante a partir de un numero aleatorio uniforme en [0, 1).
function Variants.roll(randomUnit, luckMultiplier)
	local chances = Variants.chances(luckMultiplier)
	local acc = 0
	-- se recorre de la mas rara a la mas comun
	for i = #Variants.Order, 2, -1 do
		local id = Variants.Order[i]
		acc = acc + chances[id]
		if randomUnit < acc then return id end
	end
	return "none"
end

return Variants
