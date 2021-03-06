--[[ Copyright (c) 2019 Optera
 * Part of Optera's Function Library
 *
 * See LICENSE.md in the project directory for license information.
--]]

-- find main locomotive in a given train
-- Parameters: LuaTrain
-- Returns: LuaEntity
function get_main_locomotive(train)
  if train.valid and train.locomotives and (#train.locomotives.front_movers > 0 or #train.locomotives.back_movers > 0) then
    return train.locomotives.front_movers and train.locomotives.front_movers[1] or train.locomotives.back_movers[1]
  end
end

-- find main locomotive name in a given train
-- Parameters: LuaTrain
-- Returns: string containing backer_name of main locomotive
function get_train_name(train)
  local loco = get_main_locomotive(train)
  return loco and loco.backer_name
end

-- rotates a single carriage of a train
-- Parameters: LuaEntity
-- Returns: true if rotated successful
function rotate_carriage(entity)
  local disconnected_back = entity.disconnect_rolling_stock(defines.rail_direction.back)
  local disconnected_front = entity.disconnect_rolling_stock(defines.rail_direction.front)
  entity.rotate()
  -- Only reconnect the side that was disconnected
  local reconnected_front = disconnected_front
  local reconnected_back = disconnected_back
  if disconnected_back then
    reconnected_back = entity.connect_rolling_stock(defines.rail_direction.front)
  end
  if disconnected_front then
    reconnected_front= entity.connect_rolling_stock(defines.rail_direction.back)
  end

  if disconnected_front and not reconnected_front then
    return false
  end
  if disconnected_back and not reconnected_back then
    return false
  end
  return true
end

-- creates string representing train composition
-- L for locomotives, C for cargo wagons, F for fluid wagons, A for artillery wagon
-- Parameters: LuaTrain
-- Returns: string
local concat = table.concat
function get_train_composition_string(train)
  if train and train.valid then
    local carriages = train.carriages
    local string_table = {}
    local count_wagons, count_loco_front, count_loco_back, i = 0, 0, 0, 0
    local locos_front = train.locomotives.front_movers
    for _,carriage in pairs(carriages) do
      i = i + 1
      if carriage.type == "locomotive" then
        local faces_forward = false
        for _,loco in ipairs(locos_front) do
          if carriage.unit_number == loco.unit_number then
            faces_forward = true
            break
          end
        end
        if faces_forward then
          string_table[i] = "<L<"
          count_loco_front = count_loco_front + 1
        else
          string_table[i] = ">L>"
          count_loco_back = count_loco_back + 1
        end
      elseif carriage.type == "cargo-wagon" then
        count_wagons = count_wagons + 1
        string_table[i] = "C"
      elseif carriage.type == "fluid-wagon" then
        count_wagons = count_wagons + 1
        string_table[i] = "F"
      elseif carriage.type == "artillery-wagon" then
        count_wagons = count_wagons + 1
        string_table[i] = "A"
      else
        count_wagons = count_wagons + 1
        string_table[i] = "?"
      end
    end
    return concat(string_table), {total = i, wagons = count_wagons, front_movers = count_loco_front, back_movers = count_loco_back}
  else
    return ""
  end
end

-- open train GUI for one player
-- Parameters: uint, LuaTrain
-- Returns: bool
function open_train_gui(player_index, train)
  if train and train.valid and game.players[player_index] then
    local loco = get_main_locomotive(train)
    if loco and loco.valid then
      game.players[player_index].opened = loco
      return true
    end
  end
  return false
end

return {
  get_main_locomotive = get_main_locomotive,
  get_train_name = get_train_name,
  rotate_carriage = rotate_carriage,
  get_train_composition_string = get_train_composition_string,
  open_train_gui = open_train_gui,
}