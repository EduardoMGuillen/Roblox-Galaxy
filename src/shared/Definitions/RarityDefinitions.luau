-- RarityDefinitions: rarezas de planetas. La rareza se comunica con color + texto + icono (accesibilidad).
local Rarities = {}

Rarities.Order = { "common", "uncommon", "rare", "epic", "legendary", "mythic", "secret" }

Rarities.ById = {
	common = { Id = "common", Name = "Común", Order = 1, Color = Color3.fromRGB(120, 200, 255), Icon = "●", SellMult = 1 },
	uncommon = { Id = "uncommon", Name = "Poco común", Order = 2, Color = Color3.fromRGB(110, 230, 120), Icon = "◆", SellMult = 1.5 },
	rare = { Id = "rare", Name = "Raro", Order = 3, Color = Color3.fromRGB(70, 140, 255), Icon = "▲", SellMult = 2.5 },
	epic = { Id = "epic", Name = "Épico", Order = 4, Color = Color3.fromRGB(190, 90, 255), Icon = "✦", SellMult = 5 },
	legendary = { Id = "legendary", Name = "Legendario", Order = 5, Color = Color3.fromRGB(255, 190, 50), Icon = "★", SellMult = 12 },
	mythic = { Id = "mythic", Name = "Mítico", Order = 6, Color = Color3.fromRGB(255, 80, 200), Icon = "✪", SellMult = 30 },
	secret = { Id = "secret", Name = "Secreto", Order = 7, Color = Color3.fromRGB(255, 70, 70), Icon = "✸", SellMult = 80 },
}

function Rarities.get(id)
	return Rarities.ById[id]
end

function Rarities.atLeast(id, minId)
	return Rarities.ById[id].Order >= Rarities.ById[minId].Order
end

return Rarities
