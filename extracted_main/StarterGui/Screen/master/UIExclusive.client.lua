--==================================================
-- ONE MENU AT A TIME
--
-- Every menu (inventory, shops, sell, ascend, teleport,
-- base upgrades, titles, lapis select) is opened by its
-- own script, so they could stack on top of each other.
-- This watches each menu's Container: the moment one
-- opens, every other open menu is closed.
--==================================================

local master = script.Parent

-- menu name -> the elements that make up its open window
local MENUS = {
	InventoryGui = { "Container", "Info", "info", "close", "title" },
	LapisSelect  = { "Container", "buttons", "close", "title" },
	RegularShop  = { "Container" },
	RobuxShop    = { "Container" },
	Sell         = { "Container", "buttons", "close", "title" },
	rebirth      = { "Container", "border", "close", "title", "top" },
	teleport     = { "Container", "border", "close", "title", "top" },
	BaseUpgrade  = { "Container", "close", "title" },
	Titles       = { "Container" },
}

local suppress = false

local function closeMenu(menu, parts)
	for _, name in ipairs(parts) do
		local el = menu:FindFirstChild(name)
		if el and el:IsA("GuiObject") then
			el.Visible = false
		end
	end
end

local function onOpened(openedName)
	if suppress then return end
	suppress = true
	for name, parts in pairs(MENUS) do
		if name ~= openedName then
			local menu = master:FindFirstChild(name)
			local container = menu and menu:FindFirstChild("Container")
			if container and container:IsA("GuiObject") and container.Visible then
				closeMenu(menu, parts)
			end
		end
	end
	suppress = false
end

for name in pairs(MENUS) do
	task.spawn(function()
		local menu = master:WaitForChild(name, 15)
		local container = menu and menu:WaitForChild("Container", 15)
		if not (container and container:IsA("GuiObject")) then return end
		container:GetPropertyChangedSignal("Visible"):Connect(function()
			if container.Visible then
				onOpened(name)
			end
		end)
	end)
end
