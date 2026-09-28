local highlight = script.Parent

while true do
	for hue = 0, 1, 0.01 do
		highlight.FillColor = Color3.fromHSV(hue, 1, 1)
		highlight.OutlineColor = Color3.fromHSV(hue, 1, 1)
		task.wait(0.03)
	end
end