function assert(c, ...)
	if c then
		return c, ...
	end
	if select("#", ...) == 0 then
		error("assertion failed")
	end
	error(...)
end

local function ipairs_iterator(t, index)
	local nextIndex = index + 1
	local nextValue = t[nextIndex]
	if nextValue ~= nil then
		return nextIndex, nextValue
	end
end

function ipairs(t)
	return ipairs_iterator, t, 0
end
pairs = table.pairs

do
	local function partition_nocomp(tbl, left, right, pivot)
		local pval = tbl[pivot]
		tbl[pivot], tbl[right] = tbl[right], pval
		local store = left
		for v = left, right - 1, 1 do
			local vval = tbl[v]
			if vval < pval then
				tbl[v], tbl[store] = tbl[store], vval
				store = store + 1
			end
		end
		tbl[store], tbl[right] = tbl[right], tbl[store]
		return store
	end
	local function quicksort_nocomp(tbl, left, right)
		if right > left then
			local pivot = left
			local newpivot = partition_nocomp(tbl,left,right,pivot)
			quicksort_nocomp(tbl,left,newpivot-1)
			return quicksort_nocomp(tbl,newpivot+1,right)
		end
		return tbl
	end

	local function partition_comp(tbl, left, right, pivot, comp)
		local pval = tbl[pivot]
		tbl[pivot], tbl[right] = tbl[right], pval
		local store = left
		for v = left, right - 1, 1 do
			local vval = tbl[v]
			if comp(vval, pval) then
				tbl[v], tbl[store] = tbl[store], vval
				store = store + 1
			end
		end
		tbl[store], tbl[right] = tbl[right], tbl[store]
		return store
	end
	local function quicksort_comp(tbl, left, right, comp)
		if right > left then
			local pivot = left
			local newpivot = partition_comp(tbl,left,right,pivot, comp)
			quicksort_comp(tbl,left,newpivot-1, comp)
			return quicksort_comp(tbl,newpivot+1,right, comp)
		end
		return tbl
	end

	function table.sort(tbl, comp) -- quicksort
	    if comp then
		    return quicksort_comp(tbl,1, #tbl, comp)
	    end
    	return quicksort_nocomp(tbl, 1, #tbl)
	end
end

function string.len(s)
	return #s
end

local tableconcat = table.concat

function string.rep(s, n)
	local t = {}
	for i = 1, n do
		t[i] = s
	end
	return tableconcat(t)
end

function string.gmatch(str, pattern)
	local init = 1
	local function gmatch_it()
		if init <= str:len() then 
			local s, e = str:find(pattern, init)
			if s then
				local oldInit = init
				init = e+1
				return str:match(pattern, oldInit)
			end
		end
	end
	return gmatch_it
end

function math.max(max, ...)
	local select = select
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		max = (max < v) and v or max
	end
	return max
end

function math.min(min, ...)
	local select = select
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		min = (min > v) and v or min
	end
	return min
end


do
	local static_random = newrandom()

	function math.random(upper, lower)
		return static_random:random(upper, lower)
	end

	function math.randomseed(seed)
		return static_random:seed(seed)
	end
end


do
	local error = error
	local ccreate = coroutine.create
	local cresume = coroutine.resume

	local function wrap_helper(status, ...)
		if status then
			return ...
		end
		error(...)
	end

	function coroutine.wrap(f)
		local coro = ccreate(f)
		return function(...)
			return wrap_helper(
				cresume(
					coro, ...
				)
			)
		end
	end
end


-- *************
-- COMPATIBILITY
-- *************

function table.getn (tbl)
	return #tbl
end

string.gfind = string.gmatch

function math.mod (a, b)
	return a % b
end

function require (modname) end


local function append(t, a, b, c)
  if a and a ~= "" then
    t[#t + 1] = a
  end
  if b and b ~= "" then
    t[#t + 1] = b
  end
  if c and c ~= "" then
    t[#t + 1] = c
  end
end

local function desFun(index, t)
   local old = _G[index]
   if old then
      if t then
	 for k, v in pairs(t) do
	    old[k] = v
	 end
      end
      return old
   else
      t = t or {}
      _G[index] = t
      return t
   end
end

local desEnv = {}
setmetatable(desEnv, {__newindex = function() end})
local next = next

function deserialize(str)
   -- for lua 5.0 (and 5.1)
   local f = assert(loadstring("return function(_) return " .. str .. " end"))
   setfenv(f, desEnv)
   return f()(desFun)

   -- for lua 5.1
--[[
   local f = assert(loadstring("local _ = ... return " .. str .. " end"))
   setfenv(f, desEnv)
   return f(desFun)
]]
end

local serialize_pass2

local typeSerialize = {}
local function nilSerialize(buf, value)
  append(buf, tostring(value))
end

local function stringSerialize(buf, value)
   append(buf, string.format("%q", value))
end
typeSerialize["string"] = stringSerialize

local function numberSerialize(buf, value)
   append(buf, string.format("%.17g", value))
end
typeSerialize["number"] = numberSerialize

local keywords = {}
keywords["and"] = 1
keywords["or"] = 1
keywords["not"] = 1
keywords["do"] = 1
keywords["end"] = 1
keywords["if"] = 1
keywords["then"] = 1
keywords["while"] = 1
keywords["repeat"] = 1
keywords["local"] = 1
keywords["function"] = 1
keywords["break"] = 1
keywords["return"] = 1
keywords["else"] = 1
keywords["elseif"] = 1
keywords["until"] = 1
keywords["true"] = 1
keywords["false"] = 1
keywords["nil"] = 1
keywords["in"] = 1
keywords["for"] = 1

local function tableKey2(buf, key, vars, multiline, indent)
      append(buf, "[")
      serialize_pass2(buf, key, vars, multiline, indent)
      append(buf, "]")
end

local function tableKey(buf, key, vars, multiline, indent)
   if type(key) ~= "string" then
      return tableKey2(buf, key, vars, multiline, indent)
   end
   if not keywords[key] and string.find(key, "^[%a_][%a%d_]*$") then
      return append(buf, key)
   else
      return tableKey2(buf, key, vars, multiline, indent)
   end
end

local function tableSerialize(buf, value, vars, multiline, indent)
   local var = vars[value]

   if var then
      local touched = vars[var]
      if touched then
          return append(buf, "_(", var, ")")
      else
	     vars[var] = true
      end
   end

   if var then
      append(buf, "_(", var, ",{")
   else
      append(buf, "{")
   end
   local wantComma
   local lastInt = 0
   local nextIndent = indent .. " "
   for k, v in ipairs(value) do
      if v == nil then
        break
      end
      if wantComma then
         append(buf, ",")
      end
      append(buf, multiline, nextIndent)
      serialize_pass2(buf, v, vars, multiline, nextIndent)
      wantComma = true

      lastInt = k
   end
   for k, v in pairs(value) do
      if type(k) == "number" and k == math.floor(k) and 1 <= k and k <= lastInt then
    	 -- ignore this, it's already in the table
      else
         if k ~= nil and v ~= nil then
              if wantComma then
                append(buf, ",")
              end
              append(buf, multiline, nextIndent)
              tableKey(buf, k, vars, multiline, nextIndent)
              append(buf, "=")
              serialize_pass2(buf, v, vars, multiline, nextIndent)
              wantComma = true
          end
       end
   end
   append(buf, multiline, indent)
   if var then
       append(buf, "})")
   else
       append(buf, "}")
   end
end
typeSerialize["table"] = tableSerialize


serialize_pass2 = function(buf, value, vars, multiline, indent)
   local f = typeSerialize[type(value)] or nilSerialize
   f(buf, value, vars, multiline, indent)
end

local function getVars(value, t, curVar)
   t = t or {}
   if type(value) == "table" then
      if t[value] then
	 if t[value] == 0 then
	    t[value] = curVar
	    curVar = curVar + 1
	 end
      else
	 t[value] = 0
	 for k, v in pairs(value) do
	    local t2, curVar2 = getVars(k, t, curVar)
	    curVar = curVar2
	    local t2, curVar2 = getVars(v, t, curVar)
	    curVar = curVar2
	 end
      end
   end
   return t, curVar
end

function serialize(value, multiline, indent)
   multiline = multiline or ""
   indent = indent or ""
   local vars = getVars(value, nil, 1)
   for k, v in pairs(vars) do
      if v == 0 then
	 vars[k] = nil
      end
   end
   local buf = {}
   serialize_pass2(buf, value, vars, multiline, indent)
   return table.concat(buf)
end

function pp(value)
    return serialize(value, "\n")
end
