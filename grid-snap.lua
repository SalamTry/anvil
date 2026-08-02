-- grid-snap.lua — snap every baseline to the dot grid
local M = {}
local grid
local hlist_id = node.id("hlist")
local vlist_id = node.id("vlist")
local glue_id  = node.id("glue")
local kern_id  = node.id("kern")

local function vlist_height(head)
  local h = 0
  local n = head
  while n do
    local id = n.id
    if id == hlist_id or id == vlist_id then
      h = h + n.height + n.depth
    elseif id == glue_id then
      h = h + (node.getglue(n))
    elseif id == kern_id then
      h = h + n.kern
    end
    n = n.next
  end
  return h
end

local function snap_to_grid(box, locationcode, prevdepth)
  if box.id ~= hlist_id and box.id ~= vlist_id then
    return box
  end
  if locationcode == "alignment" then
    return box
  end

  local page_head = tex.lists.page_head
  if not page_head then
    return box
  end

  local above = vlist_height(page_head)
  local natural_baseline = above + box.height
  local snapped = math.floor(natural_baseline / grid + 0.5) * grid
  if snapped < grid then snapped = grid end
  local delta = snapped - natural_baseline

  if delta ~= 0 and math.abs(delta) > 1 then
    texio.write_nl("log", string.format(
      "grid-snap: baseline %.2fpt -> %.2fpt (delta %.2fpt)",
      natural_baseline / 65536, snapped / 65536, delta / 65536
    ))
    box.height = box.height + delta
  end

  return box
end

function M.init(pitch)
  grid = pitch
  luatexbase.add_to_callback("append_to_vlist_filter", snap_to_grid, "grid-snap")
  texio.write_nl("log", string.format(
    "grid-snap: initialized, pitch = %.2fpt", grid / 65536
  ))
end

return M
