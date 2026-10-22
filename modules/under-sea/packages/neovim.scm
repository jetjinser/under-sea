;;; Generic Neovim wrapper for lazy.nvim configurations: given a config
;;; repository origin whose lazy-lock.json pins every plugin, build an
;;; editor with the Fennel/Lua sources compiled at build time and every
;;; plugin served from the store — nothing is cloned at startup.

(define-module (under-sea packages neovim)
  #:use-module (gnu)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages lua)
  #:use-module (gnu packages tree-sitter)
  #:use-module (gnu packages vim)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system trivial)
  #:use-module (ice-9 match)
  #:export (lazy-plugin-origin
            neovim-lazy-package))

(define (lazy-plugin-origin spec)
  "Return the origin for a plugin lock spec of the form
(name repo commit hash)."
  (match spec
    ((name repo commit hash)
     (origin
       (method git-fetch)
       (uri (git-reference
              (url (string-append "https://github.com/" repo))
              (commit commit)))
       (file-name (git-file-name name commit))
       (sha256 (base32 hash))))))

(define* (neovim-lazy-package name config plugins
                              #:key
                              (neovim neovim)
                              (fennel-package fennel)
                              (grammars '())
                              (fuzzy #f))
  "Return a package wrapping NEOVIM so that it loads the lazy.nvim
configuration CONFIG (an origin, typically a repository checked out at
a pinned commit).  PLUGINS is the list of lock specs — (name repo
commit hash) — matching the configuration's lazy-lock.json; each plugin
is fetched into the store and injected into lazy.nvim's setup, so no
cloning happens at startup.  The Fennel sources under config/fnl are
compiled with NEOVIM's own Fennel compiler at build time.

GRAMMARS are appended to the propagated tree-sitter grammars.  FUZZY,
when set, is a package providing libblink_cmp_fuzzy.so which is
installed as the native matcher of the blink.cmp plugin."
  (let* ((plugin-origins (map (lambda (spec)
                                (cons (car spec) (lazy-plugin-origin spec)))
                              plugins))
         (plugin-names (map car plugin-origins)))
    (package
      (name name)
      (version (package-version neovim))
      (source #f)
      (build-system trivial-build-system)
      (arguments
       (list
        #:modules '((guix build utils))
        #:builder
        #~(begin
            (use-modules (guix build utils))

            (define nvim #$(file-append neovim "/bin/nvim"))
            (define fennel-lib #$(file-append fennel-package "/share/lua/5.3"))
            (define plugin-names '#$plugin-names)
            (define config (string-append #$output "/etc/xdg/nvim"))
            (define share (string-append #$output "/share/nvim-" #$name))
            (define plugin-root (string-append share "/plugins"))
            (define compiled (string-append share "/lua"))
            (define macro-path
              (string-append plugin-root "/hibiscus.nvim/fnl/?.fnl;"
                             plugin-root "/hibiscus.nvim/fnl/?/init.fnl;"
                             plugin-root "/hibiscus.nvim/fnl/?/init-macros.fnl"))

            (setenv "HOME" (string-append (getcwd) "/build-home"))
            (mkdir-p (getenv "HOME"))
            (mkdir-p config)
            (mkdir-p plugin-root)
            (mkdir-p compiled)

            (copy-recursively #$config config)
            (delete-file (string-append config "/init.lua"))
            (for-each (lambda (f) (utime f 1 1))
                      (find-files config #:directories? #t))

            #$@(map (match-lambda
                      ((short . origin)
                       #~(copy-recursively #$origin
                                           (string-append plugin-root "/"
                                                          #$short))))
                    plugin-origins)

            #$@(if fuzzy
                   (list #~(begin
                             (define blink-dir
                               (string-append plugin-root "/blink.cmp"))
                             (mkdir-p (string-append blink-dir "/target/release"))
                             (copy-file #$(file-append fuzzy
                                                       "/lib/libblink_cmp_fuzzy.so")
                                        (string-append blink-dir
                                                       "/target/release/libblink_cmp_fuzzy.so"))))
                   '())

            (define compile-jobs
              (append
               (map (lambda (src)
                      (cons src
                            (string-append compiled "/"
                                           (basename src ".fnl") ".lua")))
                    (find-files (string-append config "/fnl") "\\.fnl$"))
               (list (cons (string-append config "/init.fnl")
                           (string-append compiled "/user-init.lua")))
               (map (lambda (src)
                      (cons src (string-append (string-drop-right src 4)
                                               ".lua")))
                    (append (if (file-exists?
                                 (string-append config "/ftplugin"))
                                (find-files (string-append config "/ftplugin")
                                            "\\.fnl$")
                                '())
                            (if (file-exists?
                                 (string-append config "/lsp"))
                                (find-files (string-append config "/lsp")
                                            "\\.fnl$")
                                '())))))

            (call-with-output-file (string-append (getcwd) "/driver.lua")
              (lambda (port)
                (format port "
package.path = ~s .. \"/?.lua;\" .. package.path
local fennel = require(\"fennel\")
fennel[\"macro-path\"] = ~s
local function slurp(p)
  local f = assert(io.open(p, \"r\"))
  local s = f:read(\"*a\")
  f:close()
  return s
end
local function spit(p, s)
  local f = assert(io.open(p, \"w\"))
  f:write(s)
  f:close()
end
local function compile(src, dst)
  local ok, out = pcall(fennel.compileString, slurp(src),
                        { filename = src, compilerEnv = _G,
                          useBitLib = true })
  if not ok then
    error(\"fennel compile failed: \" .. src .. \": \" .. tostring(out))
  end
  spit(dst, out)
end
local jobs = {
"
                        fennel-lib macro-path)
                (for-each
                 (lambda (job)
                   (format port "  { src = ~s, dst = ~s },\n"
                           (car job) (cdr job)))
                 compile-jobs)
                (format port "
}
local ok, err = pcall(function()
  for _, j in ipairs(jobs) do compile(j.src, j.dst) end
end)
if not ok then
  print(\"DRIVER-ERROR: \" .. tostring(err))
  io.stderr:write(\"DRIVER-ERROR: \" .. tostring(err) .. \"\\n\")
  vim.cmd(\"cq!\")
end
local m = assert(io.open(~s, \"w\"))
m:close()
"
                        (string-append (getcwd) "/driver-ok"))))

            (unless (zero?
                     (system* nvim "--headless" "-u" "NONE" "-i" "NONE"
                              "-c" "luafile driver.lua" "-c" "qa!"))
              (error "nvim fennel compilation failed"))
            (unless (file-exists? (string-append (getcwd) "/driver-ok"))
              (error "nvim compile driver did not complete"))

            (call-with-output-file (string-append share "/plugin-paths.lua")
              (lambda (port)
                (display "return {\n" port)
                (for-each
                 (lambda (short)
                   (format port "  [\"~a\"] = \"~a\",\n"
                           short (string-append plugin-root "/" short)))
                 plugin-names)
                (display "}\n" port)))

            (call-with-output-file (string-append config "/init.lua")
              (lambda (port)
                (format port "
local compiled = ~s
local plugin_paths = dofile(~s)
local ts_runtime = plugin_paths[\"nvim-treesitter\"]
if ts_runtime then
  vim.opt.runtimepath:prepend(ts_runtime .. \"/runtime\")
end
local lazy_dir = plugin_paths[\"lazy.nvim\"]

package.path = table.concat({
  lazy_dir .. \"/lua/?.lua\",
  lazy_dir .. \"/lua/?/init.lua\",
  compiled .. \"/?.lua\",
  compiled .. \"/?/init.lua\",
  package.path,
}, \";\")
vim.opt.runtimepath:prepend(lazy_dir)

local lazy = require(\"lazy\")
local real_setup = lazy.setup
local function lookup(name)
  return plugin_paths[name] or plugin_paths[name:match(\"([^/]+)$\")]
end
local function inject(spec)
  if type(spec) ~~ \"table\" then return spec end
  if type(spec[1]) == \"string\" and spec.dir == nil then
    local dir = lookup(spec[1])
    if dir then
      spec.dir = dir
    else
      spec.enabled = false
    end
  end
  if type(spec.dependencies) == \"table\" then
    for i, dep in ipairs(spec.dependencies) do
      if type(dep) == \"string\" then
        local dir = lookup(dep)
        if dir then
          local t = { [1] = dep }
          spec.dependencies[i] = t
          inject(t)
        end
      else
        inject(dep)
      end
    end
  end
  return spec
end
local function fix_install(opts)
  if type(opts) == \"table\" then
    opts.install = vim.tbl_extend(\"keep\", opts.install or {},
                                  { missing = false })
  end
  return opts
end
lazy.setup = function(spec, opts)
  if opts == nil and type(spec) == \"table\" and spec.spec ~~ nil then
    if type(spec.spec) == \"table\" then
      for i, entry in ipairs(spec.spec) do
        if type(entry) == \"string\" then
          local dir = lookup(entry)
          if dir then
            local t = { [1] = entry }
            spec.spec[i] = t
            inject(t)
          else
            spec.spec[i] = { [1] = entry, enabled = false }
          end
        else
          inject(entry)
        end
      end
    end
    fix_install(spec)
    return real_setup(spec)
  end
  if type(spec) == \"table\" then
    for i, entry in ipairs(spec) do
      if type(entry) == \"string\" then
        local dir = lookup(entry)
        if dir then
          local t = { [1] = entry }
          spec[i] = t
          inject(t)
        else
          spec[i] = { [1] = entry, enabled = false }
        end
      else
        inject(entry)
      end
    end
  end
  return real_setup(spec, fix_install(opts))
end

require(\"user-init\")
"
                        compiled
                        (string-append share "/plugin-paths.lua"))))

            (for-each
             (lambda (f)
               (unless (file-exists? f)
                 (error "expected compile output missing" f)))
             (map (lambda (m) (string-append compiled "/" m))
                  '("user-init.lua" "plugins.lua" "options.lua")))

            (mkdir-p (string-append #$output "/bin"))
            (call-with-output-file (string-append #$output "/bin/nvim")
              (lambda (port)
                (format port "#!~a
export XDG_CONFIG_DIRS=\"~a${XDG_CONFIG_DIRS:+:$XDG_CONFIG_DIRS}\"
exec \"~a/bin/nvim\" \"$@\"
"
                        #$(file-append bash-minimal "/bin/bash")
                        (dirname config)
                        #$neovim)
                (chmod port #o555))))))
      (inputs (append (map (match-lambda
                             ((name . origin) (list name origin)))
                           plugin-origins)
                      `(("bash" ,bash-minimal)
                        ("fennel" ,fennel-package)
                        ("neovim" ,neovim)
                        ,@(if fuzzy `(("blink-cmp-fuzzy" ,fuzzy)) '()))))
      (propagated-inputs
       (append (package-propagated-inputs neovim)
               (map (lambda (grammar)
                      (list (package-name grammar) grammar))
                    grammars)))
      (native-search-paths (package-native-search-paths neovim))
      (home-page (package-home-page neovim))
      (synopsis (string-append "Neovim with the " name " configuration"))
      (description
       "This package wraps Neovim to load a lazy.nvim configuration from
@env{XDG_CONFIG_DIRS}.  The Fennel sources are compiled with the Guix
Fennel compiler at build time and every plugin pinned in lazy-lock.json
is fetched as a Git origin into the store, so no cloning happens at
startup.")
      (license (package-license neovim)))))
