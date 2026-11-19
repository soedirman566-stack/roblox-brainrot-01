-- GameConfig: the shared tuning tables every system reads — server modules
-- and the client HUD alike. One job: hold the numbers for the speed shop,
-- the Robux passes, the pen upgrades, the treadmill and the egg hatchery,
-- so no other file hard-codes a price or a level cap.
-- Lives in ReplicatedStorage so both sides can require the same copy.

local GameConfig = {}

-- ============================================================
-- ROBUX GAME PASSES — the one and only place pass IDs live.
-- Speed x2 (1 Robux) and Speed x5 (5 Robux): permanent run-speed
-- multipliers. If a player owns both, x5 wins (they do not stack
-- to x10). Ownership is checked on the server via
-- MarketplaceService:UserOwnsGamePassAsync.
-- ============================================================
GameConfig.PassIds = {
	SpeedX2 = 2092773834,
	SpeedX5 = 2093787823,
}
GameConfig.PassMultipliers = { SpeedX2 = 2, SpeedX5 = 5 }

-- Coin-bought speed tiers: index 0 is the free base speed. Buying the
-- next tier is a one-off Coin price; the tier persists in player data.
-- Effective WalkSpeed = tier speed x pass multiplier.
GameConfig.SpeedTiers = {
	{ Speed = 16, Price = 0 },
	{ Speed = 20, Price = 2500 },
	{ Speed = 24, Price = 12000 },
	{ Speed = 29, Price = 45000 },
	{ Speed = 35, Price = 150000 },
}

-- ============================================================
-- PEN (kandang) upgrades: 20 levels. Level 1 starts with 6 pads;
-- level 20 holds 24. Every level also adds +2% income.
-- ============================================================
GameConfig.PenMaxLevel = 20
GameConfig.PenIncomeBonusPerLevel = 0.02

function GameConfig.PenCapacity(level: number): number
	level = math.clamp(level, 1, GameConfig.PenMaxLevel)
	return 6 + math.floor((level - 1) * 18 / (GameConfig.PenMaxLevel - 1))
end

-- Coin price to go from `level` to `level + 1` (0 at max level).
function GameConfig.PenUpgradeCost(level: number): number
	if level >= GameConfig.PenMaxLevel then
		return 0
	end
	return math.floor(1500 * (1.55 ^ (level - 1)) + 0.5)
end

-- ============================================================
-- TREADMILL: levels 1-10. Higher levels fill the run meter faster
-- and unlock rarer roll bands step by step. Dewa Langit is NEVER
-- in the treadmill table, at any level.
-- ============================================================
GameConfig.TreadmillMaxLevel = 10
GameConfig.TreadmillBaseSeconds = 22 -- a level-1, base-speed run

function GameConfig.TreadmillUpgradeCost(level: number): number
	if level >= GameConfig.TreadmillMaxLevel then
		return 0
	end
	return math.floor(1000 * (1.8 ^ (level - 1)) + 0.5)
end

-- Seconds one run takes at this treadmill level (before the player's
-- own speed factor is applied by the Treadmill module).
function GameConfig.TreadmillFillSeconds(level: number): number
	return GameConfig.TreadmillBaseSeconds / (1 + 0.25 * (level - 1))
end

-- Rarity factors for the treadmill roll: a rarity's creatures roll
-- with their conveyor weight multiplied by this factor. Absent = 0.
-- Lv1 Common-Rare, Lv3 +Epic, Lv5 +Legendary, Lv8 +Mythic.
function GameConfig.TreadmillFactors(level: number): { [string]: number }
	local factors = { Common = 1, Rare = 0.55 }
	if level >= 3 then
		factors.Epic = 0.12
	end
	if level >= 5 then
		factors.Legendary = 0.03
	end
	if level >= 8 then
		factors.Mythic = 0.006
	end
	return factors
end

-- ============================================================
-- EGGS (Telur): bought with Coin, incubated at the player's base
-- nest, hatched for a random brainrot from the egg's tier band.
-- Telur Ilahi is the only egg that can hatch a Dewa Langit.
-- ============================================================
GameConfig.EggDefs = {
	{ Name = "Telur Umum", Tier = "Common", Price = 400, HatchSeconds = 30,
		Factors = { Common = 1, Rare = 0.25 } },
	{ Name = "Telur Langka", Tier = "Rare", Price = 2500, HatchSeconds = 60,
		Factors = { Common = 1, Rare = 0.5, Epic = 0.08 } },
	{ Name = "Telur Epik", Tier = "Epic", Price = 12000, HatchSeconds = 120,
		Factors = { Rare = 1, Epic = 0.45, Legendary = 0.05 } },
	{ Name = "Telur Legendaris", Tier = "Legendary", Price = 60000, HatchSeconds = 240,
		Factors = { Epic = 1, Legendary = 0.4, Mythic = 0.04 } },
	{ Name = "Telur Mythic", Tier = "Mythic", Price = 250000, HatchSeconds = 420,
		Factors = { Legendary = 1, Mythic = 0.25 } },
	{ Name = "Telur Ilahi", Tier = "Dewa Langit", Price = 1200000, HatchSeconds = 600,
		Factors = { Legendary = 1, Mythic = 0.35, ["Dewa Langit"] = 0.02 } },
}

-- ============================================================
-- DAY / NIGHT: one full cycle is 6 minutes — 4 of day, 2 of night.
-- At every dawn the conveyor stock is wiped and restocked.
-- ============================================================
GameConfig.DaySeconds = 240
GameConfig.NightSeconds = 120

return GameConfig
