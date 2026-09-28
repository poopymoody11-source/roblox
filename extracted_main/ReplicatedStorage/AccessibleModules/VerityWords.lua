--==================================================
-- VERITY'S WORDS
--
-- The lines written on Verity's piece of paper. The player
-- has to recite (type) them one at a time in the recite
-- prompt; the server checks the same list before it lets
-- VerityQuest2 complete. Edit the lines here and both
-- sides stay in sync.
--==================================================

local VerityWords = {}

VerityWords.Lines = {
	"I seek the truth",
	"I fear no cruelty",
	"Verity guides my hand",
	"Open the way",
}

-- forgiving match: case, punctuation and extra spaces don't matter
function VerityWords.Normalize(s)
	s = tostring(s or ""):lower()
	s = s:gsub("[^%w%s]", "")
	s = s:gsub("%s+", " ")
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function VerityWords.Matches(typed, index)
	local line = VerityWords.Lines[index]
	return line ~= nil and VerityWords.Normalize(typed) == VerityWords.Normalize(line)
end

-- the whole recital, as the client submits it
function VerityWords.Full()
	return table.concat(VerityWords.Lines, " / ")
end

return VerityWords
