local Lootbox = {}


Lootbox.Stats = {
	["Common"] = {
		Cost = 100,
		Items = {
			{ Name = "Cloak", Weight = 70 },
			{ Name = "Cloak", Weight = 30 },
		}
	},
	["Uncommon"] = {
		Cost = 500,
		Items = {
			{ Name = "Cloak", Weight = 80 },
			{ Name = "Cloak", Weight = 20 },
		}
	},
	["Rare"] = {
		Cost = 1000,
		Items = {
			{ Name = "Cloak", Weight = 80 },
			{ Name = "Cloak", Weight = 20 },
		}
	},
	["Epic"] = {
		Cost = 1000,
		Items = {
			{ Name = "Cloak", Weight = 90 },
			{ Name = "Cloak", Weight = 10 },
		}
	},
	["Legendary"] = {
		Cost = 1000,
		Items = {
			{ Name = "Cloak", Weight = 95 },
			{ Name = "Cloak", Weight = 5 },
		}
	}
}


function LootboxRoll(lootboxType)
	print(lootboxType)
	local boxStats = Lootbox.Stats[lootboxType]
	if not boxStats then
		warn("Invalid lootbox type: " .. tostring(lootboxType))
		return nil
	end

	-- 1. Calculate total weight of all possible drops
	local totalWeight = 0
	for _, item in ipairs(boxStats.Items) do
		totalWeight = totalWeight + item.Weight
	end

	-- 2. Pick a random threshold between 1 and totalWeight
	local roll = math.random(1, totalWeight)

	-- 3. Accumulate weight until the threshold is hit
	local currentWeight = 0
	for _, item in ipairs(boxStats.Items) do
		currentWeight = currentWeight + item.Weight
		if roll <= currentWeight then
			print("Rolled: " .. item.Name)
			return item
		end
	end
end


return Lootbox
