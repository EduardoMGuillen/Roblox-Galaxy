-- Main: punto de entrada del servidor de PLANET COLLECTOR.
-- 1) construye el mundo (entorno, Cosmic Hub, contenedores), 2) inicializa los servicios en orden,
-- 3) los arranca. El servidor es la autoridad de economia, inventario, colocacion, progreso y guardado.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

ReplicatedStorage:WaitForChild("Shared")

local Server = script.Parent
local Net = require(Server.Net)

local startClock = os.clock()

---------------------------------------------------------------- mundo
local zones = Instance.new("Folder")
zones.Name = "PlayerUniverseZones"
zones.Parent = Workspace

local eventEnvironment = Instance.new("Folder")
eventEnvironment.Name = "EventEnvironment"
eventEnvironment.Parent = Workspace

require(Server.World.Environment).apply()
require(Server.World.HubBuilder).build()

---------------------------------------------------------------- servicios
-- El orden importa: define el orden de los callbacks de carga de jugador.
local ORDER = {
	"DataService", "PlayerService", "UniverseService", "DiscoveryService", "InventoryService", "MissionService",
	"EventService", "ProductionService", "EconomyService", "CapsuleService", "PlanetPlacementService",
	"UpgradeService", "GalaxyService", "RebirthService", "TradingService", "LeaderboardService", "CosmeticService",
}

local services = {}
for _, name in ipairs(ORDER) do
	services[name] = require(Server.Services[name])
end

Net.init(function(player)
	return services.PlayerService.isLoaded(player)
end)

for _, name in ipairs(ORDER) do
	services[name].Init(services)
end
for _, name in ipairs(ORDER) do
	services[name].Start()
end

game:BindToClose(function()
	services.DataService.saveAll()
end)

-- señal para los clientes de que los Remotes ya existen
local ready = Instance.new("BoolValue")
ready.Name = "ServerReady"
ready.Value = true
ready.Parent = ReplicatedStorage

print(string.format("[PlanetCollector] servidor listo en %.2fs (v%s)", os.clock() - startClock,
	require(ReplicatedStorage.Shared.Config).Version))
