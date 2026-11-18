-- UniverseLayout: geometria compartida del universo personal (parcelas, orbitas, plataforma).
-- La usan el servidor (construye la estructura fija) y el cliente (dibuja estrella, orbitas y planetas).
-- La distancia orbital solo organiza la presentacion: nunca afecta a la produccion.
local Config = require(script.Parent.Config)
local World = Config.World

local Layout = {}

Layout.DeckOffset = Vector3.new(0, 30, 262)
Layout.DeckRadius = 38
Layout.OverviewOffset = Vector3.new(0, 210, 300)

function Layout.plotCenter(index)
	return World.PlotOrigin + Vector3.new((index - 1) * World.PlotSpacing, 0, 0)
end

function Layout.orbitRadius(slot)
	return World.OrbitBaseRadius + (slot - 1) * World.OrbitSpacing
end

function Layout.outerRadius()
	return Layout.orbitRadius(Config.Economy.SlotsPerSystem)
end

-- Centro de la plataforma de observacion (el jugador mira hacia la estrella, direccion -Z)
function Layout.deckPosition(center)
	return center + Layout.DeckOffset
end

function Layout.spawnCFrame(center, seed)
	local deck = Layout.deckPosition(center)
	local angle = ((seed or 0) % 8) / 8 * math.pi * 2
	local pos = deck + Vector3.new(math.cos(angle) * 5, 4, 8 + math.sin(angle) * 5)
	return CFrame.new(pos, Vector3.new(center.X, pos.Y, center.Z))
end

-- Angulo orbital sincronizado: depende solo del slot, de la velocidad del planeta y del reloj del servidor
function Layout.orbitAngle(slot, orbitSpeed, serverTime)
	local radius = Layout.orbitRadius(slot)
	local angular = 0.16 * (orbitSpeed or 1) * math.sqrt(World.OrbitBaseRadius / radius)
	return slot * 2.399963 + serverTime * angular
end

function Layout.orbitPosition(center, slot, angle)
	local radius = Layout.orbitRadius(slot)
	return center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

return Layout
