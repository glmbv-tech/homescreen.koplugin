--[[--
Full-screen Home screen widget (PocketBook-like start screen).

Layout (portrait):

    ┌──────────────────────────────┐
    │ 14:00                   85%  │  status bar (optional)
    │ ┌───────────────┐ ┌────────┐ │
    │ │               │ │   2    │ │
    │ │       1       │ │        │ │  4 latest books
    │ │               │ ├───┬────┤ │
    │ │               │ │ 3 │ 4  │ │
    │ └───────────────┘ └───┴────┘ │
    │ ┌──┐┌──┐┌──┐┌──┐┌──┐         │  5 more books from the history
    │ │5 ││6 ││7 ││8 ││9 │         │
    │ └──┘└──┘└──┘└──┘└──┘         │
    │                              │
    │ Library History Coll. Stats Settings
    └──────────────────────────────┘
--]]--

local Blitbuffer = require("ffi/blitbuffer")
local BookList = require("ui/widget/booklist")
local ButtonDialog = require("ui/widget/buttondialog")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local ImageWidget = require("ui/widget/imagewidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local Notification = require("ui/widget/notification")
local OverlapGroup = require("ui/widget/overlapgroup")
local ReadHistory = require("readhistory")
local RightContainer = require("ui/widget/container/rightcontainer")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local lfs = require("libs/libkoreader-lfs")
local Screen = Device.screen

local CoverCache = require("homescreen_covercache")
local T = require("homescreen_l10n")

local NB_BOOKS = 9
local COVER_RATIO = 1.5 -- height / width of a tile

---------------------------------------------------------------------------
-- One book tile
---------------------------------------------------------------------------

local CoverTile = InputContainer:extend{
    width = nil,
    height = nil,
    file = nil,          -- nil: empty slot
    title = nil,
    percent = nil,       -- 0..1 or nil
    crop = true,
    show_progress = true,
    on_tap = nil,
    on_hold = nil,
}

function CoverTile:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
    if self.file and Device:isTouchDevice() then
        self.ges_events = {
            TapTile = { GestureRange:new{ ges = "tap", range = function() return self.dimen end } },
            HoldTile = { GestureRange:new{ ges = "hold", range = function() return self.dimen end } },
        }
    end
    self:setCover(self.cover_bb, self.cover_disposable)
end

function CoverTile:setCover(bb, disposable)
    if self[1] and self[1].free then
        self[1]:free()
    end
    self.has_image = bb and true or false
    if bb then
        self[1] = ImageWidget:new{
            image = bb,
            image_disposable = disposable and true or false,
            width = self.width,
            height = self.height,
            scale_factor = 0,
            crop_to_fit = self.crop,
        }
    elseif self.file then
        -- No cover (yet): show the title on a light background
        local pad = Size.padding.default
        local font_size = self.width > Screen:scaleBySize(120) and 20 or 14
        self[1] = FrameContainer:new{
            width = self.width,
            height = self.height,
            bordersize = 0,
            padding = 0,
            background = Blitbuffer.COLOR_GRAY_E,
            CenterContainer:new{
                dimen = Geom:new{ w = self.width, h = self.height },
                TextBoxWidget:new{
                    text = self.title or "",
                    face = Font:getFace("cfont", font_size),
                    width = math.max(1, self.width - 2 * pad),
                    height = math.max(1, self.height - 2 * pad),
                    height_overflow_show_ellipsis = true,
                    alignment = "center",
                    bold = true,
                },
            },
        }
    else
        -- Empty slot
        self[1] = FrameContainer:new{
            width = self.width,
            height = self.height,
            bordersize = 0,
            padding = 0,
            background = Blitbuffer.COLOR_WHITE,
            VerticalSpan:new{ width = 0 },
        }
    end
end

function CoverTile:paintTo(bb, x, y)
    InputContainer.paintTo(self, bb, x, y)
    local w, h = self.width, self.height
    if self.file or not self.has_image then
        local border_color = self.file and Blitbuffer.COLOR_DARK_GRAY or Blitbuffer.COLOR_GRAY_D
        bb:paintBorder(x, y, w, h, Size.border.thin, border_color)
    end
    if self.file and self.show_progress and self.percent and self.percent > 0 then
        local bar_h = math.max(Screen:scaleBySize(3), math.floor(h / 90))
        local bar_y = y + h - bar_h
        bb:paintRect(x, bar_y, w, bar_h, Blitbuffer.COLOR_WHITE)
        bb:paintRect(x, bar_y, math.floor(w * math.min(self.percent, 1) + 0.5), bar_h, Blitbuffer.COLOR_BLACK)
    end
end

function CoverTile:onTapTile()
    if self.on_tap then self.on_tap(self) end
    return true
end

function CoverTile:onHoldTile()
    if self.on_hold then self.on_hold(self) end
    return true
end

---------------------------------------------------------------------------
-- Bottom navigation button
---------------------------------------------------------------------------

local NavButton = InputContainer:extend{
    width = nil,
    height = nil,
    icon_file = nil,
    icon_size = nil,
    text = nil,
    callback = nil,
}

function NavButton:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
    if Device:isTouchDevice() then
        self.ges_events = {
            TapNav = { GestureRange:new{ ges = "tap", range = function() return self.dimen end } },
        }
    end
    local label = TextWidget:new{
        text = self.text,
        face = Font:getFace("cfont", 14),
        max_width = self.width - Size.padding.small * 2,
    }
    self[1] = CenterContainer:new{
        dimen = Geom:new{ w = self.width, h = self.height },
        VerticalGroup:new{
            align = "center",
            IconWidget:new{
                file = self.icon_file,
                width = self.icon_size,
                height = self.icon_size,
                alpha = true,
            },
            VerticalSpan:new{ width = Size.padding.small },
            label,
        },
    }
end

function NavButton:onTapNav()
    if self.callback then
        -- let the tap gesture finish before opening another full-screen widget
        UIManager:nextTick(self.callback)
    end
    return true
end

---------------------------------------------------------------------------
-- The Home screen itself
---------------------------------------------------------------------------

local HomeScreenWidget = InputContainer:extend{
    ui = nil,          -- FileManager or ReaderUI instance
    plugin = nil,      -- the plugin instance (settings, actions)
    covers_fullscreen = true, -- hint for UIManager:_repaint()
}

function HomeScreenWidget:init()
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end
    self.dithered = true
    self:build()
end

function HomeScreenWidget:getEntries()
    local entries = {}
    for _, item in ipairs(ReadHistory.hist) do
        if #entries >= NB_BOOKS then break end
        local file = item.file
        if file and not item.dim and lfs.attributes(file, "mode") == "file" then
            table.insert(entries, file)
        end
    end
    return entries
end

function HomeScreenWidget:getBookTitle(file)
    local title, authors
    if self.ui and self.ui.bookinfo then
        local ok, props = pcall(self.ui.bookinfo.getDocProps, self.ui.bookinfo, file, nil, true)
        if ok and props then
            title = props.display_title or props.title
            authors = props.authors
        end
    end
    if not title or title == "" then
        title = file:match("([^/]+)$"):gsub("%.[^.]+$", "")
    end
    if authors and authors ~= "" then
        authors = authors:gsub("\n.*", "") -- first author only
        return title .. "\n\n" .. authors
    end
    return title
end

function HomeScreenWidget:getPercent(file)
    local ok, info = pcall(BookList.getBookInfo, file)
    if ok and info then
        if info.status == "complete" then return 1 end
        return info.percent_finished
    end
end

--- Computes the geometry of all blocks for the current screen size.
function HomeScreenWidget:computeLayout()
    local sw, sh = Screen:getWidth(), Screen:getHeight()
    local L = { sw = sw, sh = sh }
    L.margin = Screen:scaleBySize(12)
    L.gap = Screen:scaleBySize(6)        -- "tight" spacing between covers
    L.status_h = self.plugin:isSettingTrue("show_status_bar") and Screen:scaleBySize(28) or Screen:scaleBySize(8)
    L.icon_size = Screen:scaleBySize(34)
    L.nav_h = L.icon_size + Screen:scaleBySize(30)
    L.nav_line = Size.line.thin

    local gap = L.gap
    local avail_h = sh - L.status_h - L.nav_h - L.nav_line - 2 * L.margin
    local content_w = sw - 2 * L.margin

    -- With a big cover taking 60% of the width and a 1.5 tile ratio, total
    -- height of the two blocks ≈ 1.2 × width: shrink the width if needed.
    local function totalHeight(cw)
        local big_w = math.floor((cw - gap) * 0.6)
        local small5_w = math.floor((cw - 4 * gap) / 5)
        return math.floor(big_w * COVER_RATIO) + gap + math.floor(small5_w * COVER_RATIO)
    end
    while content_w > 100 and totalHeight(content_w) > avail_h do
        content_w = content_w - 2
    end
    L.content_w = content_w
    L.side = math.floor((sw - content_w) / 2)

    -- Top block: one big cover + right column (one medium + two small)
    L.big_w = math.floor((content_w - gap) * 0.6)
    L.big_h = math.floor(L.big_w * COVER_RATIO)
    L.right_w = content_w - gap - L.big_w
    L.small_w = math.floor((L.right_w - gap) / 2)
    L.small_w2 = L.right_w - gap - L.small_w
    L.small_h = math.floor(L.small_w * COVER_RATIO)
    L.medium_h = L.big_h - gap - L.small_h

    -- Bottom block: five small covers in a row
    L.row_w = math.floor((content_w - 4 * gap) / 5)
    L.row_w_last = content_w - 4 * gap - 4 * L.row_w
    L.row_h = math.floor(L.row_w * COVER_RATIO)

    L.covers_h = L.big_h + gap + L.row_h
    L.filler_h = math.max(0, avail_h - L.covers_h)
    return L
end

function HomeScreenWidget:makeTile(index, w, h)
    local file = self.entries[index]
    local cover_bb, disposable = nil, false
    local title, percent
    if file then
        local cached = CoverCache:get(file)
        if cached then
            cover_bb = cached
        else
            if cached == nil then
                table.insert(self.pending, index)
            end
            local thumb = CoverCache:getThumbnail(file)
            if thumb then
                cover_bb, disposable = thumb, true
            end
            title = self:getBookTitle(file)
        end
        percent = self:getPercent(file)
    end
    local tile = CoverTile:new{
        width = w,
        height = h,
        file = file,
        title = title,
        percent = percent,
        crop = self.plugin:isSettingTrue("crop_covers"),
        show_progress = self.plugin:isSettingTrue("show_progress"),
        cover_bb = cover_bb,
        cover_disposable = disposable,
        on_tap = function(t) self:openBook(t.file) end,
        on_hold = function(t) self:showBookMenu(t) end,
    }
    self.tiles[index] = tile
    return tile
end

function HomeScreenWidget:buildStatusBar(L)
    if not self.plugin:isSettingTrue("show_status_bar") then
        self.clock_widget, self.battery_widget = nil, nil
        return VerticalSpan:new{ width = L.status_h }
    end
    local face = Font:getFace("ffont", 15)
    self.clock_widget = TextWidget:new{ text = self:getClockText(), face = face }
    self.battery_widget = TextWidget:new{ text = self:getBatteryText(), face = face }
    local dimen = Geom:new{ w = L.sw, h = L.status_h }
    return OverlapGroup:new{
        dimen = dimen,
        LeftContainer:new{
            dimen = dimen,
            HorizontalGroup:new{ HorizontalSpan:new{ width = L.side }, self.clock_widget },
        },
        RightContainer:new{
            dimen = dimen,
            HorizontalGroup:new{ self.battery_widget, HorizontalSpan:new{ width = L.side } },
        },
    }
end

function HomeScreenWidget:getClockText()
    local datetime = require("datetime")
    local ok, text = pcall(datetime.secondsToHour, os.time(), G_reader_settings:isTrue("twelve_hour_clock"))
    return ok and text or os.date("%H:%M")
end

function HomeScreenWidget:getBatteryText()
    if not Device:hasBattery() then return "" end
    local powerd = Device:getPowerDevice()
    local ok, level = pcall(powerd.getCapacity, powerd)
    if not ok or not level then return "" end
    local charging = false
    pcall(function() charging = powerd:isCharging() end)
    return (charging and "+ " or "") .. level .. "%"
end

function HomeScreenWidget:buildCovers(L)
    local gap = L.gap
    if #self.entries == 0 then
        return CenterContainer:new{
            dimen = Geom:new{ w = L.sw, h = L.covers_h },
            TextBoxWidget:new{
                text = T("empty_history"),
                face = Font:getFace("cfont", 20),
                width = L.content_w,
                alignment = "center",
            },
        }
    end
    local top = HorizontalGroup:new{
        align = "top",
        self:makeTile(1, L.big_w, L.big_h),
        HorizontalSpan:new{ width = gap },
        VerticalGroup:new{
            align = "left",
            self:makeTile(2, L.right_w, L.medium_h),
            VerticalSpan:new{ width = gap },
            HorizontalGroup:new{
                align = "top",
                self:makeTile(3, L.small_w, L.small_h),
                HorizontalSpan:new{ width = gap },
                self:makeTile(4, L.small_w2, L.small_h),
            },
        },
    }
    local row = HorizontalGroup:new{ align = "top" }
    for i = 5, NB_BOOKS do
        if i > 5 then table.insert(row, HorizontalSpan:new{ width = gap }) end
        table.insert(row, self:makeTile(i, i == NB_BOOKS and L.row_w_last or L.row_w, L.row_h))
    end
    return HorizontalGroup:new{
        HorizontalSpan:new{ width = L.side },
        VerticalGroup:new{
            align = "left",
            top,
            VerticalSpan:new{ width = gap },
            row,
        },
    }
end

function HomeScreenWidget:buildNavBar(L)
    local plugin_dir = self.plugin.path
    local buttons = {
        { icon = "library",     text = T("library"),     action = "library" },
        { icon = "history",     text = T("history"),     action = "history" },
        { icon = "collections", text = T("collections"), action = "collections" },
        { icon = "statistics",  text = T("statistics"),  action = "statistics" },
        { icon = "settings",    text = T("settings"),    action = "settings" },
    }
    local group = HorizontalGroup:new{ align = "center" }
    local btn_w = math.floor(L.sw / #buttons)
    for i, b in ipairs(buttons) do
        local w = (i == #buttons) and (L.sw - btn_w * (#buttons - 1)) or btn_w
        table.insert(group, NavButton:new{
            width = w,
            height = L.nav_h,
            icon_file = plugin_dir .. "/icons/" .. b.icon .. ".svg",
            icon_size = L.icon_size,
            text = b.text,
            callback = function() self:onNavAction(b.action) end,
        })
    end
    return VerticalGroup:new{
        LineWidget:new{
            dimen = Geom:new{ w = L.sw, h = L.nav_line },
            background = Blitbuffer.COLOR_GRAY,
        },
        group,
    }
end

function HomeScreenWidget:build()
    if self[1] then
        self[1]:free()
    end
    self.entries = self:getEntries()
    CoverCache:keepOnly(self.entries)
    self.tiles = {}
    self.pending = {}

    local L = self:computeLayout()
    self.layout = L
    self.dimen = Geom:new{ x = 0, y = 0, w = L.sw, h = L.sh }

    self[1] = FrameContainer:new{
        width = L.sw,
        height = L.sh,
        padding = 0,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{
            align = "left",
            self:buildStatusBar(L),
            VerticalSpan:new{ width = L.margin },
            self:buildCovers(L),
            VerticalSpan:new{ width = L.filler_h + L.margin },
            self:buildNavBar(L),
        },
    }
end

-- Extract missing covers one by one, refreshing each tile as soon as it is ready.
function HomeScreenWidget:processPending()
    self.pending_task = nil
    if self.closed then return end
    local index = table.remove(self.pending, 1)
    if not index then return end
    local tile = self.tiles[index]
    if tile and tile.file then
        local bb = CoverCache:extract(tile.file)
        if self.closed then return end
        if bb then
            tile:setCover(bb, false)
            UIManager:setDirty(self, "ui", tile.dimen, true)
        end
    end
    if #self.pending > 0 then
        self.pending_task = function() self:processPending() end
        UIManager:scheduleIn(0.05, self.pending_task)
    end
end

function HomeScreenWidget:startBackgroundTasks()
    if #self.pending > 0 and not self.pending_task then
        self.pending_task = function() self:processPending() end
        UIManager:scheduleIn(0.3, self.pending_task)
    end
    if self.clock_widget and not self.clock_task then
        self.clock_task = function()
            self.clock_task = nil
            if self.closed then return end
            self:updateStatusBar()
            self:startBackgroundTasks()
        end
        UIManager:scheduleIn(60 - os.date("*t").sec, self.clock_task)
    end
end

function HomeScreenWidget:stopBackgroundTasks()
    if self.pending_task then
        UIManager:unschedule(self.pending_task)
        self.pending_task = nil
    end
    if self.clock_task then
        UIManager:unschedule(self.clock_task)
        self.clock_task = nil
    end
end

function HomeScreenWidget:updateStatusBar()
    if not self.clock_widget then return end
    self.clock_widget:setText(self:getClockText())
    self.battery_widget:setText(self:getBatteryText())
    UIManager:setDirty(self, "ui", Geom:new{ x = 0, y = 0, w = self.layout.sw, h = self.layout.status_h })
end

function HomeScreenWidget:refresh()
    self:stopBackgroundTasks()
    self:build()
    UIManager:setDirty(self, "ui", nil, true)
    self:startBackgroundTasks()
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

function HomeScreenWidget:openBook(file)
    if lfs.attributes(file, "mode") ~= "file" then
        UIManager:show(Notification:new{ text = T("file_missing") })
        self:refresh()
        return
    end
    filemanagerutil.openFile(self.ui, file, function()
        self:onClose()
    end)
end

function HomeScreenWidget:showBookMenu(tile)
    local dialog
    dialog = ButtonDialog:new{
        title = tile.title or self:getBookTitle(tile.file),
        title_align = "center",
        buttons = {
            {
                {
                    text = T("open_book"),
                    callback = function()
                        UIManager:close(dialog)
                        self:openBook(tile.file)
                    end,
                },
            },
            {
                {
                    text = T("book_info"),
                    callback = function()
                        UIManager:close(dialog)
                        if self.ui.bookinfo then
                            self.ui.bookinfo:show(tile.file)
                        end
                    end,
                },
            },
            {
                {
                    text = T("show_in_library"),
                    callback = function()
                        UIManager:close(dialog)
                        self:showInLibrary(tile.file)
                    end,
                },
            },
            {
                {
                    text = T("reload_cover"),
                    callback = function()
                        UIManager:close(dialog)
                        CoverCache:forget(tile.file)
                        self:refresh()
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
end

function HomeScreenWidget:showInLibrary(file)
    self:onClose()
    if self.ui.document then
        self.plugin:suppressNextShow()
        self.ui:onClose()
        self.ui:showFileManager(file)
    elseif self.ui.file_chooser then
        local dir = file:match("(.*)/")
        self.ui.file_chooser:changeToPath(dir, file)
    end
end

function HomeScreenWidget:onNavAction(action)
    local ui = self.ui
    if action == "library" then
        self:onClose()
        if ui.document then
            -- opened from a book: go to the file manager
            self.plugin:suppressNextShow()
            ui:onHome()
        end
    elseif action == "history" then
        ui.history:onShowHist()
    elseif action == "collections" then
        ui.collections:onShowCollList()
    elseif action == "statistics" then
        if ui.statistics and ui.statistics.onShowCalendarView then
            ui.statistics:onShowCalendarView()
        else
            UIManager:show(Notification:new{ text = T("stats_unavailable") })
        end
    elseif action == "settings" then
        -- the "Settings" (gear) tab: 2nd in File manager, 3rd in Reader
        ui.menu:onShowMenu(ui.document and 3 or 2)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

-- Is the gesture inside KOReader's top menu zone (DTAP_ZONE_MENU, the top 1/8 of the screen)?
local function inTopMenuZone(ges)
    if not ges or not ges.pos then return false end
    local zone = G_defaults:readSetting("DTAP_ZONE_MENU") or { x = 0, y = 0, w = 1, h = 1/8 }
    local sw, sh = Screen:getWidth(), Screen:getHeight()
    local x, y = ges.pos.x, ges.pos.y
    return x >= zone.x * sw and x < (zone.x + zone.w) * sw
       and y >= zone.y * sh and y < (zone.y + zone.h) * sh
end

-- Tap / swipe down at the top of the screen opens the main menu, like in the
-- File manager and the Reader, even when it lands on a cover.
function HomeScreenWidget:handleTopMenuGesture(ges)
    if not ges or not inTopMenuZone(ges) then return false end
    local menu = self.ui and self.ui.menu
    if not menu or not menu.onShowMenu then return false end
    local activation = G_reader_settings:readSetting("activate_menu") or "swipe_tap"
    local wanted
    if ges.ges == "tap" then
        wanted = activation ~= "swipe"
    elseif ges.ges == "swipe" and ges.direction == "south" then
        wanted = activation ~= "tap"
    end
    if not wanted then return false end
    local tab_index = menu._getTabIndexFromLocation and menu:_getTabIndexFromLocation(ges) or nil
    menu:onShowMenu(tab_index)
    return true
end

-- Intercept gestures before they reach the cover tiles (children get events first).
function HomeScreenWidget:handleEvent(event)
    if event.handler == "onGesture" and self:handleTopMenuGesture(event.args and event.args[1]) then
        return true
    end
    return InputContainer.handleEvent(self, event)
end

function HomeScreenWidget:onShow()
    self:startBackgroundTasks()
    return true
end

function HomeScreenWidget:onClose()
    if self.closed then return true end
    self.closed = true
    self:stopBackgroundTasks()
    UIManager:close(self, "flashui")
    return true
end

function HomeScreenWidget:onCloseWidget()
    self.closed = true
    self:stopBackgroundTasks()
    if self.plugin then
        self.plugin:onHomeScreenClosed(self)
    end
end

-- A book is being opened (from us or from History/Collections shown above us)
function HomeScreenWidget:onShowingReader()
    self:onClose()
end

-- Screen rotation / window resize: the screen is rotated by the File manager
-- or Reader below us (they get the broadcast after us), so rebuild on next tick.
function HomeScreenWidget:scheduleRelayout()
    UIManager:nextTick(function()
        if not self.closed then self:refresh() end
    end)
end
HomeScreenWidget.onSetRotationMode = HomeScreenWidget.scheduleRelayout
HomeScreenWidget.onScreenResize = HomeScreenWidget.scheduleRelayout

-- Back from History/Collections/a dialog: refresh covers order and progress
function HomeScreenWidget:onResume()
    if not self.closed then
        UIManager:scheduleIn(0.5, function()
            if not self.closed then self:updateStatusBar() end
        end)
    end
end

function HomeScreenWidget:onBookMetadataChanged()
    if not self.closed then self:refresh() end
end

return HomeScreenWidget
