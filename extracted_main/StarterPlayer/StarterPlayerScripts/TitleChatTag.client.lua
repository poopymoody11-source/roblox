--==================================================
-- TITLE CHAT TAG  (CLIENT)
--
-- Prefixes the speaker's equipped title onto their chat
-- messages, coloured by rarity:
--
--     [La Peace] MrMajou: hello
--
-- Reads the EquippedTitle attribute TitleService sets on
-- each Player, so it works for everyone in the server,
-- not just you, and updates live when someone equips a
-- different title.
--
-- NOTE: TextChatService.OnIncomingMessage is a single
-- callback -- only one script may assign it. If you add
-- another chat modifier later, merge it into this one
-- rather than assigning the callback again.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local TitleData = require(
	ReplicatedStorage:WaitForChild("AccessibleModules"):WaitForChild("TitleDataModule")
)

local function toHex(color)
	return string.format("%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5))
end

TextChatService.OnIncomingMessage = function(message)
	local properties = Instance.new("TextChatMessageProperties")

	local source = message.TextSource
	if not source then
		return properties
	end

	local player = Players:GetPlayerByUserId(source.UserId)
	if not player then
		return properties
	end

	local titleId = player:GetAttribute("EquippedTitle")
	local title = titleId and TitleData.ById[titleId]

	-- The starter title isn't worth showing on every message.
	if not title or title.Id == TitleData.DefaultTitle then
		return properties
	end

	local hex = toHex(TitleData.GetColor(title.Id))
	properties.PrefixText = string.format(
		'<font color="#%s">[%s]</font> %s',
		hex, title.Name, message.PrefixText
	)

	return properties
end
