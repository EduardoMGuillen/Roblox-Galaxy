-- EconomyService: unica puerta de entrada para modificar monedas (Energy, Stardust, Cores).
-- Valida cantidades, evita negativos/overflow, registra transacciones criticas y aplica el tick de
-- produccion agregado (un calculo por jugador y tick, nunca por planeta y frame).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Progression = require(Shared.Progression)
local Config = Defs.Config

local EconomyService = {}
local S = nil

local CURRENCIES = { Energy = true, Stardust = true, Cores = true }
local log = {}
local LOG_MAX = 300

local function isFinite(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function record(player, currency, delta, reason)
	table.insert(log, { Time = os.time(), UserId = player.UserId, Currency = currency, Delta = delta, Reason = reason })
	if #log > LOG_MAX then table.remove(log, 1) end
end

function EconomyService.getLog()
	return log
end

-- Suma moneda. earned = true cuenta como Energy generada (estadisticas y misiones).
function EconomyService.add(player, currency, amount, reason, earned)
	local profile = S.PlayerService.profile(player)
	if not profile or not CURRENCIES[currency] or not isFinite(amount) or amount <= 0 then return false end
	if currency ~= "Energy" then amount = math.floor(amount) end
	if amount <= 0 then return false end
	profile[currency] = math.min(Config.Economy.MaxCurrency, profile[currency] + amount)
	if currency == "Energy" and earned then
		profile.RunEnergy = math.min(Config.Economy.MaxCurrency, profile.RunEnergy + amount)
		profile.TotalEnergy = math.min(Config.Economy.MaxCurrency, profile.TotalEnergy + amount)
		S.MissionService.progress(player, "EarnEnergy", amount)
	end
	if reason ~= "production" then record(player, currency, amount, reason) end
	S.PlayerService.sync(player, currency)
	return true
end

function EconomyService.canAfford(player, currency, amount)
	local profile = S.PlayerService.profile(player)
	return profile ~= nil and CURRENCIES[currency] == true and isFinite(amount) and amount >= 0 and profile[currency] >= amount
end

-- Gasta moneda de forma atomica. Devuelve false si no alcanza (nunca deja saldo negativo).
function EconomyService.spend(player, currency, amount, reason)
	if not EconomyService.canAfford(player, currency, amount) then return false end
	local profile = S.PlayerService.profile(player)
	profile[currency] = math.max(0, profile[currency] - amount)
	record(player, currency, -amount, reason)
	S.PlayerService.sync(player, currency)
	return true
end

-- Ganancias sin conexion: tiempo desde el ultimo guardado, validado y con tope.
local function grantOffline(player, session, info)
	local profile = session.Profile
	if info.SessionOnly or info.IsNew or profile.LastSave <= 0 then return end
	local elapsed = os.time() - profile.LastSave
	if elapsed < Config.Economy.OfflineMinSeconds then return end -- incluye relojes inconsistentes (negativo)
	local capped = math.min(elapsed, Progression.offlineCapSeconds(profile))
	local rate = Progression.production(profile, 1).Total
	local amount = math.floor(rate * capped * Progression.offlineRate(profile))
	if amount <= 0 then return end
	EconomyService.add(player, "Energy", amount, "offline", true)
	session.Derived._Session.Offline = { Seconds = capped, Away = elapsed, Energy = amount }
end

function EconomyService.Init(services)
	S = services
	S.PlayerService.onLoaded(grantOffline)
end

function EconomyService.Start()
	task.spawn(function()
		local last = os.clock()
		local counter = 0
		while true do
			task.wait(Config.Economy.TickSeconds)
			local now = os.clock()
			local dt = math.min(now - last, 5)
			last = now
			counter = counter + 1
			for player, session in pairs(S.PlayerService.all()) do
				local production = session.Derived._Production
				local rate = production and production.Total or 0
				if rate > 0 then
					EconomyService.add(player, "Energy", rate * dt, "production", true)
					if rate > session.Profile.Stats.BestRate then
						session.Profile.Stats.BestRate = rate
					end
				end
				if counter % 5 == 0 then
					S.PlayerService.sync(player, "RunEnergy")
					S.PlayerService.sync(player, "TotalEnergy")
					S.PlayerService.updateLeaderstats(player)
				end
			end
		end
	end)
end

return EconomyService
