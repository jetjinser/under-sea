-- lazy-ir-dump.lua --- Print the resolved lazy.nvim spec as JSON.
--
-- lazy.nvim keeps the merged specification in memory
-- (require("lazy.core.config").plugins), but only ever writes lazy-lock.json
-- to disk, which records plugin *names* and revisions and no repository.  This
-- script prints that in-memory IR as a JSON document for
-- scripts/lazy-lock-import.scm --ir=FILE, which then has a real repository for
-- every plugin instead of recovering it from the configuration sources.
--
-- Run it in a session where the configuration has already called
-- require("lazy").setup().  Point nvim at the configuration through a private
-- XDG_CONFIG_HOME (with <dir>/nvim a symlink to it) rather than with -u: only
-- in that layout does nvim put the configuration directory on 'runtimepath',
-- which Fennel setups need before their init.fnl is sourced:
--
--   XDG_CONFIG_HOME=<dir> nvim --headless \
--     -c 'luafile <repo>/scripts/lazy-ir-dump.lua' -c 'qa!'
--
-- For a configuration whose plugins are not installed, import its spec
-- directly and keep lazy from cloning anything:
--
--   nvim --headless --clean --cmd "set rtp+=<lazy.nvim>" \
--     -c 'lua require("lazy").setup({ spec = { import = "plugins" }, install = { missing = false }, checker = { enabled = false } })' \
--     -c 'luafile <repo>/scripts/lazy-ir-dump.lua' -c 'qa!'
--
-- A configuration that bootstraps lazy.nvim (and spec macros such as
-- tangerine/hibiscus) by cloning them at startup needs those on
-- 'runtimepath' first; a configuration whose plugins are missing will try to
-- install them unless its own setup sets install.missing = false (in a
-- headless dump that installer can be neutralised instead:
--   --cmd "lua require('lazy.core.loader').install_missing = function() end").
--
-- Output: {"plugins": [{"name", "url", "branch", "enabled", "dependencies"}],
--          "disabled": ["name", ...]}
-- `disabled` lists the plugins lazy disabled, which are absent from `plugins`.

local function fail(message)
  io.stderr:write("lazy-ir-dump: ", message, "\n")
  vim.cmd("cquit!")
end

local ok, Config = pcall(require, "lazy.core.config")
if not ok then
  fail("lazy.nvim is not on 'runtimepath' in this session: " .. tostring(Config))
end

if vim.tbl_isempty(Config.plugins or {}) then
  fail("lazy.nvim is not set up in this session (run it after require(\"lazy\").setup())")
end

local plugins = {}
for name, plugin in pairs(Config.plugins) do
  plugins[#plugins + 1] = {
    name = name,
    url = plugin.url,
    branch = plugin.branch,
    enabled = plugin.enabled ~= false,
    dependencies = plugin.dependencies or plugin.dep or {},
  }
end
table.sort(plugins, function(a, b)
  return a.name < b.name
end)

local disabled = {}
for name in pairs((Config.spec and Config.spec.disabled) or {}) do
  disabled[#disabled + 1] = name
end
table.sort(disabled)

io.write(vim.json.encode({ plugins = plugins, disabled = disabled }), "\n")
