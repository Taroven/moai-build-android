local lfs = lfs or require("lfs")
local fs = fs or require("util.filesystem")

local ignore = {
	["."] = true,
	[".."] = true,
}

local concat = function (src)
	if type(src) == "table" then
		local s = ""
		for k,v in pairs(src) do
			s = s .. "\n" .. k .. " = " .. v
		end
		return s
	else
		return tostring(src)
	end
end

-- append file contents of src to the line after first match of dest within s (ugly as sin, it works well enough)
-- Results will be in reverse order, which shouldn't ever matter.
-- Assumes that a file path is passed unless given a table for src (in which case the table is concatenated and used instead)
local stitch = function (src, dest, marker)
	local s = type(src) == "table" and table.concat(src,"\n") or fs.read(src)
	local d = fs.read(dest,true)
	if marker then
		for i,v in ipairs(d) do
			if string.match(v,marker) then
				table.insert(d, i + 1, s)
				break
			end
		end
	else
		d[#d + 1] = s
	end
	
	return fs.write(d, dest)
end

-- match and replace text within all files listed in 't' (uses string.gsub for replacement)
local replace = function (t,src,dest)
	if type(t) == "string" then t = {t} end
	for i,path in ipairs(t) do
		local attr = lfs.attributes(path)
		if attr and attr.mode ~= "directory" then -- this acts up pretty hard when given a directory.
			if string.match(path,"^%.") then path = lfs.currentdir() .. fs.sep .. path; end
			if attr.mode == "file" then -- being extra careful not to touch things that should not be touched
				print("replace: working with " .. path, concat(src), dest or "")
				local s = fs.read(path)
				local final,rep = s,0
				if type(src) == "string" then
					final,rep = string.gsub(final,src,dest)
				elseif type(src) == "table" then
					for k,v in pairs(src) do
						local r = 0
						final,r = string.gsub(final,k,v)
						rep = rep + r
					end
				end
				if rep > 0 then
					fs.write(final,path,test)
					print("replace: made " .. rep .. " replacements in file " .. path)
				end
			end
		end
	end
end

-- remove lines containing specified text (src)
local repline = function (t,src,dest,test)
	if type(t) == "string" then t = {t} end
	local repl = type(src) == "table" and src or {[src] = dest or false}
	for k,v in pairs(src) do
		if v == "" or type(v) ~= "string" then
			src[k] = false
		end
	end
	
	for i,path in ipairs(t) do
		local attr = lfs.attributes(path)
		if attr and attr.mode ~= "directory" then -- this acts up pretty hard when given a directory.
			if string.match(path,"^%.") then path = lfs.currentdir() .. "/" .. path; end
			local attr = lfs.attributes(path)
			if attr.mode == "file" then
				print("blank: working with " .. path, concat(src), dest or "")
				local s = fs.read(path,true)
	
				local final
				local rep,removed = 0, 0
				for i,line in ipairs(s) do
					for k,v in pairs(repl) do
						if type(v) == "string" then
							local f,r = string.gsub(line,k,v)
							if r > 0 then
								line[i] = f
								rep = rep + r
							end
						else -- remove line
							if string.match(line,k) then
								table.remove(s,i)
								removed = removed + 1
							end
						end
					end
				end	
				if rep > 0 or removed > 0 then
					fs.write(final,path,test)
					if rep > 0 then print("repline: made " .. rep .. " replacements in file " .. path) end
					if removed > 0 then print("repline: removed " .. removed " lines in file " .. path) end
				end
			end
		end
	end
end

local split = function (s,sep)
	sep = escape(sep)
	local t = {}
	for part in string.gmatch(s,"([%w%d]+)[" .. sep .. "]?") do
		t[#t + 1] = part
	end
	return t
end

return {
	stitch = stitch,
	replace = replace,
	repline = repline,
}