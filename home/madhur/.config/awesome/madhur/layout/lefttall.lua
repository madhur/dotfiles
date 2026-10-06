local math = math

local mylayout = {}

mylayout.name = "lefttall"

-- Like the standard "tall" layout (master pinned to the left, slaves
-- stacked in a single column on the right), except the master column
-- is ALWAYS sized as workarea.width * master_width_factor -- even when
-- it's the only client on the tag. Unlike awful.layout.suit.tile.right,
-- it never grows to fill the screen and never centers itself when
-- alone, so mod+h/l (incmwfact) keeps resizing it and the freed space
-- on the right just shows the background.
function mylayout.arrange(p)
    local area = p.workarea
    local t = p.tag or screen[p.screen].selected_tag
    local cls = p.clients

    local nmaster = math.min(t.master_count, #cls)
    local nslaves = #cls - nmaster

    local mwfact = t.master_width_factor
    if nslaves > 0 then
        -- master_width_factor can legitimately sit at 1.0 (full width) while
        -- solo -- that's the point of this layout. But if a slave then shows
        -- up, a master_width that big leaves it 0px wide, off the right edge,
        -- and effectively invisible. Cap the width actually used for layout
        -- (not the stored master_width_factor) so a slave always gets a
        -- visible share; mwfact itself is untouched, so going back down to
        -- one window still reaches true 100%.
        mwfact = math.min(mwfact, 0.9)
    end

    local master_width = area.width * mwfact
    if nmaster == 0 then master_width = 0 end

    local slave_x = area.x + master_width

    -- masters: stacked in the left column
    for idx = 1, nmaster do
        local c = cls[idx]
        p.geometries[c] = {
            x = area.x,
            y = area.y + (idx - 1) * (area.height / nmaster),
            width = master_width,
            height = area.height / nmaster,
        }
    end

    -- slaves: stacked in the remaining right column
    for idx = 1, nslaves do
        local c = cls[idx + nmaster]
        p.geometries[c] = {
            x = slave_x,
            y = area.y + (idx - 1) * (area.height / nslaves),
            width = area.width - master_width,
            height = area.height / nslaves,
        }
    end
end

return mylayout
