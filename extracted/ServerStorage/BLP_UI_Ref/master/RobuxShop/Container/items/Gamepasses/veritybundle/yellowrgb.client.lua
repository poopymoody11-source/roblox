local frame = script.Parent

while true do
	-- Yellow → Golden Yellow
	for hue = 0.12, 0.16, 0.001 do
		frame.BackgroundColor3 = Color3.fromHSV(hue, 0.8, 1)
		task.wait(0.03)
	end

	-- Golden Yellow → Yellow
	for hue = 0.16, 0.12, -0.001 do
		frame.BackgroundColor3 = Color3.fromHSV(hue, 0.8, 1)
		task.wait(0.03)
	end
end