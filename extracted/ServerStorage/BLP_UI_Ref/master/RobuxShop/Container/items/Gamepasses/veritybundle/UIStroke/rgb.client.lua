local stroke = script.Parent

while true do
	for hue = 0, 1, 0.005 do
		stroke.Color = Color3.fromHSV(hue, 1, 1)
		task.wait(0.02)
	end
end