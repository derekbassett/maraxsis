local collision_mask_util = require '__core__/lualib/collision-mask-util'

local water = {
    type = 'simple-entity',
    name = 'h2o-water-shader',
    localised_name = 'Maraxsis water shader', -- dont @ me
    count_as_rock_for_filtered_deconstruction = false,
    icon_size = 64,
    protected_from_tile_building = false,
    remove_decoratives = "false",
    selectable_in_game = false,
    subgroup = data.raw.tile['water'].subgroup,
    flags = {'not-on-map'},
    collision_box = {{-16, -16}, {16, 16}},
    secondary_draw_order = -1,
    collision_mask = {layers = {}},
    render_layer = 'light-effect',
    icon = '__maraxsis__/graphics/tile/water/water-combined.png',
    icon_size = 32,
    autoplace = {
        probability_expression = 'maraxsis_water_32x32'
    },
}

local frame_sequence = {}
for k = 1, 32 do
    table.insert(frame_sequence, k)
end
local visiblity = tonumber(settings.startup['h2o-water-opacity'].value) / 255
water.animations = {
    tint = {r = visiblity, g = visiblity, b = visiblity, a = 1 / 255},
    height = 256,
    width = 256,
    line_length = 32,
    variation_count = 1,
    filename = '__maraxsis__/graphics/tile/water/water-combined.png',
    frame_count = 32,
    animation_speed = 0.5,
    scale = 4,
    frame_sequence = frame_sequence,
    draw_as_glow = false,
    shift = nil,
    flags = {'no-scale'}
}
data:extend {water}

local layer = 4
local waterifiy = {
    ---creates a copy of a tile prototype that can be used underneath py fancy water
    ---@param tile string
    ---@param include_submarine_exclusion_zone boolean
    ---@return table
    tile = function(tile, include_submarine_exclusion_zone)
        tile = table.deepcopy(data.raw.tile[tile])
        tile.localised_name = {'tile-name.underwater'}
        tile.name = tile.name .. '-underwater'
        tile.collision_mask = {layers = {[maraxsis_collision_mask] = true}}
        tile.layer = layer
        ---@diagnostic disable-next-line: param-type-mismatch
        tile.map_color = h2o.color_combine(tile.map_color or data.raw.tile['water'].map_color, data.raw.tile['deepwater'].map_color, 0.25)
        tile.absorptions_per_second = table.deepcopy(data.raw.tile['water'].absorptions_per_second)
        tile.draw_in_water_layer = true
        --tile.walking_sound = nil -- TODO: add a swimming sound
        tile.walking_speed_modifier = 0.2
        water_tile_type_names[#water_tile_type_names + 1] = tile.name

        if not include_submarine_exclusion_zone then return {tile} end

        local submarine_exclusion_zone = table.deepcopy(tile)
        submarine_exclusion_zone.layer = layer
        submarine_exclusion_zone.name = tile.name .. '-submarine-exclusion-zone'
        submarine_exclusion_zone.collision_mask = {
            layers = {[maraxsis_collision_mask] = true, ['rail'] = true}
        }
        water_tile_type_names[#water_tile_type_names + 1] = submarine_exclusion_zone.name

        layer = layer + 1
        return {tile, submarine_exclusion_zone}
    end,
    ---@param entity string
    ---@return table
    entity = function(entity)
        local underwater
        for entity_prototype in pairs(defines.prototypes.entity) do
            if entity_prototype ~= 'player-port' then -- todo: remove this check when vanilla updates spage age
                for _, prototype in pairs(data.raw[entity_prototype]) do
                    if prototype.name == entity then
                        underwater = prototype
                        break
                    end
                end
            end
        end
        if not underwater then error('entity not found ' .. entity) end
        underwater = table.deepcopy(underwater)
        underwater.localised_name = underwater.localised_name or {'entity-name.' .. underwater.name}
        underwater.name = underwater.name .. '-underwater'

        underwater.localised_name = underwater.localised_name or {'entity-name.' .. underwater.name}
        collision_mask_util.get_mask(underwater)[maraxsis_collision_mask] = nil
        --collision_mask_util.get_mask(underwater)
        ---@diagnostic disable-next-line: param-type-mismatch
        underwater.map_color = h2o.color_combine(underwater.map_color or data.raw.tile['water'].map_color, data.raw.tile['deepwater'].map_color, 0.3)

        return {underwater}
    end,
}

data:extend(waterifiy.tile('sand-1', true))
data:extend(waterifiy.tile('sand-3', true))
data:extend(waterifiy.tile('dirt-5', true))
data:extend(waterifiy.tile('grass-2', false))
data:extend(waterifiy.entity('cliff'))
data:extend(waterifiy.entity('big-sand-rock'))
data.raw.cliff['cliff-underwater'].collision_mask = {layers = {['item'] = true, ['object'] = true, ['water_tile'] = true}} -- player should 'swim over' cliffs

---creates a new cliff entity with the upper area masked with the provided tile
---@param tile string
local function trenchifiy(tile)
    local results = {}

    local cliff = data.raw['cliff']['cliff']
    for k, orientation in pairs(cliff.orientations) do
        local pictures = {}

        for _, picture in pairs(orientation.pictures) do
            local layer = table.deepcopy(picture.layers[1])
            layer.filename = layer.filename:gsub('.png', '-' .. tile .. '.png')
            layer.filename = layer.filename:gsub('__base__/graphics/terrain/cliffs/', '__maraxsis__/graphics/entity/cliffs/hr-')
            pictures[#pictures + 1] = layer
        end

        results[#results + 1] = {
            name = tile .. '-trench-' .. k:gsub('_', '-'),
            type = 'simple-entity',
            localised_name = {'entity-name.cliff'},
            subgroup = 'cliffs',
            order = 'x[' .. k .. ']',
            collision_box = {{-2, -2}, {2, 2}},
            count_as_rock_for_filtered_deconstruction = false,
            collision_mask = {layers = {}},
            map_color = data.raw.tile[tile .. '-underwater'].map_color,
            flags = {},
            secondary_draw_order = -1,
            render_layer = 'ground-layer-4',
            protected_from_tile_building = false,
            remove_decoratives = "false",
            selectable_in_game = false,
            icon = data.raw.cliff.cliff.icon,
            icon_size = data.raw.cliff.cliff.icon_size,
            pictures = pictures
        }
    end

    return results
end

data:extend(trenchifiy('dirt-5'))

local trench_entrance = table.deepcopy(data.raw.tile['out-of-map'])
trench_entrance.name = 'trench-entrance'
trench_entrance.layer = 255
trench_entrance.map_color = {0, 0, 0.1, 1}
trench_entrance.destroys_dropped_items = true
trench_entrance.allows_being_covered = false
trench_entrance.walking_speed_modifier = 0.2
trench_entrance.collision_mask = {layers = {['item'] = true, ['object'] = true, [maraxsis_collision_mask] = true}}
data:extend {trench_entrance}
