-- UpgradeService: costes, niveles y efectos de mejoras. El precio siempre se calcula en el servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Net = require(script.Parent.Parent.Net)

local UpgradeService = {}
local S = nil

local function purchase(player, upgradeId)
	local profile = S.PlayerService.profile(player)
	local def = Defs.Upgrades.ById[upgradeId]
	if not def then return false, "Mejora desconocida." end
	local level = Defs.Upgrades.level(profile, upgradeId)
	if level >= def.MaxLevel then return false, "Esa mejora ya está al máximo." end
	local cost = def.Cost(level)
	if not S.EconomyService.spend(player, def.Currency, cost, "upgrade:" .. upgradeId) then
		if def.Currency == "Cores" then return false, "No tienes suficientes Cosmic Cores." end
		return false, "No tienes suficiente Energy."
	end
	profile.Upgrades[upgradeId] = level + 1
	S.PlayerService.sync(player, "Upgrades", upgradeId)
	profile.Stats.UpgradesBought = profile.Stats.UpgradesBought + 1
	S.MissionService.progress(player, "BuyUpgrades", 1)
	S.PlayerService.tutorialEvent(player, "buy_upgrade")
	S.ProductionService.recalc(player)
	return true, { Level = level + 1, Spent = cost }
end

function UpgradeService.Init(services)
	S = services
	Net.handle("PurchaseUpgrade", { Args = { { "string", Max = 24 } }, Cooldown = 0.08 }, purchase)
end

function UpgradeService.Start() end

return UpgradeService
