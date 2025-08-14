local luasnip = require("luasnip")
local s = luasnip.snippet
local t = luasnip.text_node
return {s("all", t("allocator: std.mem.Allocator"))}
