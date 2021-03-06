--- helper functions -----------------------------------------------------------
kui.GetClassColour = function(class, str)
	if not class then
		class = select(2, UnitClass('player'))
	elseif not RAID_CLASS_COLORS[class] then
		-- assume class is a unit
		class = select(2, UnitClass(class))
	end
	
	if CUSTOM_CLASS_COLORS then
		class = CUSTOM_CLASS_COLORS[class]
	else
		class = RAID_CLASS_COLORS[class]
	end
	
	if str then
		return string.format("%02x%02x%02x", class.r*255, class.g*255, class.b*255)
	else
		return class
	end
end

kui.UnitIsPet = function(unit)
	return (not UnitIsPlayer(unit) and UnitPlayerControlled(unit))
end

kui.GetUnitColour = function(unit, str)
	-- class colour for players or pets
	-- faction colour for NPCs
	local ret, r, g, b
	
	if (UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit))
		or UnitIsDeadOrGhost(unit)
		or not UnitIsConnected(unit)
	then
		ret = { r = .5, g = .5, b = .5 }
	else
		if UnitIsPlayer(unit) or kui.UnitIsPet(unit) then
			return kui.GetClassColour(unit, str)
		else
			r, g, b = UnitSelectionColor(unit)
			ret = { r = r, g = g, b = b }
		end
	end
	
	if str then
		return string.format("%02x%02x%02x", ret.r*255, ret.g*255, ret.b*255)
	else
		return ret
	end
end

kui.UnitLevel = function(unit)
	level, cl	= UnitLevel(unit), UnitClassification(unit)
	l			= level
	
	if l < 0 then
		level	= '??'
		l		= 999
	end
	
	if cl == 'elite' then
		cl = '+'
	elseif cl == 'rareelite' then
		cl = 'r+'
	elseif cl == 'rare' then
		cl = 'r'
	elseif cl == 'worldboss' then
		cl = 'b'
	else
		cl = ''
	end
	
	return level, cl, GetQuestDifficultyColor(l)
end

kui.CreateFontString = function(parent, args)
	local ob, font, size, outline, alpha, shadow
	args = args or {}

	if args.reset then
		-- to change an already existing fontString
		ob = parent
	else
		ob = parent:CreateFontString(nil, 'OVERLAY')
	end

	font	= args.font or NAMEPLATE_FONT
	size	= args.size or 12
	outline	= args.outline or nil
	alpha	= args.alpha or 1
	shadow	= args.shadow or false
	
	ob:SetFont(font, size, outline)
	ob:SetAlpha(alpha)
	
	if shadow then
		ob:SetShadowColor(0, 0, 0, 1)
		ob:SetShadowOffset(type(shadow) == 'table' and unpack(shadow) or 1, -1)
	elseif not shadow and args.reset then
		-- remove the shadow
		ob:SetShadowColor(0, 0, 0, 0)
	end
	
	return ob
end

-- Format numbers
kui.num = function(num)
	if num < 1000 then
		return num
	elseif num >= 1000000 then
		return string.format('%.1fm', num/1000000)
	elseif num >= 1000 then
		return string.format('%.1fk', num/1000)
	end
end

-- Format times (given in seconds)
kui.FormatTime = function(s)
	if s > 86400 then
		-- days
		return ceil(s/86400) .. 'd', s%86400
	elseif s >= 3600 then
		-- hours
		return ceil(s/3600) .. 'h', s%3600
	elseif s >= 60 then
		-- minutes
		return ceil(s/60) .. 'm', s%60
	elseif s <= 10 then
		return ceil(s), s - format("%.1f", s)
	end
	
	return floor(s), s - floor(s)
end

-- Pluralise a word pertaining to a value
kui.Pluralise = function(word, value, with)
	if value == 1 then
		return word
	else
		return word .. (with and with or 's')
	end
end

-- substr for utf8 characters (which are somtimes longer than 1 byte)
kui.utf8sub = function(string, fin)
	local b = string:len()
	
	if b <= fin then
		return string
	else
		local len, index = 0, 1
		
		while index <= b do
			len = len + 1
			
			local c = string:byte(index)
			if c > 240 then
				index = index + 4
			elseif c > 225 then
				index = index + 3
			elseif c > 192 then
				index = index + 2
			else
				index = index + 1
			end
			
			if len == fin then
				break
			end
		end
		
		if len == fin and index <= b then
			return string:sub(1, index - 1)
		else
			return string
		end
	end
end

string.kuisub = kui.utf8sub

-- Frame fading functions
-- (without the taint of UIFrameFade & the lag of AnimationGroups)
kui.frameFadeFrame = CreateFrame('Frame')
kui.FADEFRAMES = {}

kui.frameIsFading = function(frame)
	for index, value in pairs(kui.FADEFRAMES) do
		if value == frame then
			return true
		end
	end
end

kui.frameFadeRemoveFrame = function(frame)
	tDeleteItem(kui.FADEFRAMES, frame)
end

kui.frameFadeOnUpdate = function(self, elapsed)
	local frame, info
	for index, value in pairs(kui.FADEFRAMES) do
		frame, info = value, value.fadeInfo
		
		if info.startDelay and info.startDelay > 0 then
			info.startDelay = info.startDelay - elapsed
		else
			info.fadeTimer = (info.fadeTimer and info.fadeTimer + elapsed) or 0
			
			if info.fadeTimer < info.timeToFade then
				-- perform animation in either direction
				if info.mode == 'IN' then
					frame:SetAlpha(
						(info.fadeTimer / info.timeToFade) *
						(info.endAlpha - info.startAlpha) +
						info.startAlpha
					)
				elseif info.mode == 'OUT' then
					frame:SetAlpha(
						((info.timeToFade - info.fadeTimer) / info.timeToFade) *
						(info.startAlpha - info.endAlpha) + info.endAlpha
					)
				end
			else
				-- animation has ended
				frame:SetAlpha(info.endAlpha)
				
				if info.fadeHoldTime and info.fadeHoldTime > 0 then
					info.fadeHoldTime = info.fadeHoldTime - elapsed
				else
					kui.frameFadeRemoveFrame(frame)
					
					if info.finishedFunc then
						info.finishedFunc()
						info.finishedFunc = nil
					end
				end
			end
		end
	end
	
	if #kui.FADEFRAMES == 0 then
		self:SetScript('OnUpdate', nil)
	end
end

--[[
	info = {
		mode			= "IN" (nil) or "OUT",
		startAlpha		= alpha value to start at,
		endAlpha		= alpha value to end at,
		timeToFade		= duration of animation,
		startDelay		= seconds to wait before starting animation,
		fadeHoldTime 	= seconds to wait after ending animation before calling finishedFunc,
		finishedFunc	= function to call after animation has ended,
	}
]]
kui.frameFade = function(frame, info)
    if not frame then return end

    info		= info or {}
    info.mode	= info.mode or 'IN'
	
    if info.mode == 'IN' then
		info.startAlpha	= info.startAlpha or 0
		info.endAlpha	= info.endAlpha or 1
	elseif info.mode == 'OUT' then
		info.startAlpha	= info.startAlpha or 1
		info.endAlpha	= info.endAlpha or 0
	end
	
	frame:SetAlpha(info.startAlpha)
	frame.fadeInfo = info
	
	if not kui.frameIsFading(frame) then
		tinsert(kui.FADEFRAMES, frame)
		kui.frameFadeFrame:SetScript('OnUpdate', kui.frameFadeOnUpdate)
	end
end
