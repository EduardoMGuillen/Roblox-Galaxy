-- AudioController: musica ambiental y efectos de sonido (respetando los ajustes del jugador).
-- Si un sonido no tiene asset configurado (id 0) simplemente no suena.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = require(ReplicatedStorage:WaitForChild("Shared").Assets)

local Audio = {}
local ctx = nil
local sounds = {}
local music = nil
local currentTrack = nil

local VOLUMES = { click = 0.35, hover = 0.2, success = 0.5, error = 0.4, charge = 0.5, reveal = 0.55, fanfare = 0.6, portal = 0.5,
	notify = 0.45, collect = 0.45 }

local function settings()
	return ctx.State.Data.Settings or {}
end

function Audio.play(name)
	if not settings().Sfx then return end
	local sound = sounds[name]
	if not sound then
		local url = Assets.sound(name)
		if url == "" then return end
		sound = Instance.new("Sound")
		sound.Name = "Sfx_" .. name
		sound.SoundId = url
		sound.Volume = VOLUMES[name] or 0.5
		sound.Parent = SoundService
		sounds[name] = sound
	end
	SoundService:PlayLocalSound(sound)
end

local function updateMusic()
	local track = ctx.State.locationOwner() and "music_universe" or "music_hub"
	local url = Assets.sound(track)
	if url == "" then url = Assets.sound("music_hub") end
	if not settings().Music or url == "" then
		if music then music:Stop() end
		currentTrack = nil
		return
	end
	if not music then
		music = Instance.new("Sound")
		music.Name = "Music"
		music.Looped = true
		music.Volume = 0.22
		music.Parent = SoundService
	end
	if currentTrack ~= url then
		currentTrack = url
		music:Stop()
		music.SoundId = url
		music:Play()
	elseif not music.IsPlaying then
		music:Play()
	end
end

function Audio.init(context)
	ctx = context
	ctx.Audio = Audio
	ctx.Kit.onClick = function()
		Audio.play("click")
	end
	ctx.State.on("Settings", updateMusic)
	ctx.State.on("_Session", updateMusic)
	updateMusic()
end

return Audio
