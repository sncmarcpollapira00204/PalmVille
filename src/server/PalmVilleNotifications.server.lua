local ReplicatedStorage = game:GetService("ReplicatedStorage")

local event = ReplicatedStorage:FindFirstChild("PalmVilleNotificationEvent")
if not event then
	event = Instance.new("RemoteEvent")
	event.Name = "PalmVilleNotificationEvent"
	event.Parent = ReplicatedStorage
end
