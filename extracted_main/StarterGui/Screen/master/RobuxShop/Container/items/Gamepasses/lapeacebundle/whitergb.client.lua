local frame = script.Parent

while true do
	-- White → slightly dimmer white
	for brightness = 1, 0.85, -0.001 do
		frame.BackgroundColor3 = Color3.new(brightness, brightness, brightness)
		task.wait(0.03)
	end

	-- Dimmer white → white
	for brightness = 0.85, 1, 0.001 do
		frame.BackgroundColor3 = Color3.new(brightness, brightness, brightness)
		task.wait(0.03)
	end
end