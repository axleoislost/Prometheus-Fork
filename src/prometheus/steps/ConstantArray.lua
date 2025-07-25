 -- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- ConstantArray.lua
--
-- This Script provides a Simple Obfuscation Step that wraps the entire Script into a function

-- TODO: Wrapper Functions
-- TODO: Proxy Object for indexing: e.g: ARR[X] becomes ARR + X

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local visitast = require("prometheus.visitast");
local util     = require("prometheus.util")
local Parser   = require("prometheus.parser");
local enums = require("prometheus.enums")

local LuaVersion = enums.LuaVersion;
local AstKind = Ast.AstKind;

local ConstantArray = Step:extend();
ConstantArray.Description = "This Step will Extract all Constants and put them into an Array at the beginning of the script";
ConstantArray.Name = "Constant Array";

ConstantArray.SettingsDescriptor = {
	Treshold = {
		name = "Treshold",
		description = "The relative amount of nodes that will be affected",
		type = "number",
		default = 1,
		min = 0,
		max = 1,
	},
	StringsOnly = {
		name = "StringsOnly",
		description = "Wether to only Extract Strings",
		type = "boolean",
		default = true,
	},
	Shuffle = {
		name = "Shuffle",
		description = "Wether to shuffle the order of Elements in the Array",
		type = "boolean",
		default = true,
	},
	Rotate = {
		name = "Rotate",
		description = "Wether to rotate the String Array by a specific (random) amount. This will be undone on runtime.",
		type = "boolean",
		default = true,
	},
	LocalWrapperTreshold = {
		name = "LocalWrapperTreshold",
		description = "The relative amount of nodes functions, that will get local wrappers",
		type = "number",
		default = 1,
		min = 0,
		max = 1,
	},
	LocalWrapperCount = {
		name = "LocalWrapperCount",
		description = "The number of Local wrapper Functions per scope. This only applies if LocalWrapperTreshold is greater than 0",
		type = "number",
		min = 0,
		max = 512,
		default = 333,
	},
	LocalWrapperArgCount = {
		name = "LocalWrapperArgCount",
		description = "The number of Arguments to the Local wrapper Functions",
		type = "number",
		min = 1,
		default = 192,
		max = 200,
	};
	MaxWrapperOffset = {
		name = "MaxWrapperOffset",
		description = "The Max Offset for the Wrapper Functions",
		type = "number",
		min = 0,
		default = 65535,
	};
	Encoding = {
		name = "Encoding",
		description = "The Encoding to use for the Strings",
		type = "enum",
		default = "ascii85",
		values = {
			"none",
			"ascii85",
		},
	}
}

local function callNameGenerator(generatorFunction, ...)
	if(type(generatorFunction) == "table") then
		generatorFunction = generatorFunction.generateName;
	end
	return generatorFunction(...);
end

function ConstantArray:init(settings)
	
end

function ConstantArray:createArray()
	local entries = {};
	for i, v in ipairs(self.constants) do
		if type(v) == "string" then
			v = self:encode(v);
		end
		entries[i] = Ast.TableEntry(Ast.ConstantNode(v));
	end
	return Ast.TableConstructorExpression(entries);
end

function ConstantArray:indexing(index, data)
	if self.LocalWrapperCount > 0 and data.functionData.local_wrappers then
		local wrappers = data.functionData.local_wrappers;
		local wrapper = wrappers[math.random(#wrappers)];

		local args = {};
		local ofs = index - self.wrapperOffset - wrapper.offset;
		for i = 1, self.LocalWrapperArgCount, 1 do
			if i == wrapper.arg then
				args[i] = Ast.NumberExpression(ofs);
			else
				args[i] = Ast.NumberExpression(math.random(ofs - 1024, ofs + 1024));
			end
		end

		data.scope:addReferenceToHigherScope(wrappers.scope, wrappers.id);
		return Ast.FunctionCallExpression(Ast.IndexExpression(
			Ast.VariableExpression(wrappers.scope, wrappers.id),
			Ast.StringExpression(wrapper.index)
		), args);
	else
		data.scope:addReferenceToHigherScope(self.rootScope,  self.wrapperId);
		return Ast.FunctionCallExpression(Ast.VariableExpression(self.rootScope, self.wrapperId), {
			Ast.NumberExpression(index - self.wrapperOffset);
		});
	end
end

function ConstantArray:getConstant(value, data)
	if(self.lookup[value]) then
		return self:indexing(self.lookup[value], data)
	end
	local idx = #self.constants + 1;
	self.constants[idx] = value;
	self.lookup[value] = idx;
	return self:indexing(idx, data);
end

function ConstantArray:addConstant(value)
	if(self.lookup[value]) then
		return
	end
	local idx = #self.constants + 1;
	self.constants[idx] = value;
	self.lookup[value] = idx;
end

local function reverse(t, i, j)
	while i < j do
	  t[i], t[j] = t[j], t[i]
	  i, j = i+1, j-1
	end
end
  
local function rotate(t, d, n)
	n = n or #t
	d = (d or 1) % n
	reverse(t, 1, n)
	reverse(t, 1, d)
	reverse(t, d+1, n)
end

local rotateCode = [=[
	for i, v in ipairs({{1, LEN}, {1, SHIFT}, {SHIFT + 1, LEN}}) do
		while v[1] < v[2] do
			ARR[v[1]], ARR[v[2]], v[1], v[2] = ARR[v[2]], ARR[v[1]], v[1] + 1, v[2] - 1
		end
	end
]=];

function ConstantArray:addRotateCode(ast, shift)
	local parser = Parser:new({
		LuaVersion = LuaVersion.Lua51;
	});

	local newAst = parser:parse(string.gsub(string.gsub(rotateCode, "SHIFT", tostring(shift)), "LEN", tostring(#self.constants)));
	local forStat = newAst.body.statements[1];
	forStat.body.scope:setParent(ast.body.scope);
	visitast(newAst, nil, function(node, data)
		if(node.kind == AstKind.VariableExpression) then
			if(node.scope:getVariableName(node.id) == "ARR") then
				data.scope:removeReferenceToHigherScope(node.scope, node.id);
				data.scope:addReferenceToHigherScope(self.rootScope, self.arrId);
				node.scope = self.rootScope;
				node.id    = self.arrId;
			end
		end
	end)

	table.insert(ast.body.statements, 1, forStat);
end

function ConstantArray:addDecodeCode(ast)
    -- ascii85 decode function injected as Lua code
    local ascii85DecodeCode = [[
    do
			x8 = getfenv()
			i2 = unpack
			z6 = _ENV
        local arr = ARR;
        local result = {};
        local function ascii85_decode(str)
            local result = {};
            local i = 1;
            local len = #str;

            while i <= len do
                local c = string.sub(str, i, i);
                if c == 'z' then
                    table.insert(result, string.char(0,0,0,0));
                    i = i + 1;
                elseif c:match("%s") then
                    i = i + 1;
                else
                    local group = {};
                    local j = 0;
                    while j < 5 and i + j <= len do
                        local ch = string.sub(str, i + j, i + j);
                        if ch == 'z' or ch == ' ' or ch == '\n' or ch == '\r' then
                            break;
                        end
                        group[#group + 1] = ch;
                        j = j + 1;
                    end

                    local groupLen = #group;
                    for _ = groupLen + 1, 5 do
                        group[#group + 1] = 'u';
                    end

                    local chunk = 0;
                    for k = 1, 5 do
                        chunk = chunk * 85 + (string.byte(group[k]) - 33);
                    end

                    local bytesToOutput = groupLen - 1;
                    for b = 3, 3 - (bytesToOutput - 1), -1 do
                        local byte = math.floor(chunk / (256 ^ b)) % 256;
                        table.insert(result, string.char(byte));
                    end

                    i = i + groupLen;
                end
            end
	c9 = newproxy
    y1 = setmetatable
            return table.concat(result);
        end
    z9 = getmetatable
	j8 = select
	t7 = getfenv
        for i = 1, #arr do
            local data = arr[i];
            if type(data) == "string" then
                arr[i] = ascii85_decode(data);
            end
        end
    end
    ]]

    local parser = Parser:new({
        LuaVersion = LuaVersion.Lua51;
    })

    local newAst = parser:parse(ascii85DecodeCode)
    local forStat = newAst.body.statements[1]
    forStat.body.scope:setParent(ast.body.scope)

    visitast(newAst, nil, function(node, data)
        if node.kind == AstKind.VariableExpression then
            if node.scope:getVariableName(node.id) == "ARR" then
                data.scope:removeReferenceToHigherScope(node.scope, node.id)
                data.scope:addReferenceToHigherScope(self.rootScope, self.arrId)
                node.scope = self.rootScope
                node.id = self.arrId
            end
        end
    end)

    table.insert(ast.body.statements, 1, forStat)
end


function ConstantArray:createBase64Lookup()
	local entries = {};
	local i = 0;
	for char in string.gmatch(self.base64chars, ".") do
		table.insert(entries, Ast.KeyedTableEntry(Ast.StringExpression(char), Ast.NumberExpression(i)));
		i = i + 1;
	end
	util.shuffle(entries);
	return Ast.TableConstructorExpression(entries);
end

function ConstantArray:encode(str)
    if self.Encoding == "ascii85" then
        local function ascii85_encode(data)
            local result = {}
            local len = #data
            local i = 1

            while i <= len do
                local chunk = 0
                local chunkSize = math.min(4, len - i + 1)

                for j = 0, 3 do
                    local byte = 0
                    if j < chunkSize then
                        byte = string.byte(data, i + j)
                    end
                    chunk = chunk * 256 + byte
                end

                if chunk == 0 and chunkSize == 4 then
                    table.insert(result, 'z')
                else
                    local encoded = {}
                    for _ = 1, 5 do
                        encoded[#encoded + 1] = string.char((chunk % 85) + 33)
                        chunk = math.floor(chunk / 85)
                    end
                    local encodedStr = table.concat(encoded, '')
                    encodedStr = encodedStr:reverse()
                    if chunkSize < 4 then
                        encodedStr = encodedStr:sub(1, chunkSize + 1)
                    end
                    table.insert(result, encodedStr)
                end

                i = i + 4
            end

            return table.concat(result)
        end

        return ascii85_encode(str)
    end
end

function ConstantArray:apply(ast, pipeline)
	self.rootScope = ast.body.scope;
	self.arrId     = self.rootScope:addVariable();

	self.base64chars = table.concat(util.shuffle{
		"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
		"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
		"0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
		"+", "/",
	});

	self.constants = {};
	self.lookup    = {};

	-- Extract Constants
	visitast(ast, nil, function(node, data)
		-- Apply only to some nodes
		if math.random() <= self.Treshold then
			node.__apply_constant_array = true;
			if node.kind == AstKind.StringExpression then
				self:addConstant(node.value);
			elseif not self.StringsOnly then
				if node.isConstant then
					if node.value ~= nil then
						self:addConstant(node.value);
					end 
				end
			end
		end
	end);

	-- Shuffle Array
	if self.Shuffle then
		self.constants = util.shuffle(self.constants);
		self.lookup    = {};
		for i, v in ipairs(self.constants) do
			self.lookup[v] = i;
		end
	end

	-- Set Wrapper Function Offset
	self.wrapperOffset = math.random(-self.MaxWrapperOffset, self.MaxWrapperOffset);
	self.wrapperId     = self.rootScope:addVariable();

	visitast(ast, function(node, data)
		-- Add Local Wrapper Functions
		if self.LocalWrapperCount > 0 and node.kind == AstKind.Block and node.isFunctionBlock and math.random() <= self.LocalWrapperTreshold then
			local id = node.scope:addVariable()
			data.functionData.local_wrappers = {
				id = id;
				scope = node.scope,
			};
			local nameLookup = {};
			for i = 1, self.LocalWrapperCount, 1 do
				local name;
				repeat
					name = callNameGenerator(pipeline.namegenerator, math.random(1, self.LocalWrapperArgCount * 16));
				until not nameLookup[name];
				nameLookup[name] = true;

				local offset = math.random(-self.MaxWrapperOffset, self.MaxWrapperOffset);
				local argPos = math.random(1, self.LocalWrapperArgCount);

				data.functionData.local_wrappers[i] = {
					arg   = argPos,
					index = name,
					offset =  offset,
				};
				data.functionData.__used = false;
			end
		end
		if node.__apply_constant_array then
			data.functionData.__used = true;
		end
	end, function(node, data)
		-- Actually insert Statements to get the Constant Values
		if node.__apply_constant_array then
			if node.kind == AstKind.StringExpression then
				return self:getConstant(node.value, data);
			elseif not self.StringsOnly then
				if node.isConstant then
					return node.value ~= nil and self:getConstant(node.value, data);
				end
			end
			node.__apply_constant_array = nil;
		end

		-- Insert Local Wrapper Declarations
		if self.LocalWrapperCount > 0 and node.kind == AstKind.Block and node.isFunctionBlock and data.functionData.local_wrappers and data.functionData.__used then
			data.functionData.__used = nil;
			local elems = {};
			local wrappers = data.functionData.local_wrappers;
			for i = 1, self.LocalWrapperCount, 1 do
				local wrapper = wrappers[i];
				local argPos = wrapper.arg;
				local offset = wrapper.offset;
				local name   = wrapper.index;

				local funcScope = Scope:new(node.scope);

				local arg = nil;
				local args = {};

				for i = 1, self.LocalWrapperArgCount, 1 do
					args[i] = funcScope:addVariable();
					if i == argPos then
						arg = args[i];
					end
				end

				local addSubArg;

				-- Create add and Subtract code
				if offset < 0 then
					addSubArg = Ast.SubExpression(Ast.VariableExpression(funcScope, arg), Ast.NumberExpression(-offset));
				else
					addSubArg = Ast.AddExpression(Ast.VariableExpression(funcScope, arg), Ast.NumberExpression(offset));
				end

				funcScope:addReferenceToHigherScope(self.rootScope, self.wrapperId);
				local callArg = Ast.FunctionCallExpression(Ast.VariableExpression(self.rootScope, self.wrapperId), {
					addSubArg
				});

				local fargs = {};
				for i, v in ipairs(args) do
					fargs[i] = Ast.VariableExpression(funcScope, v);
				end

				elems[i] = Ast.KeyedTableEntry(
					Ast.StringExpression(name),
					Ast.FunctionLiteralExpression(fargs, Ast.Block({
						Ast.ReturnStatement({
							callArg
						});
					}, funcScope))
				)
			end
			table.insert(node.statements, 1, Ast.LocalVariableDeclaration(node.scope, {
				wrappers.id
			}, {
				Ast.TableConstructorExpression(elems)
			}));
		end
	end);

	self:addDecodeCode(ast);

	local steps = util.shuffle({
		-- Add Wrapper Function Code
		function() 
			local funcScope = Scope:new(self.rootScope);
			-- Add Reference to Array
			funcScope:addReferenceToHigherScope(self.rootScope, self.arrId);

			local arg = funcScope:addVariable();
			local addSubArg;

			-- Create add and Subtract code
			if self.wrapperOffset < 0 then
				addSubArg = Ast.SubExpression(Ast.VariableExpression(funcScope, arg), Ast.NumberExpression(-self.wrapperOffset));
			else
				addSubArg = Ast.AddExpression(Ast.VariableExpression(funcScope, arg), Ast.NumberExpression(self.wrapperOffset));
			end

			-- Create and Add the Function Declaration
			table.insert(ast.body.statements, 1, Ast.LocalFunctionDeclaration(self.rootScope, self.wrapperId, {
				Ast.VariableExpression(funcScope, arg)
			}, Ast.Block({
				Ast.ReturnStatement({
					Ast.IndexExpression(
						Ast.VariableExpression(self.rootScope, self.arrId),
						addSubArg
					)
				});
			}, funcScope)));

			-- Resulting Code:
			-- function xy(a)
			-- 		return ARR[a - 10]
			-- end
		end,
		-- Rotate Array and Add unrotate code
		function()
			if self.Rotate and #self.constants > 1 then
				local shift = math.random(1, #self.constants - 1);

				rotate(self.constants, -shift);
				self:addRotateCode(ast, shift);
			end
		end,
	});

	for i, f in ipairs(steps) do
		f();
	end

	-- Add the Array Declaration
	table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(self.rootScope, {self.arrId}, {self:createArray()}));

	self.rootScope = nil;
	self.arrId     = nil;

	self.constants = nil;
	self.lookup    = nil;
end

return ConstantArray;
