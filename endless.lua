local NAME = "lua:endless"

local cfg = { min_w = 480, min_h = 320, gap = 5, zoom = 1.0, follow = true }
local spaces = {}

local function clamp(x, a, b)
    return math.max(a, math.min(b, x))
end

local function ws_id(window)
    local ws = window and window.workspace
    return ws and ws.id or 0
end

local function get_space(id)
    local s = spaces[id]
    if not s then
        s = { root = nil, leaves = {}, boxes = {}, hist = {}, cam_x = 0, cam_y = 0, center = false }
        spaces[id] = s
    end
    return s
end

local function push_hist(S, id)
    for i, v in ipairs(S.hist) do
        if v == id then
            table.remove(S.hist, i)
            break
        end
    end
    table.insert(S.hist, 1, id)
    if #S.hist > 16 then
        table.remove(S.hist)
    end
end

local function replace(S, old, new)
    local p = old.parent
    new.parent = p
    if not p then
        S.root = new
    elseif p.a == old then
        p.a = new
    else
        p.b = new
    end
end

local function remove_leaf(S, id)
    local leaf = S.leaves[id]
    if not leaf then
        return
    end
    S.leaves[id] = nil
    S.boxes[id] = nil
    local p = leaf.parent
    if not p then
        S.root = nil
        return
    end
    local sibling = (p.a == leaf) and p.b or p.a
    replace(S, p, sibling)
end

local function last_leaf(node)
    while node.b do
        node = node.b
    end
    return node
end

local function insert_leaf(S, id)
    local leaf = { id = id }
    S.leaves[id] = leaf
    if not S.root then
        S.root = leaf
        return
    end
    local anchor
    for _, hid in ipairs(S.hist) do
        if hid ~= id and S.leaves[hid] then
            anchor = S.leaves[hid]
            break
        end
    end
    anchor = anchor or last_leaf(S.root)
    local b = S.boxes[anchor.id]
    local dir = (b and b.h > b.w) and "v" or "h"
    local node = { dir = dir, ratio = 0.5, a = anchor, b = leaf }
    replace(S, anchor, node)
    anchor.parent = node
    leaf.parent = node
end

local function sync(S, ctx)
    local present = {}
    local active
    for _, t in ipairs(ctx.targets) do
        local w = t.window
        if w then
            present[w.stable_id] = t
            if w.active then
                active = w.stable_id
            end
        end
    end
    for id in pairs(S.leaves) do
        if not present[id] then
            remove_leaf(S, id)
        end
    end
    for _, t in ipairs(ctx.targets) do
        local w = t.window
        if w and not S.leaves[w.stable_id] then
            insert_leaf(S, w.stable_id)
        end
    end
    return present, active
end

local function measure(node, mw, mh)
    if not node.a then
        node.nw, node.nh = mw, mh
        return
    end
    measure(node.a, mw, mh)
    measure(node.b, mw, mh)
    if node.dir == "h" then
        node.nw = node.a.nw + node.b.nw
        node.nh = math.max(node.a.nh, node.b.nh)
    else
        node.nw = math.max(node.a.nw, node.b.nw)
        node.nh = node.a.nh + node.b.nh
    end
end

local function assign(node, x, y, w, h, out)
    if not node.a then
        out[node.id] = { x = x, y = y, w = w, h = h }
        return
    end
    if node.dir == "h" then
        local aw = clamp(w * node.ratio, node.a.nw, w - node.b.nw)
        assign(node.a, x, y, aw, h, out)
        assign(node.b, x + aw, y, w - aw, h, out)
    else
        local ah = clamp(h * node.ratio, node.a.nh, h - node.b.nh)
        assign(node.a, x, y, w, ah, out)
        assign(node.b, x, y + ah, w, h - ah, out)
    end
end

local function fit(c, p, len, view)
    if p < c then
        return p
    end
    if p + len > c + view then
        return math.min(p, p + len - view)
    end
    return c
end

local function fit_zoom(S, ctx) if not S or not S.root then return cfg.zoom end local g = cfg.gap local vw, vh = ctx.area.w - g, ctx.area.h - g local lo, hi = 0.35, 1.0 measure(S.root, cfg.min_w * hi + g, cfg.min_h * hi + g) if S.root.nw <= vw and S.root.nh <= vh then return hi end for _ = 1, 24 do local mid = (lo + hi) / 2 measure(S.root, cfg.min_w * mid + g, cfg.min_h * mid + g) if S.root.nw <= vw and S.root.nh <= vh then lo = mid else hi = mid end end return lo end
local function fit_zoom(S, ctx) if not S or not S.root then return cfg.zoom end local g = cfg.gap local vw, vh = ctx.area.w - g, ctx.area.h - g local lo, hi = 0.35, 1.0 measure(S.root, cfg.min_w * hi + g, cfg.min_h * hi + g) if S.root.nw <= vw and S.root.nh <= vh then return hi end for _ = 1, 24 do local mid = (lo + hi) / 2 measure(S.root, cfg.min_w * mid + g, cfg.min_h * mid + g) if S.root.nw <= vw and S.root.nh <= vh then lo = mid else hi = mid end end return lo end
local function active_leaf(S, ctx)
    for _, t in ipairs(ctx.targets) do
        local w = t.window
        if w and w.active then
            return S.leaves[w.stable_id]
        end
    end
end

local function first_leaf(node)
    while node.a do
        node = node.a
    end
    return node
end

local function leaf_order(node, out)
    if not node.a then
        out[#out + 1] = node.id
        return out
    end
    leaf_order(node.a, out)
    leaf_order(node.b, out)
    return out
end

local function place_focus(S, ctx, present, active)
    local leaf = S.leaves[active]
    if not leaf then
        return false
    end
    local partner
    local p = leaf.parent
    if p then
        partner = (p.a == leaf) and first_leaf(p.b).id or last_leaf(p.a).id
    end
    local idx = {}
    for i, id in ipairs(leaf_order(S.root, {})) do
        idx[id] = i
    end
    local lo = partner and math.min(idx[active], idx[partner]) or idx[active]
    local g = cfg.gap
    local vx, vy = ctx.area.x + g / 2, ctx.area.y + g / 2
    local vw, vh = math.max(1, ctx.area.w - g), math.max(1, ctx.area.h - g)
    local cellw = partner and vw / 2 or vw
    for id, t in pairs(present) do
        local j = idx[id]
        if j then
            t:place({ x = vx + (j - lo) * cellw + g / 2, y = vy + g / 2, w = math.max(1, cellw - g), h = math.max(1, vh - g) })
        end
    end
    return true
end

hl.layout.register("endless", {
    recalculate = function(ctx)
        if #ctx.targets == 0 then
            return
        end

        local S = get_space(ws_id(ctx.targets[1].window))
        local present, active = sync(S, ctx)
        if not S.root then
            return
        end

        if S.focus and active and place_focus(S, ctx, present, active) then return end
        local g = cfg.gap
        local vx, vy = ctx.area.x + g / 2, ctx.area.y + g / 2
        local vw, vh = math.max(1, ctx.area.w - g), math.max(1, ctx.area.h - g)

        measure(S.root, cfg.min_w * cfg.zoom + g, cfg.min_h * cfg.zoom + g)

        local cw, ch = math.max(vw, S.root.nw), math.max(vh, S.root.nh)
        local out = {}
        assign(S.root, 0, 0, cw, ch, out)
        S.boxes = out

        local cx = clamp(S.cam_x, 0, cw - vw)
        local cy = clamp(S.cam_y, 0, ch - vh)

        if active and out[active] then
            local b = out[active]
            if S.center then
                cx = clamp(b.x + b.w / 2 - vw / 2, 0, cw - vw)
                cy = clamp(b.y + b.h / 2 - vh / 2, 0, ch - vh)
                S.center = false
            elseif cfg.follow then
                cx = clamp(fit(cx, b.x, b.w, vw), 0, cw - vw)
                cy = clamp(fit(cy, b.y, b.h, vh), 0, ch - vh)
            end
        end

        S.cam_x, S.cam_y = cx, cy

        for id, t in pairs(present) do
            local b = out[id]
            if b then
                t:place({
                    x = vx + b.x - cx + g / 2,
                    y = vy + b.y - cy + g / 2,
                    w = math.max(1, b.w - g),
                    h = math.max(1, b.h - g),
                })
            end
        end
    end,

    layout_msg = function(ctx, msg)
        local cmd, a1, a2 = msg:match("^(%S+)%s*(%S*)%s*(%S*)")
        local first = ctx.targets[1]
        local S = first and get_space(ws_id(first.window))

        if cmd == "refresh" then
            return true
        elseif cmd == "focus" then
            if S then S.focus = (a1 == "on") or (a1 ~= "off" and not S.focus) end
        elseif cmd == "zoom" then
            if a1 == "in" then
                cfg.zoom = clamp(cfg.zoom * 1.15, 0.35, 3.0)
            elseif a1 == "out" then
                cfg.zoom = clamp(cfg.zoom / 1.15, 0.35, 3.0)
            elseif a1 == "fit" then cfg.zoom = (cfg.zoom ~= 1.0) and 1.0 or fit_zoom(S, ctx) elseif a1 == "fit" then cfg.zoom = fit_zoom(S, ctx) elseif a1 == "reset" then
                cfg.zoom = 1.0
            else
                return "endless: zoom in|out|reset"
            end
        elseif cmd == "min" then
            local w, h = tonumber(a1), tonumber(a2)
            if not w or not h then
                return "endless: min <w> <h>"
            end
            cfg.min_w, cfg.min_h = clamp(w, 80, 4000), clamp(h, 60, 4000)
        elseif cmd == "gap" then
            local n = tonumber(a1)
            if not n then
                return "endless: gap <px>"
            end
            cfg.gap = clamp(n, 0, 100)
        elseif cmd == "follow" then
            cfg.follow = (a1 ~= "off")
        elseif cmd == "center" then
            if S then
                S.center = true
            end
        elseif cmd == "grow" or cmd == "shrink" then
            local leaf = S and active_leaf(S, ctx)
            local p = leaf and leaf.parent
            if p then
                local d = (cmd == "grow") and 0.05 or -0.05
                if p.b == leaf then
                    d = -d
                end
                p.ratio = clamp(p.ratio + d, 0.1, 0.9)
            end
        elseif cmd == "split" then
            local leaf = S and active_leaf(S, ctx)
            local p = leaf and leaf.parent
            if p then
                p.dir = (p.dir == "h") and "v" or "h"
            end
        else
            return "endless: focus|zoom|min|gap|follow|center|grow|shrink|split|refresh"
        end

        return true
    end,
})

hl.on("window.active", function(w, reason)
    if not w then
        return
    end
    local S = spaces[ws_id(w)]
    if S then
        push_hist(S, w.stable_id)
    end
    if reason == 1 then
        return
    end
    local l = w.layout
    if l and l.name == NAME then
        hl.dispatch(hl.dsp.layout("refresh"))
    end
end)
