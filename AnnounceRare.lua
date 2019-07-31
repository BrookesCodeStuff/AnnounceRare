-------------------------------------------------------------------------------
-- Announce Rare (BFA 8.2) By Crackpotx (US, Lightbringer)
-------------------------------------------------------------------------------
local AR = LibStub("AceAddon-3.0"):NewAddon("AnnounceRare", "AceComm-3.0", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
local CTL = assert(ChatThrottleLib, "AnnounceRare requires ChatThrottleLib.")
local L = LibStub("AceLocale-3.0"):GetLocale("AnnounceRare", false)

-- local api cache
local C_ChatInfo_GetNumActiveChannels = C_ChatInfo.GetNumActiveChannels
local C_Map_GetBestMapForUnit = C_Map.GetBestMapForUnit
local C_Map_GetMapInfo = C_Map.GetMapInfo
local C_Map_GetPlayerMapPosition = C_Map.GetPlayerMapPosition
local CombatLogGetCurrentEventInfo = _G["CombatLogGetCurrentEventInfo"]
local EnumerateServerChannels = _G["EnumerateServerChannels"]
local GetAddOnMetadata = _G["GetAddOnMetadata"]
local GetChannelName = _G["GetChannelName"]
local GetGameTime = _G["GetGameTime"]
local GetItemInfo = _G["GetItemInfo"]
local GetLocale = _G["GetLocale"]
local GetPlayerMapPosition = _G["GetPlayerMapPosition"]
local GetZoneText = _G["GetZoneText"]
local IsAddOnLoaded = _G["IsAddOnLoaded"]
local SendChatMessage = _G["SendChatMessage"]
local UnitAffectingCombat = _G["UnitAffectingCombat"]
local UnitAura = _G["UnitAura"]
local UnitClassification = _G["UnitClassification"]
local UnitExists = _G["UnitExists"]
local UnitGUID = _G["UnitGUID"]
local UnitHealth = _G["UnitHealth"]
local UnitHealthMax = _G["UnitHealthMax"]
local UnitIsDead = _G["UnitIsDead"]
local UnitName = _G["UnitName"]

AR.title = GetAddOnMetadata("Lorewalkers", "Title")
AR.version = GetAddOnMetadata("AnnounceRare", "Version")

local band = bit.band
local ceil = math.ceil
local match = string.match
local format = string.format
local pairs = pairs
local strsplit = strsplit
local tonumber = tonumber
local tostring = tostring

local channelFormat = "%s - %s"
local channelRUFormat = "%s: %s"
local outputChannel = "|cffffff00%s|r"
local messageToSend = L["%s%s (%s/%s %.2f%%) is at %s %s%s, and %s"]
local deathMessage = L["%s%s has been slain %sat %02d:%02d server time!"]
local defaults = {
	global = {
		armory = true,
		autoAnnounce = false,
		advertise = false,
		announceDeath = true,
		debug = false,
		drill = true,
		monitor = true,
		onLoad = false,
		output = "CHANNEL",
		tomtom = true,
	}
}

-- options table
local options = {
	name = AR.title,
	handler = AR,
	type = "group",
	args = {
		header = {
			type = "header",
			order = 1,
			name = (L["|cffff7d0aVersion:|r %s"]):format(AR.version),
			width = "full",
		},
		general = {
			type = "group",
			order = 2,
			name = L["General Options"],
			guiInline = true,
			args = {
				advertise = {
					type = "toggle",
					order = 1,
					name = L["Advertise AR"],
					desc = L["Adds a prefix to chat messages with the name of the addon."],
					get = function(info) return AR.db.global.advertise end,
					set = function(info, value) AR.db.global.advertise = value end,
				},
				onLoad = {
					type = "toggle",
					order = 2,
					name = L["Loading Message"],
					desc = L["Display a loading message when the addon first loads."],
					get = function(info) return AR.db.global.onLoad end,
					set = function(info, value) AR.db.global.onLoad = value end,
				},
				monitor = {
					type = "toggle",
					order = 3,
					name = L["Monitor Chat"],
					desc = L["Monitor chat for announcements from other users. This is used as a throttle, or to direct you to a rare via TomTom waypoints (if enabled)."],
					get = function(info) return AR.db.global.monitor end,
					set = function(info, value) AR.db.global.monitor = value end,
				},
				debug = {
					type = "toggle",
					order = 4,
					name = L["Debugging"],
					desc = L["Enable this to assist with fixing a bug or unintended functionality."],
					get = function(info) return AR.db.global.debug end,
					set = function(info, value) AR.db.global.debug = value; self.debug = value end,
				},
			},
		},
		announcements = {
			type = "group",
			order = 3,
			guiInline = true,
			name = L["Announcement Options"],
			args = {
				output = {
					type = "select",
					order = 1,
					name = L["Channel Output"],
					desc = L["Channel to send the messages to."],
					values = {
						["CHANNEL"] = L["General Chat"],
						["SAY"] = L["Say"],
						["YELL"] = L["Yell"],
						["PARTY"] = L["Party"],
						["RAID"] = L["Raid"],
						["GUILD"] = L["Guild"],
						["OFFICER"] = L["Officer"],
					},
					get = function(info) return AR.db.global.output end,
					set = function(info, value) AR.db.global.output = value end,
				},
				autoAnnounce = {
					type = "toggle",
					order = 2,
					name = L["Auto Announce"],
					desc = L["Automatically announce rares when targeting one in Mechagon or Nazjatar."],
					get = function(info) return AR.db.global.autoAnnounce end,
					set = function(info, value) AR.db.global.autoAnnounce = value end,
				},
				announceDeath = {
					type = "toggle",
					order = 3,
					name = L["Announce Death"],
					desc = L["Automatically announce when a rare dies."],
					get = function(info) return AR.db.global.announceDeath end,
					set = function(info, value) AR.db.global.announceDeath = value end,
				},
				armory = {
					type = "toggle",
					order = 4,
					name = L["Announce Armories"],
					desc = L["Automatically announces armories when you mouseover a broken one, or mouseover the various items."],
					get = function(info) return AR.db.global.armory end,
					set = function(info, value) AR.db.global.armory = value end,
				},
				drill = {
					type = "toggle",
					order = 5,
					name = L["Drill Announcements"],
					desc = L["Announce drill sites to let people know what mob is about to be available."],
					get = function(info) return AR.db.global.drill end,
					set = function(info, value) AR.db.global.drill = value end,
				},
				tomtom = {
					type = "toggle",
					order = 6,
					name = L["TomTom Waypoints"],
					desc = L["Automatically create TomTom waypoints for you when a drill site is activated.\n\n|cffff0000REQUIRES TOMTOM ADDON!|r"],
					disabled = function() return not AR.db.global.drill end,
					get = function(info) return AR.db.global.tomtom end,
					set = function(info, value) AR.db.global.tomtom = value end,
				},
			},
		},
	}
}

--[[local rares = {
	[151884] = "Fungarian Furor", -- Fungarian Furor
	[135497] = "Fungarian Furor", -- Fungarian Furor
	[151625] = "The Scrap King", -- The Scrap King
	[151623] = "The Scrap King (Mounted)", -- The Scrap King (Mounted)
	[152569] = "Crazed Trogg (Green)", -- Crazed Trogg (Green)
	[152570] = "Crazed Trogg (Blue)", -- Crazed Trogg (Blue)
	[149847] = "Crazed Trogg (Orange)", -- Crazed Trogg (Orange)

	-- for the drills
	[153206] = "Ol' Big Tusk",
	[154342] = "Arachnoid Harvester (Alt Time)",
	[154701] = "Gorged Gear-Cruncher",
	[154739] = "Caustic Mechaslime",
	[152113] = "The Kleptoboss",
	[153200] = "Boilburn",
	[153205] = "Gemicide",
}]]

local function UpdateDuplicates(id)
	if id == 151884 then
		AR.rares[#AR.rares + 1] = 135497
	elseif id == 135497 then
		AR.rares[#AR.rares + 1] = 151884
	elseif id == 151625 then
		AR.rares[#AR.rares + 1] = 151623
	elseif id == 151623 then
		AR.rares[#AR.rares + 1] = 151625
	elseif id == 152569 then
		AR.rares[#AR.rares + 1] = 152570
		AR.rares[#AR.rares + 1] = 149847
	elseif id == 152570 then
		AR.rares[#AR.rares + 1] = 152569
		AR.rares[#AR.rares + 1] = 149847
	elseif id == 149847 then
		AR.rares[#AR.rares + 1] = 152569
		AR.rares[#AR.rares + 1] = 152570
	end
end

local function GetTargetId()
	local guid = UnitGUID("target")
	if guid == nil then return nil end
	local unitType, _, _, _, _, unitId = strsplit("-", guid);
	return (unitType == "Creature" or UnitType == "Vehicle") and tonumber(unitId) or nil
end

local function GetNPCGUID(guid)
	if guid == nil then return nil end
	local unitType, _, _, _, _, unitId = strsplit("-", guid);
	return (unitType == "Creature" or UnitType == "Vehicle") and tonumber(unitId) or nil
end

local function GetGeneralChannelNumber()
	local zoneText = GetZoneText()
	local general = EnumerateServerChannels()
	if zoneText == nil or general == nil then return false end
	return GetChannelName(GetLocale() == "ruRU" and channelRUFormat:format(general, zoneText) or channelFormat:format(general, zoneText))
end

local function GetDelocalizedChannel(chan)
	if chan == L["general"] then
		return "CHANNEL"
	elseif chan == L["say"] then
		return "SAY"
	elseif chan == L["guild"] then
		return "GUILD"
	elseif chan == L["officer"] then
		return "OFFICER"
	elseif chan == L["yell"] then
		return "YELL"
	elseif chan == L["party"] then
		return "PARTY"
	elseif chan == L["raid"] then
		return "RAID"
	else
		return false
	end
end

local function IsValidOutputChannel(chan)
	return (chan == L["general"] or chan == L["say"] or chan == L["guild"] or chan == L["officer"] or chan == L["yell"] or chan == L["party"] or chan == L["raid"]) and true or false
end

-- Time Displacement
local function IsInAltTimeline()
	for i = 1, 40 do
		local name = UnitAura("player", i)
		if name == L["Time Displacement"] then
			return true
		end
	end
	return false
end

local function GetConfigStatus(configVar)
	return configVar == true and ("|cff00ff00%s|r"):format(L["ENABLED"]) or ("|cffff0000%s|r"):format(L["DISABLED"])
end

local function FormatNumber(n)
    if n >= 10^6 then
        return format("%.2fm", n / 10^6)
    elseif n >= 10^3 then
        return format("%.2fk", n / 10^3)
    else
        return tostring(n)
    end
end

local function FindInArray(toFind, arraySearch)
	if #arraySearch == 0 then return false end
	for _, value in pairs(arraySearch) do
		if value == toFind then
			return true
		end
	end
	return false
end

local function DecRound(num, decPlaces)
	return format("%." .. (decPlaces or 0) .. "f", num)
end

local function ValidNPC(id)
	return (AR.rares["mechagon"][id] ~= nil or AR.rares["nazjatar"][id] ~= nil) and true or false
end

--[[local function ValidTarget(cmdRun)
	-- if no target, then fail
	if not UnitExists("target") then
		return false
	else
		local tarClass = UnitClassification("target")
		if tarClass ~= "rare" and tarClass ~= "rareelite" then
			return false
		else
			if UnitIsDead("target") then
				return false
			else
				local tarId = GetNPCGUID(UnitGUID("target"))
				if tarId == nil then
					return false
				else 
					--return (not cmdRun and not FindInArray(tarId, AR.rares)) and true or false
					return cmdRun == true and true or not FindInArray(tarId, AR.rares)
				end
			end
		end
	end
end]]

function AR:AnnounceRare()
	-- player target is a rare
	local tarId, tarCombat = GetTargetId(), UnitAffectingCombat("target")
	local tarHealth, tarHealthMax = UnitHealth("target"), UnitHealthMax("target")
	local tarHealthPercent = (tarHealth / tarHealthMax) * 100
	local tarPos = C_Map_GetPlayerMapPosition(C_Map_GetBestMapForUnit("player"), "player")
	local genId = GetGeneralChannelNumber()

	if tarId == nil then
		self:Print(L["Unable to determine target's GUID."])
	elseif AR.db.global.output:upper() == "CHANNEL" and not genId then
		self:Print(L["Unable to determine your general channel number."])
	else
		CTL:SendChatMessage("NORMAL", "AnnounceRare", messageToSend:format(
			self.db.global.advertise == true and "AnnounceRare: " or "",
			self.rares[self.zoneText][tarId].name,
			FormatNumber(tarHealth),
			FormatNumber(tarHealthMax),
			tarHealthPercent,
			ceil(tarPos.x * 10000) / 100,
			ceil(tarPos.y * 10000) / 100,
			IsInAltTimeline() == true and " " .. L["in the alternative timeline"] or "",
			UnitAffectingCombat("target") == true and L["has been engaged!"] or L["has NOT been engaged!"]
		), self.db.global.output:upper(), nil, self.db.global.output:upper() == "CHANNEL" and genId or nil)
		self.rares[self.zoneText][tarId].lastSeen = time()
		self.rares[self.zoneText][tarId].announced = true
	end
end

function AR:CreateWaypoint(x, y, name)
	if not TomTom then
		self:Print(L["You must have TomTom installed to use waypoints."])
		return
	elseif not self.db.global.tomtom then
		return
	end
	if self.lastWaypoint ~= false then
		TomTom:RemoveWaypoint(self.lastWaypoint)
	end

	self.lastWaypoint = TomTom:AddWaypoint(C_Map_GetBestMapForUnit("player"), x / 100, y / 100, {
		title = name,
		persistent = false,
		minimap = true,
		world = true
	})

	-- create an auto expire timer
	if self.tomtomExpire ~= false then self.tomtomExpire:Cancel() end
	self.tomtomExpire = self:ScheduleTimer(120, function()
		if AR.lastWaypoint ~= nil and AR.lastWaypoint ~= false then
			TomTom:RemoveWaypoint(AR.lastWaypoint)
		end
	end)
end

function AR:CheckZone(...)
	local mapId = C_Map_GetBestMapForUnit("player")
	if mapId == nil then
		self.correctZone = false
	else
		local mapInfo = C_Map_GetMapInfo(mapId)
		if (mapId == 1355 or mapInfo["parentMapID"] == 1355) or (mapId == 1462 or mapInfo["parentMapID"] == 1462) and self.correctZone == false then
			self.correctZone = true
		elseif ((mapId ~= 1355 and mapInfo["parentMapID"] ~= 1355 and mapId ~= 1462 and mapInfo["parentMapID"] ~= 1462) or mapId == nil) and self.correctZone == true then
			self.correctZone = false
		end
	end
end

function AR:Print(msg)
	print(("|cffff7d0aAR:|r |cffffffff%s|r"):format(msg))
end

function AR:PLAYER_TARGET_CHANGED()
	if self.db.global.autoAnnounce and self.correctZone then
		local tarId = GetTargetId()
		if tarId ~= nil then
			self:AnnounceRare()
			self.rares[#self.rares + 1] = tarId
			UpdateDuplicates(tarId)
		end
	end
end

function AR:COMBAT_LOG_EVENT_UNFILTERED()
	local _, subevent, _, _, _, sourceFlags, _, srcGuid, srcName = CombatLogGetCurrentEventInfo()
	if subevent == "UNIT_DIED" and self.correctZone then
		local id = GetNPCGUID(srcGuid)
		if id ~= 151623 and self.db.global.announceDeath == true and then
			local hours, minutes = GetGameTime()
			local genId = GetGeneralChannelNumber()

			if id == nil then
				self:Print(L["Unable to determine the NPC's GUID."])
			elseif self.db.global.output:upper() == "CHANNEL" and not genId then
				self:Print(L["Unable to determine your general channel number."])
			else
				CTL:SendChatMessage("NORMAL", "AnnounceRare", deathMessage:format(
					self.db.global.advertise == true and "AnnounceRare: " or "",
					rares[id] ~= nil and rares[id] or srcName,
					IsInAltTimeline() == true and L["in the alternative timeline"] .. " " or "",
					hours,
					minutes
				), self.db.global.output:upper(), nil, self.db.global.output:upper() == "CHANNEL" and genId or nil)
			end
		end
	end
end

function AR:UPDATE_MOUSEOVER_UNIT(...)
	if self.correctZone then
		local ttItemName = GameTooltip:GetUnit()
		local armoryName = GetItemInfo(169868)
		if self.db.global.armory and (ttItemName == "Broken Rustbolt Armory" or ttItemName == armoryName) and self.lastArmory <= time() - 300 then
			local genId = GetGeneralChannelNumber()
			local tarPos = C_Map_GetPlayerMapPosition(C_Map_GetBestMapForUnit("player"), "player")
			CTL:SendChatMessage("NORMAL", "AnnounceRare", (L["%sArmory is located at %s %s!"]):format(ttItemName == "Broken Rustbolt Armory" and L["Broken"] .. " " or "", ceil(tarPos.x * 10000) / 100, ceil(tarPos.y * 10000) / 100), self.db.global.output:upper(), nil, self.db.global.output:upper() == "CHANNEL" and genId or nil)
			self.lastArmory = time()
		end
	end
end

function AR:CHAT_MSG_CHANNEL(msg, ...)

end

--[[function AR:CHAT_MSG_MONSTER_EMOTE(msg, ...)
	if self.db.global.drill and self.correctZone and msg:match("DR-") then
		local _, _, drill = strsplit(" ", msg)
		local x, y, rareName
		if drill == "DR-TR28" then
			x, y = 56.25, 36.25
			rareName = "Ol' Big Tusk"
		elseif drill == "DR-TR35" then
			x, y = 63, 25.75
			rareName = "Arachnoid Harvester (Alt Time)"
		elseif drill == "DR-CC61" then
			x, y = 72.71, 53.93
			rareName = "Gorged Gear-Cruncher"
		elseif drill == "DR-CC73" then
			x, y = 66.50, 58.85
			rareName = "Caustic Mechaslime"
		elseif drill == "DR-CC88" then
			x, y = 68.40, 48
			rareName = "The Kleptoboss"
		elseif drill == "DR-JD41" then
			x, y = 51.25, 50.20
			rareName = "Boilburn"
		elseif drill == "DR-JD99" then
			x, y = 59.75, 67.25
			rareName = "Gemicide"
		else
			return
		end

		CTL:SendChatMessage("NORMAL", "AnnounceRare", (L["%s (%s) is up at %s %s."]):format(
			drill,
			rareName,
			x,
			y	
		), self.db.global.output:upper(), nil, self.db.global.output:upper() == "CHANNEL" and genId or nil)
		
		-- create waypoint
		if self.db.global.tomtom and self.tomtom then
			self:CreateWaypoint(x, y, ("%s: %s"):format(drill, rareName))
		end
	end
end]]

function AR:PLAYER_ENTERING_WORLD()
	-- init some stuff
	self.rares = {}
	self.correctZone = false
	self.lastArmory = 0
	self:CheckZone()

	-- tomtom waypoint settings
	--self.tomtom = IsAddOnLoaded("TomTom")
	--self.lastWaypoint = false
	--self.tomtomExpire = false

	-- chat command using aceconsole-3.0
	self:RegisterChatCommand("rare", function(args)
		local key = self:GetArgs(args, 1)
		if key == L["auto"] then
			self.db.global.autoAnnounce = not self.db.global.autoAnnounce
			self:Print((L["Auto Announce has been %s!"]):format(GetConfigStatus(self.db.global.autoAnnounce)))
		elseif key == L["death"] then
			self.db.global.announceDeath = not self.db.global.announceDeath
			self:Print((L["Death Announcements have been %s!"]):format(GetConfigStatus(self.db.global.announceDeath)))
		elseif key == L["adv"] then
			self.db.global.advertise = not self.db.global.advertise
			self:Print((L["Advertisements have been %s!"]):format(GetConfigStatus(self.db.global.advertise)))
		elseif key == L["armory"] then
			self.db.global.armory = not self.db.global.armory
			self:Print((L["Armory announcements have been %s!"]):format(GetConfigStatus(self.db.global.armory)))
		--[[elseif key == "drill" then
			self.db.global.drill = not self.db.global.drill
			self:Print((L["Drill announcements have been %s!"]):format(GetConfigStatus(self.db.global.drill)))]]
		elseif key == L["help"] or key == "?" then
			self:Print(L["Command Line Help"])
			self:Print(L["|cffffff00/rare|r - Announce rare to general chat."])
			self:Print(L["|cffffff00/rare armory|r - Toggle armory announcements."])
			self:Print(L["|cffffff00/rare auto|r - Toggle auto announcements."])
			self:Print(L["|cffffff00/rare death|r - Toggle death announcements."])
			--self:Print(L["|cffffff00/rare drill|r - Toggle drill announcements."])
			self:Print(L["|cffffff00/rare load|r - Toggle loading announcement."])
			self:Print(L["|cffffff00/rare tomtom|r - Toggle TomTom waypoints."])
			self:Print(L["|cffffff00/rare output (general|say|yell|guild|party|raid)|r - Change output channel."])
			self:Print(L["|cffffff00/rare status|r or |cffffff00/rare config|r - Print current configuration."])
			self:Print(L["|cffffff00/rare help|r or |cffffff00/rare ?|r - Print this help again."])
		elseif key == L["load"] then
			self.db.global.onLoad = not self.db.global.onLoad
			self:Print((L["Loading message has been %s!"]):format(GetConfigStatus(self.db.global.onLoad)))
		elseif key == L["reset"] then
			self.rares = {}
			self.lastArmory = 0
			self:Print(L["Rare list has been reset."])
		elseif key == L["status"] or key == L["config"] then
			self:Print((L["AnnounceRare by Crackpotx v%s"]):format(self.version))
			self:Print(L["For Help: |cffffff00/rare help|r"])
			self:Print((L["Advertisements: %s"]):format(GetConfigStatus(self.db.global.advertise)))
			self:Print((L["Armory Announcements: %s"]):format(GetConfigStatus(self.db.global.armory)))
			self:Print((L["Automatic Announcements: %s"]):format(GetConfigStatus(self.db.global.autoAnnounce)))
			self:Print((L["Death Announcements: %s"]):format(GetConfigStatus(self.db.global.announceDeath)))
			--self:Print((L["Drill Notifications: %s"]):format(GetConfigStatus(self.db.global.drill)))
			self:Print((L["Load Announcement: %s"]):format(GetConfigStatus(self.db.global.onLoad)))
			self:Print((L["TomTom Waypoints: %s"]):format(GetConfigStatus(self.db.global.tomtom)))
			self:Print((L["Output Channel: |cffffff00%s|r"]):format(self.db.global.output:upper() == "CHANNEL" and "GENERAL" or self.db.global.output))
		--[[elseif key == "tomtom" then
			self.db.global.tomtom = not self.db.global.tomtom
			self:Print((L["TomTom waypoints have been %s!"]):format(GetConfigStatus(self.db.global.tomtom)))]]
		elseif key == L["output"] then
			local _, value = self:GetArgs(args, 2)
			if value == "" or value == nil then
				self:Print(L["You must provide an output channel for the announcements."])
			else
				value = value:lower()
				if not IsValidOutputChannel(value) then
					self:Print((L["Valid Outputs: %s, %s, %s, %s, %s, %s, %s"]):format(
						outputChannel:format(L["general"]),
						outputChannel:format(L["say"]),
						outputChannel:format(L["yell"]),
						outputChannel:format(L["guild"]),
						outputChannel:format(L["officer"]),
						outputChannel:format(L["party"]),
						outputChannel:format(L["raid"])
					))
				else
					self.db.global.output = value ~= L["general"] and GetDelocalizedChannel(value) or "CHANNEL"
					self:Print((L["Changed output to %s!"]):format(outputChannel:format(value:upper())))
				end
			end
		else 
			local tarClass = UnitClassification("target")
			if self.correctZone then
				if ValidTarget(true) then
					self:AnnounceRare()
				elseif not UnitExists("target") then
					self:Print(L["You do not have a target."])
				elseif UnitIsDead("target") then
					self:Print(format(L["%s is already dead."], UnitName("target"))) 
				elseif (tarClass ~= "rare" and tarClass ~= "rareelite") then
					self:Print(format(L["%s is not a rare or you have killed it today."], UnitName("target")))
				end
			else
				self:Print(L["You must be in Mechagon or Nazjatar to use this command."])
			end
		end
	end)

	if self.db.global.onLoad == true then
		self:Print((L["AnnounceRare v%s loaded! Please use |cffffff00/rare help|r for commands."]):format(GetAddOnMetadata("AnnounceRare", "Version")))
	end
end

function AR:OnInitialize()
	-- setup database and config ui
	self.db = LibStub("AceDB-3.0"):New("AnnounceRareDB", defaults)
	LibStub("AceConfig-3.0"):RegisterOptionsTable("AnnounceRare", options)
	self.optionsUI = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("AnnounceRare", "AnnounceRare")

	self.debug = self.db.global.debug

	-- register our events
	--self:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
	--self:RegisterEvent("CHAT_MSG_CHANNEL")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	self:RegisterEvent("ZONE_CHANGED", function() AR:CheckZone() end)
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() AR:CheckZone() end)
end

AR.rares = {
	["mechagon"] = {
		[151934] = {
			["name"] = L["Arachnoid Harvester"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[150394] = {
			["name"] = L["Armored Vaultbot"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[153200] = {
			["name"] = L["Boilburn"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[151308] = {
			["name"] = L["Boggac Skullbash"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[152001] = {
			["name"] = L["Bonepicker"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[154739] = {
			["name"] = L["Caustic Mechaslime"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[151569] = {
			["name"] = L["Deepwater Maw"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[150342] = {
			["name"] = L["Earthbreaker Gulroc"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[154153] = {
			["name"] = L["Enforcer KX-T57"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[151202] = {
			["name"] = L["Foul Manifestation"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[151884] = {
			["name"] = L["Fungarian Furor"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[135497] = {
			["name"] = L["Fungarian Furor"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[153228] = {
			["name"] = L["Gear Checker Cogstar"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[153205] = {
			["name"] = L["Gemicide"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[154701] = {
			["name"] = L["Gorged Gear-Cruncher"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[151684] = {
			["name"] = L["Jawbreaker"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[152007] = {
			["name"] = L["Killsaw"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[151933] = {
			["name"] = L["Malfunctioning Beastbot"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[151124] = {
			["name"] = L["Mechagonian Nullifier"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[151672] = {
			["name"] = L["Mecharantula"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[151627] = {
			["name"] = L["Mr. Fixthis"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[151296] = {
			["name"] = L["OOX-Avenger/MG"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[153206] = {
			["name"] = L["Ol' Big Tusk"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[152764] = {
			["name"] = L["Oxidized Leachbeast"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[151702] = {
			["name"] = L["Paol Pondwader"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[150575] = {
			["name"] = L["Rumblerocks"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[152182] = {
			["name"] = L["Rustfeather"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[155583] = {
			["name"] = L["Scrapclaw"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[150937] = {
			["name"] = L["Seaspit"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[153000] = {
			["name"] = L["Sparkqueen P'Emp"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[153226] = {
			["name"] = L["Steel Singer Freza"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[155060] = {
			["name"] = L["The Doppel Gang"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[152113] = {
			["name"] = L["The Kleptoboss"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[151940] = {
			["name"] = L["Uncle T'Rogg"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[151625] = {
			["name"] = L["The Scrap King"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[151623] = {
			["name"] = L["The Scrap King (Mounted)"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[154342] = {
			["name"] = L["Arachnoid Harvester (Alt Time)"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[154225] = {
			["name"] = L["The Rusty Prince (Alt Time)"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[154968] = {
			["name"] = L["Armored Vaultbot (Alt Time)"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[152569] = {
			["name"] = L["Crazed Trogg (Green)"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[152570] = {
			["name"] = L["Crazed Trogg (Blue)"],
			["lastSeen"] = 0,
			["announced"] = false
		},
		[149847] = {
			["name"] = L["Crazed Trogg (Orange)"],
			["lastSeen"] = 0,
			["announced"] = false
		},
	},
	["nazjatar"] = {
		[152415] = {
			["name"] = L["Alga the Eyeless"],
			["lastSeen"] = 0,
			["announced"] = false
		},                 
		[152681] = {
			["name"] = L["Prince Typhonus"],
			["lastSeen"] = 0,
			["announced"] = false
		},                  
		[153658] = {
			["name"] = L["Shiz'narasz the Consumer"],
			["lastSeen"] = 0,
			["announced"] = false
		},         
		[151719] = {
			["name"] = L["Voice in the Deeps"],
			["lastSeen"] = 0,
			["announced"] = false
		},               
		[152794] = {
			["name"] = L["Amethyst Spireshell"],
			["lastSeen"] = 0,
			["announced"] = false
		},              
		[152756] = {
			["name"] = L["Daggertooth Terror"],
			["lastSeen"] = 0,
			["announced"] = false
		},               
		[144644] = {
			["name"] = L["Mirecrawler"],
			["lastSeen"] = 0,
			["announced"] = false
		},                      
		[152465] = {
			["name"] = L["Needlespine"],
			["lastSeen"] = 0,
			["announced"] = false
		},                      
		[152795] = {
			["name"] = L["Sandclaw Stoneshell"],
			["lastSeen"] = 0,
			["announced"] = false
		},              
		[150191] = {
			["name"] = L["Avarius"],
			["lastSeen"] = 0,
			["announced"] = false
		},                          
		[152361] = {
			["name"] = L["Banescale the Packfather"],
			["lastSeen"] = 0,
			["announced"] = false
		},         
		[149653] = {
			["name"] = L["Carnivorous Lasher"],
			["lastSeen"] = 0,
			["announced"] = false
		},               
		[152323] = {
			["name"] = L["King Gakula"],
			["lastSeen"] = 0,
			["announced"] = false
		},                      
		[150583] = {
			["name"] = L["Rockweed Shambler"],
			["lastSeen"] = 0,
			["announced"] = false
		},                
		[151870] = {
			["name"] = L["Sandcastle"],
			["lastSeen"] = 0,
			["announced"] = false
		},                       
		[153898] = {
			["name"] = L["Tidelord Aquatus"],
			["lastSeen"] = 0,
			["announced"] = false
		},                 
		[153928] = {
			["name"] = L["Tidelord Dispersius"],
			["lastSeen"] = 0,
			["announced"] = false
		},              
		[154148] = {
			["name"] = L["Tidemistress Leth'sindra"],
			["lastSeen"] = 0,
			["announced"] = false
		},         
		[150468] = {
			["name"] = L["Vor'koth"],
			["lastSeen"] = 0,
			["announced"] = false
		},                         
		[152566] = {
			["name"] = L["Anemonar"],
			["lastSeen"] = 0,
			["announced"] = false
		},                         
		[152567] = {
			["name"] = L["Kelpwillow"],
			["lastSeen"] = 0,
			["announced"] = false
		},                       
		[152397] = {
			["name"] = L["Oronu"],
			["lastSeen"] = 0,
			["announced"] = false
		},                            
		[152568] = {
			["name"] = L["Urduu"],
			["lastSeen"] = 0,
			["announced"] = false
		},                            
		[152548] = {
			["name"] = L["Scale Matriarch Gratinax"],
			["lastSeen"] = 0,
			["announced"] = false
		},         
		[152542] = {
			["name"] = L["Scale Matriarch Zodia"],
			["lastSeen"] = 0,
			["announced"] = false
		},            
		[152545] = {
			["name"] = L["Scale Matriarch Vynara"],
			["lastSeen"] = 0,
			["announced"] = false
		},           
		[152712] = {
			["name"] = L["Blindlight"],
			["lastSeen"] = 0,
			["announced"] = false
		},                       
		[152556] = {
			["name"] = L["Chasm-Haunter"],
			["lastSeen"] = 0,
			["announced"] = false
		},                    
		[152291] = {
			["name"] = L["Deepglider"],
			["lastSeen"] = 0,
			["announced"] = false
		},                       
		[152555] = {
			["name"] = L["Elderspawn Nalaada"],
			["lastSeen"] = 0,
			["announced"] = false
		},               
		[152414] = {
			["name"] = L["Elder Unu"],
			["lastSeen"] = 0,
			["announced"] = false
		},                        
		[152553] = {
			["name"] = L["Garnetscale"],
			["lastSeen"] = 0,
			["announced"] = false
		},                      
		[152448] = {
			["name"] = L["Iridescent Glimmershell"],
			["lastSeen"] = 0,
			["announced"] = false
		},          
		[152682] = {
			["name"] = L["Prince Vortran"],
			["lastSeen"] = 0,
			["announced"] = false
		},                   
		[152552] = {
			["name"] = L["Shassera"],
			["lastSeen"] = 0,
			["announced"] = false
		},                         
		[152359] = {
			["name"] = L["Siltstalker the Packmother"],
			["lastSeen"] = 0,
			["announced"] = false
		},       
		[152290] = {
			["name"] = L["Soundless"],
			["lastSeen"] = 0,
			["announced"] = false
		},                        
		[152360] = {
			["name"] = L["Toxigore the Alpha"],
			["lastSeen"] = 0,
			["announced"] = false
		},               
		[152416] = {
			["name"] = L["Allseer Oma'kill"],
			["lastSeen"] = 0,
			["announced"] = false
		}, 
	}
}