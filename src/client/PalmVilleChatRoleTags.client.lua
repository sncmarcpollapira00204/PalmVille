local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ROLE_TAGS = {
	OWNER = {label = "Owner", color = "#FF3B4F"},
	["MASTER DEVELOPER"] = {label = "Developer", color = "#4DA3FF"},
	["HEAD ADMIN"] = {label = "Head Admin", color = "#FF69B4"},
}

local function escapeRichText(value)
	return tostring(value)
		:gsub("&", "&amp;")
		:gsub("<", "&lt;")
		:gsub(">", "&gt;")
		:gsub('"', "&quot;")
		:gsub("'", "&apos;")
end

TextChatService.OnIncomingMessage = function(message)
	if not message.TextSource then
		return nil
	end

	local player = Players:GetPlayerByUserId(message.TextSource.UserId)
	if not player then
		return nil
	end

	local role = player:GetAttribute("PalmVilleAdminRole")
	local tag = type(role) == "string" and ROLE_TAGS[role]
	if not tag then
		return nil
	end

	local properties = Instance.new("TextChatMessageProperties")
	local prefix = message.PrefixText or player.DisplayName
	local safePrefix = escapeRichText(prefix)
	properties.PrefixText = string.format(
		'<font color="%s">[%s]</font> %s',
		tag.color,
		escapeRichText(tag.label),
		safePrefix
	)
	return properties
end
