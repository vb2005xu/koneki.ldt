--------------------------------------------------------------------------------
-- Copyright (c) 2011, 2013 Sierra Wireless and others.
-- All rights reserved. This program and the accompanying materials
-- are made available under the terms of the Eclipse Public License v1.0
-- which accompanies this distribution, and is available at
-- http://www.eclipse.org/legal/epl-v10.html
--
-- Contributors:
--     Sierra Wireless - initial API and implementation
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Corrects the indentation of a Lua source file, through semantic analysis
-- with Metalua.
--
-- @module luaformatter
--
--------------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- This module is still work in progress, here some point to work on:
--
-- * Avoid to go forward when obviously no indentation needs to be done
--   (e.g. in function parameters, or a single-line call)
--
-- * Separate helper functions from config
--
-- * Re-work the indent function, especially the way to restore indentation.
-- -----------------------------------------------------------------------------

require 'metalua.loader'

local pp   = require'metalua.pprint'
local mlc  = require 'metalua.compiler'.new()
local Q    = require 'metalua.treequery'

local M    = {}

--------------------------------------------------------------------------------
-- Format walking utilities
--------------------------------------------------------------------------------

-- Returns the first and last lineinfo positions of a given AST node,
-- by default including any comments immediately before it.
local function getrange(node, ignorecomments)
    local li = node.lineinfo
    if not li then return nil, nil end
    local first, last = li.first, li.last
    if not ignorecomments and first.comments then
        first = first.comments.lineinfo.first end
    return first, last
end

-- Main indenting function:
--
-- * registers lines where indentation must be increased by
--   setting `st.indentation[line_num]` to `true` (will be
--   turned  into numbers in a later step)
--
-- * fills unindentations from line to line
--   `st.unindentation[line_2] = line_1`, indicating that line
--   `line_2` must be de-indented to the same level as `line_1`.
--
local function indent(st, first, last, parent)
  local startline  = first.line
  local startindex = first.offset
  local endline    = last.line

  -- FIXME: comment unclear
  -- Indent following lines when current one does not start with the
  -- first statement of the current block.
  if not st.source:sub(1,startindex-1):find("[\r\n]%s*$") then
    startline = startline + 1
  end

  -- Nothing interesting to do
  if endline < startline then return end

  -- Indent block first line
  st.indentation[startline] = true

  -- Restore indentation
  if not st.unindentation[endline+1] then
      -- Only when not already set by a parent node
      local parent_first_line, _ =  getrange(parent).line
      st.unindentation[endline+1] = parent_first_line
  end
end

---
-- Indents parameters
--
-- @param firstparam first parameter of the given callable
local function indentparams(st, firstparam, lastparam, parent)
    local left, _  = getrange(firstparam)
    local _, right = getrange(lastparam)
    indent(st, left, right, parent)
end

---
-- Indent all lines of a chunk, including optional suffix comment
local function indentchunk(st, node, parent)
    local first = getrange(node[1])
    local last  = node[#node].lineinfo.last
    if last.comments then last = last.comments.lineinfo.last end
    indent(st, first, last, parent)
end

---
-- Indent all lines of an expression list.
local function indentexprlist(st, node, parent, ignorecomments)
    local first, last = getrange(node, ignorecomments)
    indent(st, first, last, parent)
end

-- Case-by-case functions. If a function `case[tag]` exists, it's applied
-- to every node with this `tag`, in traversal order.
local case = { }

--------------------------------------------------------------------------------
-- Expressions formatters
--------------------------------------------------------------------------------
function case.String(st, node)
    local first, last = getrange(node, true)
	-- Forbid indentation within multi-line strings
    for line = first.line+1, last.line do
        st.indentation[line]=false
    end
end

function case.Table(st, node, parent)

  if not st.indenttable then return end

  -- Format inside the table only if it spans over several lines
  local first, last = getrange(node, true)
  if #node == 0 or first.line == last.line then return end

  local first_child, _ = getrange(node[1], false)
  local _, last_child  = getrange(node[#node])
  indent(st, first_child, last_child, node)
end

--------------------------------------------------------------------------------
-- Statements formatters
--------------------------------------------------------------------------------
function case.Forin(st, node)
  local ids, iterator, _ = unpack(node)
  indentexprlist(st, ids, node)
  indentexprlist(st, iterator, node)
end

function case.Fornum(st, node)
  -- Format from variable name to last header expression
  local var, init, limit, step = unpack(node)
  local first, _ = getrange(var, false)
  local _, last  = getrange(node[#node])
  indent(st, first, last, node)
end

function case.Function(st, node)
  local params, chunk = unpack(node)
  indentexprlist(st, params, node)
end

function case.Index(st, node, parent)
  -- Don't indent if the index is on one line
  if node.lineinfo.first.line == node.lineinfo.last.line then return end

  local left, right = unpack(node)
  local _, left_last = getrange(left)
  -- For Call, Set and Local nodes we want to indent to end of the parent node, not only the index itself
  if (parent[1] == node and parent.tag == 'Call') or
     (parent[1] and #parent[1]==1 and parent[1][1]==node and (parent.tag=='Set' or parent.tag=='Local')) then
      local _, parent_last = getrange(parent)
      -- FIXME: used to be indent(left.line, left.offset+1, last.line)?!
      indent(st, left_last, parent_last, parent)
  else
      local _, right_last = getrange(right)
      -- FIXME: used to be indent(left.line, left.offset+1, last.line)?!
      indent(st, left_last, right_last, node)
  end
end

function case.If(st, node)
  -- Indent only conditions, chunks are already taken care of.
  for cond_index=1, #node-1, 2 do
    indentexprlist(st, node[cond_index], node)
  end
end

function case.Call(st, node, parent)
  local expr, firstparam = unpack(node)
  if firstparam then
    indentparams(st, firstparam, node[#node], node)
  end
end

function case.Invoke(st, node, parent)
  local obj, method_name, first_param = unpack(node)

  --indent method_name
  local _, obj_last  = getrange(obj)
  local _, node_last = getrange(node)
  -- FIXME: used to be indent(left.line, left.offset+1, last.line)?!
  indent(st, obj_last, node_last, node)

  --indent parameters
  if first_param then
    indentparams(st, first_param, node[#node], method_name)
  end

end

---
-- Indents `Local and `Set
local function assignments(st, node)

  -- Indent only when node spreads across several lines
  local first, last = getrange(node, true)
  if first.line == last.line then return end

  -- Format it
  local lhs, exprs = unpack(node)
  if #exprs == 0 then
    -- Regular `Local handling
    indentexprlist(st, lhs, node)
    -- Avoid problems and format functions later.
  elseif not (#exprs == 1 and exprs[1].tag == 'Function') then
    -- for local, indent lhs
    if node.tag == 'Local' then
      -- Otherwise, indent LHS and expressions like a single chunk.
      local left_first, _ = getrange(lhs, true)
      local _, right_last = getrange(exprs)
      indent(st, left_first, right_last, node)
    end
    -- In this chunk indent expressions one more.
    indentexprlist(st, exprs, node)
  end
end

case.Local = assignments
case.Set   = assignments

function case.Repeat(st, node)
  local _, expr = unpack(node)
  indentexprlist(st, expr, node)
end

function case.Return(st, node, parent)
  if #node > 0 then indentchunk(st, node, parent) end
end


function case.While(st, node)
  local expr, _ = unpack(node)
  indentexprlist(st. expr, node)
end

local function case_block(st, node, parent)
    if #node == 0 or not parent then return  end -- Ignore empty nodes
    indentchunk(st, node, parent)
end


--------------------------------------------------------------------------------
-- Computes the indentation levels of each source line.
-- @param source code to analyze
-- @return #table {linenumber = indentationlevel}
-- @usage local depth = format.indentLevel("local var")
--------------------------------------------------------------------------------
local function getindentlevel(source, indenttable)

  -- Reject invalid chunks
  if not loadstring(source, 'CheckingFormatterSource') then return end

  -- A TreeQuery request traverses the tree, marking lines to indent
  -- and de-indent through indirect calls to the `indent()` function
  -- above.  Nodes which require specialized indentation rules have
  -- those rules implemented in `case[tag](st, node, parent_node,
  -- ...)`, where `tag` is the node's tag name. Blocks are handled by
  -- `case_block(st, node)`.
  --
  -- Once `indent()` has marked the indentation and de-indentation
  -- places (as well as the long-string areas which must not be
  -- indented)`, the two tables `st.indentation` and
  -- `st.unindentation` are traversed line-number by line-number to
  -- compute the actual indentation level of each line.
  --
  -- This resulting table, associating an indentation level, is
  -- returned as the function's result.

  local ast = mlc:src_to_ast(source)

  local st = {
      indenttable   = indenttable;
      indentation   = { }; -- initially line # -> true/false/nil:
      -- * true  => indent this line,
      -- * nil   => stay at previous indentation level,
      -- * false => leave indentation as it was in original sources (multi-line long string).
      unindentation = { };
      -- line_2 -> line_1 means "indent line_2 at the same level as line_1",
      -- with line_2 > line_1.
      source      = source -- source code to be reformatted
  }

  -- TreeQuery callback, dispatching between `case[tag]` and `case_block` workers.
  local function onNode(...)
      local tag = (...).tag
      if not tag then case_block(st, ...) else
          local f = case[tag]
          if f then f(st, ...) end
      end
  end

  Q(ast) :foreach (onNode)

  -- Built depth table
  local currentdepth = 0
  local depthtable = { } -- line # -> indentation

  local last  = ast.lineinfo.last
  if last.comments then last = last.comments.lineinfo.last end

  for line=1, last.line do

    -- Restore depth
    if st.unindentation[line] then
      currentdepth = depthtable[st.unindentation[line]]
    end

    -- Indent
    if st.indentation[line] then
      currentdepth = currentdepth + 1
      depthtable[line] = currentdepth
    elseif st.indentation[line] == false then
      -- Ignore any kind of indentation
      depthtable[line] = false
    else
      -- Use current indentation
      depthtable[line] = currentdepth
    end

  end
  return depthtable
end

--------------------------------------------------------------------------------
-- Indent Lua Source Code.
--
-- @function [parent=#luaformatter] indentcode
-- @param source      source code to format
-- @param delimiter   line delimiter to use
-- @param indenttable boolean true if you want to indent in table
-- @param ...         either an indentation string or 2 numbers: tab size, indent size
-- @return #string formatted code
--
-- @usage indentcode('local var', '\n', true, '\t')
-- @usage indentcode('local var', '\n', true, --[[tabulationSize]]4, --[[indentationSize]]2)
--------------------------------------------------------------------------------
function M.indentcode(source, delimiter, indenttable, ...)
  -- function `tabulate(depth)` will generate the proper combination of space/tab
  -- characters to represent an indentation of level `depth`, according to the
  -- configuration parameters
  local tabulate
  if select('#', ...) > 1 then -- handle mixes of tabs and spaces
    local tabSize, indentationSize = ...
    assert(type(tabSize)=='string', "Invalid tabulation size")
    assert(type(indentationSize)=='number', "Invalid indentation size")
    -- When tabulation size and indentation size is given, tabulation is
    -- composed of tabulation and spaces
    tabulate = function(depth)
      local range      = depth * indentationSize
      local spaceCount = range % tabSize
      local tabCount   = range - spaceCount
      local tab, space = '\t', ' '
      return tab:rep(tabCount) .. space:rep(spaceCount)
    end
  else -- the indentation string/char has been passed as fourth param.
    local char = ...
    assert(type(char)=='string', "Invalid indentation string")
    -- When tabulation character is given, this character will be duplicated
    -- according to length
    tabulate = function (depth) return char:rep(depth) end
  end

  -- Delimiter position table
  -- Initialization represent string start offset
  local delimiterLength = #delimiter
  local positions = {1-delimiterLength}
  for position in source :gmatch ("()"..delimiter) do
      table.insert(positions, position)
  end

  -- No delimiter found => nothing to indent
  if #positions < 2 then return source end

  -- calculate indentation
  local linetodepth = getindentlevel(source, indenttable)

  -- Concatenate string with right indentation
  local result = { }
  local function acc(str) table.insert(result, str) end

  for position, offset in ipairs(positions) do
    -- Get the interval between two positions
    local next_offset = positions[position+1] or 0
    local rawline = source:sub(offset + delimiterLength, next_offset -1)

    -- Trim white spaces
    local indentcount = linetodepth[position]
    if not indentcount then acc(rawline)
    else
      -- Append correct indentation to non-empty lines
      local line = rawline :match "^%s*(.-)%s*$"
      if line ~= "" then acc(tabulate(indentcount)..line) end
    end

    -- Append carriage return
    -- While on last character append carriage return only if at end of
    -- original source
    -- FIXME: the resulting string's length is delimiterLength+1. Off-by-1?
    -- FIXME: gets end-of-source, not end-of-line?!
    local endofline = source:sub(#source-delimiterLength)
    if position < #positions or endofline == delimiter then
      result[#result+1] = delimiter
    end
  end

  result = table.concat(result)

  -- assert(result:gsub('%s','')==source:gsub('%s','')) -- sanity check

  return result

end

-- Same as `indentsource`, but takes a filename instead of the sources
-- in a string.
function M.indentfile(filename, ...)
    local f = assert(io.open(filename))
    local src = f :read '*a'
    f :close()
    return M.indentcode(src, ...)
end

-- Simply returns the module when called from `require()`,
-- run on the filename passed as parameter if called from shell.
-- TODO: use alt_getopts to handle CLI parameters.
local loaded_as_module = type(package.loaded[...]) == 'userdata'
if loaded_as_module then return M
else print(M.indentfile(assert(...), '\n', true, '  ')) end