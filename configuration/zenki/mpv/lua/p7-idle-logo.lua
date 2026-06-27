-- p7 idle screen replacement for the mpv zenka
-- hides the built-in mpv logo / "[ drop files ]" text and shows our own
-- also applies OSC color theme via change-list (bypasses '#' limitation)

local mp = require 'mp'
local msg = require 'mp.msg'
local options = require 'mp.options'
local utils = require 'mp.utils'

local o = {
    logo_image = "",
    logo_scale = 0.25,
    logo_text = "< mpv.play >",
    text_size = 28,
    text_color = "47C306",
    text_outline = 1,
    text_outline_color = "000000",
    text_shadow = 0,
    text_shadow_color = "12061B",
    text_font = "sans-serif",
    show_text = true,
    z_index = 0,
    tmp_dir = "/run/.7",

    -- OSC color theme opts (empty = don't apply, leave OSC defaults)
    -- passed as p7_idle-osc_KEY=VALUE via --script-opts (no '#' needed here)
    osc_bg      = "",   -- osc background_color
    osc_boxalpha= "",   -- osc boxalpha [ numeric 0=opaque 255=clear ]
    osc_timecode= "",   -- osc timecode_color
    osc_title   = "",   -- osc title_color
    osc_timepos = "",   -- osc time_pos_color
    osc_btn     = "",   -- osc buttons_color
    osc_sbtnL   = "",   -- osc small_buttonsL_color
    osc_sbtnR   = "",   -- osc small_buttonsR_color
    osc_topbtn  = "",   -- osc top_buttons_color
    osc_held    = "",   -- osc held_element_color
    osc_outline = "",   -- osc time_pos_outline_color
    osc_layout  = "",   -- osc layout [ topbar|bottombar|box|slimbox|floating ]

    -- native mpv OSD colors [ arrow-key seek bar, status text ]
    osd_color      = "",   -- --osd-color      [ seek bar fill + OSD text ]
    osd_back_color = "",   -- --osd-back-color [ seek bar background ]
}
options.read_options(o, "p7_idle")

local LOGO_ID = 42

local logo_ready = false
local logo_w, logo_h = 0, 0
local logo_bgra = ""

local function file_exists(path)
    local f = io.open(path, "rb")
    if f then f:close() return true end
    return false
end

local function hex2ass(hex)
    hex = tostring(hex):match("^%s*(.-)%s*$")
    hex = hex:gsub("^['\"]+", ""):gsub("['\"]+$", "")
    hex = hex:match("^%s*(.-)%s*$")
    hex = hex:gsub("^#", "")
    if #hex == 6 then
        return hex:sub(5,6) .. hex:sub(3,4) .. hex:sub(1,2)
    end
    return hex
end

-- apply OSC theme colors — one change-list call per opt (comma in value = broken)
local function apply_osc_opts()
    local count = 0

    local function set_color(key, val)
        if val and val ~= "" then
            val = val:gsub("^#", "")
            if #val == 6 then
                mp.commandv("change-list", "script-opts", "append",
                    "osc-" .. key .. "=#" .. val)
                count = count + 1
            end
        end
    end
    local function set_plain(key, val)
        if val and val ~= "" then
            mp.commandv("change-list", "script-opts", "append",
                "osc-" .. key .. "=" .. val)
            count = count + 1
        end
    end

    set_color("background_color",       o.osc_bg)
    set_color("timecode_color",         o.osc_timecode)
    set_color("title_color",            o.osc_title)
    set_color("time_pos_color",         o.osc_timepos)
    set_color("buttons_color",          o.osc_btn)
    set_color("small_buttonsL_color",   o.osc_sbtnL)
    set_color("small_buttonsR_color",   o.osc_sbtnR)
    set_color("top_buttons_color",      o.osc_topbtn)
    set_color("held_element_color",     o.osc_held)
    set_color("time_pos_outline_color", o.osc_outline)
    set_plain("boxalpha",               o.osc_boxalpha)
    set_plain("layout",                 o.osc_layout)

    if count > 0 then
        msg.info("p7-idle-logo: applied " .. count .. " osc opts")
    end
end

-- defer so the built-in OSC has time to register its read_options callback
mp.add_timeout(0.1, apply_osc_opts)

local function apply_osd_colors()
    if o.osd_color ~= "" then
        local c = o.osd_color:gsub("^#", "")
        if #c == 6 then mp.set_property("osd-color", "#" .. c) end
    end
    if o.osd_back_color ~= "" then
        local c = o.osd_back_color:gsub("^#", "")
        if #c == 6 then mp.set_property("osd-back-color", "#" .. c) end
    end
end
apply_osd_colors()

local function shell(args)
    local res = mp.command_native({
        name = "subprocess",
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false,
        args = args,
    })
    if res and res.status == 0 then
        return res.stdout or ""
    end
    if res and res.stderr then
        msg.warn(table.concat(args, " ") .. " : " .. res.stderr)
    else
        msg.warn("command failed: " .. table.concat(args, " "))
    end
    return nil
end

local function prepare_logo()
    if o.logo_image == "" or not file_exists(o.logo_image) then
        msg.info("p7-idle-logo: no logo_image configured or file not found")
        return false
    end

    local pid = utils.getpid()
    local base = o.tmp_dir .. "/p7-mpv-idle-logo-" .. pid
    logo_bgra = base .. ".bgra"

    mp.command_native({
        name = "subprocess",
        playback_only = false,
        args = {"mkdir", "-p", o.tmp_dir},
    })

    local size = shell({"identify", "-format", "%w %h", o.logo_image})
    if not size then
        msg.warn("p7-idle-logo: cannot identify " .. o.logo_image)
        return false
    end
    local src_w, src_h = size:match("^(%d+)%s+(%d+)")
    src_w, src_h = tonumber(src_w), tonumber(src_h)
    if not src_w or not src_h then return false end

    local max = 1024
    local scale = 1
    if math.max(src_w, src_h) > max then
        scale = max / math.max(src_w, src_h)
    end
    logo_w = math.floor(src_w * scale)
    logo_h = math.floor(src_h * scale)

    local geo = logo_w .. "x" .. logo_h
    shell({"convert", o.logo_image, "-resize", geo, "bgra:" .. logo_bgra})

    if not file_exists(logo_bgra) then
        msg.warn("p7-idle-logo: failed to create bgra from " .. o.logo_image)
        return false
    end
    logo_ready = true
    return true
end

local osd_overlay = nil

local function render()
    if not logo_ready and o.logo_image ~= "" then
        prepare_logo()
    end

    local osd_w = mp.get_property_number("osd-width") or 0
    local osd_h = mp.get_property_number("osd-height") or 0
    if osd_w == 0 or osd_h == 0 then return end

    local dw, dh = 0, 0
    local logo_x, logo_y = 0, 0

    local text_y = math.floor(osd_h / 2)

    if logo_ready then
        dh = math.floor(osd_h * o.logo_scale)
        dw = math.floor(dh * logo_w / logo_h)
        logo_x = math.floor((osd_w - dw) / 2)

        -- center logo+text as a single block; gap between logo bottom and text
        local gap = math.floor(o.text_size * 0.3)
        local block_h = dh + gap + o.text_size
        logo_y = math.floor((osd_h - block_h) / 2)
        text_y = logo_y + dh + gap + math.floor(o.text_size / 2)

        mp.command_native({
            name = "overlay-add",
            id = LOGO_ID,
            x = logo_x,
            y = logo_y,
            file = logo_bgra,
            offset = 0,
            fmt = "bgra",
            w = logo_w,
            h = logo_h,
            stride = logo_w * 4,
            dw = dw,
            dh = dh,
        })
    end

    if o.show_text and o.logo_text ~= "" then
        if not osd_overlay then
            osd_overlay = mp.create_osd_overlay("ass-events")
        end
        osd_overlay.res_x = osd_w
        osd_overlay.res_y = osd_h
        osd_overlay.z = o.z_index
        osd_overlay.data = string.format(
            "{\\an5\\fs%d\\fn%s\\1c&H%s&\\3c&H%s&\\4c&H%s&\\bord%d\\shad%d\\pos(%d,%d)}%s",
            o.text_size, o.text_font,
            hex2ass(o.text_color),
            hex2ass(o.text_outline_color),
            hex2ass(o.text_shadow_color),
            o.text_outline, o.text_shadow,
            math.floor(osd_w / 2), text_y, o.logo_text
        )
        osd_overlay:update()
    end
end

local function hide()
    if osd_overlay then
        osd_overlay:remove()
        osd_overlay = nil
    end
    mp.command_native({name = "overlay-remove", id = LOGO_ID})
end

local function update()
    if mp.get_property_native("idle-active") then
        render()
    else
        hide()
    end
end

mp.observe_property("idle-active", "native", update)
mp.observe_property("osd-width", "native", function()
    if mp.get_property_native("idle-active") then render() end
end)
mp.observe_property("osd-height", "native", function()
    if mp.get_property_native("idle-active") then render() end
end)

-- protocol-7 hotkeys --
mp.add_key_binding("Alt+.", "p7-open-window-place", function()
    mp.commandv("script-message", "protocol7-open-window-place")
end)
mp.add_key_binding("Alt+,", "p7-toggle-input-lock", function()
    mp.commandv("script-message", "protocol7-toggle-input-lock")
end)

mp.register_event("shutdown", function()
    hide()
    if logo_bgra ~= "" then
        os.remove(logo_bgra)
    end
end)

-- #,,.,,..,,...,.,,,...,..,,,,.,.,.,..,,..,,,,,,..,,...,...,,,,,..,,.,,,...,,..,
-- #RAQBPW2FKLX4ZEI4HCOLBHKFGWMUTBQGKBGLVAKNCFN2LCGXGDJ2CNPMX2XQGTWNNOETGR5XYWZJS
-- #\\\|G6TWT64LNHC55HLIWE5Q4AEC4GSG3D2PEKH4JL4V4JY6FJ6FEKM \ / AMOS7 \ YOURUM ::
-- #\[7]6TOKJUX2ECGO64PAQUWNXEO6T3MESNZG5HIH5U6KURCGHBAKKOCI 7  DATA SIGNATURE ::
-- #:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
