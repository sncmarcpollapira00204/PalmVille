local ServerStorage = game:GetService("ServerStorage")
local templates = ServerStorage:WaitForChild("PalmVilleAdminItems")

return {
	RICE_SEED = {
		displayName = "Rice Seed",
		template = templates:WaitForChild("RICE_SEED"),
		maxAmount = 99,
	},
}