#! /usr/bin/lua
------------------------------------------------------------------------------
-- (c) 2011 Radosław Kowalski <rk@bixbite.pl>                               --
-- Lua Auto Path Generator v0.1                                             --
-- Licensed under the same terms as Lua (MIT license).                      --
------------------------------------------------------------------------------


--- Match multiple pattern for a single string.
-- @param str a string to be matched for
-- @param ... pattern(s)
-- @return list of matched captures (duplicates are omitted)
function multi_match(str, ...)
  assert(type(str) == "string", "str must be a string!")

  local res = {}
  for _, pat in ipairs({...}) do
    local matches = {}
    string.gsub(str, pat, function(s) table.insert(matches, s) end)
    for _, v in ipairs(matches) do table.insert(res, v) end
  end
  return res
end


--- Iterates over files content in specified directory using globbing.
-- @param dir a directory from which to start
-- @param a globbing pattern
-- @return iterator which return subsequent file's content (if it's html it'll be stripped from html tags)
function doc_iterator(dir, glob)
  dir = dir or "/usr/"
  assert(type(dir) == "string", "dir must be a string!")
  assert(type(glob) == "string", "glob must be a string!")

  return coroutine.wrap(function()
    local findin = io.popen("find " .. dir .. " -type f -iname '" .. glob .. "'")
    if findin then
      for path in findin:lines() do
        local data
        local f = io.open(path, "r")
        if f then
          data = f:read("*a")
          f:close()
          if #multi_match(path, "%.html$", "%.htm$") > 0 then
            -- big value for "-width" parameter value to avoid wrapped functions
            f = io.popen("echo " .. string.format("%q", data) .. " | html2text -width 8192", "r")
            if f then
              data = f:read("*a")
              f:close()
            end
          end
          coroutine.yield(data)
        end
      end
    end
  end)
end


--- Search given string for Lua identifiers.
-- @param str a string
-- @return list of found identifiers
function lua_names_from(str)
  assert(type(str) == "string", "str must be a string!")

  local markers = {}
  -- initialize patters ought to match Lua identifiers
  for i = 1, 5 do
    local list = {}
    for k = 1, i do table.insert(list, '%a[%w_]*') end
    local pat = "(" .. table.concat(list, "%.") .. (i == 1 and "%([^)]-%)" or "") ..")"
    table.insert(markers, pat)
  end

  local set = {}
  -- try to match and store Lua identifiers
  string.gsub(str, '([^\n]*)', function(s)
    local m = multi_match(s, unpack(markers))
      -- Populate set (to avoid duplicated entries) and trim them from
      -- brackets.
      for _, v in ipairs(m) do set[string.gsub(v, '%(.*$', "")] = true end
  end)
  -- convert found identifiers from set to list and return it
  local list = {}
  for k, _ in pairs(set) do table.insert(list, k) end
  return list
end


function Lua_paths_from(dir, glob)
  local set = {}
  -- iterate over files' content
  for doc in doc_iterator(dir, glob) do
    -- put in a set what were found
    for _, v in ipairs(lua_names_from(doc)) do
      set[v] = true
    end
  end
  local list = {}
  -- convert to a list
  for k, _ in pairs(set) do table.insert(list, k) end
  -- sort it for more elegant looks
  table.sort(list)
  return list
end


if select("#", ...) == 2 then
  for _, v in ipairs(Lua_paths_from(select(1, ...), select(2, ...))) do
    print(v)
  end
else
  print([[
Lua Auto Path Generator v0.1
  (c) 2011 Radosław Kowalski <rk@bixbite.pl>
  Licensed under the same terms as Lua (MIT license).

  This script scans directories with supposed documentation and tries to guess
  Lua paths and function names.

  There must be two self explanatory arguments specified:
    lapg.lua directory_from_which_to_start globbing_pattern

  In a result list of found path names will be outputted to stdout.

  For an example to get paths from the LÖVE (http://love2d.org/) framework
  installed in /usr/ directory you can just execute:

    lapg.lua /usr '*love*html'
  ]])
end
