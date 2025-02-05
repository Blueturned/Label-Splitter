local TextS = game:GetService("TextService")

local TextAnimator = {}
local textLabels = {}

function TextAnimator.Animate(textLabel : TextLabel, text : string, returnSize)
	--Error handling
	if not textLabel then
		warn("TextLabel not assigned")
	end
	
	if not text then
		text = textLabel.Text
	end
	
	if textLabel.TextScaled and textLabel.RichText then
		warn("Module does not support 'TextScaled' and 'RichText' being set to true. Disable one or the other!")
		return
	end
	
	if textLabel:FindFirstChildOfClass("UIAspectRatioConstraint") then
		warn("Module does not yet support 'UIAspectRatioConstraint'")
		return
	end
	
	--Remove/replace RichText elements/line breaks tags
	text = text:gsub("<[^<>]->", "")
	text = text:gsub("<br%s*/>", "\n")
	
	local screenGui = textLabel.Parent
	local stringCount = string.len(text)
	local completelength = textLabel.TextBounds

	local generatedSize = 0
	local lineBreaksPos = {}
	
	--Simple functions to convert scale to offset and vice versa
	local function offsetToScale(udim : UDim2)
		local absSize = screenGui.AbsoluteSize
		local scale = UDim2.new(udim.X.Offset / absSize.X + udim.X.Scale, 0, udim.Y.Offset / absSize.Y + udim.Y.Scale, 0)
		return scale
	end
	
	local function scaleToOffset(udim : UDim2)
		local absSize = screenGui.AbsoluteSize
		local offset = UDim2.new(0, absSize.X * udim.X.Scale + udim.X.Offset, 0, absSize.Y * udim.Y.Scale + udim.Y.Offset)
		return offset
	end
	
	--Simple function to update the label so that the labels size is acurate to each character's size
	local function updateUdimToBounds(label)
		label.Size = scaleToOffset(label.Size)
		local originalSize = label.Size.X.Offset
		local size = UDim2.new(0, label.TextBounds.X, 0, label.TextBounds.Y)
		local sizeChange = (originalSize - label.TextBounds.X) / 2
		label.Position = UDim2.new(0, label.Position.X.Offset + sizeChange, 0, label.Position.Y.Offset)
		return size
	end
	
	--Calculates the position of the given labels
	local function calculatePos(charLabel, prevLabel, lineBreaks, lineOffsetY)
		--Converts labels to offset
		local labelSizeOffset : UDim2 = scaleToOffset(textLabel.Size)
		local labelPosOffset : UDim2 = scaleToOffset(textLabel.Position)
		labelPosOffset = Vector2.new(labelPosOffset.X.Offset, labelPosOffset.Y.Offset)
		labelSizeOffset = Vector2.new(labelSizeOffset.X.Offset, labelSizeOffset.Y.Offset)

		if not prevLabel then --Calculates the position of the first label
			charLabel.Position = UDim2.new(0, (labelPosOffset.X - completelength.X / 2) + charLabel.TextBounds.X / 2, 0, labelPosOffset.Y + labelSizeOffset.Y / 2 - charLabel.TextBounds.Y / 2 - lineOffsetY)
			prevLabel = charLabel
			return
		end
		
		if lineOffsetY and lineOffsetY > 0 then --Calculates the position of the first label of a new line
			charLabel.Position = UDim2.new(0, (labelPosOffset.X - completelength.X / 2) + charLabel.TextBounds.X / 2, 0, prevLabel.Position.Y.Offset + lineOffsetY)
			prevLabel = charLabel
			return
		end
		
		--Calculates the position of the next labels within a line
		local size = Vector2.new((prevLabel.TextBounds.X + charLabel.TextBounds.X)/ 2, (prevLabel.TextBounds.Y + charLabel.TextBounds.Y)/ 2)

		charLabel.Position = UDim2.new(0, prevLabel.Position.X.Offset + size.X, 0, prevLabel.Position.Y.Offset)
		prevLabel = charLabel
		return
	end
	
	--Creates the labels for the given character
	local function createLabels(char, lineBreaks)
		if char == nil then return end	
		
		local newLabel = textLabel:Clone()
		local labelScript = newLabel:FindFirstChildOfClass("Script") or newLabel:FindFirstChildOfClass("LocalScript") or newLabel:FindFirstChildOfClass("ModuleScript")
		if labelScript then
			labelScript:Destroy()
		end
		newLabel.Parent = textLabel.Parent
		newLabel.Text = char
		newLabel.Size = UDim2.new(textLabel.Size.X.Scale, 0, 0, completelength.Y / lineBreaks)
		newLabel.Name = char
		newLabel.TextTransparency = 0
		
		return newLabel
	end
	
	local function calculateLineBreaks()
		local lineBreaks = 0
		
		local newLabel = textLabel:Clone()
		if #newLabel:GetChildren() > 0 then
			newLabel:ClearAllChildren()
		end
		newLabel.Parent = textLabel.Parent
		newLabel.Visible = false

		local prevSize
		
		for i = 1, #text, 1 do
			newLabel.Text = text:sub(1, i)
			local newSize = newLabel.TextBounds
			
			if not prevSize or newSize.Y > prevSize.Y then --This adds 1 to line breaks if linebreaks is still 0, or the yTextBounds Changes
				lineBreaks += 1
			end
			
			prevSize = newLabel.TextBounds
		end
		
		return lineBreaks
	end
	
	local lineBreaks = calculateLineBreaks()
	
	local function findLineBreaks()
		local prevLabel = nil
		local labels = {}
		local tabLables = {}
		local generatedSize = 0
		local maxSize = completelength.X
		local index = 0
		local words = text:split(" ")
		local currentLine = 1
		
		for i, word in ipairs(words) do
			index += 1
			
			if i ~= #words then --Insures that the last word doesn't end with a space
				word = word .. " "
			end

			local label = createLabels(word, lineBreaks)
			 
			--Tables to track 
			table.insert(labels, label)
			table.insert(tabLables, label)
			generatedSize += label.TextBounds.X

			if generatedSize > maxSize then --Checks if there still is a line break when the 'space' is cleared
				generatedSize -= label.TextBounds.X
				label.Text = string.gsub(label.Text, " ", "")
				
				generatedSize += label.TextBounds.X
				if generatedSize > maxSize then
					if i ~= #words then
						label.Text = word .. " "
					end
					
					generatedSize = 0
					generatedSize += label.TextBounds.X
					prevLabel.Text = string.gsub(prevLabel.Text, " ", "")


					lineBreaksPos[currentLine] = 0
					for j, lab in ipairs(tabLables) do
						if lab ~= tabLables[index] then
							lineBreaksPos[currentLine] += string.len(lab.Text)
						end
					end

					index = 1
					table.clear(tabLables)
					table.insert(tabLables, label)
					currentLine += 1
				end
			end
			
			prevLabel = label
			
		end

		for _, label in labels do
			label:Destroy()
		end
		
	end
	
	findLineBreaks()
	
	local function generateText()
		local charsGenerated = 0
		local currentTab = 1
		local prevLabel = nil
		local lineOffsetY = textLabel.TextBounds.Y / (2 + 2 / (lineBreaks - 1)) --Formula to get the starting offset of the line
		
		for i = 1, #text, 1 do
			local char = text:sub(i, i)
			local label : TextLabel = createLabels(char, lineBreaks)
			calculatePos(label, prevLabel, lineBreaks, lineOffsetY)
			prevLabel = label
		
			lineOffsetY = 0
			if charsGenerated == lineBreaksPos[currentTab] then
				currentTab += 1
				charsGenerated -= charsGenerated
				lineOffsetY = completelength.Y / lineBreaks
			end 
			charsGenerated += 1
			table.insert(textLabels, label)
		end
		
		if returnSize then
			
		end
		for _, label in textLabels do
			label.Size = updateUdimToBounds(label)
			label.Position = offsetToScale(label.Position)
			label.Size = offsetToScale(label.Size)
		end
	end
	
	generateText()
	
	textLabel:Destroy()
	
	return textLabels
end

return TextAnimator
