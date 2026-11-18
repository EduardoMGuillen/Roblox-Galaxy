-- MissionService: misiones diarias/semanales y objetivo del evento activo. Progreso y reclamacion
-- validados en servidor. Sin castigos por perder dias: simplemente se generan misiones nuevas.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Progression = require(Shared.Progression)
local Net = require(script.Parent.Parent.Net)
local Missions = Defs.Missions

local MissionService = {}
local S = nil
local dirty = {}

local function dayKey(now)
	return math.floor(now / 86400)
end

local function weekKey(now)
	-- el dia 0 de la epoca unix fue jueves; +3 hace que la semana empiece en lunes
	return math.floor((dayKey(now) + 3) / 7)
end

local function generate(player, profile, scope, key, count)
	local pool = Missions.ByScope[scope]
	local rng = Random.new(player.UserId * 31 + key * 7919 + (scope == "weekly" and 17 or 0))
	local order = {}
	for i = 1, #pool do
		order[i] = i
	end
	rng:Shuffle(order)
	local tier = Progression.tier(profile)
	local production = Progression.production(profile, 1).Total
	local list = {}
	for i = 1, math.min(count, #order) do
		local template = pool[order[i]]
		list[i] = {
			Id = template.Id,
			Goal = template.Goal(tier, production),
			Progress = 0,
			Claimed = false,
			Stardust = template.Stardust(tier),
			Energy = math.floor(math.max(250, production * Missions.EnergyRewardSeconds[scope])),
		}
	end
	return list
end

-- Genera misiones si cambio el dia/semana. Devuelve true si hubo cambios.
function MissionService.refresh(player)
	local profile = S.PlayerService.profile(player)
	if not profile then return false end
	local now = os.time()
	local m = profile.Missions
	local changed = false
	if m.DailyKey ~= dayKey(now) or #m.Daily == 0 then
		m.DailyKey = dayKey(now)
		m.Daily = generate(player, profile, "daily", m.DailyKey, Missions.DailyCount)
		changed = true
	end
	if m.WeeklyKey ~= weekKey(now) or #m.Weekly == 0 then
		m.WeeklyKey = weekKey(now)
		m.Weekly = generate(player, profile, "weekly", m.WeeklyKey, Missions.WeeklyCount)
		changed = true
	end
	local schedule = Defs.Events.schedule(now)
	if m.EventKey ~= schedule.CycleIndex then
		m.EventKey = schedule.CycleIndex
		m.EventProgress = 0
		m.EventClaimed = false
		changed = true
	end
	if changed then S.PlayerService.sync(player, "Missions") end
	return changed
end

function MissionService.progress(player, missionType, amount)
	local profile = S.PlayerService.profile(player)
	if not profile or amount <= 0 then return end
	local m = profile.Missions
	local changed = false
	for _, list in ipairs({ m.Daily, m.Weekly }) do
		for _, mission in ipairs(list) do
			local template = Missions.ById[mission.Id]
			if template and template.Type == missionType and mission.Progress < mission.Goal then
				mission.Progress = math.min(mission.Goal, mission.Progress + amount)
				changed = true
			end
		end
	end
	local active = S.EventService.active()
	if active and active.Objective.Type == missionType and m.EventKey == S.EventService.cycleIndex()
		and m.EventProgress < active.Objective.Goal then
		m.EventProgress = math.min(active.Objective.Goal, m.EventProgress + amount)
		changed = true
	end
	if changed then dirty[player] = true end
end

local function claim(player, scope, index)
	local profile = S.PlayerService.profile(player)
	local m = profile.Missions
	if scope == "event" then
		local active = S.EventService.active()
		if not active or m.EventKey ~= S.EventService.cycleIndex() then return false, "No hay evento activo." end
		if m.EventClaimed then return false, "Ya reclamaste esta recompensa." end
		if m.EventProgress < active.Objective.Goal then return false, "Objetivo sin completar." end
		m.EventClaimed = true
		S.PlayerService.sync(player, "Missions")
		S.EconomyService.add(player, "Stardust", active.RewardStardust, "event:" .. active.Id)
		MissionService.progress(player, "EventParticipation", 1)
		return true, { Stardust = active.RewardStardust }
	end
	local list = (scope == "daily" and m.Daily) or (scope == "weekly" and m.Weekly) or nil
	if not list then return false, "Misión inválida." end
	local mission = list[index]
	if not mission then return false, "Misión inválida." end
	if mission.Claimed then return false, "Ya reclamaste esta misión." end
	if mission.Progress < mission.Goal then return false, "Misión sin completar." end
	mission.Claimed = true
	S.PlayerService.sync(player, "Missions")
	S.EconomyService.add(player, "Stardust", mission.Stardust, "mission:" .. mission.Id)
	S.EconomyService.add(player, "Energy", mission.Energy, "mission:" .. mission.Id, false)
	return true, { Stardust = mission.Stardust, Energy = mission.Energy }
end

function MissionService.Init(services)
	S = services
	S.PlayerService.onLoaded(function(player)
		MissionService.refresh(player)
	end)
	S.PlayerService.onLeaving(function(player)
		dirty[player] = nil
	end)
	Net.handle("ClaimMission", { Args = { { "string", Max = 12 }, { "integer", Min = 1, Max = 10 } }, Cooldown = 0.2 }, claim)
end

function MissionService.Start()
	task.spawn(function()
		local ticks = 0
		while true do
			task.wait(2)
			ticks = ticks + 1
			for player in pairs(dirty) do
				S.PlayerService.sync(player, "Missions")
			end
			dirty = {}
			if ticks % 15 == 0 then
				for player in pairs(S.PlayerService.all()) do
					MissionService.refresh(player)
				end
			end
		end
	end)
end

return MissionService
