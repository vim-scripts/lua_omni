" Vim filetype plugin file
"    Language:  lua
"      Plugin:  Lua Omni Complete (version 0.17)
"  Maintainer:  Radek Kowalski <rk@bixbite.pl>
"  Last Change: 2011.05.20
"  License: Licensed under the same terms as Lua (MIT license).

" check if Vim is in correct version and has Lua support
if v:version < 703
  echo "Only Vim version 7.3 (or newer) is supported!"
  finish
endif
if !has("lua")
  echo "Lua support must be enabled!"
  finish
endif

" as usual...
if exists("b:did_lua_completions")
  finish
endif
let b:did_lua_completions = 1

" save and reset compatibility options
let s:save_cpo = &cpo
set cpo&vim

" source Lua...
luafile ~/.vim/ftplugin/lua_omni.lua

" options...
set shiftwidth=2
set number

" mappings...
if !hasmapto('<Plug>PrintFunctionList')
  map <unique> <Leader>fl  <Plug>PrintFunctionList
endif
if !hasmapto('<Plug>WriteAndLuaFile')
  map <unique> <Leader>lf  <Plug>WriteAndLuaFile
endif
if !hasmapto('<Plug>SetLuaIabbrevs')
  map <unique> <Leader>sli  <Plug>SetLuaIabbrevs
endif
if !hasmapto('<Plug>ClearLuaIabbrevs')
  map <unique> <Leader>cli  <Plug>ClearLuaIabbrevs
endif

noremap <unique> <script> <Plug>PrintFunctionList   :lua print_function_list()<CR>
noremap <unique> <script> <Plug>WriteAndLuaFile     :w<CR>:luafile %<CR>
noremap <unique> <script> <Plug>SetLuaIabbrevs      :call SetLuaIabbrevs()<CR>
noremap <unique> <script> <Plug>ClearLuaIabbrevs    :call ClearLuaIabbrevs()<CR>


" Common Lua abbreviations
let s:iabbrevlist = [
\ ["pr(", "print("],
\ ["con(", "table.concat("],
\ ["ip(", "ipairs("],
\ ["pa(", "pairs("],
\ ["ins(", "table.insert("],
\ ["gmatch(", "string.gmatch("],
\ ["find(", "string.find("],
\ ["sub(", "string.sub("],
\ ["gsub(", "string.gsub("],
\ ["loc", "local"],
\ ["unp(", "unpack("],
\ ["match(", "string.match("],
\ ["sort(", "table.sort("],
\ ["ty(", "type("],
\ ["fore(", "table.foreach("],
\ ["forei(", "table.foreachi("],
\ ["func", "function"],
\ ["th", "then"],
\ ["el", "else"],
\ ["ei", "elseif"],
\ ["rep(", "string.rep("],
\ ["len(", "string.len("],
\ ["wrap(", "coroutine.wrap("],
\ ["yield(", "coroutine.yield("]
\ ]

function! SetLuaIabbrevs()
  for a in s:iabbrevlist
    execute "iabbrev " . a[0] . " " . a[1]
  endfor
endfunction

function! ClearLuaIabbrevs()
  for a in s:iabbrevlist
    execute "iunabbrev " . a[0]
  endfor
endfunction

" completion function...
function! CompleteLua(findstart, base)
  lua completefunc_luacode()
endfunction
"set completefunc=CompleteLua
set omnifunc=CompleteLua


" add support for folding of Lua functions
"function! FoldLuaLevel(v:lnum)
function! FoldLuaLevel(linenum)
  lua foldlevel_luacode()
endfunction

" set the foldexpr Vim variable
set foldexpr=FoldLuaLevel(v:lnum)
set foldmethod=expr
set nofoldenable



" restore compatibility options
let &cpo = s:save_cpo
