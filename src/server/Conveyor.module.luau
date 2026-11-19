-- Conveyor: the shop lane. Brainrots ride the belt from the shop end of the
-- map to the far end; walking up and holding the prompt buys one and sends
-- it to a free pad on your base. Wild commons also wander the grass and can
-- be caught for free. One job: offers — spawning, moving and selling them.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BrainrotDefs = require(script.Parent:WaitForChild("BrainrotDefs"))
local Factory = require(script.Parent:WaitForChild("BrainrotFactory"))

local Conveyor = {}

local BELT_START_X = -100
local BELT_END_X = 104
local BELT_SPEED = 7 -- studs per second
local BELT_Y = 1.0 -- belt top surface height
local MAX_OFFERS = 6
local SPAWN_INTERVAL = 3.2
local WILD_INTERVAL = 26
local WILD_LIFETIME = 45

local plots = nil
local economy = nil
local notify: ((Player, string) -> ())? = nil

local rng = Random.new()
local offers: { any } = {}
local running = false

function Conveyor.Init(deps)
	plots = deps.Plots
	economy = deps.Economy
	notify = deps.Notify
end

local function tell(player: Player, text: string)
	if notify then
		notify(player, text)
	end
end

local function removeOffer(offer, destroyModel: boolean)
	local index = table.find(offers, offer)
	if index then
		table.remove(offers, index)
	end
	if destroyModel and offer.Model then
		offer.Model:Destroy()
	end
end

-- Hands a brainrot to a player: onto a free pad, or not at all.
local function giveToPlayer(player: Player, def, model: Model): boolean
	local pad = plots.FreePad(player)
	if not pad then
		tell(player, "Your pen is full!")
		return false
	end
	plots.PlaceOnPad(player, def, model, pad)
	return true
end

local function spawnOffer(startX: number?)
	local def = BrainrotDefs.Roll(rng, false)
	local x = startX or BELT_START_X
	local origin = CFrame.new(x, BELT_Y, 0) * CFrame.Angles(0, math.rad(-90), 0)
	local model = Factory.Build(def, origin)
	model.Parent = Workspace

	local offer = { Model = model, Def = def, X = x }
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy · " .. BrainrotDefs.FormatCash(def.Price) .. " Coin"
	prompt.ObjectText = def.Name .. " · " .. BrainrotDefs.FormatCash(def.Income) .. " Coin/s"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model:FindFirstChild("Body")
	prompt.Triggered:Connect(function(player)
		if not economy.TrySpend(player, def.Price) then
			tell(player, "Not enough Coin for " .. def.Name .. "!")
			return
		end
		if giveToPlayer(player, def, model) then
			removeOffer(offer, false)
			prompt:Destroy()
			tell(player, "Bought " .. def.Name .. "!")
		else
			economy.AddCoin(player, def.Price) -- refund: no pad, no sale
		end
	end)
	table.insert(offers, offer)
end

local function spawnWild()
	local def = BrainrotDefs.Roll(rng, true)
	-- Grass bands north and south of the lane, clear of the base plots.
	local x = rng:NextNumber(-150, 150)
	local z = rng:NextNumber(18, 34) * (if rng:NextNumber() < 0.5 then -1 else 1)
	local origin = CFrame.new(x, 0.1, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local model = Factory.Build(def, origin)
	model.Parent = Workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CatchPrompt"
	prompt.ActionText = "Catch FREE"
	prompt.ObjectText = "Wild " .. def.Name
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = model:FindFirstChild("Body")
	prompt.Triggered:Connect(function(player)
		if giveToPlayer(player, def, model) then
			prompt:Destroy()
			tell(player, "Caught a wild " .. def.Name .. "!")
		end
	end)
	task.delay(WILD_LIFETIME, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

function Conveyor.Start()
	if running then
		return
	end
	running = true

	-- Belt movement: offers ride east and despawn at the end of the lane.
	RunService.Heartbeat:Connect(function(dt)
		for i = #offers, 1, -1 do
			local offer = offers[i]
			offer.X += BELT_SPEED * dt
			if offer.X >= BELT_END_X then
				removeOffer(offer, true)
			else
				offer.Model:PivotTo(CFrame.new(offer.X, BELT_Y, 0) * CFrame.Angles(0, math.rad(-90), 0))
			end
		end
	end)

	task.spawn(function()
		while running do
			if #offers < MAX_OFFERS then
				spawnOffer()
			end
			task.wait(SPAWN_INTERVAL)
		end
	end)

	task.spawn(function()
		while running do
			task.wait(WILD_INTERVAL)
			spawnWild()
		end
	end)
end

-- The tsunami washes the belt clean.
function Conveyor.ClearLane()
	for i = #offers, 1, -1 do
		removeOffer(offers[i], true)
	end
end

-- Dawn restock (called by DayNight): every unsold brainrot on the belt
-- despawns and a fresh lineup rides in, staggered along the lane so the
-- belt is full the moment the new day starts. Brainrots already placed
-- on bases are records in PlotManager, never offers — untouched here.
function Conveyor.Restock()
	Conveyor.ClearLane()
	for i = 0, MAX_OFFERS - 1 do
		spawnOffer(BELT_START_X + i * 30)
	end
end

return Conveyor
