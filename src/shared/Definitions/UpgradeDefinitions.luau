-- UpgradeDefinitions: mejoras compradas con Energy (se reinician al ascender) y con Cosmic Cores (permanentes).
-- Cost(level) = coste de pasar del nivel `level` al siguiente. Effect(level) = efecto total con ese nivel.
local Upgrades = {}

local function geometric(base, growth)
	return function(level)
		return math.floor(base * growth ^ level)
	end
end

local function linear(base, step)
	return function(level)
		return base + step * level
	end
end

Upgrades.List = {
	---------------------------------------------------------------- Energy
	{ Id = "reactor", Name = "Reactor Estelar", Currency = "Energy", MaxLevel = 100, Icon = "⚡",
		Description = "+10% de producción total por nivel.",
		Cost = geometric(400, 1.32), Effect = function(level) return 1 + 0.10 * level end, EffectKind = "mult" },
	{ Id = "efficiency", Name = "Eficiencia de Cápsulas", Currency = "Energy", MaxLevel = 10, Icon = "💊",
		Description = "-3% al precio de todas las cápsulas por nivel.",
		Cost = geometric(2000, 2.2), Effect = function(level) return 1 - 0.03 * level end, EffectKind = "discount" },
	{ Id = "hangar", Name = "Hangar Orbital", Currency = "Energy", MaxLevel = 10, Icon = "🎒",
		Description = "+25 espacios de inventario por nivel.",
		Cost = geometric(5000, 2), Effect = function(level) return 25 * level end, EffectKind = "flat" },
	{ Id = "battery", Name = "Baterías Offline", Currency = "Energy", MaxLevel = 8, Icon = "🔋",
		Description = "+1 hora de ganancias sin conexión por nivel.",
		Cost = geometric(10000, 3), Effect = function(level) return level end, EffectKind = "hours" },
	{ Id = "resonance", Name = "Resonancia Orbital", Currency = "Energy", MaxLevel = 10, Icon = "🔗",
		Description = "+10% de potencia a todas las sinergias por nivel.",
		Cost = geometric(25000, 2.5), Effect = function(level) return 1 + 0.10 * level end, EffectKind = "mult" },
	---------------------------------------------------------------- Cosmic Cores (permanentes)
	{ Id = "core_power", Name = "Núcleo de Poder", Currency = "Cores", MaxLevel = 20, Icon = "💠",
		Description = "+25% de producción permanente por nivel.",
		Cost = linear(2, 1), Effect = function(level) return 1 + 0.25 * level end, EffectKind = "mult" },
	{ Id = "core_luck", Name = "Suerte Cósmica", Currency = "Cores", MaxLevel = 10, Icon = "🍀",
		Description = "+15% de probabilidad de variantes por nivel (las probabilidades mostradas se actualizan).",
		Cost = linear(3, 2), Effect = function(level) return 1 + 0.15 * level end, EffectKind = "mult" },
	{ Id = "core_offline", Name = "Colector Nocturno", Currency = "Cores", MaxLevel = 5, Icon = "🌙",
		Description = "+10% de eficiencia de ganancias sin conexión por nivel.",
		Cost = linear(2, 1), Effect = function(level) return 0.10 * level end, EffectKind = "add" },
	{ Id = "core_start", Name = "Legado Estelar", Currency = "Cores", MaxLevel = 5, Icon = "🌟",
		Description = "Multiplica x10 por nivel la Energy inicial tras cada ascensión.",
		Cost = linear(2, 2), Effect = function(level) return 10 ^ level end, EffectKind = "mult" },
	{ Id = "core_multi", Name = "Apertura Múltiple", Currency = "Cores", MaxLevel = 2, Icon = "🎰",
		Description = "Nivel 1: abre 3 cápsulas a la vez. Nivel 2: abre 10 a la vez.",
		Cost = linear(4, 6), Effect = function(level) return level end, EffectKind = "level" },
}

Upgrades.ById = {}
for index, u in ipairs(Upgrades.List) do
	u.Order = index
	Upgrades.ById[u.Id] = u
end

function Upgrades.get(id)
	return Upgrades.ById[id]
end

function Upgrades.level(profile, id)
	return (profile.Upgrades and profile.Upgrades[id]) or 0
end

function Upgrades.effect(profile, id)
	local def = Upgrades.ById[id]
	return def.Effect(Upgrades.level(profile, id))
end

return Upgrades
