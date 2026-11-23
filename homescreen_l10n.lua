--[[--
Strings of the Home screen plugin in English, Russian and Ukrainian.

The language follows the one selected in KOReader (Settings → Language).
Any other language falls back to English.
--]]--

local STRINGS = {
    en = {
        open_book          = "Open",
        book_info          = "Book information",
        show_in_library    = "Show in Library",
        reload_cover       = "Reload cover",
        plugin_name        = "Home screen",
        plugin_description = "A start screen with the covers of the last nine books from the history and quick buttons: Library, History, Collections, Statistics, Settings.",
        home_screen        = "Home screen",
        open_home_screen   = "Open home screen",
        library            = "Library",
        history            = "History",
        collections        = "Collections",
        statistics         = "Statistics",
        settings           = "Settings",
        show_on_startup    = "Show at startup",
        show_on_book_close = "Show after closing a book",
        show_progress      = "Show reading progress",
        show_status_bar    = "Show clock and battery",
        crop_covers        = "Fill tiles with covers (crop)",
        clear_cache        = "Clear cover cache",
        cache_cleared      = "Cover cache cleared.",
        empty_history      = "The history is empty.\nOpen a book from the Library.",
        file_missing       = "File does not exist.",
        stats_unavailable  = "The Reading statistics plugin is disabled.",
        loading_covers     = "Loading covers…",
    },
    ru = {
        open_book          = "Открыть",
        book_info          = "Информация о книге",
        show_in_library    = "Показать в Библиотеке",
        reload_cover       = "Обновить обложку",
        plugin_name        = "Главный экран",
        plugin_description = "Стартовый экран с обложками девяти последних книг из истории и кнопками: Библиотека, История, Коллекции, Статистика, Настройки.",
        home_screen        = "Главный экран",
        open_home_screen   = "Открыть главный экран",
        library            = "Библиотека",
        history            = "История",
        collections        = "Коллекции",
        statistics         = "Статистика",
        settings           = "Настройки",
        show_on_startup    = "Показывать при запуске",
        show_on_book_close = "Показывать после закрытия книги",
        show_progress      = "Показывать прогресс чтения",
        show_status_bar    = "Показывать часы и заряд батареи",
        crop_covers        = "Заполнять плитки обложками (обрезка)",
        clear_cache        = "Очистить кэш обложек",
        cache_cleared      = "Кэш обложек очищен.",
        empty_history      = "История пуста.\nОткройте книгу из Библиотеки.",
        file_missing       = "Файл не существует.",
        stats_unavailable  = "Плагин «Статистика чтения» отключён.",
        loading_covers     = "Загрузка обложек…",
    },
    uk = {
        open_book          = "Відкрити",
        book_info          = "Інформація про книгу",
        show_in_library    = "Показати в Бібліотеці",
        reload_cover       = "Оновити обкладинку",
        plugin_name        = "Головний екран",
        plugin_description = "Стартовий екран з обкладинками дев'яти останніх книг з історії та кнопками: Бібліотека, Історія, Колекції, Статистика, Налаштування.",
        home_screen        = "Головний екран",
        open_home_screen   = "Відкрити головний екран",
        library            = "Бібліотека",
        history            = "Історія",
        collections        = "Колекції",
        statistics         = "Статистика",
        settings           = "Налаштування",
        show_on_startup    = "Показувати під час запуску",
        show_on_book_close = "Показувати після закриття книги",
        show_progress      = "Показувати прогрес читання",
        show_status_bar    = "Показувати годинник і заряд батареї",
        crop_covers        = "Заповнювати плитки обкладинками (обрізання)",
        clear_cache        = "Очистити кеш обкладинок",
        cache_cleared      = "Кеш обкладинок очищено.",
        empty_history      = "Історія порожня.\nВідкрийте книгу з Бібліотеки.",
        file_missing       = "Файл не існує.",
        stats_unavailable  = "Плагін «Статистика читання» вимкнено.",
        loading_covers     = "Завантаження обкладинок…",
    },
}

local function currentLang()
    local lang
    local ok, gettext = pcall(require, "gettext")
    if ok and type(gettext) == "table" and gettext.current_lang and gettext.current_lang ~= "C" then
        lang = gettext.current_lang
    end
    if not lang and G_reader_settings then
        lang = G_reader_settings:readSetting("language")
    end
    lang = type(lang) == "string" and lang:lower() or "en"
    if lang:match("^uk") then return "uk" end
    if lang:match("^ru") then return "ru" end
    return "en"
end

--- Returns the translated string for `key` in the current KOReader language.
local function T(key)
    local lang_table = STRINGS[currentLang()] or STRINGS.en
    return lang_table[key] or STRINGS.en[key] or key
end

return T
