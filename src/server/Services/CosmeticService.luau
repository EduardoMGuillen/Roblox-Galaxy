-- CosmeticService: compra (con Stardust) y equipamiento de cosmeticos del universo. Sin efecto economico.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Net = require(script.Parent.Parent.Net)

local CosmeticService = {}
local S = nil

local function buy(player, cosmeticId)
	local profile = S.PlayerService.profile(player)
	local def = Defs.Cosmetics.ById[cosmeticId]
	if not def then return false, "Cosmético desconocido." end
	if profile.Cosmetics.Owned[cosmeticId] then return false, "Ya tienes ese cosmético." end
	if def.Price > 0 and not S.EconomyService.spend(player, "Stardust", def.Price, "cosmetic:" .. cosmeticId) then
		return false, "No tienes suficiente Stardust."
	end
	profile.Cosmetics.Owned[cosmeticId] = true
	S.PlayerService.sync(player, "Cosmetics", "Owned", cosmeticId)
	return true, { Id = cosmeticId }
end

local function equip(player, cosmeticId)
	local profile = S.PlayerService.profile(player)
	local def = Defs.Cosmetics.ById[cosmeticId]
	if not def then return false, "Cosmético desconocido." end
	if not profile.Cosmetics.Owned[cosmeticId] then return false, "Aún no tienes ese cosmético." end
	profile.Cosmetics.Equipped[def.Category] = cosmeticId
	S.PlayerService.sync(player, "Cosmetics", "Equipped", def.Category)
	S.UniverseService.publish(player)
	return true, { Id = cosmeticId }
end

function CosmeticService.Init(services)
	S = services
	Net.handle("BuyCosmetic", { Args = { { "string", Max = 32 } }, Cooldown = 0.3 }, buy)
	Net.handle("EquipCosmetic", { Args = { { "string", Max = 32 } }, Cooldown = 0.2 }, equip)
end

function CosmeticService.Start() end

return CosmeticService
