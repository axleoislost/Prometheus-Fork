return {
    Strong = {
        LuaVersion = "LuaU";
        VarNamePrefix = "",
        NameGenerator = "MangledShuffled",
        PrettyPrint = false,
        Seed = 0;
        Steps = {
            {
                Name = "Vmify",
                Settings = {}
            };
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
            };
            {
                Name = "NumbersToExpressions";
                Settings = {}
            };
            {
                Name = "Vmify",
                Settings = {}
            },
            {
                Name = "ConstantArray",
                Settings = {
                    Treshold = 1;
                    StringsOnly = true,
                    Shuffle = true,
                    Rotate = true;
                    LocalWrapperTreshold = 0
                }
            }
        }
    };
    Normal = {
        LuaVersion = "LuaU",
        VarNamePrefix = "",
        NameGenerator = "MangledShuffled",
        PrettyPrint = false,
        Seed = 0;
        Steps = {
            {
                Name = "WatermarkCheck",
                Settings = {
                    Content = "Prometheus Obfuscator"
                }
            },
            {
                Name = "EncryptStrings";
                Settings = {}
            };
            {
                Name = "AntiTamper";
                Settings = {
                    UseDebug = false
                }
            },
            {
                Name = "NumbersToExpressions";
                Settings = {}
            },
            {
                Name = "Vmify";
                Settings = {}
            },
            {
                Name = "ConstantArray";
                Settings = {
                    Treshold = 1;
                    StringsOnly = true,
                    Shuffle = true,
                    Rotate = true;
                    LocalWrapperTreshold = 0
                }
            }
        }
    }
}
