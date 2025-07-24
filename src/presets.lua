--[[
    This Script is Part of the Prometheus Obfuscator by Levno_710
    ---------------------------------------------------------------
    File: pipeline.lua

    This script provides configuration presets for the obfuscation process.
--]]

return {
    ["Strong"] = { -- VERY strong obfuscation preset

        -- Target Lua version
        LuaVersion = "LuaU",

        -- Variable name prefix (none for minified)
        VarNamePrefix = "",

        -- Variable name generator (obfuscated names like IlI1lI1l)
        NameGenerator = "MangledShuffled",

        -- Disable pretty printing for compact output
        PrettyPrint = false,

        -- Seed is generated based on current time (0 = random)
        Seed = 0,

        -- Obfuscation steps
        Steps = {
            {
                Name = "Vmify",
                Settings = {}
            },
            {
                Name = "WatermarkCheck",
                Settings = {
                    Content = "Prometheus Obfuscator"
                }
            },
            {
                Name = "EncryptStrings",
                Settings = {}
            },
            {
                Name = "AntiTamper",
                Settings = {
                    UseDebug = false
                }
            },
            {
                Name = "NumbersToExpressions",
                Settings = {}
            },
            {
                Name = "Vmify",
                Settings = {}
            },
            {
                Name = "ConstantArray",
                Settings = {
                    Treshold               = 1,
                    StringsOnly           = true,
                    Shuffle               = true,
                    Rotate                = true,
                    LocalWrapperTreshold  = 0
                }
            }
        }
    },

    ["Normal"] = { -- Normal obfuscation preset

        LuaVersion = "LuaU",
        VarNamePrefix = "",
        NameGenerator = "MangledShuffled",
        PrettyPrint = false,
        Seed = 0,

        Steps = {
            {
                Name = "WatermarkCheck",
                Settings = {
                    Content = "Prometheus Obfuscator"
                }
            },
            {
                Name = "EncryptStrings",
                Settings = {}
            },
            {
                Name = "AntiTamper",
                Settings = {
                    UseDebug = false
                }
            },
            {
                Name = "NumbersToExpressions",
                Settings = {}
            },
            {
                Name = "Vmify",
                Settings = {}
            },
            {
                Name = "ConstantArray",
                Settings = {
                    Treshold               = 1,
                    StringsOnly           = true,
                    Shuffle               = true,
                    Rotate                = true,
                    LocalWrapperTreshold  = 0
                }
            }
        }
    }
}
