--[[--
Cover cache of the Home screen plugin.

Covers are looked up in this order:
  1. memory (decoded blitbuffers of the books shown in this session);
  2. disk: <koreader data dir>/cache/homescreen/<md5 of the path>.png;
  3. the book itself (slow: the document has to be opened), the result
     is downscaled and saved to the disk cache.

The CoverBrowser database (if that plugin is enabled and already has a
thumbnail) is used as a quick temporary picture until extraction finishes.
--]]--

local DataStorage = require("datastorage")
local DocSettings = require("docsettings")
local RenderImage = require("ui/renderimage")
local Screen = require("device").screen
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local md5 = require("ffi/sha2").md5
local util = require("util")

local CoverCache = {
    dir = DataStorage:getDataDir() .. "/cache/homescreen",
    mem = {},  -- file path -> { bb = blitbuffer or false }
}

local function mtime(path)
    return path and lfs.attributes(path, "modification")
end

function CoverCache:_paths(file)
    local hash = md5(file)
    return self.dir .. "/" .. hash .. ".png", self.dir .. "/" .. hash .. ".none"
end

--- Maximum size of a stored cover: enough for the biggest tile on this screen.
function CoverCache:_maxSize()
    local w = math.floor(math.max(Screen:getWidth(), Screen:getHeight()) * 0.55)
    return w, math.floor(w * 1.6)
end

-- A cache file is valid if it is newer than the book and than its custom cover.
function CoverCache:_isFresh(cache_file, file)
    local cache_time = mtime(cache_file)
    if not cache_time then return false end
    local book_time = mtime(file) or 0
    if book_time > cache_time then return false end
    local ok, custom_cover = pcall(DocSettings.findCustomCoverFile, DocSettings, file)
    if ok and custom_cover then
        local custom_time = mtime(custom_cover) or 0
        if custom_time > cache_time then return false end
    end
    return true
end

--- Returns the cover blitbuffer, false (known to have no cover) or nil (unknown yet: call extract()).
function CoverCache:get(file)
    local entry = self.mem[file]
    if entry ~= nil then
        return entry.bb
    end
    local png, none = self:_paths(file)
    if self:_isFresh(png, file) then
        local ok, bb = pcall(RenderImage.renderImageFile, RenderImage, png, false)
        if ok and bb then
            self.mem[file] = { bb = bb }
            return bb
        end
    elseif self:_isFresh(none, file) then
        self.mem[file] = { bb = false }
        return false
    end
    return nil
end

--- Quick low-resolution cover from the CoverBrowser database, if any (not cached by us).
function CoverCache:getThumbnail(file)
    local ok, BookInfoManager = pcall(require, "bookinfomanager")
    if not ok or type(BookInfoManager) ~= "table" or not BookInfoManager.getBookInfo then
        return nil
    end
    local ok2, bookinfo = pcall(BookInfoManager.getBookInfo, BookInfoManager, file, true)
    if ok2 and bookinfo and bookinfo.cover_bb then
        return bookinfo.cover_bb
    end
    return nil
end

local function fitSize(img_w, img_h, max_w, max_h)
    if img_w <= max_w and img_h <= max_h then
        return img_w, img_h
    end
    local scale = math.min(max_w / img_w, max_h / img_h)
    return math.max(1, math.floor(img_w * scale + 0.5)), math.max(1, math.floor(img_h * scale + 0.5))
end

--- Opens the book, extracts its cover, stores it in memory and on disk.
-- Returns the blitbuffer or false.
function CoverCache:extract(file)
    local bb
    local ok, err = pcall(function()
        local BookInfo = require("apps/filemanager/filemanagerbookinfo")
        bb = BookInfo:getCoverImage(nil, file)
    end)
    if not ok then
        logger.warn("HomeScreen: cover extraction failed for", file, err)
        bb = nil
    end

    util.makePath(self.dir)
    local png, none = self:_paths(file)
    if bb then
        local max_w, max_h = self:_maxSize()
        local w, h = fitSize(bb:getWidth(), bb:getHeight(), max_w, max_h)
        if w ~= bb:getWidth() or h ~= bb:getHeight() then
            bb = RenderImage:scaleBlitBuffer(bb, w, h, true)
        end
        local ok_png, err_png = pcall(bb.writePNG, bb, png)
        if not ok_png then
            logger.warn("HomeScreen: cannot write cover cache", png, err_png)
        end
        os.remove(none)
        self.mem[file] = { bb = bb }
        return bb
    end
    -- remember that this book has no cover
    local f = io.open(none, "w")
    if f then f:close() end
    os.remove(png)
    self.mem[file] = { bb = false }
    return false
end

--- Frees decoded covers of books that are no longer shown.
function CoverCache:keepOnly(files)
    local keep = {}
    for _, file in ipairs(files) do keep[file] = true end
    for file, entry in pairs(self.mem) do
        if not keep[file] then
            if entry.bb then entry.bb:free() end
            self.mem[file] = nil
        end
    end
end

--- Drops a single book from the cache (e.g. after its cover was changed).
function CoverCache:forget(file)
    local entry = self.mem[file]
    if entry and entry.bb then entry.bb:free() end
    self.mem[file] = nil
    local png, none = self:_paths(file)
    os.remove(png)
    os.remove(none)
end

function CoverCache:clear()
    for _, entry in pairs(self.mem) do
        if entry.bb then entry.bb:free() end
    end
    self.mem = {}
    if lfs.attributes(self.dir, "mode") == "directory" then
        for name in lfs.dir(self.dir) do
            if name:match("%.png$") or name:match("%.none$") then
                os.remove(self.dir .. "/" .. name)
            end
        end
    end
end

return CoverCache
