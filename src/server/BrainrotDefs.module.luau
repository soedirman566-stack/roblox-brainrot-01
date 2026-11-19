-- BrainrotDefs: the catalog of absurd meme characters a player can own.
-- One job: say what exists — name, rarity, price, income per second, look.
-- Every other system reads this table; nothing else hard-codes a brainrot.
--
-- The rarity ladder, low to high: Common, Rare, Epic, Legendary, Mythic,
-- and above them all DEWA LANGIT — sky-god creatures of absurd size that
-- almost never ride the conveyor. A def's Look table tells BrainrotFactory
-- which accessories to bolt on (ears, horns, wings, fins, tails, crowns,
-- halos); plain creatures simply have no Look field.

local BrainrotDefs = {}

BrainrotDefs.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Dewa Langit" }

BrainrotDefs.RarityColors = {
	Common = Color3.fromRGB(178, 190, 181),
	Rare = Color3.fromRGB(84, 150, 255),
	Epic = Color3.fromRGB(178, 102, 255),
	Legendary = Color3.fromRGB(255, 196, 46),
	Mythic = Color3.fromRGB(255, 84, 150),
	-- Celestial white-gold: bright enough to read as "divine" at a distance.
	["Dewa Langit"] = Color3.fromRGB(255, 242, 194),
}

-- Weight is the conveyor's roll weight: commons flood the belt, mythics
-- almost never ride it, and a Dewa Langit is a once-in-a-blue-moon event.
-- Income is Coin per second while on a base pad. Scale is body size —
-- Dewa Langit scales (3.0+) make them tower over players and bases.
BrainrotDefs.List = {
	{ Name = "Noobini", Rarity = "Common", Price = 25, Income = 1, Weight = 30, Scale = 0.9, Color = Color3.fromRGB(245, 205, 48) },
	{ Name = "Pizzanini", Rarity = "Common", Price = 60, Income = 2, Weight = 27, Scale = 1.0, Color = Color3.fromRGB(240, 160, 60) },
	{ Name = "Burp Froggo", Rarity = "Common", Price = 120, Income = 4, Weight = 24, Scale = 1.0, Color = Color3.fromRGB(110, 205, 90) },
	{ Name = "Sir Quackalot", Rarity = "Common", Price = 250, Income = 8, Weight = 20, Scale = 1.05, Color = Color3.fromRGB(250, 240, 200) },
	{ Name = "DJ Bananini", Rarity = "Rare", Price = 600, Income = 16, Weight = 16, Scale = 1.1, Color = Color3.fromRGB(255, 225, 90) },
	{ Name = "Turbo Toastini", Rarity = "Rare", Price = 1300, Income = 30, Weight = 13, Scale = 1.1, Color = Color3.fromRGB(214, 150, 84) },
	{ Name = "Capitano Cappuccino", Rarity = "Rare", Price = 3000, Income = 65, Weight = 10, Scale = 1.15, Color = Color3.fromRGB(170, 120, 80) },
	{ Name = "Glorbo Melonini", Rarity = "Epic", Price = 7000, Income = 140, Weight = 7, Scale = 1.2, Color = Color3.fromRGB(90, 190, 110) },
	{ Name = "Zibra Zebroni", Rarity = "Epic", Price = 15000, Income = 290, Weight = 5, Scale = 1.25, Color = Color3.fromRGB(235, 235, 235) },
	{ Name = "Robo Rizzini", Rarity = "Epic", Price = 32000, Income = 600, Weight = 3.6, Scale = 1.3, Color = Color3.fromRGB(150, 170, 190) },
	{ Name = "Squalo Dorato", Rarity = "Epic", Price = 48000, Income = 1050, Weight = 2.8, Scale = 1.35, Color = Color3.fromRGB(255, 190, 60),
		Look = { Fin = true, Tail = "Fluke", Glow = true } },
	{ Name = "Pando Roboto", Rarity = "Epic", Price = 65000, Income = 1400, Weight = 2.4, Scale = 1.35, Color = Color3.fromRGB(240, 240, 245),
		Look = { Ears = "Round", Antenna = true } },
	{ Name = "King Kokonut", Rarity = "Legendary", Price = 75000, Income = 1350, Weight = 2.2, Scale = 1.4, Color = Color3.fromRGB(140, 95, 55),
		Look = { Crown = true } },
	{ Name = "La Mucca Banana", Rarity = "Legendary", Price = 180000, Income = 3000, Weight = 1.4, Scale = 1.45, Color = Color3.fromRGB(250, 245, 230),
		Look = { Ears = "Round", Horns = true } },
	{ Name = "Elefante Cristallo", Rarity = "Legendary", Price = 260000, Income = 4600, Weight = 1.0, Scale = 1.55, Color = Color3.fromRGB(170, 225, 255),
		Look = { Ears = "Round", Trunk = true, Glow = true } },
	{ Name = "Pavone Reale", Rarity = "Legendary", Price = 380000, Income = 6800, Weight = 0.8, Scale = 1.5, Color = Color3.fromRGB(60, 200, 170),
		Look = { Crown = true, Tail = "Fan", Wings = "Small" } },
	{ Name = "Tiburon Fantasma", Rarity = "Mythic", Price = 450000, Income = 7500, Weight = 0.7, Scale = 1.6, Color = Color3.fromRGB(120, 200, 235),
		Look = { Fin = true, Tail = "Fluke" } },
	{ Name = "Godini Brainrotti", Rarity = "Mythic", Price = 1100000, Income = 19000, Weight = 0.35, Scale = 1.8, Color = Color3.fromRGB(255, 215, 90),
		Look = { Crown = true, Halo = true, Glow = true } },
	{ Name = "Gatto Galattico", Rarity = "Mythic", Price = 1600000, Income = 26000, Weight = 0.28, Scale = 1.65, Color = Color3.fromRGB(90, 60, 160),
		Look = { Ears = "Point", Tail = "Long", Halo = true, Glow = true } },
	{ Name = "Drago Vulcano", Rarity = "Mythic", Price = 2400000, Income = 40000, Weight = 0.2, Scale = 1.75, Color = Color3.fromRGB(200, 70, 40),
		Look = { Horns = true, Wings = "Big", Tail = "Long", Glow = true } },
	-- DEWA LANGIT: the ultimate tier. Colossal (Scale 3.0+), blindingly
	-- priced, and with the lowest conveyor weights in the game.
	{ Name = "Naga Langit Suci", Rarity = "Dewa Langit", Price = 12000000, Income = 220000, Weight = 0.05, Scale = 3.0, Color = Color3.fromRGB(250, 244, 220),
		Look = { Horns = true, Wings = "Huge", Crown = true, Halo = true, Tail = "Long", Glow = true } },
	{ Name = "Feniks Bintang", Rarity = "Dewa Langit", Price = 20000000, Income = 380000, Weight = 0.03, Scale = 3.3, Color = Color3.fromRGB(255, 220, 130),
		Look = { Wings = "Huge", Halo = true, Tail = "Fan", Glow = true } },
	{ Name = "Paus Bulan", Rarity = "Dewa Langit", Price = 32000000, Income = 600000, Weight = 0.018, Scale = 3.6, Color = Color3.fromRGB(200, 215, 255),
		Look = { Fin = true, Tail = "Fluke", Halo = true, Glow = true } },
}

BrainrotDefs.ByName = {}
for _, def in ipairs(BrainrotDefs.List) do
	BrainrotDefs.ByName[def.Name] = def
end

local totalWeight = 0
for _, def in ipairs(BrainrotDefs.List) do
	totalWeight += def.Weight
end

-- A weighted pick for the conveyor and for wild spawns (commons only there).
function BrainrotDefs.Roll(rng: Random, commonsOnly: boolean)
	local limit = totalWeight
	if commonsOnly then
		limit = 0
		for _, def in ipairs(BrainrotDefs.List) do
			if def.Rarity == "Common" then
				limit += def.Weight
			end
		end
	end
	local roll = rng:NextNumber(0, limit)
	local acc = 0
	for _, def in ipairs(BrainrotDefs.List) do
		if commonsOnly and def.Rarity ~= "Common" then
			continue
		end
		acc += def.Weight
		if roll <= acc then
			return def
		end
	end
	return BrainrotDefs.List[1]
end

-- A weighted pick restricted to a rarity band: `factors` maps rarity ->
-- multiplier on the creature's conveyor weight (absent or 0 = excluded).
-- The treadmill and the egg hatchery roll this way, each with their own
-- band — which is how Dewa Langit stays conveyor/stealing-only for the
-- treadmill (factor never set) yet hatchable from Telur Ilahi.
function BrainrotDefs.RollWeighted(rng: Random, factors: { [string]: number })
	local limit = 0
	for _, def in ipairs(BrainrotDefs.List) do
		limit += def.Weight * (factors[def.Rarity] or 0)
	end
	if limit <= 0 then
		return BrainrotDefs.List[1]
	end
	local roll = rng:NextNumber(0, limit)
	local acc = 0
	for _, def in ipairs(BrainrotDefs.List) do
		acc += def.Weight * (factors[def.Rarity] or 0)
		if acc > 0 and roll <= acc then
			return def
		end
	end
	return BrainrotDefs.List[1]
end

-- "1234567" -> "1,234,567": Coin figures stay readable on signs and prompts.
function BrainrotDefs.FormatCash(amount: number): string
	local text = tostring(math.floor(amount))
	local out = ""
	while #text > 3 do
		out = "," .. string.sub(text, -3) .. out
		text = string.sub(text, 1, -4)
	end
	return text .. out
end

return BrainrotDefs
