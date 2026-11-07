local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local event = ReplicatedStorage:WaitForChild("UnderwaterChestFeedback")

local function notify(data)
	if type(data) ~= "table" then
		return
	end

	local title = tostring(data.title or "Underwater Chest")
	local message = tostring(data.message or "")

	if message == "" then
		return
	end

	local notificationTitle = title
	if data.kind == "jackpot" then
		notificationTitle = "JACKPOT! " .. title
	end

	for attempt = 1, 8 do
		local ok = pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = notificationTitle,
				Text = message,
				Duration = data.kind == "jackpot" and 6 or 4,
			})
		end)

		if ok then
			return
		end

		task.wait(0.5)
	end

	warn("[Underwater Chest] Could not display reward notification: " .. message)
end

event.OnClientEvent:Connect(notify)
