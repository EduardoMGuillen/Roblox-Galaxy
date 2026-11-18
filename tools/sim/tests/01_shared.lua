-- Pruebas de las definiciones compartidas y de Progression (logica pura).
local SIM = ...
SIM.loadProject()
local errs = SIM.checkAllSyntax()
assert(#errs == 0, "errores de sintaxis:\n" .. table.concat(errs, "\n"))

SIM.run("server", function()
	local RS = SIM.getService("ReplicatedStorage")
	local require = SIM.G.require
	local Defs = require(RS.Shared.Defs)
	local Profile = require(RS.Shared.Profile)
	local Progression = require(RS.Shared.Progression)
	local Format = require(RS.Shared.Util.Format)

	-- probabilidades de capsulas: suman 100 y cada pool existe y coincide en rareza
	for _, cap in ipairs(Defs.Capsules.List) do
		local sum = 0
		for rarity, pct in pairs(cap.Odds) do
			sum = sum + pct
			assert(Defs.Rarities.ById[rarity], "rareza desconocida " .. rarity)
			assert(cap.Pools[rarity] and #cap.Pools[rarity] > 0, cap.Id .. ": pool vacio para " .. rarity)
			for _, pid in ipairs(cap.Pools[rarity]) do
				local def = Defs.Planets.ById[pid]
				assert(def, cap.Id .. ": planeta desconocido " .. pid)
				assert(def.Rarity == rarity, cap.Id .. ": " .. pid .. " no es " .. rarity)
			end
		end
		assert(sum == 100, cap.Id .. ": las probabilidades suman " .. sum)
		assert(Defs.Galaxy.ById[cap.RequiresSystem], cap.Id .. ": sistema requerido invalido")
	end
	-- todo planeta se puede obtener en alguna capsula
	local obtainable = {}
	for _, cap in ipairs(Defs.Capsules.List) do
		for _, pool in pairs(cap.Pools) do
			for _, pid in ipairs(pool) do obtainable[pid] = true end
		end
	end
	for _, def in ipairs(Defs.Planets.List) do
		assert(obtainable[def.Id], "planeta no obtenible: " .. def.Id)
		assert(Defs.Rarities.ById[def.Rarity], def.Id .. ": rareza invalida")
		assert(Defs.Galaxy.ById[def.System], def.Id .. ": sistema invalido")
		for _, e in ipairs(def.Elements) do
			assert(Defs.Planets.ElementNames[e], def.Id .. ": elemento sin nombre " .. e)
		end
	end
	assert(#Defs.Planets.List == 25, "se esperaban 25 planetas")
	-- valores del manual
	local expect = { terra = 10, rocanox = 12, dunaris = 20, glaciera = 22, jovian = 35, inferno = 40, amethyst = 42,
		aureon = 60, nebulon = 70, shadowra = 100, quantum = 110, singularity = 150, cryostar = 200, volcanis = 220, zenith = 250 }
	for id, base in pairs(expect) do
		assert(Defs.Planets.ById[id].Base == base, id .. ": produccion base distinta del manual")
	end
	-- tirada de capsula: distribucion aproximada
	local rng = SIM.G.Random.new(42)
	local counts = {}
	local N = 20000
	for _ = 1, N do
		local _, rarity = Defs.Capsules.roll(Defs.Capsules.ById.solar, Defs.Rarities.Order, rng:NextNumber(), rng:NextNumber())
		counts[rarity] = (counts[rarity] or 0) + 1
	end
	for rarity, pct in pairs(Defs.Capsules.ById.solar.Odds) do
		local got = counts[rarity] / N * 100
		assert(math.abs(got - pct) < 1.5, ("solar %s: esperado %d%%, obtenido %.2f%%"):format(rarity, pct, got))
	end
	-- variantes: suma 1
	local ch = Defs.Variants.chances(1)
	local s = 0
	for _, v in pairs(ch) do s = s + v end
	assert(math.abs(s - 1) < 1e-9)
	assert(Defs.Variants.roll(0.9999, 1) == "none")
	assert(Defs.Variants.roll(0.0001, 1) == "cosmic")

	-- perfil y produccion
	local p = Profile.default(1000)
	assert(Progression.production(p).Total == 0)
	p.Planets.p1 = { Id = "terra", V = "none", E = false, L = false }
	p.Planets.p2 = { Id = "inferno", V = "golden", E = false, L = false }
	p.Planets.p3 = { Id = "inferno", V = "none", E = true, L = false }
	p.Placed.solar.s1 = "p1"
	p.Placed.solar.s2 = "p2"
	p.Placed.solar.s3 = "p3"
	local prod = Progression.production(p)
	-- 10 + 40*2 + 40*3 = 210, sinergia duo de fuego +10% => 231
	assert(math.abs(prod.Total - 231) < 1e-6, "produccion esperada 231, fue " .. prod.Total)
	assert(prod.Systems.solar.Synergies[1] == "fire_duo")
	p.Upgrades.reactor = 5
	p.Ascensions = 1
	assert(math.abs(Progression.production(p).Total - 231 * 1.5 * 2) < 1e-6)
	assert(Progression.findPlaced(p, "p2") == "solar")
	-- reconciliacion repara datos corruptos
	local bad = Profile.default(0)
	bad.Energy = -5
	bad.Planets.p9 = { Id = "noexiste" }
	bad.Planets.p4 = { Id = "terra" }
	bad.Placed.solar.s8 = "p4" -- slot bloqueado
	bad.Placed.solar.s1 = "p9" -- instancia inexistente
	bad.Upgrades.reactor = 9999
	bad.Systems.nebula = nil
	bad.Placed.nebula = { s1 = "p4" }
	Profile.reconcile(bad, 0)
	assert(bad.Energy == 0 and bad.Planets.p9 == nil and bad.Planets.p4.V == "none")
	assert(bad.Placed.solar.s8 == nil and bad.Placed.solar.s1 == nil and bad.Placed.nebula == nil)
	assert(bad.Upgrades.reactor == 100 and bad.NextUid == 5)
	-- requisitos y estados de sistema
	local st, checks = Progression.systemState(Profile.default(0), "nebula")
	assert(st == "locked" and #checks == 2)
	st = Progression.systemState(Profile.default(0), "void")
	assert(st == "locked")
	-- formato
	assert(Format.number(1240000) == "1.24M", Format.number(1240000))
	assert(Format.number(12500) == "12.5K" and Format.number(999) == "999" and Format.number(0) == "0")
	assert(Format.number(1e18) == "1.00Qi", Format.number(1e18))
	assert(Format.commas(1234567) == "1,234,567")
	assert(Format.percent(0.125) == "12.5%" and Format.percent(0.5) == "50%" and Format.percent(0.001) == "0.10%", Format.percent(0.001))
	assert(Format.duration(3725) == "1h 02m" and Format.clock(754) == "12:34")
	assert(Format.mult(2) == "x2" and Format.mult(1.5) == "x1.5")
	-- ascension
	assert(Defs.Ascension.multiplier(0) == 1 and Defs.Ascension.multiplier(5) == 12 and Defs.Ascension.multiplier(6) == 17)
	assert(Defs.Ascension.next(5).Requirements[1].Type == "RunEnergy" and #Defs.Ascension.next(0).Requirements == 2)
	-- eventos: calendario
	local sch = Defs.Events.schedule(1800 * 10 + 5)
	assert(sch.Active and sch.EndsAt == 1800 * 10 + 600)
	assert(Defs.Events.schedule(1800 * 10 + 700).Active == nil)
end)
SIM.assertNoErrors("shared")
print("OK shared")
