-- EventService: eventos cosmicos globales calculados con el tiempo del servidor (sin temporizadores
-- falsos). Expone los modificadores activos y gestiona los meteoritos de Meteor Shower.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Net = require(script.Parent.Parent.Net)
local Events = Defs.Events

local EventService = {}
local S = nil

local current = nil -- definicion del evento activo o nil
local schedule = Events.schedule(os.time())
local rng = Random.new()
local meteorCounter = 0

local METEOR_INTERVAL = 4
local METEOR_LIFETIME = 14
local METEOR_MAX_ACTIVE = 5

function EventService.active()
	return current
end

function EventService.cycleIndex()
	return schedule.CycleIndex
end

function EventService.productionMultiplier()
	return (current and current.Effects.Production) or 1
end

function EventService.variantLuck()
	return (current and current.Effects.VariantLuck) or 1
end

function EventService.capsuleDiscount()
	return (current and current.Effects.CapsuleDiscount) or 1
end

function EventService.view()
	return {
		Id = current and current.Id or nil,
		EndsAt = schedule.EndsAt,
		NextId = schedule.Next.Id,
		NextStartsAt = schedule.NextStartsAt,
		Cycle = schedule.CycleIndex,
	}
end

local function broadcast()
	for player in pairs(S.PlayerService.all()) do
		S.PlayerService.setDerived(player, "_Event", EventService.view())
	end
end

local function update()
	local newSchedule = Events.schedule(os.time())
	local newActive = newSchedule.Active
	local changed = newActive ~= current or newSchedule.CycleIndex ~= schedule.CycleIndex
	schedule = newSchedule
	if changed then
		local previous = current
		current = newActive
		for player in pairs(S.PlayerService.all()) do
			S.MissionService.refresh(player)
		end
		broadcast()
		if (previous and previous.Effects.Production) or (current and current.Effects.Production) then
			S.ProductionService.recalcAll()
		end
		if current then
			Net.fireAll("Notify", { Kind = "event", Text = current.Icon .. " ¡Evento " .. current.Name .. "! " .. current.Description })
		end
	end
end

local function spawnMeteors()
	if not current or not current.Effects.Meteors then return end
	local now = os.clock()
	for player, session in pairs(S.PlayerService.all()) do
		local meteors = session.Meteors
		if not meteors then
			meteors = {}
			session.Meteors = meteors
		end
		local count = 0
		for id, expires in pairs(meteors) do
			if expires < now then meteors[id] = nil else count = count + 1 end
		end
		if count < METEOR_MAX_ACTIVE then
			meteorCounter = meteorCounter + 1
			local id = "m" .. tostring(meteorCounter)
			meteors[id] = now + METEOR_LIFETIME
			Net.fire("Meteor", player, { Id = id, Seed = rng:NextInteger(1, 1000000), Lifetime = METEOR_LIFETIME })
		end
	end
end

local function collectMeteor(player, id)
	local session = S.PlayerService.get(player)
	local meteors = session.Meteors
	if not meteors or not meteors[id] then return false, "Ese meteorito ya no está." end
	if meteors[id] < os.clock() then
		meteors[id] = nil
		return false, "Ese meteorito se desintegró."
	end
	meteors[id] = nil
	local reward = rng:NextInteger(1, 3)
	S.EconomyService.add(player, "Stardust", reward, "meteor")
	session.Profile.Stats.MeteorsCollected = session.Profile.Stats.MeteorsCollected + 1
	S.MissionService.progress(player, "CollectMeteors", 1)
	return true, { Stardust = reward }
end

function EventService.Init(services)
	S = services
	current = schedule.Active
	Net.event("Meteor")
	S.PlayerService.onLoaded(function(player, session)
		session.Derived._Event = EventService.view()
	end)
	Net.handle("CollectMeteor", { Args = { { "string", Max = 16 } }, Cooldown = 0.1 }, collectMeteor)
end

function EventService.Start()
	task.spawn(function()
		local elapsed = 0
		while true do
			task.wait(1)
			elapsed = elapsed + 1
			update()
			if elapsed % METEOR_INTERVAL == 0 then
				spawnMeteors()
			end
		end
	end)
end

return EventService
