-- SpeedPass: how fast a player runs. Two layers multiply together:
-- Coin-bought speed tiers from the shop (GameConfig.SpeedTiers, stored
-- in Economy) and the permanent Robux game passes — Speed x2 and
-- Speed x5 (GameConfig.PassIds). Owning both passes means x5 wins.
-- One job: effective WalkSpeed — computing it, applying it to the
-- character, checking pass ownership on join and the moment a
-- purchase finishes, and selling the next Coin tier.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local BrainrotDefs = require(script.Parent:WaitForChild("BrainrotDefs"))

local SpeedPass = {}

local economy = nil
local notify: ((Player, string) -> ())? = nil

function SpeedPass.Init(deps)
	economy = deps.Economy
	notify = deps.Notify

	-- A pass bought mid-session applies the moment the purchase closes.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		if passId == GameConfig.PassIds.SpeedX2 then
			economy.SetPass(player, "SpeedX2", true)
		elseif passId == GameConfig.PassIds.SpeedX5 then
			economy.SetPass(player, "SpeedX5", true)
		else
			return
		end
		SpeedPass.ApplySpeed(player)
		if notify then
			notify(player, "Speed pass active — you are faster now!")
		end
	end)
end

local function tell(player: Player, text: string)
	if notify then
		notify(player, text)
	end
end

-- The pass multiplier: x5 beats x2 beats nothing.
function SpeedPass.PassMultiplier(player: Player): number
	local entry = economy.Get(player)
	if not entry then
		return 1
	end
	if entry.PassX5 then
		return GameConfig.PassMultipliers.SpeedX5
	end
	if entry.PassX2 then
		return GameConfig.PassMultipliers.SpeedX2
	end
	return 1
end

-- Tier speed x pass multiplier.
function SpeedPass.EffectiveSpeed(player: Player): number
	local entry = economy.Get(player)
	local tier = entry and entry.SpeedTier or 0
	local tierSpeed = GameConfig.SpeedTiers[tier + 1].Speed
	return tierSpeed * SpeedPass.PassMultiplier(player)
end

-- Carrying a stolen brainrot slows you to 75% of your effective speed.
function SpeedPass.CarrySpeed(player: Player): number
	return math.max(10, math.floor(SpeedPass.EffectiveSpeed(player) * 0.75))
end

-- Pushes the right WalkSpeed onto the character (carry speed while
-- carrying) and mirrors the number into an attribute for the HUD.
function SpeedPass.ApplySpeed(player: Player)
	local effective = SpeedPass.EffectiveSpeed(player)
	player:SetAttribute("EffectiveSpeed", effective)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if player:GetAttribute("Carrying") then
			humanoid.WalkSpeed = SpeedPass.CarrySpeed(player)
		else
			humanoid.WalkSpeed = effective
		end
	end
end

-- Asks MarketplaceService what this player already owns (join-time).
function SpeedPass.CheckPasses(player: Player)
	local entry = economy.Get(player)
	if not entry then
		return
	end
	for which, passId in pairs(GameConfig.PassIds) do
		if passId and passId ~= 0 then
			local ok, owned = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			if ok and owned then
				economy.SetPass(player, which, true)
			end
		end
	end
	SpeedPass.ApplySpeed(player)
end

-- Sells the next Coin speed tier, if there is one and it is affordable.
function SpeedPass.BuyNextTier(player: Player)
	local entry = economy.Get(player)
	if not entry then
		return
	end
	local nextTier = entry.SpeedTier + 1
	local spec = GameConfig.SpeedTiers[nextTier + 1]
	if not spec then
		tell(player, "Your speed is already MAX!")
		return
	end
	if not economy.TrySpend(player, spec.Price) then
		tell(player, "Speed tier " .. nextTier .. " needs " .. BrainrotDefs.FormatCash(spec.Price) .. " Coin!")
		return
	end
	economy.SetSpeedTier(player, nextTier)
	SpeedPass.ApplySpeed(player)
	tell(player, "Speed tier " .. nextTier .. " — WalkSpeed " .. spec.Speed .. "!")
end

return SpeedPass
