--[[--
Home screen: a PocketBook-like start screen for KOReader.

Shows the covers of the 9 most recent books from the history
(1 big + 1 medium + 2 small on top, 5 small below) and a bottom bar with
Library, History, Collections, Statistics and Settings buttons.

@module koplugin.HomeScreen
--]]--

local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local CoverCache = require("homescreen_covercache")
local HomeScreenWidget = require("homescreen_widget")
local T = require("homescreen_l10n")

local SETTINGS_KEY = "homescreen"
local DEFAULTS = {
    show_on_startup = true,
    show_on_book_close = true,
    show_progress = true,
    show_status_bar = true,
    crop_covers = true,
}

-- Session state shared by all plugin instances (one instance per FileManager/ReaderUI).
local session = {
    started = false,          -- the first FileManager of this KOReader run has been created
    suppress_next = false,    -- skip auto-show once (we are going to the Library on purpose)
    widget = nil,             -- currently shown HomeScreenWidget
}

local HomeScreen = WidgetContainer:extend{
    name = "homescreen",
    is_doc_only = false,
}

function HomeScreen:init()
    self.settings = G_reader_settings:readSetting(SETTINGS_KEY) or {}
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)

    if not self.ui.document then
        -- File manager instance: at startup, or after a book has been closed.
        local is_startup = not session.started
        session.started = true
        if session.suppress_next then
            session.suppress_next = false
        elseif (is_startup and self:isSettingTrue("show_on_startup"))
            or (not is_startup and self:isSettingTrue("show_on_book_close")) then
            -- The file manager is shown right after plugins init: show on top of it.
            UIManager:nextTick(function()
                self:onShowHomeScreen()
            end)
        end
    else
        session.started = true
    end
end

function HomeScreen:isSettingTrue(key)
    local v = self.settings[key]
    if v == nil then v = DEFAULTS[key] end
    return v and true or false
end

function HomeScreen:toggleSetting(key)
    self.settings[key] = not self:isSettingTrue(key)
    G_reader_settings:saveSetting(SETTINGS_KEY, self.settings)
end

function HomeScreen:suppressNextShow()
    session.suppress_next = true
end

function HomeScreen:onDispatcherRegisterActions()
    Dispatcher:registerAction("homescreen_show", {
        category = "none",
        event = "ShowHomeScreen",
        title = T("open_home_screen"),
        general = true,
    })
end

function HomeScreen:onShowHomeScreen()
    if session.widget and not session.widget.closed then
        session.widget:refresh()
        return true
    end
    local widget = HomeScreenWidget:new{
        ui = self.ui,
        plugin = self,
    }
    session.widget = widget
    UIManager:show(widget, "flashui")
    return true
end

function HomeScreen:onHomeScreenClosed(widget)
    if session.widget == widget then
        session.widget = nil
    end
end

function HomeScreen:onCloseWidget()
    -- Our UI (FileManager/ReaderUI) is going away: don't leave the home screen
    -- bound to a dead instance.
    if session.widget and session.widget.ui == self.ui and not session.widget.closed then
        session.widget:onClose()
    end
end

function HomeScreen:addToMainMenu(menu_items)
    local function toggle(key, text_key, separator)
        return {
            text = T(text_key),
            checked_func = function() return self:isSettingTrue(key) end,
            callback = function() self:toggleSetting(key) end,
            separator = separator,
        }
    end
    menu_items.homescreen = {
        text = T("home_screen"),
        sorting_hint = "main",
        sub_item_table = {
            {
                text = T("open_home_screen"),
                callback = function(touchmenu_instance)
                    if touchmenu_instance then touchmenu_instance:closeMenu() end
                    self:onShowHomeScreen()
                end,
                separator = true,
            },
            toggle("show_on_startup", "show_on_startup"),
            toggle("show_on_book_close", "show_on_book_close"),
            toggle("show_status_bar", "show_status_bar"),
            toggle("show_progress", "show_progress"),
            toggle("crop_covers", "crop_covers", true),
            {
                text = T("clear_cache"),
                keep_menu_open = true,
                callback = function()
                    CoverCache:clear()
                    UIManager:show(InfoMessage:new{ text = T("cache_cleared"), timeout = 2 })
                end,
            },
        },
    }
end

return HomeScreen
