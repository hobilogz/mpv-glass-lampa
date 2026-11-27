local mp = require("mp")
local utils = require("mp.utils")

local pending, active

local function decode(value)
    return (value:gsub("%%(%x%x)", function(byte) return string.char(tonumber(byte, 16)) end))
end

local function set_title(value)
    local title = value:gsub("[%z\1-\31\127]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    if title ~= "" then mp.set_property("file-local-options/force-media-title", title) end
end

local function torrent_file(url)
    local path = url:match("^https?://[^/]+([^?]*)") or ""
    local hash = path:match("/gst/(%x+)/master%.m3u8$")
    if not hash and path:match("/stream/[^/]+$") then
        hash = url:match("[?&]link=(%x+)&") or url:match("[?&]link=(%x+)$")
    end
    local index = url:match("[?&]index=(%d+)&") or url:match("[?&]index=(%d+)$")
    if hash and #hash == 40 and index and #index <= 10 then
        return hash:lower(), tostring(tonumber(index))
    end
end

mp.add_hook("on_load", 50, function()
    pending = nil
    local path = mp.get_property("path", "")
    local stream, token, start, label = path:match(
        "^(https?://[^#]+)#lampa%-mpv=(%x+)&start=(%d+)&title=([^#&]*)$")
    if stream and #token == 32 and #start <= 7 and #label <= 3000 then
        local hash, index = torrent_file(stream)
        if not hash then return end
        local name = hash .. "-" .. index .. ".json"
        local file = mp.command_native({"expand-path", "~~/lampa-progress/" .. name})
        pending = {token = token:lower(), file = file}
        mp.set_property("stream-open-filename", stream)
        mp.set_property("file-local-options/save-position-on-quit", "no")
        mp.set_property("file-local-options/start", start)
        set_title(decode(label))
        return
    end

    stream, label = path:match("^(https?://[^#]+)#lampa%-title=([^#&]+)$")
    if stream and #label <= 3000 and torrent_file(stream) then
        mp.set_property("stream-open-filename", stream)
        set_title(decode(label))
    end
end)

mp.add_hook("on_preloaded", 50, function()
    if mp.get_property("force-media-title", "") ~= "" then return end
    local url = mp.get_property("path", "")
    if not torrent_file(url) then return end
    local raw = url:match("^https?://[^?]+/stream/([^/?#]+)%?")
    if not raw then return end
    local once = decode(raw)
    local name = raw:find("%%25%x%x") and decode(once) or once
    local current = mp.get_property("media-title", ""):match("^[^?#]*")
    if current == "" or current == raw or current == once or current == name then
        set_title((name:gsub("%.%w+$", "")))
    end
end)

local function save(final)
    local entry = active
    if not entry or not entry.file or not entry.duration or not entry.time then return end
    local time = math.min(entry.duration, entry.time)
    if time < 1 and not entry.saved then return end
    if time == entry.saved and not final then return end

    local temp = entry.file .. "." .. entry.token .. ".tmp"
    local file = io.open(temp, "wb")
    if not file then return end
    file:write(utils.format_json({token = entry.token, time = time, duration = entry.duration, final = final}))
    file:close()
    if not os.rename(temp, entry.file) then
        os.remove(entry.file)
        if not os.rename(temp, entry.file) then
            os.remove(temp)
            return
        end
    end
    entry.saved = time
end

local function sample()
    if not active then return end
    local time = mp.get_property_number("time-pos")
    local duration = mp.get_property_number("duration")
    if time and time >= 0 and duration and duration >= 1 and duration <= 604800 then
        active.time = math.floor(time + 0.5)
        active.duration = math.floor(duration + 0.5)
    end
end

local timer = mp.add_periodic_timer(1, function()
    sample()
    save(false)
end)
timer:kill()

mp.register_event("file-loaded", function()
    active = pending
    pending = nil
    if active then timer:resume() end
end)

mp.observe_property("time-pos", "number", function(_, time)
    if active and time and time >= 0 then active.time = math.floor(time + 0.5) end
end)

mp.register_event("end-file", function(event)
    if active and active.duration and event.reason == "eof" then active.time = active.duration end
    save(true)
    timer:kill()
    active = nil
    pending = nil
end)

mp.register_event("shutdown", function()
    sample()
    save(true)
end)
