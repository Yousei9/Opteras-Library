--[[ Copyright (c) 2019 Optera, Eduran
 * Part of Optera's Function Library
 *
 * See LICENSE.md in the project directory for license information.
--]]

--[[ USAGE INSTRUCTIONS
-- import module for use in your mod:
custom_log, custom_print, custom_tostring, logger_settings = require(_"__OpteraLib___.script.logger")

-- custom_log function:
Takes a variable number of arguments of any type. Arguments are
converted into a human-readable string, concatenated and written
to factorio_current.log. The logged message is pre-pended with the
file and line from which custom_log was called.

-- custom_print function
Takes a variable number of arguments of any type. Arguments are
converted into a human-readable string, concatenate and printed
to Factorios ingame console for every player.

-- custom_tostring function
Takes asingle argument of any type (additional arguments are
ignored). Returns a human-readable string representing the
argument.

-- logger_settings
A table with settings 'max_depth' and 'class_dictionary'.
'max_depth' decides how many levels of nested tables or objects
are converted to string.
'class_dictionary' is used to tell logger which Factorio objects
to convert to string. The syntax and composition of the dictionary
is explained below.

--]]
local class_dict = {}
local settings = {
  max_depth = 4, -- maximum depth up to which nested objects are converted
  class_dictionary = class_dict,
  }
--[[
Define factorio objects and properties logger should convert to tables.
Class names have to be a key with table value in class_dict.
Table syntax for each class:
- property_name = true
  converts Class.property_name to string and lists it under its own name
- display_name = {"property_name"}
  converts Class.property_name to string and lists it under display_name
- display_name = {"property_name", "sub_property_name"}
  converts Class.property_name.sub_property_name to string and lists it under display_name
- display_name = "method_name"
  calls Class.method_name() and converts return value to string, listed under display_name
--]]

class_dict.LuaGuiElement = {
  name = true,
  type = true,
  parent_name = {"parent", "name"},
  children_names = true,
  visible = true,
  style_name = {"style", "name"},
}
class_dict.LuaTrain = {
  id = true,
  state = true,
  contents = "get_contents",
  fluid_contents = "get_fluid_contents",
}
class_dict.LuaPlayer = {
  name = true,
  index = true,
  opened = true,
}
class_dict.LuaEntity = {
  backer_name = true,
  name = true,
  type = true,
  position = true,
}
class_dict.LuaCircuitNetwork = {
  entity = true,
  wire_type = true,
  signals = true,
  network_id = true,
}
class_dict.LuaStyle = {
  name = true,
  minimal_height = true,
  maximal_height = true,
  minimal_width = true,
  maximal_width = true,
}

-- cache functions
local match, format, gsub, find = string.match, string.format, string.gsub, string.find
local concat = table.concat
local getinfo = debug.getinfo
local log, tostring = log, tostring
local select, pairs, type, pcall = select, pairs, type, pcall
local block = serpent.block
-- custom formatting for serpent.block output when handling factorio classes
local function serpb(arg)
   return block(
    arg, {
      sortkeys = false,
      custom = (function(tag,head,body,tail)
        if find(tag, '^FOBJ_') then
          --body = body:gsub("\n%s+", "")
          tag = gsub(tag, "^FOBJ_", "")
          tag = gsub(tag, "[%s=]", "")
          return tag..head..body..tail
        else
          return tag..head..body..tail
        end
      end)
    }
  )
end

-- read class name of a Factorio lua object from string returned by its .help() method
local function help2name(str)
  return match(str, "Help for%s([^:]*)")
end

-- Factorio lua objects are tables with key "__self" and a userdata value; most of them have a .help() method
local function is_object(tb)
  if tb["__self"] and type(tb["__self"]) == "userdata" then
    local b1, b2 = pcall(function() return tb.valid and tb.help end)
    return b1 and b2
  end
  return false
end

local function function_to_string(func)
  local info = getinfo(func, "S")
  return format("[%s]:%d", info.short_src, info.linedefined)
end

local function get_class_property(obj, property_name, property)
  local value
  if property == true then
    value = obj[property_name]
  elseif type(property) == "table" then
    value = obj
    for _,v in pairs(property) do
      value = value[v]
      if type(value) ~= "table" then
        break
      end
    end
  elseif type(property) == "string" then
    value = obj[property]()
  end
  return value
end


local function factorio_obj_to_table(obj)
  local class_name = help2name(obj.help())
  local tb = nil
  if class_dict[class_name] then
    tb = {}
    for property_name, property in pairs(class_dict[class_name]) do
      local status, value = pcall(get_class_property, obj, property_name, property)
      tb[property_name] = status and value or nil
    end
  end
  return {["FOBJ_"..class_name] = tb} -- prefix for formatting with serpent.block
end

local function table_to_string(tb, level)
  level = (level or 0) + 1
  -- check for stuff that serpent does not convert to my liking and do the conversion here
  local log_tb = {} -- copy table, otherwise logger would modify the original input table
  for k,v in pairs(tb) do
    if type(v) == "table" and is_object(v) then
      log_tb[k] = table_to_string(factorio_obj_to_table(v), level) -- yay, recursion
    elseif type(v) == "table" and level < settings.max_depth then --regular table
      log_tb[k] = table_to_string(v, level) -- more recursion
    elseif type(v) == "function" then
      v = function_to_string(v)
    else
      log_tb[k] = v
    end
  end
  if level == 1 then
    return serpb(log_tb) -- format converted table with serpent
  else
    return log_tb
  end
end

-- convert any type of argument into a human-readable string
local function any_to_string(arg)
  if arg == nil then
    return "<nil>" -- otherwise the argument is just ommited
  end
  local t = type(arg)
  if t == "string" then return arg
  elseif t == "number" or t == "boolean" then return tostring(arg)
  elseif t == "function" then
    return function_to_string(arg)
  elseif t == "table" then
    if is_object(arg) then
      return table_to_string(factorio_obj_to_table(arg))
    else
      return table_to_string(arg)
    end
  elseif t == "userdata" then
    return serpb(arg)
  else
    log("Unknown data type: " .. t)
  end
end

-- main function to generate output
local function _tostring(...)
  -- convert all arguments to strings and concatenate
  local string_tb = {}
  for i = 1, select("#", ...) do
    string_tb[i] = any_to_string(select(i, ...))
  end
  return concat(string_tb, " ")
end

local function _log(...)
  local info = getinfo(2, "Sl")
  local msg_tag = format("%s:%d", info.short_src, info.currentline)

  -- build prefix
  local message = "<" .. msg_tag .. ">\n" .. _tostring(...)

  log(message)
  return message
end

local function _print(...)
  if game then game.print(_tostring(...)) end
end

return function() return _log, _print, _tostring, settings end