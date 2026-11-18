-- Defs: punto unico de acceso a todas las definiciones compartidas.
local Definitions = script.Parent.Definitions

return {
	Config = require(script.Parent.Config),
	Rarities = require(Definitions.RarityDefinitions),
	Variants = require(Definitions.VariantDefinitions),
	Planets = require(Definitions.PlanetDefinitions),
	Capsules = require(Definitions.CapsuleDefinitions),
	Galaxy = require(Definitions.GalaxyDefinitions),
	Synergies = require(Definitions.SynergyDefinitions),
	Upgrades = require(Definitions.UpgradeDefinitions),
	Ascension = require(Definitions.AscensionDefinitions),
	Missions = require(Definitions.MissionDefinitions),
	Events = require(Definitions.EventDefinitions),
	Cosmetics = require(Definitions.CosmeticDefinitions),
}
