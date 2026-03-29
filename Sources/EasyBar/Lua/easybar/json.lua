--- Module contract:
--- Owns JSON encoding and decoding for Swift-Lua process messages.
--- Returns one table with `encode(...)` and `decode(...)`.
local M = {}
local utf8lib = rawget(_G, "utf8")

--- Encodes one Lua string as a JSON string literal.
local function encode_string(value)
	local replacements = {
		['"'] = '\\"',
		["\\"] = "\\\\",
		["\b"] = "\\b",
		["\f"] = "\\f",
		["\n"] = "\\n",
		["\r"] = "\\r",
		["\t"] = "\\t",
	}

	return '"'
		.. value:gsub('[%z\1-\31\\"]', function(char)
			return replacements[char] or string.format("\\u%04x", char:byte())
		end)
		.. '"'
end

--- Returns whether a Lua table should be encoded as a JSON array.
local function is_array(value)
	local count = 0
	local max_index = 0

	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return false
		end

		if key > max_index then
			max_index = key
		end

		count = count + 1
	end

	return max_index == count
end

--- Encodes one Lua value as JSON.
local function encode_value(value)
	local value_type = type(value)

	if value == nil then
		return "null"
	end

	if value_type == "boolean" then
		return value and "true" or "false"
	end

	if value_type == "number" then
		return tostring(value)
	end

	if value_type == "string" then
		return encode_string(value)
	end

	if value_type == "table" then
		if is_array(value) then
			local out = {}
			for i = 1, #value do
				out[#out + 1] = encode_value(value[i])
			end
			return "[" .. table.concat(out, ",") .. "]"
		end

		local out = {}
		for key, item in pairs(value) do
			out[#out + 1] = encode_string(tostring(key)) .. ":" .. encode_value(item)
		end
		table.sort(out)
		return "{" .. table.concat(out, ",") .. "}"
	end

	error("unsupported json encode type: " .. value_type)
end

--- Encodes one Lua value tree into a JSON string.
function M.encode(value)
	return encode_value(value)
end

local Parser = {}
Parser.__index = Parser

function Parser:new(text)
	return setmetatable({
		text = text,
		pos = 1,
		len = #text,
	}, self)
end

function Parser:peek()
	return self.text:sub(self.pos, self.pos)
end

function Parser:next()
	local char = self.text:sub(self.pos, self.pos)
	self.pos = self.pos + 1
	return char
end

function Parser:skip_whitespace()
	while self.pos <= self.len do
		local char = self:peek()
		if char == " " or char == "\n" or char == "\r" or char == "\t" then
			self.pos = self.pos + 1
		else
			break
		end
	end
end

function Parser:expect(expected)
	local actual = self:next()
	if actual ~= expected then
		error("expected '" .. expected .. "', got '" .. tostring(actual) .. "'")
	end
end

function Parser:parse_string()
	self:expect('"')

	local out = {}

	while self.pos <= self.len do
		local char = self:next()

		if char == '"' then
			return table.concat(out)
		end

		if char == "\\" then
			local escape = self:next()

			if escape == '"' then
				out[#out + 1] = '"'
			elseif escape == "\\" then
				out[#out + 1] = "\\"
			elseif escape == "/" then
				out[#out + 1] = "/"
			elseif escape == "b" then
				out[#out + 1] = "\b"
			elseif escape == "f" then
				out[#out + 1] = "\f"
			elseif escape == "n" then
				out[#out + 1] = "\n"
			elseif escape == "r" then
				out[#out + 1] = "\r"
			elseif escape == "t" then
				out[#out + 1] = "\t"
			elseif escape == "u" then
				local hex = self.text:sub(self.pos, self.pos + 3)
				if #hex ~= 4 or not hex:match("^[0-9a-fA-F]+$") then
					error("invalid unicode escape")
				end
				self.pos = self.pos + 4

				local code = tonumber(hex, 16)

				if utf8lib and utf8lib.char then
					out[#out + 1] = utf8lib.char(code)
				else
					out[#out + 1] = "?"
				end
			else
				error("invalid escape sequence")
			end
		else
			out[#out + 1] = char
		end
	end

	error("unterminated string")
end

function Parser:parse_number()
	local start = self.pos

	local function advance_if(pattern)
		local char = self:peek()
		if char ~= "" and char:match(pattern) then
			self.pos = self.pos + 1
			return true
		end
		return false
	end

	advance_if("[-]")

	if self:peek() == "0" then
		self.pos = self.pos + 1
	else
		if not advance_if("%d") then
			error("invalid number")
		end
		while advance_if("%d") do
		end
	end

	if self:peek() == "." then
		self.pos = self.pos + 1
		if not advance_if("%d") then
			error("invalid fraction")
		end
		while advance_if("%d") do
		end
	end

	local char = self:peek()
	if char == "e" or char == "E" then
		self.pos = self.pos + 1
		advance_if("[+-]")
		if not advance_if("%d") then
			error("invalid exponent")
		end
		while advance_if("%d") do
		end
	end

	local value = tonumber(self.text:sub(start, self.pos - 1))
	if value == nil then
		error("invalid number")
	end

	return value
end

function Parser:parse_literal()
	if self.text:sub(self.pos, self.pos + 3) == "true" then
		self.pos = self.pos + 4
		return true
	end

	if self.text:sub(self.pos, self.pos + 4) == "false" then
		self.pos = self.pos + 5
		return false
	end

	if self.text:sub(self.pos, self.pos + 3) == "null" then
		self.pos = self.pos + 4
		return nil
	end

	error("invalid literal")
end

function Parser:parse_array()
	self:expect("[")
	self:skip_whitespace()

	local out = {}

	if self:peek() == "]" then
		self.pos = self.pos + 1
		return out
	end

	while true do
		out[#out + 1] = self:parse_value()
		self:skip_whitespace()

		local char = self:peek()
		if char == "]" then
			self.pos = self.pos + 1
			break
		end

		self:expect(",")
		self:skip_whitespace()
	end

	return out
end

function Parser:parse_object()
	self:expect("{")
	self:skip_whitespace()

	local out = {}

	if self:peek() == "}" then
		self.pos = self.pos + 1
		return out
	end

	while true do
		local key = self:parse_string()
		self:skip_whitespace()
		self:expect(":")
		self:skip_whitespace()
		out[key] = self:parse_value()
		self:skip_whitespace()

		local char = self:peek()
		if char == "}" then
			self.pos = self.pos + 1
			break
		end

		self:expect(",")
		self:skip_whitespace()
	end

	return out
end

function Parser:parse_value()
	self:skip_whitespace()

	local char = self:peek()

	if char == '"' then
		return self:parse_string()
	end

	if char == "{" then
		return self:parse_object()
	end

	if char == "[" then
		return self:parse_array()
	end

	if char == "-" or char:match("%d") then
		return self:parse_number()
	end

	return self:parse_literal()
end

--- Decodes one JSON string into Lua values.
function M.decode(text)
	local parser = Parser:new(text)
	local value = parser:parse_value()
	parser:skip_whitespace()

	if parser.pos <= parser.len then
		error("trailing characters after json value")
	end

	return value
end

return M
