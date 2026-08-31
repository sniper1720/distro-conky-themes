-- Distro Conky Themes: Octopus Main Lua Script

require('cairo')

local config_dir = conky_config:gsub("conky.conf$", "")
local settings = dofile(config_dir .. "settings.lua")

local function get_asset_path(asset_type, name)
    local theme = settings.theme_mode:lower()
    local path = config_dir .. "assets/"
    if asset_type == "common" then
        return path .. "common/" .. name
    elseif asset_type == "theme" then
        return path .. theme .. "/" .. name
    end
    return path .. name
end

function set_color(cr, alpha)
    if settings.theme_mode == "WHITE" then
        cairo_set_source_rgba(cr, 1, 1, 1, alpha)
    else
        cairo_set_source_rgba(cr, 0, 0, 0, alpha)
    end
end

function draw_image(cr, xc, yc, radius, path)
    if not path then return end
    local image = cairo_image_surface_create_from_png(path)
    if cairo_surface_status(image) ~= CAIRO_STATUS_SUCCESS then return end

    local w = cairo_image_surface_get_width(image)
    local h = cairo_image_surface_get_height(image)

    cairo_save(cr)
    cairo_arc(cr, xc, yc, radius, 0, 2 * math.pi)
    cairo_clip(cr)
    cairo_new_path(cr)
    cairo_translate(cr, xc, yc)
    cairo_scale(cr, (2 * radius) / w, (2 * radius) / h)
    cairo_translate(cr, -w / 2, -h / 2)
    cairo_set_source_surface(cr, image, 0, 0)
    cairo_paint(cr)
    cairo_restore(cr)
    cairo_surface_destroy(image)
end

function conky_setup() end

function conky_main()
    if conky_window == nil then return end

    local updates = tonumber(conky_parse("${updates}"))
    if updates < 3 then return end

    local surface
    if conky_surface ~= nil then
        surface = conky_surface()
    elseif cairo_xlib_surface_create ~= nil and conky_window.display then
        surface = cairo_xlib_surface_create(
            conky_window.display,
            conky_window.drawable,
            conky_window.visual,
            conky_window.width,
            conky_window.height)
    end
    if not surface then return end

    local cr = cairo_create(surface)
    if not cr then return end

    local font_opts = cairo_font_options_create()
    cairo_font_options_set_hint_style(font_opts, CAIRO_HINT_STYLE_FULL)
    cairo_font_options_set_hint_metrics(font_opts, CAIRO_HINT_METRICS_ON)
    cairo_font_options_set_antialias(font_opts, CAIRO_ANTIALIAS_GRAY)
    cairo_set_font_options(cr, font_opts)
    cairo_font_options_destroy(font_opts)

    local extents = cairo_text_extents_t:create()

    local width = conky_window.width
    local height = conky_window.height
    local interface = settings.network_interface
    local centerx = width / 2
    local centery = height / 2

    local head_radius = height / 15

    local disc_ratio = settings.disc_alpha or 0

    draw_image(cr, centerx, centery, head_radius, get_asset_path("theme", "linux.png"))

    if disc_ratio > 0 then
        set_color(cr, disc_ratio)
        cairo_arc(cr, centerx, centery, head_radius, 0, 2 * math.pi)
        cairo_fill(cr)
    end

    set_color(cr, 0.9)
    cairo_set_line_width(cr, height / 250)
    cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
    cairo_set_line_join(cr, CAIRO_LINE_JOIN_ROUND)
    cairo_arc(cr, centerx, centery, head_radius, 0, 2 * math.pi)
    cairo_stroke(cr)

    local clock_text = conky_parse("${time %X}")
    local clock_font = math.floor(height / 15)
    local clock_y = height / 6
    cairo_select_font_face(cr, "Roboto", 0, 1)
    cairo_set_font_size(cr, clock_font)
    cairo_text_extents(cr, clock_text, extents)
    set_color(cr, 1)
    cairo_move_to(cr, centerx - (extents.x_bearing + extents.width) / 2, clock_y)
    cairo_show_text(cr, clock_text)

    local clock_bottom = clock_y + extents.height + extents.y_bearing

    local hostname_text = conky_parse("${nodename}")
    local hostname_font = math.floor(height / 30)
    cairo_select_font_face(cr, "Roboto", 0, 1)
    cairo_set_font_size(cr, hostname_font)
    cairo_text_extents(cr, hostname_text, extents)
    set_color(cr, 1)
    local hostname_gap = hostname_font * 0.2
    cairo_move_to(cr, centerx - (extents.x_bearing + extents.width) / 2, clock_bottom + hostname_gap - extents.y_bearing)
    cairo_show_text(cr, hostname_text)

    local function draw_section(angle_deg, label, value_text, icon_name, is_gauge, gauge_val, warn_on_low)
        local angle = angle_deg * math.pi / 180
        local item_startx = centerx + math.cos(angle) * head_radius
        local item_starty = centery + math.sin(angle) * head_radius
        local spread = 6
        local item_endx = centerx + math.cos(angle) * width / spread
        local item_endy = centery + math.sin(angle) * height / spread
        local item_curvex = centerx + math.cos(angle) * width / (spread * 2)
        local item_curvey = centery + math.sin(angle) * height / (spread * 2)
        local item_radius = height / 50
        local item_centerx = item_endx + math.cos(angle) * (item_radius + (height / 150))
        local item_centery = item_endy + math.sin(angle) * (item_radius + (height / 150))
        local item_font_size = height / 50

        local cp1x, cp1y = item_curvex, item_curvey
        local curve_offset = height / 7.5
        local cp2x, cp2y = item_curvex, item_curvey - curve_offset

        if angle_deg == 50 then cp2x = item_curvex - curve_offset; cp2y = item_curvey + (curve_offset * 0.4) end
        if angle_deg == 90 then cp2x = item_curvex - curve_offset; cp2y = item_curvey + curve_offset end
        if angle_deg == 130 then cp2y = item_curvey + curve_offset end
        if angle_deg == 210 then cp2y = item_curvey - (curve_offset * 0.7) end
        if angle_deg == 250 then cp2x = item_curvex + (curve_offset * 0.5); cp2y = item_curvey - (curve_offset * 0.7) end
        if angle_deg == 170 then cp2y = item_curvey - (curve_offset * 0.4) end
        if angle_deg == 320 or angle_deg == 310 then cp2y = item_curvey - (curve_offset * 0.7) end

        cairo_move_to(cr, item_startx, item_starty)
        cairo_curve_to(cr, cp1x, cp1y, cp2x, cp2y, item_endx, item_endy)
        set_color(cr, 0.5)
        cairo_stroke(cr)

        local gauge_percent = tonumber(gauge_val or 0) or 0
        -- warn_on_low inverts the >85% critical tint for gauges where a low
        -- value is the danger (battery near empty), not a high one (CPU, RAM).
        local gauge_critical = false
        if is_gauge then
            gauge_critical = (warn_on_low and gauge_percent < 20) or (not warn_on_low and gauge_percent > 85)
        end

        cairo_arc(cr, item_centerx, item_centery, item_radius + (height / 150), 0, 2 * math.pi)
        set_color(cr, 0.4)
        if gauge_critical then
            cairo_set_source_rgba(cr, 1, 0, 0, 0.4)
        end
        cairo_fill(cr)

        if icon_name then
            draw_image(cr, item_centerx, item_centery, item_radius, get_asset_path("theme", icon_name))
        end

        cairo_arc(cr, item_centerx, item_centery, item_radius + (height / 150), 0, 2 * math.pi)
        set_color(cr, 1)
        if gauge_critical then
            cairo_set_source_rgba(cr, 1, 0, 0, 1)
        end
        cairo_stroke(cr)

        set_color(cr, 1)
        cairo_select_font_face(cr, "Roboto", 0, 1)
        cairo_set_font_size(cr, item_font_size)
        cairo_text_extents(cr, label, extents)
        cairo_move_to(cr, item_centerx - extents.width / 2, item_centery - item_radius * 1.6)
        cairo_show_text(cr, label)

        if value_text then
            local value_offset = height / 100
            cairo_select_font_face(cr, "Roboto", 0, 0)
            cairo_set_font_size(cr, item_font_size)
            if type(value_text) == "table" then
                for i, v in ipairs(value_text) do
                    cairo_text_extents(cr, v, extents)
                    cairo_move_to(cr, item_centerx - extents.width / 2, item_centery + item_radius + (item_font_size * i) + value_offset + 8)
                    cairo_show_text(cr, v)
                end
            else
                cairo_text_extents(cr, value_text, extents)
                cairo_move_to(cr, item_centerx - extents.width / 2, item_centery + item_radius + item_font_size + value_offset + 8)
                cairo_show_text(cr, value_text)
            end
        end

        return item_centerx, item_centery, item_radius, item_font_size
    end

    local function draw_child_arm(px, py, pradius, angle_deg, heading, rows, font_size)
        local angle = angle_deg * math.pi / 180
        local startx = px + math.cos(angle) * pradius
        local starty = py + math.sin(angle) * pradius
        local spread = 6
        local endx = startx + math.cos(angle) * width / spread
        local endy = starty + math.sin(angle) * height / spread
        local curvex = startx + math.cos(angle) * width / (spread * 2)
        local curvey = starty + math.sin(angle) * height / (spread * 2)

        local curve_offset = height / 7.5
        local cp2x, cp2y = curvex, curvey - curve_offset
        if angle_deg == 230 or angle_deg == 310 then
            cp2y = curvey - (curve_offset * 0.7)
        end

        cairo_move_to(cr, startx, starty)
        cairo_curve_to(cr, curvex, curvey, cp2x, cp2y, endx, endy)
        set_color(cr, 0.5)
        cairo_stroke(cr)

        local align_x
        if heading then
            cairo_select_font_face(cr, "Roboto", 0, 1)
            cairo_set_font_size(cr, font_size)
            cairo_text_extents(cr, heading, extents)
            align_x = endx - extents.width / 2
            set_color(cr, 1)
            cairo_move_to(cr, align_x, endy + font_size + 2)
            cairo_show_text(cr, heading)
        end

        set_color(cr, 0.7)
        cairo_select_font_face(cr, "Roboto", 0, 0)
        cairo_set_font_size(cr, font_size / 1.4)
        for i, row in ipairs(rows) do
            cairo_text_extents(cr, row, extents)
            local row_x = endx - extents.width / 2
            if heading then row_x = align_x end
            cairo_move_to(cr, row_x, endy + (font_size / 1.2) * (i + 1) + 5)
            cairo_show_text(cr, row)
        end
    end

    -- CPU
    local cpu_val = conky_parse("${cpu}")
    local cpu_cx, cpu_cy, cpu_radius, cpu_font = draw_section(10, "CPU", cpu_val .. "%", "cpu", true, cpu_val)

    local top_cpu_rows = {}
    for i = 1, 10 do
        local name = string.sub(conky_parse("${top name " .. i .. "}") .. "          ", 1, 10)
        top_cpu_rows[i] = name .. " " .. conky_parse("${top cpu " .. i .. "}") .. "%"
    end
    draw_child_arm(cpu_cx, cpu_cy, cpu_radius, 0, "Top 10 Process", top_cpu_rows, cpu_font)

    local core_rows = {}
    local cpu_count = conky_info.cpu_count or 0
    if cpu_count == 0 then
        local f = io.open("/proc/stat")
        if f then
            for line in f:lines() do
                if line:match("^cpu%d") then cpu_count = cpu_count + 1 end
            end
            f:close()
        end
        if cpu_count == 0 then cpu_count = 1 end
    end
    if cpu_count > 16 then cpu_count = 16 end
    for i = 1, cpu_count do
        core_rows[i] = "Core " .. i .. ": " .. conky_parse("${cpu cpu" .. i .. "}") .. "%"
    end
    draw_child_arm(cpu_cx, cpu_cy, cpu_radius, 70, "Cpu Cores", core_rows, cpu_font)

    -- SWAP
    local swap_val = conky_parse("${swapperc}")
    if swap_val == "" then swap_val = "0" end
    draw_section(50, "SWAP", swap_val .. "%", "swap", true, swap_val)

    -- Uptime
    draw_section(90, "UPTIME", conky_parse("${uptime_short}"), "uptime", false)

    -- Root Disk
    local free = "Free: " .. conky_parse("${fs_free /}")
    local total = "Total: " .. conky_parse("${fs_size /}")
    draw_section(130, "ROOT", { free, total }, "root", false)

    -- RAM
    local ram_val = conky_parse("${memperc}")
    local ram_cx, ram_cy, ram_radius, ram_font = draw_section(210, "RAM", ram_val .. "%", "ram", true, ram_val)

    local top_mem_rows = {}
    for i = 1, 10 do
        local name = string.sub(conky_parse("${top_mem name " .. i .. "}") .. "          ", 1, 10)
        top_mem_rows[i] = name .. " " .. conky_parse("${top_mem mem_res " .. i .. "}")
    end
    draw_child_arm(ram_cx, ram_cy, ram_radius, 230, "Top 10 Process", top_mem_rows, ram_font)

    -- Battery: conky's native objects report "not present" (short status 'N')
    -- on desktop PCs, so the arm is drawn only when a battery actually exists.
    local battery_status = conky_parse("${battery_short}")
    if battery_status ~= "N" and battery_status ~= "" then
        local battery_percent = conky_parse("${battery_percent}")
        local battery_time = conky_parse("${battery_time}")
        draw_section(250, "BATTERY", { battery_percent .. "%", battery_time }, "battery", true, battery_percent, true)
    end

    -- Mail: native ${new_mails} counts the Maildir the user syncs with their
    -- own tool (mbsync/fetchmail/offlineimap), so no credentials ever live in
    -- conky. Hidden when no Maildir is configured.
    if settings.mail_dir ~= "" then
        local new_mails = conky_parse("${new_mails " .. settings.mail_dir .. "}")
        draw_section(290, "MAIL", new_mails .. " new", "mail", false)
    end

    -- Disk I/O
    local disk_cx, disk_cy, disk_radius, disk_font = draw_section(170, "DISK I/O", conky_parse("${diskio}"), "root", false)
    draw_child_arm(disk_cx, disk_cy, disk_radius, 180, nil, {
        "Read: " .. conky_parse("${diskio_read}"),
        "Write: " .. conky_parse("${diskio_write}"),
    }, disk_font)

    -- Network
    local ip_addr = conky_parse("${addr " .. interface .. "}")
    local net_cx, net_cy, net_radius, net_font = draw_section(320, "IP", ip_addr, "network", false)
    draw_child_arm(net_cx, net_cy, net_radius, 310, nil, {
        "Upload: " .. conky_parse("${upspeed " .. interface .. "}"),
        "Download: " .. conky_parse("${downspeed " .. interface .. "}"),
    }, net_font)

    cairo_destroy(cr)
end
