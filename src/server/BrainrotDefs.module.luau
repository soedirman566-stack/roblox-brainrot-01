-- BrainrotDefs: the catalog of absurd meme characters a player can own.
-- One job: say what exists — name, rarity, price, income per second, look.
-- Every other system reads this table; nothing else hard-codes a brainrot.

local BrainrotDefs = {}

BrainrotDefs.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

BrainrotDefs.RarityColors = {
	Common = Color3.fromRGB(178, 190, 181),
	Rare = Color3.fromRGB(84, 150, 255),
	Epic = Color3.fromRGB(178, 102, 255),
	Legendary = Color3.fromRGB(255, 196, 46),
	Mythic = Color3.fromRGB(255, 84, 150),
}

-- Weight is the conveyor's roll weight: commons flood the belt, mythics
-- almost never ride it. Income is cash per second while on a base pad.
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
	{ Name = "King Kokonut", Rarity = "Legendary", Price = 75000, Income = 1350, Weight = 2.2, Scale = 1.4, Color = Color3.fromRGB(140, 95, 55) },
	{ Name = "La Mucca Banana", Rarity = "Legendary", Price = 180000, Income = 3000, Weight = 1.4, Scale = 1.45, Color = Color3.fromRGB(250, 245, 230) },
	{ Name = "Tiburon Fantasma", Rarity = "Mythic", Price = 450000, Income = 7500, Weight = 0.7, Scale = 1.6, Color = Color3.fromRGB(120, 200, 235) },
	{ Name = "Godini Brainrotti", Rarity = "Mythic", Price = 1100000, Income = 19000, Weight = 0.35, Scale = 1.8, Color = Color3.fromRGB(255, 215, 90) },
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

-- "1234567" -> "1,234,567": cash figures stay readable on signs and prompts.
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
