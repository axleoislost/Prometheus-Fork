-- Encrypts strings in base64, not very secure but performance will be better

local Step    = require("prometheus.step")
local Ast     = require("prometheus.ast")
local Scope   = require("prometheus.scope")
local Parser  = require("prometheus.parser")
local Enums   = require("prometheus.enums")
local visitast= require("prometheus.visitast")
local util    = require("prometheus.util")
local AstKind = Ast.AstKind

local defaultB64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function shuffleString(str)
    local t = {}
    for i = 1, #str do
        t[i] = str:sub(i,i)
    end
    math.randomseed(os.time() + os.clock()*100000)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return table.concat(t)
end

local function base64encode(data, alphabet)
    local b64chars = alphabet
    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do
            r = r .. (b%2^i - b%2^(i-1) > 0 and '1' or '0')
        end
        return r
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c=0
        for i=1,6 do
            c = c + (x:sub(i,i)=='1' and 2^(6-i) or 0)
        end
        return b64chars:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data % 3 + 1])
end

local EncryptStrings = Step:extend()
EncryptStrings.Description = "Encrypt strings using randomly shuffled Base64 alphabet."
EncryptStrings.Name        = "Encrypt Strings"

function EncryptStrings:init(settings) end

function EncryptStrings:CreateEncryptionService()
    local shuffledAlphabet = shuffleString(defaultB64)
    local code = string.format([[
do
	
    local b64chars = %q
     function m(data)
        data = string.gsub(data, '[^'..b64chars..'=]', '')
        return (data:gsub('.', function(x)
            if x == '=' then return '' end
            local r,f='', (b64chars:find(x, 1, true)-1)
            for i=6,1,-1 do
                r = r .. (f%%2^i - f%%2^(i-1) > 0 and '1' or '0')
            end
            return r
        end):gsub('%%d%%d%%d?%%d?%%d?%%d?%%d?%%d?', function(x)
            if #x ~= 8 then return '' end
            local c=0
            for i=1,8 do
                c = c + (x:sub(i,i) == '1' and 2^(8-i) or 0)
            end
            return string.char(c)
        end))
    end
    function t(str)
        return m(str)
    end
end
]], shuffledAlphabet)

    local function encrypt(str)
        return base64encode(str, shuffledAlphabet)
    end

    return {
        encrypt = encrypt,
        genCode = function() return code end,
    }
end

function EncryptStrings:apply(ast, pipeline)
    local svc     = self:CreateEncryptionService()
    local code    = svc.genCode()
    local newAst  = Parser:new({ LuaVersion = Enums.LuaVersion.Lua51 }):parse(code)
    local doStat  = newAst.body.statements[1]

    local scope     = ast.body.scope
    local decryptVar= scope:addVariable()

    doStat.body.scope:setParent(ast.body.scope)
    visitast(newAst, nil, function(node, data)
        if node.kind == AstKind.FunctionDeclaration then
            if node.scope:getVariableName(node.id) == "t" then
                data.scope:removeReferenceToHigherScope(node.scope, node.id)
                data.scope:addReferenceToHigherScope(scope, decryptVar)
                node.scope = scope
                node.id    = decryptVar
            end
        end
    end)

    visitast(ast, nil, function(node, data)
        if node.kind == AstKind.StringExpression then
            data.scope:addReferenceToHigherScope(scope, decryptVar)
            local encoded = svc.encrypt(node.value)
            return Ast.FunctionCallExpression(
                Ast.VariableExpression(scope, decryptVar),
                { Ast.StringExpression(encoded) }
            )
        end
    end)

    table.insert(ast.body.statements, 1, doStat)
    table.insert(ast.body.statements, 1,
        Ast.LocalVariableDeclaration(scope, { decryptVar }, {}))

    return ast
end

return EncryptStrings