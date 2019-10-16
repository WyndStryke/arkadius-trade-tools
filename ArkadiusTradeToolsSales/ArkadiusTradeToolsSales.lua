ArkadiusTradeTools.Modules.Sales = ArkadiusTradeTools.Templates.Module:New(ArkadiusTradeTools.NAME .. "Sales", ArkadiusTradeTools.TITLE .. " - Sales", ArkadiusTradeTools.VERSION, ArkadiusTradeTools.AUTHOR)
local ArkadiusTradeToolsSales = ArkadiusTradeTools.Modules.Sales
ArkadiusTradeToolsSales.Localization = {}
ArkadiusTradeToolsSales.SalesTables = {}

local L = ArkadiusTradeToolsSales.Localization
local SalesTables = ArkadiusTradeToolsSales.SalesTables
local DefaultSettings
local Settings
local TemporaryVariables

local NUM_SALES_TABLES = 16
local SECONDS_IN_DAY = 60*60*24

--------------------------------------------------------
------------------- Helper functions -------------------
--------------------------------------------------------

--------------------------------------------------------
-------------------- List functions --------------------
--------------------------------------------------------
local ArkadiusTradeToolsSalesList = ArkadiusTradeToolsSortFilterList:Subclass()

function ArkadiusTradeToolsSalesList:New(parent, ...)
    return ArkadiusTradeToolsSortFilterList.New(self, parent, ...)
end

function ArkadiusTradeToolsSalesList:Initialize(listControl)
    ArkadiusTradeToolsSortFilterList.Initialize(self, listControl)
	
	--- sort up down ---

    self.SORT_KEYS = {["sellerName"] = {tiebreaker = "timeStamp"},
                      ["buyerName"]  = {tiebreaker = "timeStamp"},
                      ["guildName"]  = {tiebreaker = "timeStamp"},
--                    ["itemName"]   = {tiebreaker = "timeStamp"},
--					  ["eaprice"]    = {tiebreaker = "price"},
					  ["price"]      = {tiebreaker = "timeStamp"},
                      ["timeStamp"]  = {}}

    ZO_ScrollList_AddDataType(self.list, 1, "ArkadiusTradeToolsSalesRow", 32,
        function(listControl, data)
            self:SetupSaleRow(listControl, data)
        end
    )

    local function OnHeaderToggle(switch, pressed)
        self[switch:GetParent().key.."Switch"] = pressed
        self:CommitScrollList()
        Settings.filters[switch:GetParent().key] = pressed
    end

    local function OnHeaderFilterToggle(switch, pressed)
        self[switch:GetParent().key.."Switch"] = pressed
        self.Filter:SetNeedsRefilter()
        self:RefreshFilters()
        Settings.filters[switch:GetParent().key] = pressed
    end

	--- +/- toggle ---
	
    self.sellerNameSwitch = Settings.filters.sellerName
    self.buyerNameSwitch = Settings.filters.buyerName
    self.guildNameSwitch = Settings.filters.guildName
    self.itemNameSwitch = Settings.filters.itemName
    self.timeStampSwitch = Settings.filters.timeStamp
	self.eapriceSwitch = Settings.filters.eaprice
	self.priceSwitch = Settings.filters.price
	
    self.sortHeaderGroup.headerContainer.sortHeaderGroup = self.sortHeaderGroup
    self.sortHeaderGroup:HeaderForKey("sellerName").switch:SetPressed(self.sellerNameSwitch)
    self.sortHeaderGroup:HeaderForKey("sellerName").switch.tooltip:SetContent(L["ATT_STR_FILTER_COLUMN_TOOLTIP"])
    self.sortHeaderGroup:HeaderForKey("sellerName").switch.OnToggle = OnHeaderFilterToggle
    self.sortHeaderGroup:HeaderForKey("buyerName").switch:SetPressed(self.buyerNameSwitch)
    self.sortHeaderGroup:HeaderForKey("buyerName").switch.tooltip:SetContent(L["ATT_STR_FILTER_COLUMN_TOOLTIP"])
    self.sortHeaderGroup:HeaderForKey("buyerName").switch.OnToggle = OnHeaderFilterToggle
    self.sortHeaderGroup:HeaderForKey("guildName").switch:SetPressed(self.guildNameSwitch)
    self.sortHeaderGroup:HeaderForKey("guildName").switch.tooltip:SetContent(L["ATT_STR_FILTER_COLUMN_TOOLTIP"])
    self.sortHeaderGroup:HeaderForKey("guildName").switch.OnToggle = OnHeaderFilterToggle
    self.sortHeaderGroup:HeaderForKey("itemName").switch:SetPressed(self.itemNameSwitch)
    self.sortHeaderGroup:HeaderForKey("itemName").switch.tooltip:SetContent(L["ATT_STR_FILTER_COLUMN_TOOLTIP"])
    self.sortHeaderGroup:HeaderForKey("itemName").switch.OnToggle = OnHeaderFilterToggle
    self.sortHeaderGroup:HeaderForKey("timeStamp").switch:SetPressed(self.timeStampSwitch)
    self.sortHeaderGroup:HeaderForKey("timeStamp").switch.OnToggle = OnHeaderToggle
	--self.sortHeaderGroup:HeaderForKey("eaprice").switch:SetPressed(self.eapriceSwitch)
    --self.sortHeaderGroup:HeaderForKey("eaprice").switch.OnToggle = OnHeaderToggle
	--self.sortHeaderGroup:HeaderForKey("price").switch:SetPressed(self.priceSwitch)
    --self.sortHeaderGroup:HeaderForKey("price").switch.OnToggle = OnHeaderToggle
    self.sortHeaderGroup:SelectHeaderByKey("timeStamp", true)
    self.sortHeaderGroup:SelectHeaderByKey("timeStamp", true)
    self.currentSortKey = "timeStamp"
end

function ArkadiusTradeToolsSalesList:SetupFilters()
    local useSubStrings = ArkadiusTradeToolsSales.frame.filterBar.SubStrings:IsPressed()

    local CompareStringsFuncs = {}
    CompareStringsFuncs[true] = function(string1, string2) string2 = string2:gsub("-", "--") return (string.find(string1, string2) ~= nil) end
    CompareStringsFuncs[false] = function(string1, string2) return (string1 == string2) end

    local item = ArkadiusTradeToolsSales.frame.filterBar.Time:GetSelectedItem()
    local newerThanTimeStamp = item.NewerThanTimeStamp()
    local olderThanTimestamp = item.OlderThanTimeStamp()

    local function CompareTimestamp(timeStamp)
        return ((timeStamp >= newerThanTimeStamp) and (timeStamp < olderThanTimestamp))
    end

    local function CompareUsernames(userName1, userName2)
        return CompareStringsFuncs[useSubStrings](TemporaryVariables.displayNamesLowered[userName1], userName2)
    end

    local function CompareGuildNames(guildName1, guildName2)
        return CompareStringsFuncs[useSubStrings](TemporaryVariables.guildNamesLowered[guildName1], guildName2)
    end

    local function CompareItemNames(itemLink, itemName)
        return (CompareStringsFuncs[useSubStrings](TemporaryVariables.itemNamesLowered[TemporaryVariables.itemLinkInfos[itemLink].name], itemName)) or
               (CompareStringsFuncs[useSubStrings](TemporaryVariables.traitNamesLowered[TemporaryVariables.itemLinkInfos[itemLink].trait], itemName)) or
               (CompareStringsFuncs[useSubStrings](TemporaryVariables.qualityNamesLowered[TemporaryVariables.itemLinkInfos[itemLink].quality], itemName))
    end

    self.Filter:SetKeywords(ArkadiusTradeToolsSales.frame.filterBar.Text:GetStrings())
    self.Filter:SetKeyFunc(1, "timeStamp", CompareTimestamp)

    if (self["buyerNameSwitch"])
        then self.Filter:SetKeyFunc(2, "buyerName", CompareUsernames)
    else
        self.Filter:SetKeyFunc(2, "buyerName", nil)
    end

    if (self["sellerNameSwitch"])
        then self.Filter:SetKeyFunc(2, "sellerName", CompareUsernames)
    else
        self.Filter:SetKeyFunc(2, "sellerName", nil)
    end

    if (self["guildNameSwitch"])
        then self.Filter:SetKeyFunc(2, "guildName", CompareGuildNames)
    else
        self.Filter:SetKeyFunc(2, "guildName", nil)
    end

    if (self["itemNameSwitch"])
        then self.Filter:SetKeyFunc(2, "itemLink", CompareItemNames)
    else
        self.Filter:SetKeyFunc(2, "itemLink", nil)
    end
end

function ArkadiusTradeToolsSalesList:SetupSaleRow(rowControl, rowData)
    rowControl.data = rowData
    local data = rowData.rawData
    local sellerName = GetControl(rowControl, "SellerName")
    local buyerName = GetControl(rowControl, "BuyerName")
    local guildName = GetControl(rowControl, "GuildName")
    local itemLink = GetControl(rowControl, "ItemLink")
	local eaprice = GetControl(rowControl, "eaPrice")
    local price = GetControl(rowControl, "Price")
    local timeStamp = GetControl(rowControl, "TimeStamp")
    local icon = GetItemLinkInfo(data.itemLink)

    sellerName:SetText(data.sellerName)
    sellerName:SetWidth(sellerName.header:GetWidth() - 10)
    sellerName:SetHidden(sellerName.header:IsHidden())
    sellerName:SetColor(ArkadiusTradeTools:GetDisplayNameColor(data.sellerName):UnpackRGBA())

    buyerName:SetText(data.buyerName)
    buyerName:SetWidth(buyerName.header:GetWidth() - 10)
    buyerName:SetHidden(buyerName.header:IsHidden())
    buyerName:SetColor(ArkadiusTradeTools:GetDisplayNameColor(data.buyerName):UnpackRGBA())

    guildName:SetText(data.guildName)
    guildName:SetWidth(guildName.header:GetWidth() - 10)
    guildName:SetHidden(guildName.header:IsHidden())
    guildName:SetColor(ArkadiusTradeTools:GetGuildColor(data.guildName):UnpackRGBA())

    itemLink:SetText(data.itemLink)
    itemLink:SetWidth(itemLink.header:GetWidth() - 10)
    itemLink:SetHidden(itemLink.header:IsHidden())
    itemLink:SetIcon(icon)
	
	if (data.quantity == 1) then
        data.eaprice=data.price
    else
        data.eaprice=math.attRound(data.price/data.quantity, 2)
    end
		
	eaprice:SetText(ArkadiusTradeTools:LocalizeDezimalNumber(data.eaprice) .. " |t16:16:EsoUI/Art/currency/currency_gold.dds|t")
    eaprice:SetWidth(eaprice.header:GetWidth() - 10)
    eaprice:SetHidden(eaprice.header:IsHidden())	

    price:SetText(ArkadiusTradeTools:LocalizeDezimalNumber(data.price) .. " |t16:16:EsoUI/Art/currency/currency_gold.dds|t")
    price:SetWidth(price.header:GetWidth() - 10)
    price:SetHidden(price.header:IsHidden())

    if (self.timeStampSwitch) then
        timeStamp:SetText(ArkadiusTradeTools:TimeStampToDateTimeString(data.timeStamp + ArkadiusTradeTools:GetLocalTimeShift()))
    else
        timeStamp:SetText(ArkadiusTradeTools:TimeStampToAgoString(data.timeStamp))
    end

    timeStamp:SetWidth(timeStamp.header:GetWidth() - 10)
    timeStamp:SetHidden(timeStamp.header:IsHidden())
	

    if (data.quantity == 1) then
        itemLink:SetQuantity("")
    else
        itemLink:SetQuantity(data.quantity)
    end

    if (data.internal == 1) then
        buyerName.normalColor = ZO_ColorDef:New(0.5, 0.5, 1, 1)
    else
        buyerName.normalColor = ZO_ColorDef:New(1, 1, 1, 1)
	end

    ArkadiusTradeToolsSortFilterList.SetupRow(self, rowControl, rowData)
end

---------------------------------------------------------------------------------------
function ArkadiusTradeToolsSales:Initialize(serverName, displayName)
    for i = 1, NUM_SALES_TABLES do
        if (SalesTables[i] == nil) then
            d("ArkadiusTradeToolsSales: Error! Number of data tables is not correct. Maybe you forgot to activate them in the addons menu?")

            return
        end
    end

    self.serverName = serverName
    self.displayName = displayName

    --- Setup sales frame ---
    self.frame = ArkadiusTradeToolsSalesFrame
    ArkadiusTradeTools.TabWindow:AddTab(self.frame, L["ATT_STR_SALES"], "/esoui/art/vendor/vendor_tabicon_sell_up.dds", "/esoui/art/vendor/vendor_tabicon_sell_up.dds", {left = 0.15, top = 0.15, right = 0.85, bottom = 0.85})

    self.list = ArkadiusTradeToolsSalesList:New(self, self.frame)
    self.frame.list = self.frame:GetNamedChild("List")
    self.frame.filterBar = self.frame:GetNamedChild("FilterBar")
    self.frame.headers = self.frame:GetNamedChild("Headers")
--    self.frame.headers.OnHeaderShow = function(header, hidden) self:OnHeaderVisibilityChanged(header, hidden) end
--    self.frame.headers.OnHeaderHide = function(header, hidden) self:OnHeaderVisibilityChanged(header, hidden) end
    self.frame.headers.sellerName = self.frame.headers:GetNamedChild("SellerName")
    self.frame.headers.buyerName = self.frame.headers:GetNamedChild("BuyerName")
    self.frame.headers.guildName = self.frame.headers:GetNamedChild("GuildName")
    self.frame.headers.itemLink = self.frame.headers:GetNamedChild("ItemLink")
	self.frame.headers.eaprice = self.frame.headers:GetNamedChild("eaPrice")
    self.frame.headers.price = self.frame.headers:GetNamedChild("Price")
    self.frame.headers.timeStamp = self.frame.headers:GetNamedChild("TimeStamp")
    self.frame.timeSelect = self.frame:GetNamedChild("TimeSelect")
    self.frame.OnResize = self.OnResize
    self.frame:SetHandler("OnEffectivelyShown", function(_, hidden) if (hidden == false) then self.list:RefreshData() end end)

    self:LoadSales()
    self:LoadSettings()

    self.GuildRoster:Initialize(Settings.guildRoster)
    self.TradingHouse:Initialize(Settings.tradingHouse)
    self.TooltipExtensions:Initialize(Settings.tooltips)

    self.addMenuItems = {}

    ZO_PreHook('ZO_LinkHandler_OnLinkClicked', function(...) return self:OnLinkClicked(...) end)
    ZO_PreHook('ZO_LinkHandler_OnLinkMouseUp', function(...) return self:OnLinkClicked(...) end)
    ZO_PreHook('ZO_InventorySlot_ShowContextMenu', function(...) return self:ShowContextMenu(...) end)
    ZO_PreHook('ShowMenu', function() return self:ShowMenu() end)

--ZO_PreHookHandler(ZO_SmithingTopLevelCreationPanelResultTooltip, "OnMouseUp", function(...)
--    d("xxx")
--end)
--local ZO_SmithingTopLevelCreationPanelResultTooltipSetPendingSmithingItem = ZO_SmithingTopLevelCreationPanelResultTooltip.SetPendingSmithingItem
--ZO_SmithingTopLevelCreationPanelResultTooltip.SetPendingSmithingItem = function(...) ZO_SmithingTopLevelCreationPanelResultTooltipSetPendingSmithingItem(...) d(...) end


    --- Setup FilterBar ---
    local function callback(...)
        self.list.Filter:SetNeedsRefilter()
        self.list:RefreshData()
        Settings.filters.timeSelection = self.frame.filterBar.Time:GetSelectedIndex()
    end

    self.frame.filterBar.Time:AddItem({name = L["ATT_STR_TODAY"], callback = callback, NewerThanTimeStamp = function() return ArkadiusTradeTools:GetStartOfDay(0) end, OlderThanTimeStamp = function() return GetTimeStamp() end})
    self.frame.filterBar.Time:AddItem({name = L["ATT_STR_YESTERDAY"], callback = callback, NewerThanTimeStamp = function() return ArkadiusTradeTools:GetStartOfDay(-1) end, OlderThanTimeStamp = function() return ArkadiusTradeTools:GetStartOfDay(0) - 1 end})
    self.frame.filterBar.Time:AddItem({name = L["ATT_STR_TWO_DAYS_AGO"], callback = callback, NewerThanTimeStamp = function() return ArkadiusTradeTools:GetStartOfDay(-2) end, OlderThanTimeStamp = function() return ArkadiusTradeTools:GetStartOfDay(-1) - 1 end})
    self.frame.filterBar.Time:AddItem({name = L["ATT_STR_THIS_WEEK"], callback = callback, NewerThanTimeStamp = function() return ArkadiusTradeTools:GetStartOfWeek(0, true) end, OlderThanTimeStamp = function() return GetTimeStamp() end})
    self.frame.filterBar.Time:AddItem({name = L["ATT_STR_LAST_WEEK"], callback = callback, NewerThanTimeStamp = function() return ArkadiusTradeTools:GetStartOfWeek(-1, true) end, OlderThanTimeStamp = function() return ArkadiusTradeTools:GetStartOfWeek(0, true) - 1 end})
    self.frame.filterBar.Time:AddItem({name = L["ATT_STR_PRIOR_WEEK"], callback = callback, NewerThanTimeStamp = function() return ArkadiusTradeTools:GetStartOfWeek(-2, true) end, OlderThanTimeStamp = function() return ArkadiusTradeTools:GetStartOfWeek(-1, true) - 1 end})
    self.frame.filterBar.Time:AddItem({name = L["ATT_STR_7_DAYS"], callback = callback, NewerThanTimeStamp = function() return ArkadiusTradeTools:GetStartOfDay(-7) end, OlderThanTimeStamp = function() return GetTimeStamp() end})
    self.frame.filterBar.Time:AddItem({name = L["ATT_STR_10_DAYS"], callback = callback, NewerThanTimeStamp = function() return ArkadiusTradeTools:GetStartOfDay(-10) end, OlderThanTimeStamp = function() return GetTimeStamp() end})
    self.frame.filterBar.Time:AddItem({name = L["ATT_STR_14_DAYS"], callback = callback, NewerThanTimeStamp = function() return ArkadiusTradeTools:GetStartOfDay(-14) end, OlderThanTimeStamp = function() return GetTimeStamp() end})
    self.frame.filterBar.Time:AddItem({name = L["ATT_STR_30_DAYS"], callback = callback, NewerThanTimeStamp = function() return 0 end, OlderThanTimeStamp = function() return GetTimeStamp() end})
    self.frame.filterBar.Time:SelectByIndex(Settings.filters.timeSelection)
    self.frame.filterBar.Text.OnChanged = function(text) self.list:RefreshFilters() end
    self.frame.filterBar.Text:SetText(displayName:lower())
    self.frame.filterBar.Text.tooltip:SetContent(L["ATT_STR_FILTER_TEXT_TOOLTIP"])
    self.frame.filterBar.SubStrings.OnToggle = function(switch, pressed) self.list.Filter:SetNeedsRefilter() self.list:RefreshFilters() Settings.filters.useSubStrings = pressed end
    self.frame.filterBar.SubStrings:SetPressed(Settings.filters.useSubStrings)
    self.frame.filterBar.SubStrings.tooltip:SetContent(L["ATT_STR_FILTER_SUBSTRING_TOOLTIP"])
    ---------------------------------------------

    self.list:RefreshData()
    ArkadiusTradeTools:RegisterCallback(ArkadiusTradeTools.EVENTS.ON_GUILDHISTORY_STORE, function(...) self:OnGuildHistoryEventStore(...) end)
end

function ArkadiusTradeToolsSales:Finalize()
    self:SaveSettings()
    self:DeleteSales()
end

function ArkadiusTradeToolsSales:GetSettingsMenu()
    local settingsMenu = {}
    local guildNames = {}

    table.insert(settingsMenu, {type = "header", name = L["ATT_STR_SALES"]})
    table.insert(settingsMenu, {type = "checkbox", name = L["ATT_STR_ENABLE_GUILD_ROSTER_EXTENSIONS"], getFunc = function() return self.GuildRoster:IsEnabled() end, setFunc = function(bool) self.GuildRoster:Enable(bool) end})
    table.insert(settingsMenu, {type = "checkbox", name = L["ATT_STR_ENABLE_TRADING_HOUSE_EXTENSIONS"], getFunc = function() return self.TradingHouse:IsEnabled() end, setFunc = function(bool) self.TradingHouse:Enable(bool) end, requiresReload = true})
    table.insert(settingsMenu, {type = "checkbox", name = L["ATT_STR_ENABLE_TOOLTIP_EXTENSIONS"], getFunc = function() return self.TooltipExtensions:IsEnabled() end, setFunc = function(bool) self.TooltipExtensions:Enable(bool) end})
    table.insert(settingsMenu, {type = "checkbox", name = L["ATT_STR_ENABLE_TOOLTIP_EXTENSIONS_GRAPH"], getFunc = function() return self.TooltipExtensions:IsGraphEnabled() end, setFunc = function(bool) self.TooltipExtensions:EnableGraph(bool) end, disabled = function() return not self.TooltipExtensions:IsEnabled() end})
    table.insert(settingsMenu, {type = "checkbox", name = L["ATT_STR_ENABLE_TOOLTIP_EXTENSIONS_CRAFTING"], getFunc = function() return self.TooltipExtensions:IsCraftingEnabled() end, setFunc = function(bool) self.TooltipExtensions:EnableCrafting(bool) end, disabled = function() return not self.TooltipExtensions:IsEnabled() end})

    for guildName, _ in pairs(TemporaryVariables.guildNamesLowered) do
        table.insert(guildNames, guildName)
    end

    table.sort(guildNames)

    table.insert(settingsMenu, {type = "description", text = L["ATT_STR_KEEP_SALES_FOR_DAYS"]})

    for _, guildName in pairs(guildNames) do
        table.insert(settingsMenu, {type = "slider", name = guildName, min = 1, max = 30, getFunc = function() return Settings.guilds[guildName].keepSalesForDays end, setFunc = function(value) Settings.guilds[guildName].keepSalesForDays = value end})
    end

    table.insert(settingsMenu, {type = "custom"})

    return settingsMenu
end

function ArkadiusTradeToolsSales:LoadSettings()
    --- Apply list header visibilites ---
    if (Settings.hiddenHeaders) then
        local headers = self.frame.headers

        for _, headerKey in pairs(Settings.hiddenHeaders) do
            for i = 1, headers:GetNumChildren() do
                local header = headers:GetChild(i)

                if ((header.key) and (header.key == headerKey)) then
                    header:SetHidden(true)

                    break
                end
            end
        end
    end

    --- Apply days to save sales per guild ---
    for guildName, _ in pairs(TemporaryVariables.guildNamesLowered) do
        Settings.guilds[guildName] = Settings.guilds[guildName] or {}

        if ((not Settings.guilds[guildName].keepSalesForDays) or ((Settings.guilds[guildName].keepSalesForDays < 1) and (Settings.guilds[guildName].keepSalesForDays > 30))) then
            Settings.guilds[guildName].keepSalesForDays = DefaultSettings.keepSalesForDays
        end
    end
end

function ArkadiusTradeToolsSales:SaveSettings()
    --- Save list header visibilites ---
    Settings.hiddenHeaders = {}

    if ((self.frame) and (self.frame.headers)) then
        local headers = self.frame.headers

        for i = 1, headers:GetNumChildren() do
            local header = headers:GetChild(i)

            if ((header.key) and (header:IsControlHidden())) then
                table.insert(Settings.hiddenHeaders, header.key)
            end
        end
    end
end

function ArkadiusTradeToolsSales:LoadSales()
    for t = 1, #SalesTables do
        for eventId, sale in pairs(SalesTables[t][self.serverName].sales) do
            self:UpdateTemporaryVariables(sale)
            self.list:UpdateMasterList(sale)
        end
    end
end

function ArkadiusTradeToolsSales:UpdateTemporaryVariables(sale)
    local displayNamesLowered = TemporaryVariables.displayNamesLowered
    local guildNamesLowered = TemporaryVariables.guildNamesLowered
    local itemNamesLowered = TemporaryVariables.itemNamesLowered
    local itemSales = TemporaryVariables.itemSales
    local guildSales = TemporaryVariables.guildSales

    local itemLinkInfos = TemporaryVariables.itemLinkInfos
    local itemLink = sale.itemLink
    --local itemTimeStampHour = ArkadiusTradeTools:GetStartOfHourFromTimeStamp(sale.timeStamp)

    --- Store item link information ---
    local itemName
    local itemType
    local itemLevel
    local itemCP
    local itemTrait
    local itemQuality
    local itemVouchers

    if (not itemLinkInfos[itemLink]) then
        itemName = GetItemLinkName(itemLink)
        itemType, _ = GetItemLinkItemType(itemLink)
        itemLevel = GetItemLinkRequiredLevel(itemLink)
        itemCP = GetItemLinkRequiredChampionPoints(itemLink)
        itemQuality = GetItemLinkQuality(itemLink)

        if ((itemType == ITEMTYPE_ARMOR) or (itemType == ITEMTYPE_WEAPON) or (itemType == ITEMTYPE_ARMOR_TRAIT) or (itemType == ITEMTYPE_WEAPON_TRAIT) or (itemType == ITEMTYPE_JEWELRY_TRAIT)) then
            --- This function is EXTREMELY time consuming ---
            itemTrait = GetItemLinkTraitInfo(itemLink)
        else
            itemTrait = ITEM_TRAIT_TYPE_NONE
        end

        if (itemType == ITEMTYPE_MASTER_WRIT) then
            itemVouchers = tonumber(GenerateMasterWritRewardText(itemLink):match("[0-9]+"))
        end

        itemLinkInfos[itemLink] = {name = itemName, itype = itemType, level = itemLevel, cp = itemCP, trait = itemTrait, quality = itemQuality, vouchers = itemVouchers}
    else
        itemName = itemLinkInfos[itemLink].name
        itemType = itemLinkInfos[itemLink].itype
        itemLevel = itemLinkInfos[itemLink].level
        itemCP = itemLinkInfos[itemLink].cp
        itemTrait = itemLinkInfos[itemLink].trait
        itemQuality = itemLinkInfos[itemLink].quality
    end

    --- Store item sales information ---
    itemSales[itemName] = itemSales[itemName] or {}
    itemSales[itemName][itemType] = itemSales[itemName][itemType] or {}
    itemSales[itemName][itemType][itemLevel] = itemSales[itemName][itemType][itemLevel] or {}
    itemSales[itemName][itemType][itemLevel][itemCP] = itemSales[itemName][itemType][itemLevel][itemCP] or {}
    itemSales[itemName][itemType][itemLevel][itemCP][itemTrait] = itemSales[itemName][itemType][itemLevel][itemCP][itemTrait] or {}
    itemSales[itemName][itemType][itemLevel][itemCP][itemTrait][itemQuality] = itemSales[itemName][itemType][itemLevel][itemCP][itemTrait][itemQuality] or {}

    table.insert(itemSales[itemName][itemType][itemLevel][itemCP][itemTrait][itemQuality], sale)

    --- Store name strings in lower case to improve filter performance ---
    displayNamesLowered[sale.buyerName] = displayNamesLowered[sale.buyerName] or sale.buyerName:lower()
    displayNamesLowered[sale.sellerName] = displayNamesLowered[sale.sellerName] or sale.sellerName:lower()
    guildNamesLowered[sale.guildName] = guildNamesLowered[sale.guildName] or sale.guildName:lower()
    itemNamesLowered[itemName] = itemNamesLowered[itemName] or itemName:lower()

    --- Store player sales/purchases per guild ---
    guildSales[sale.guildName] = guildSales[sale.guildName] or {sales = {}, displayNames = {}}
    guildSales[sale.guildName].displayNames[sale.buyerName] = guildSales[sale.guildName].displayNames[sale.buyerName] or {sales = {}, purchases = {}}
    guildSales[sale.guildName].displayNames[sale.sellerName] = guildSales[sale.guildName].displayNames[sale.sellerName] or {sales = {}, purchases = {}}

    table.insert(guildSales[sale.guildName].sales, sale)
    table.insert(guildSales[sale.guildName].displayNames[sale.buyerName].purchases, #guildSales[sale.guildName].sales)
    table.insert(guildSales[sale.guildName].displayNames[sale.sellerName].sales, #guildSales[sale.guildName].sales)
end

function ArkadiusTradeToolsSales:AddEvent(guildId, category, eventIndex)
    local eventType, secsSinceEvent, seller, buyer, quantity, itemLink, price, tax = GetGuildEventInfo(guildId, category, eventIndex)

    if (eventType ~= GUILD_EVENT_ITEM_SOLD) then
        return false
    end

    local timeStamp = GetTimeStamp()
    local guildName = GetGuildName(guildId)
    local eventTimeStamp = timeStamp - secsSinceEvent

    if ((Settings.guilds[guildName]) and (Settings.guilds[guildName].keepSalesForDays) and (Settings.guilds[guildName].keepSalesForDays < 10)) then
        local olderThanTimeStamp = timeStamp - Settings.guilds[guildName].keepSalesForDays * SECONDS_IN_DAY

        if (eventTimeStamp < olderThanTimeStamp) then
            return false
        end
    end

    local eventId = GetGuildEventId(guildId, category, eventIndex)
    local eventIdNum = tonumber(Id64ToString(eventId))
    local dataIndex = math.floor((eventIdNum % (NUM_SALES_TABLES * 2)) / 2) + 1
    local dataTable = SalesTables[dataIndex][self.serverName]

    if (eventIdNum ~= 0) then
        if (dataTable.sales[eventIdNum] == nil) then
            -- Add event to data table --
            dataTable.sales[eventIdNum] = {}
            dataTable.sales[eventIdNum].timeStamp = eventTimeStamp
            dataTable.sales[eventIdNum].guildName = guildName
            dataTable.sales[eventIdNum].sellerName = seller
            dataTable.sales[eventIdNum].buyerName = buyer
            dataTable.sales[eventIdNum].quantity = quantity
            dataTable.sales[eventIdNum].itemLink = itemLink
			dataTable.sales[eventIdNum].eaprice = eaprice
            dataTable.sales[eventIdNum].price = price
            dataTable.sales[eventIdNum].taxes = tax

            if (GetGuildMemberIndexFromDisplayName(guildId, buyer)) then
                dataTable.sales[eventIdNum].internal = 1
            else
                dataTable.sales[eventIdNum].internal = 0
            end

            --- Update temporary lists ---
            self:UpdateTemporaryVariables(dataTable.sales[eventIdNum])

            --- Update guild roster ---
            self.GuildRoster:Update(dataTable.sales[eventIdNum].guildName, dataTable.sales[eventIdNum].sellerName)
            self.GuildRoster:Update(dataTable.sales[eventIdNum].guildName, dataTable.sales[eventIdNum].buyerName)

            --- Add event to lists master list ---
            self.list:UpdateMasterList(dataTable.sales[eventIdNum])

            -- Announce sale
            if (dataTable.sales[eventIdNum].sellerName == self.displayName) then
                local saleString = string.format(L["ATT_FMTSTR_ANNOUNCE_SALE"], dataTable.sales[eventIdNum].quantity, dataTable.sales[eventIdNum].itemLink, ArkadiusTradeTools:LocalizeDezimalNumber(dataTable.sales[eventIdNum].price) .. " |t16:16:EsoUI/Art/currency/currency_gold.dds|t", dataTable.sales[eventIdNum].guildName)
                ArkadiusTradeTools:ShowNotification(saleString)
            end

            return true
        else
--[=[           local oldBuyerName = self.SavedVariables.displayNames[dataTable.sales[eventIdNum][BUYER]]
            local oldSellerName = self.SavedVariables.displayNames[dataTable.sales[eventIdNum][SELLER]]

            if (oldBuyerName ~= buyer) then
               self.SavedVariables.renames[buyer] = oldBuyerName
            end

            if (oldSellerName ~= seller) then
               self.SavedVariables.renames[seller] = oldSellerName
            end--]=]
        end
    end

    return false
end

function ArkadiusTradeToolsSales:GetItemSalesInformation(itemLink, fromTimeStamp, allQualities)
    if (not self:IsItemLink(itemLink)) then
        return {}
    end

    fromTimeStamp = fromTimeStamp or 0
    local result = {[itemLink] = {}}
    local itemSales = TemporaryVariables.itemSales
    local itemLinkInfos = TemporaryVariables.itemLinkInfos
    local itemLinkInfo = itemLinkInfos[itemLink]
    local itemType
    local itemQuality
    local itemName
    local itemLevel
    local itemCP
    local itemTrait

    if (itemLinkInfo) then
        itemType = itemLinkInfo.itype
        itemQuality = itemLinkInfo.quality
        itemName = itemLinkInfo.name
        itemLevel = itemLinkInfo.level
        itemCP = itemLinkInfo.cp
        itemTrait = itemLinkInfo.trait
    else
        itemType = GetItemLinkItemType(itemLink)
        itemQuality = GetItemLinkQuality(itemLink)
        itemName = GetItemLinkName(itemLink)
        itemLevel = GetItemLinkRequiredLevel(itemLink)
        itemCP = GetItemLinkRequiredChampionPoints(itemLink)
        itemTrait = GetItemLinkTraitInfo(itemLink)
    end

    if ((itemSales[itemName]) and (itemSales[itemName][itemType]) and (itemSales[itemName][itemType][itemLevel]) and (itemSales[itemName][itemType][itemLevel][itemCP]) and (itemSales[itemName][itemType][itemLevel][itemCP][itemTrait])) then
        for quality, sales in pairs(itemSales[itemName][itemType][itemLevel][itemCP][itemTrait]) do
            local res = nil

            if (quality == itemQuality) then
                res = result[itemLink]
            else
                if (allQualities) then
                    local link

                    if (#sales > 0) then
                        link = sales[1].itemLink
                        result[link] = {}
                        res = result[link]
                    end
                end
            end

            if (res) then
                for _, sale in pairs(sales) do
                    local res1 = res

                    if (sale.timeStamp > fromTimeStamp) then
                        if ((itemType == ITEMTYPE_POTION) or (itemType == ITEMTYPE_POISON)) then
						    if (sale.itemLink ~= itemLink) then
                                res1 = nil
                            end
                        end

                        local data = {}
                        data.price = sale.price
					    data.timeStamp = sale.timeStamp
                        data.guildName = sale.guildName
					
                        if (itemType == ITEMTYPE_MASTER_WRIT) then
                            data.quantity = itemLinkInfos[sale.itemLink].vouchers
                        else
                            data.quantity = sale.quantity
                        end

                        if (res1) then
                            table.insert(res1, data)
                        end
                    end
                end
            end
        end
    end

    return result
end

function ArkadiusTradeToolsSales:GetPurchasesAndSalesVolumes(guildName, displayName, newerThanTimeStamp, olderThanTimestamp)
    newerThanTimeStamp = newerThanTimeStamp or 0
    olderThanTimestamp = olderThanTimestamp or GetTimeStamp()

    local guildSales = TemporaryVariables.guildSales
    local purchasesVolume = 0
    local salesVolume = 0

    if ((guildSales) and (guildSales[guildName]) and (guildSales[guildName].displayNames[displayName])) then
        --- Collect sales volume ---
        for _, i in pairs(guildSales[guildName].displayNames[displayName].sales) do
            if ((guildSales[guildName].sales[i].timeStamp >= newerThanTimeStamp) and (guildSales[guildName].sales[i].timeStamp <= olderThanTimestamp)) then
                salesVolume = salesVolume + guildSales[guildName].sales[i].price
            end
        end

        --- Collect purchases volume ---
        for _, i in pairs(guildSales[guildName].displayNames[displayName].purchases) do
            if ((guildSales[guildName].sales[i].timeStamp >= newerThanTimeStamp) and (guildSales[guildName].sales[i].timeStamp <= olderThanTimestamp)) then
                purchasesVolume = purchasesVolume + guildSales[guildName].sales[i].price
            end
        end
    end

    return purchasesVolume, salesVolume
end

function ArkadiusTradeToolsSales:GetAveragePricePerItem(itemLink, newerThanTimeStamp)
    if (not self:IsItemLink(itemLink)) then
        return 0
    end

    newerThanTimeStamp = newerThanTimeStamp or 0
    local itemSales = self:GetItemSalesInformation(itemLink, newerThanTimeStamp)
    local itemQuality = GetItemLinkQuality(itemLink)
    local itemType = GetItemLinkItemType(itemLink)
    local averagePrice = 0
    local quantity = 0

    for _, sale in pairs(itemSales[itemLink]) do
        averagePrice = averagePrice + sale.price
        quantity = quantity + sale.quantity
    end

    if (quantity > 0) then
        averagePrice = math.attRound(averagePrice / quantity, 2)
    else
        averagePrice = 0
    end

    if (itemType == ITEMTYPE_MASTER_WRIT) then
        local vouchers = tonumber(GenerateMasterWritRewardText(itemLink):match("[0-9]+"))
        averagePrice = averagePrice * vouchers
    end

    return averagePrice
end


function ArkadiusTradeToolsSales:GetCrafingComponentPrices(itemLink, fromTimeStamp)
    if (not self:IsItemLink(itemLink)) then
        return {}
    end

    local itemLinkInfos = TemporaryVariables.itemLinkInfos
    local itemLinkInfo = itemLinkInfos[itemLink]
    local itemType
    local components

    if (itemLinkInfo) then
        itemType = itemLinkInfo.itype
    else
        itemType = GetItemLinkItemType(itemLink)
    end

    if (itemType == ITEMTYPE_MASTER_WRIT) then
        components = self:GetMasterWritComponents(itemLink)
    else
        return {}
    end

    for _, component in ipairs(components) do
        component.price = self:GetAveragePricePerItem(component.itemLink, fromTimeStamp)
    end

    return components
end

function ArkadiusTradeToolsSales:DeleteSales()
    local olderThanTimeStamps = {}
    local timeStamp = GetTimeStamp()

    for guildName, guildData in pairs(Settings.guilds) do
        olderThanTimeStamps[guildName] = timeStamp - guildData.keepSalesForDays * SECONDS_IN_DAY
    end

    --- Delete old sales ---
    for _, salesTable in pairs(SalesTables) do
	    for serverName, data in pairs(salesTable) do
            local sales = data.sales

	        for id, sale in pairs(sales) do
                timeStamp = olderThanTimeStamps[sale.guildName] or DefaultSettings.keepSalesForDays * SECONDS_IN_DAY

                if (sale.timeStamp <= timeStamp) then
                    sales[id] = nil
                end
            end
        end
	end
end

function ArkadiusTradeToolsSales:StatsToChat(itemLink, language)
    if (not self:IsItemLink(itemLink)) then
        return
    end

    itemLink = self:NormalizeItemLink(itemLink)
    local L = L

    if ((language) and (L[language])) then
        L = L[language]
    end

--    local days = ArkadiusTradeToolsSalesPopupTooltip:GetDays()
    local days = Settings.tooltips.days
    local fromTimeStamp = GetTimeStamp() - days * 60 * 60 * 24
    local itemSales = self:GetItemSalesInformation(itemLink, fromTimeStamp)
    local numSales = 0
    local averagePrice = 0
    local quantity = 0
    local vouchers = 0

    if (itemSales[itemLink]) then
        for _, sale in pairs(itemSales[itemLink]) do
            averagePrice = averagePrice + sale.price
            quantity = quantity + sale.quantity
            numSales = numSales + 1
        end

        if (quantity > 0) then
            averagePrice = math.attRound(averagePrice / quantity, 2)
        else
            averagePrice = 0
        end
    end

    itemLink = itemLink:gsub("H0:", "H1:")
    local chatString
    local itemType = GetItemLinkItemType(itemLink)

    if (numSales > 0) then
        if (itemType == ITEMTYPE_MASTER_WRIT) then
            local vouchers = tonumber(GenerateMasterWritRewardText(itemLink):match("[0-9]+"))
            chatString = string.format(L["ATT_FMTSTR_STATS_MASTER_WRIT"], itemLink, ArkadiusTradeTools:LocalizeDezimalNumber(averagePrice * vouchers), ArkadiusTradeTools:LocalizeDezimalNumber(numSales), ArkadiusTradeTools:LocalizeDezimalNumber(quantity), ArkadiusTradeTools:LocalizeDezimalNumber(averagePrice), days)
        else
            if (quantity > numSales) then
                chatString = string.format(L["ATT_FMTSTR_STATS_ITEM"], itemLink, ArkadiusTradeTools:LocalizeDezimalNumber(averagePrice), ArkadiusTradeTools:LocalizeDezimalNumber(numSales), ArkadiusTradeTools:LocalizeDezimalNumber(quantity), days)
            else
                chatString = string.format(L["ATT_FMTSTR_STATS_NO_QUANTITY"], itemLink, ArkadiusTradeTools:LocalizeDezimalNumber(averagePrice), ArkadiusTradeTools:LocalizeDezimalNumber(numSales), days)
            end
        end
    else
        chatString = string.format(L["ATT_FMTSTR_STATS_NO_SALES"], itemLink, days)
    end

    CHAT_SYSTEM.textEntry:InsertLink(chatString)
end

function ArkadiusTradeToolsSales:GetStatistics(newerThanTimeStamp, olderThanTimeStamp)
    newerThanTimeStamp = newerThanTimeStamp or 0
    olderThanTimeStamp = olderThanTimeStamp or GetTimeStamp()

    local result = {}
    local salesVolumePerGuild
    local salesVolumePerPlayer
    local salesCountPerGuild
    local salesCountPerPlayer
    local taxesPerGuild
    local taxesPerPlayer
	local internalSalesVolumePerGuild
	local internalSalesVolumePerPlayer
    local itemCountPerGuild
    local itemCountPerPlayer
    local guildSales = TemporaryVariables.guildSales

    for guildName, guildNameData in pairs(guildSales) do
        salesVolumePerGuild = 0
        internalSalesVolumePerGuild = 0
        salesCountPerGuild = 0
        itemCountPerGuild = 0
        taxesPerGuild = 0

        for displayName, displayNameData in pairs(guildNameData.displayNames) do
            salesVolumePerPlayer = 0
            internalSalesVolumePerPlayer = 0
            salesCountPerPlayer = 0
            taxesPerPlayer = 0
            itemCountPerPlayer = 0

            for _, saleIndex in pairs(displayNameData.sales) do
		        if ((guildNameData.sales[saleIndex].timeStamp >= newerThanTimeStamp) and ((guildNameData.sales[saleIndex].timeStamp < olderThanTimeStamp))) then
                    salesVolumePerPlayer = salesVolumePerPlayer + guildNameData.sales[saleIndex].price
                    internalSalesVolumePerPlayer = internalSalesVolumePerPlayer + guildNameData.sales[saleIndex].price * guildNameData.sales[saleIndex].internal
                    itemCountPerPlayer = itemCountPerPlayer + guildNameData.sales[saleIndex].quantity
                    salesCountPerPlayer = salesCountPerPlayer + 1
                    taxesPerPlayer = taxesPerPlayer + guildNameData.sales[saleIndex].taxes
                end
            end

            salesVolumePerGuild = salesVolumePerGuild + salesVolumePerPlayer
            internalSalesVolumePerGuild = internalSalesVolumePerGuild + internalSalesVolumePerPlayer
            itemCountPerGuild = itemCountPerGuild + itemCountPerPlayer
            salesCountPerGuild = salesCountPerGuild + salesCountPerPlayer
            taxesPerGuild = taxesPerGuild + taxesPerPlayer

            if (salesVolumePerPlayer > 0) then
                local data = {}
                data.displayName = displayName
                data.guildName = guildName
                data.salesVolume = salesVolumePerPlayer
                data.salesCount = salesCountPerPlayer
                data.itemCount = itemCountPerPlayer
                data.taxes = taxesPerPlayer
                data.internalSalesVolumePercentage = math.attRound(100 / salesVolumePerPlayer * internalSalesVolumePerPlayer, 2)

                table.insert(result, data)
            end
        end

        if (salesVolumePerGuild > 0) then
            local data = {}
            data.displayName = ""
            data.guildName = guildName
            data.salesVolume = salesVolumePerGuild
            data.salesCount = salesCountPerGuild
            data.itemCount = itemCountPerGuild
            data.taxes = taxesPerGuild
            data.internalSalesVolumePercentage = math.attRound(100 / salesVolumePerGuild * internalSalesVolumePerGuild, 2)

            table.insert(result, data)
        end
    end

    return result
end

function ArkadiusTradeToolsSales:IsItemLink(itemLink)
    if (type(itemLink) == "string") then
        return (itemLink:match("|H%d:item:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+|h.*|h") ~= nil)
    end

    return false
end

function ArkadiusTradeToolsSales:NormalizeItemLink(itemLink)
    if (not self:IsItemLink(itemLink)) then
        return nil
    end

    itemLink = itemLink:gsub("H1:", "H0:")

    --- Clear crafted flag and extra text---
    local subString1 = itemLink:match("|H%d:item:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:")
    local subString2 = itemLink:match(":%d+:%d+:%d+:%d+|h.*|h")
    subString2 = subString2:gsub("|h.*|h", "|h|h")
    return subString1 .. "0" .. subString2
end

function ArkadiusTradeToolsSales:OnGuildHistoryEventStore(guildId)
    self.nextGuildHistoryScanIndex = self.nextGuildHistoryScanIndex or {}
    self.nextGuildHistoryScanIndex[guildId] = self.nextGuildHistoryScanIndex[guildId] or 1

    local numGuildEvents = GetNumGuildEvents(guildId, GUILD_HISTORY_STORE)
    local listNeedsRefresh = false

local mss=GetGameTimeMilliseconds()	
    for i = self.nextGuildHistoryScanIndex[guildId], numGuildEvents do
        if (self:AddEvent(guildId, GUILD_HISTORY_STORE, i) == true) then
            listNeedsRefresh = true
        end
    end
local mse=GetGameTimeMilliseconds()
--d(mse-mss)

    if (listNeedsRefresh) then
        if (self.list:IsHidden()) then
            self.list:BuildMasterList()
        else
            self.list:RefreshData()
        end
    end

    self.nextGuildHistoryScanIndex[guildId] = GetNumGuildEvents(guildId, GUILD_HISTORY_STORE) + 1
end

function ArkadiusTradeToolsSales.OnResize(frame, width, height)
    frame.headers:Update()
    ZO_ScrollList_Commit(frame.list)
end

function ArkadiusTradeToolsSales:OnHeaderVisibilityChanged(header, hidden)
    d(hidden)
end

--- Prehooked API functions ---
function ArkadiusTradeToolsSales:OnLinkClicked(itemLink, mouseButton)
    if ((self:IsItemLink(itemLink)) and (mouseButton == MOUSE_BUTTON_INDEX_RIGHT)) then
        self.addMenuItems[L["ATT_STR_STATS_TO_CHAT"]] = function() self:StatsToChat(itemLink) end

        if (GetCVar("language.2") ~= "en") then
            self.addMenuItems[L["en"]["ATT_STR_STATS_TO_CHAT"]] = function() self:StatsToChat(itemLink, "en") end
        end
    end

    return false
end

function ArkadiusTradeToolsSales:ShowContextMenu(inventorySlot)
    local slotType = ZO_InventorySlot_GetType(inventorySlot)
    local itemLink = nil

    if ((slotType == SLOT_TYPE_ITEM) or (slotType == SLOT_TYPE_EQUIPMENT) or (slotType == SLOT_TYPE_BANK_ITEM) or (slotType == SLOT_TYPE_GUILD_BANK_ITEM) or (slotType == SLOT_TYPE_TRADING_HOUSE_POST_ITEM) or
        (slotType == SLOT_TYPE_REPAIR) or (slotType == SLOT_TYPE_CRAFTING_COMPONENT) or (slotType == SLOT_TYPE_PENDING_CRAFTING_COMPONENT) or (slotType == SLOT_TYPE_PENDING_CRAFTING_COMPONENT) or
        (slotType == SLOT_TYPE_PENDING_CRAFTING_COMPONENT) or (slotType == SLOT_TYPE_CRAFT_BAG_ITEM) or (slotType == SLOT_TYPE_MAIL_QUEUED_ATTACHMENT)) then
        local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)

        itemLink = GetItemLink(bag, index)
    elseif (slotType == SLOT_TYPE_TRADING_HOUSE_ITEM_RESULT) then
        itemLink = GetTradingHouseSearchResultItemLink(ZO_Inventory_GetSlotIndex(inventorySlot))
    elseif (slotType == SLOT_TYPE_TRADING_HOUSE_ITEM_LISTING) then
        itemLink = GetTradingHouseListingItemLink(ZO_Inventory_GetSlotIndex(inventorySlot))
    elseif (slotType == SLOT_TYPE_MAIL_ATTACHMENT) then
        local attachmentIndex = ZO_Inventory_GetSlotIndex(inventorySlot)

        if(attachmentIndex) then
            if (not inventorySlot.money) then
                itemLink = GetAttachedItemLink(MAIL_INBOX:GetOpenMailId(), attachmentIndex)
            end
        end
    end

    if (self:IsItemLink(itemLink)) then 
        self.addMenuItems[L["ATT_STR_STATS_TO_CHAT"]] = function() self:StatsToChat(itemLink) end
        self.addMenuItems[L["ATT_STR_OPEN_POPUP_TOOLTIP"]] = function() ZO_LinkHandler_OnLinkClicked(itemLink, MOUSE_BUTTON_INDEX_LEFT) end

        if (GetCVar("language.2") ~= "en") then
            self.addMenuItems[L["en"]["ATT_STR_STATS_TO_CHAT"]] = function() self:StatsToChat(itemLink, "en") end
        end
    end

    return false
end

function ArkadiusTradeToolsSales:ShowMenu()
    for text, callback in pairs(self.addMenuItems) do
        AddMenuItem(text, callback)
    end

    self.addMenuItems = {}

    return false
end

--------------------------------------------------------
------------------- Local functions --------------------
--------------------------------------------------------
local function PrepareTemporaryVariables()
    TemporaryVariables = {}
    TemporaryVariables.displayNamesLowered = {}
    TemporaryVariables.guildNamesLowered = {}
    TemporaryVariables.itemNamesLowered = {}
    TemporaryVariables.traitNamesLowered = {}
    TemporaryVariables.qualityNamesLowered = {}
    TemporaryVariables.itemLinkInfos = {}
    TemporaryVariables.itemSales = {}
    TemporaryVariables.guildSales = {}

    for i = ITEM_TRAIT_TYPE_MIN_VALUE, ITEM_TRAIT_TYPE_MAX_VALUE do
        TemporaryVariables.traitNamesLowered[i] = GetString("SI_ITEMTRAITTYPE", i):lower()
    end

    for i = ITEM_QUALITY_MIN_VALUE, ITEM_QUALITY_MAX_VALUE do
        TemporaryVariables.qualityNamesLowered[i] = GetString("SI_ITEMQUALITY", i):lower()
    end
end

local function onAddOnLoaded(eventCode, addonName)
    if (addonName ~= ArkadiusTradeToolsSales.NAME) then
        return
    end

    DefaultSettings = {}
    DefaultSettings.keepSalesForDays = 30

    ArkadiusTradeToolsSalesData = ArkadiusTradeToolsSalesData or {}
    ArkadiusTradeToolsSalesData.settings = ArkadiusTradeToolsSalesData.settings or {}

    Settings = ArkadiusTradeToolsSalesData.settings
    Settings.guilds = Settings.guilds or {}
    Settings.guildRoster = Settings.guildRoster or {}
    Settings.tooltips = Settings.tooltips or {}
    Settings.tradingHouse = Settings.tradingHouse or {}
    Settings.filters = Settings.filters or {}
    Settings.filters.timeSelection = Settings.filters.timeSelection or 4
    if (Settings.filters.sellerName == nil) then Settings.filters.sellerName = true end
    if (Settings.filters.buyerName == nil) then Settings.filters.buyerName = false end
    if (Settings.filters.guildName == nil) then Settings.filters.guildName = true end
    if (Settings.filters.itemName == nil) then Settings.filters.itemName = true end
    if (Settings.filters.timeStamp == nil) then Settings.filters.timeStamp = false end
    if (Settings.filters.price == nil) then Settings.filters.price = false end
    if (Settings.filters.useSubStrings == nil) then Settings.filters.useSubStrings = true end

    PrepareTemporaryVariables()

    EVENT_MANAGER:UnregisterForEvent(ArkadiusTradeToolsSales.NAME, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ArkadiusTradeToolsSales.NAME, EVENT_ADD_ON_LOADED, onAddOnLoaded)
