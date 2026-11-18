-- Config: tablas de balance y constantes centrales de PLANET COLLECTOR.
-- Todos los valores economicos son orientativos y se pueden ajustar aqui sin tocar la logica.
local Config = {}

Config.Version = "1.0.0"

-- Persistencia
Config.Data = {
	StoreName = "PlanetCollector_Profiles_v1",
	Version = 1,
	AutosaveInterval = 120, -- segundos
	LockTimeout = 600, -- un candado de sesion mas viejo que esto se considera abandonado
	LoadRetries = 4,
	SaveRetries = 4,
}

-- Economia base
Config.Economy = {
	StartingEnergy = 250,
	MaxCurrency = 1e18, -- limite seguro (los double pierden precision de enteros a partir de ~9e15)
	TickSeconds = 1,
	SlotsPerSystem = 8,
	InventoryBaseCapacity = 150,
	SellValueSeconds = 45, -- vender un planeta devuelve N segundos de su produccion base x multiplicador de sistema
	OfflineBaseCapHours = 2,
	OfflineBaseRate = 0.5, -- fraccion de la produccion que se gana desconectado
	OfflineMinSeconds = 60,
}

-- Capsulas
Config.Capsules = {
	CooldownSeconds = 0.5,
	BatchSizes = { 1, 3, 10 }, -- desbloqueables con la mejora de nucleo "multi"
}

-- Evolucion (Terra -> Terra Prime)
Config.Evolution = {
	CopiesRequired = 2, -- copias normales adicionales que se consumen
	ProductionMultiplier = 3,
	EnergyCostPerBase = 1500, -- coste = produccion base x este valor
	StardustPerRarityOrder = 10,
	ScaleMultiplier = 1.18,
}

-- Trading
Config.Trade = {
	MaxItemsPerSide = 8,
	RequestTimeout = 30,
	ReviewSeconds = 5,
	MinPlaytimeSeconds = 0,
}

-- Leaderboard
Config.Leaderboard = {
	RefreshSeconds = 120,
	Size = 10,
	StorePrefix = "PlanetCollector_LB_v1_",
}

-- Mundo
Config.World = {
	HubSpawn = Vector3.new(0, 6, 78),
	PlotCount = 12,
	PlotOrigin = Vector3.new(0, 900, 6000),
	PlotSpacing = 2600,
	OrbitBaseRadius = 46,
	OrbitSpacing = 19,
	StarRadius = 15,
	PlanetBaseRadius = 5,
}

-- Monetizacion responsable: solo cosmetica/comodidad. 0 = desactivado.
Config.GamePasses = {
	VIP = 0, -- id de GamePass para titulo/insignia VIP (cosmetico)
}

-- Tutorial
Config.TutorialSteps = { "welcome", "open_capsule", "go_universe", "place_planet", "watch_production", "buy_upgrade", "done" }

-- Ajustes por defecto del jugador
Config.DefaultSettings = {
	Music = true,
	Sfx = true,
	ReducedEffects = false,
	SkipCapsuleAnimation = false,
	ShowOtherNames = true,
	LowQuality = false,
	LargeText = false,
}

return Config
