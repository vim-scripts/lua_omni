--
--------------------------------------------------------------------------------
--         FILE:  lua_omni.lua
--        USAGE:  ---
--  DESCRIPTION:  Lua functions for Vim's omni completions (plus other).
--      OPTIONS:  ---
-- REQUIREMENTS:  ---
--         BUGS:  ---
--        NOTES:  ---
--       AUTHOR:  R. Kowalski
--      COMPANY:  ---
--      VERSION:  0.11
--      CREATED:  10.11.2010
--     REVISION:  ---
--------------------------------------------------------------------------------
--



--- Iterator which walks over a Vim buffer.
-- @param buf buffer to be used as source
-- @return next buffer's line
function line_buf_iter(buf)
  buf = buf or vim.buffer()
  local lineidx = 0
  return function()
	lineidx = lineidx + 1
	if lineidx <= #buf then
	  return buf[lineidx]
	end
  end
end

-- The completion functionality ------------------------------------------------

--- Search for a single part path in _G environment.
-- Nested tables aren't supported.
-- @param pat path to be used in search
-- @return Table with list of k, v pairs.
-- k is function, table, or just variable) name.
-- v is an actual object reference.
function find_completions1(pat)
  local comps = {}
  for k, v in pairs(_G) do
	if string.find(k, "^" .. pat) then
	  table.insert(comps, {k, v})
	end
  end
  return comps
end

--- Search for multi level paths starting from _G environment.
-- @param pat path to be used in search
-- @return Table with list of k, v pairs.
-- k is function, table, or just variable name (however it's absolute path).
-- v is an actual object reference.
function find_completions2(pat)
  local results = {}
  -- split path pattern into levels
  local levels = {}
  for lev in string.gmatch(pat, "[^%.]+") do
	table.insert(levels, lev)
  end
  -- if the last character in pat is '.' and matching all level
  if string.sub(pat, -1) == "." then
	table.insert(levels, ".*")
  end
  -- set prepath if there are multiple levels (used for generating absolute paths)
  local prepath = #levels > 1 and table.concat(slice(levels, 1, #levels - 1), ".") .. "." or ""
  -- find target table namespace
  local where = _G
  for i, lev in ipairs(levels) do
	if i < #levels then		-- not last final path's part?
	  local w = where[lev]
	  if w and type(w) == "table" then	-- going into inner table/namespace?
		where = w
	  else	-- not, path is incorrect!
		break
	  end
	else	-- the last part of path
	  for k, v in pairs(where) do
		if string.find(k, "^" .. lev) then	-- final names search...
		  table.insert(results, {prepath .. k, v})
		end
	  end
	end
  end
  return results
end

--- Utility function to be used with Vim's completefunc.
function completion_findstart()
  local w = vim.window()
  local buf = w.buffer
  local line = buf[w.line]
  for i = w.col - 1, 1, -1 do
	local c = string.sub(line, i, i)
	if string.find(c, "[^a-zA-Z0-9_-%.]") then
	  return i
	end
  end
  return 0
end

--- Find matching completions.
-- @param base a base to which complete
-- @return list with possible (string) abbreviations
function complete_base_string(base)
  local t = {}
  if type(base) == "string" then
	-- completion using _G environment
	local comps = find_completions2(base)
	for _, v in pairs(comps) do
	  table.insert(t, v[1])
	end
	table.sort(t)
	-- completion using local variable assignments
	local s, e = in_func_body(vim.window().buffer, vim.window().line)
	if s then	-- check if cursor is within function definition
	  -- get and filter possible variable assignments
	  local assigments = {}
	  for i, v in ipairs(search_assignments1(vim.window().buffer, s, e)) do
		if string.find(v, "^" .. base) then table.insert(assigments, v) end
	  end
	  table.sort(assigments)
	  -- merge assigment list at the beginning of final table
	  t = merge_list(assigments, t)
	end
  end
  return t
end

--- To be called within CompleteLua Vim function.
function completefunc_luacode()
  -- getting arguments from Vim function
  local findstart = vim.eval("a:findstart")
  local base = vim.eval("a:base")
  -- this function is called twice - first for finding range in line to complete
  if findstart == 1 then
	vim.command("return " .. completion_findstart())
  else		-- the second run - do proper complete
	local comps = complete_base_string(base)
	for i = 1, #comps do comps[i] = "'" .. comps[i] .. "'" end
	-- returning 
	vim.command("return [" .. table.concat(comps, ", ") .. "]")
  end
end

-- The outline window. ---------------------------------------------------------

--- Get a list of Lua defined functions in a buffer.
-- @param buf a buffer to be used (parsed?) for doing funcs list (optional, if
-- absent then use current one)
-- @return list of {linenumber, linecontent} tables
function function_list(buf)
  local funcs = {}
  local linenum = 0
  for line in line_buf_iter(buf) do
	linenum = linenum + 1
	if string.find(line, "^%s-function%s+") then
	  funcs[#funcs + 1] = {linenum, line}
	end
  end
  return funcs
end

--- Prints list of function within Vim buffer.
-- The output format is line_number: function func_name __spaces__ function's title (if exists)
-- @param buf buffer to be used as source
function print_function_list(buf)
  local funcnumber
  local funclist = function_list(buf)
  local countsize = #tostring(funclist[#funclist][1])
  for i, f in ipairs(funclist) do
	if i == 1 then print("line: function definition...") end
	-- try to get any doc about function...
	local doc = func_doc(f[1])
	local title = string.gmatch(doc["---"] or "", "[^\n]+")
	title = title and title() or nil
	local s = string.format("%" .. countsize .. "d: %-" .. (40 - countsize) ..  "s %s", f[1], f[2],
			(title or ""))
	print(s)
	funcnumber = i
  end
  if not funcnumber then print "no functions found..." end
end

--- Checks if current line lies in function definition.
-- Depends on usual code formating where "function" and "end" statements start
-- at first column.
-- @param buf Vim's buffer to be used as source (current one if absent)
-- @param line line number to be checked for being within function' body
-- @return funcstart, funcend pair or nil, nil if line is outside a function
function in_func_body(buf, line)
  if not line then
	buf = vim.window().buffer
	line = vim.window().line
  end
  buf = buf or vim.buffer()
  -- search for function definition first
  local funcstart
  for lineidx = line, 1, -1 do
	-- If iterating back end at first column is found, then it's outside
	-- function.
	if string.find(buf[lineidx], "^end") then break end
	if string.find(buf[lineidx], "^function") then
	  funcstart = lineidx
	  break
	end
  end
  -- search for the function's closing "end"
  -- (depends on an usual formating, doesn't count code chunks)
  local funcend
  if funcstart then	-- search for function's end only when start was found...
	for lineidx = line + 1, #buf do
	  if string.find(buf[lineidx], "^end") then
		funcend = lineidx 
		break
	  end
	end
  end
  return funcstart, funcend
end

--- Search for variable assignments in a Vim buffer within given line range.
-- Note: it's not perfect - will not find assignments in "for ... in"
-- constructs. Inner closure visibility ranges are also ignored.
-- @param buf Vim buffer to be used
-- @param startline line number from search of assignments will begin
-- @param endline line number to search of assignments will end
-- @return table with list of found variable names
function search_assignments1(buf, startline, endline)	-- TODO add support for function's arguments and "if var in" statements
  -- for testing, delete when not needed anymore
--  if not buf then
--	buf = vim.window().buffer
--	startline, endline = in_func_body()
--  end
  assert(type(buf) == "userdata", "buf must be a Vim buffer!")
  assert(type(startline) == "number", "startline must be a number!")
  assert(type(endline) == "number", "endline must be a number!")
  assert(startline < endline, "startline must precede endline!")
  -- assignment has a forms like:
  -- varname = something
  -- varname1[, varname2[, varname3]] = something1[, something2[, something3]]
  -- lets assume that there is only one "=" per line
  -- visibility of closures by dammed (for now...)
  local assignments = {}
  for lineidx = startline, endline - 1 do
	-- filter out eventual comments
	local line = string.gsub(buf[lineidx], "%s*%-%-.*$", "")
	-- check if there is assignment in a line
	local s, e = string.find(line, "[^=]=[^=]")
	if s then
	  local _s, _e, pre, post = string.find(line, "%s([%w,%s_,]+)=(.+)")
	  -- focus on pre, variable names are most important
	  if pre then
		-- if subnum == 1 then assignment is local
		local line, subnum = string.gsub(pre, "local%s+", "")
		-- just store variable names in a set
		for varname in string.gmatch(line, "[^, \t]+") do assignments[varname] = true end
	  end
	end
  end
  -- convert set to a list
  local assignmentlist = {}
  for k, v in pairs(assignments) do table.insert(assignmentlist, k) end
  return assignmentlist
end

--- Miscellaneous. -------------------------------------------------------------

--- Prints keys within a table (or environment). Similar to Python's dir.
-- @param t should be a table or a nil
function dir(t)
  if t == nil then
	t = _G
  assert(type(t) == "table", "t should be a table!")
  elseif type(t) == "table" then
	for k, v in pairs(t) do
	  print(k .. ":", v)
	end
  end
end

--- Prints keys of internal Vim's vim Lua module.
function dir_vim()
  for k, v in pairs(vim) do
	local ty = type(v)
	if ty == "function" or ty == "string" or ty == "number" then
	  print(k)
	end
  end
end

--- Slice function operating on tables.
-- Minus indexes aren't supported (yet...).
-- @param t a table to be sliced
-- @param s the starting index of slice (inclusive)
-- @param s the ending index of slice (inclusive)
-- @return a new table containing a slice from t
function slice(t, s, e)
  assert(type(t) == "table", "t should be a table!")
  s = s or 1
  e = e or #t
  local sliced = {}
  for idx = s, e do
	if t[idx] then table.insert(sliced, t[idx]) end
  end
  return sliced
end

--- Merges multiple tables as lists.
-- @return resulting list have merged arguments from left to right in ascending order
function merge_list(...)
  local res = {}
  for idx = 1, select("#", ...) do
	local t = select(idx, ...)
	if type(t) == "table" then
	  for i, v in ipairs(t) do table.insert(res, v) end
	else
	  table.insert(res, t)
	end
  end
  return res
end

--- Returns list of active windows in a current tab.
-- @return vim.window like tables with similar keys
function window_list()
  local idx = 1
  local winlist = {}
  while true do
	local w = vim.window(idx)
	if not w then break end
	winlist[#winlist + 1] = {line = w.line, col = w.col, width = w.width,
								height = w.height, firstline = w.buffer[1],
								currentline = w.buffer[w.line]}
	idx = idx + 1
  end
  return winlist
end

--- Just prints current window list.
function print_window_list()
  local wincount
  for i, w in ipairs(window_list()) do
	if i == 1 then print("win number, line, col, width, height :current line content...") end
	print(string.format("%02d: %s", i, w.currentline))
	wincount = i
  end
  if not wincount then print("no windows found (how it's possible?!)...") end
end

--- Try to parse function documentation using luadoc format.
-- At first it wasn't easy to write, but after some thought I had it done
-- in quite efficient way (I think :).
-- @param line starting line of function which luadoc to parse
-- @param buf Vim's buffer to be used as source (current one if absent)
-- @return table containing k/v pairs analogous to luadoc's "@" flags
function func_doc(line, buf)
  buf = buf or vim.buffer()
  assert(type(line) == "number", "line must be a number!")
  assert(line >= 1 and line <= #buf, "line should be withing range of buffer's lines!")
  local curlines, doc = {}, {}
  for l = line - 1, 1, -1 do
	local spciter = string.gmatch(buf[l], "%S+")
	local pre = spciter()
	local flag, fvalue, rest
	if pre == "---" then
	  rest = table.concat(iter_to_table(spciter), " ")
	  table.insert(curlines, rest)
	  doc["---"] = curlines
	elseif pre == "--" then
	  flag = spciter()
	  if string.sub(flag, 1, 1) == "@" then
		fvalue = spciter()
		rest = table.concat(iter_to_table(spciter), " ")
		table.insert(curlines, rest)
		doc[flag .. ":" .. fvalue] = curlines
		curlines = {}
	  else
		rest = table.concat(iter_to_table(spciter), " ")
		table.insert(curlines, rest)
	  end
	else
	  break
	end
  end
  -- post reverse and concat doc's strings
  for k, t in pairs(doc) do
	local reversed = {}
	for i = 1, #t do reversed[i] = t[#t - i + 1] end	-- reverse accumulated lines
	doc[k] = table.concat(reversed, "\n")
  end
  return doc
end

--- Translates iterator function into a table.
-- @param iter iterator function
-- @return table populated by iterator
function iter_to_table(iter)
  assert(type(iter) == "function", "iter has to be a function!")
  local t = {}
  local idx = 0
  for v in iter do
	idx = idx + 1
	t[idx] = v
  end
  return t
end
