local luasnip = require("luasnip")
local s = luasnip.snippet
local t = luasnip.text_node
local i = luasnip.insert_node
-- TODO:
-- * Snippets with newline?
-- * Override existing snippets?
-- * Import already defined s, t, i, etc... from luasnip instead of defining our own?
return {
    s("all", t("allocator: std.mem.Allocator")),
    s("aall", t("allocator: *std.heap.ArenaAllocator")),
    s("fri", {t("for (0.."), i(1, "", {}), t(") |"), i(2, "i", {}), t("| {"), i(3, "", {}), t("}")})
}
