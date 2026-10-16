;;; lazy-lock-import.scm --- Import the plugin pins of a lazy.nvim Neovim
;;; configuration as Guix origin definitions.
;;;
;;; Usage:
;;;   guix repl -- scripts/lazy-lock-import.scm [OPTIONS] REPOSITORY
;;;
;;; REPOSITORY  Git URL of a Neovim configuration repository whose root holds
;;;             lazy-lock.json.  Its Fennel (.fnl) and Lua (.lua) specs name
;;;             plugins as owner/repo (bare or as a full URL) unless --ir
;;;             supplies the repositories instead.
;;;
;;; Options:
;;;   --commit=REV   pin the configuration at REV instead of the tip of its
;;;                  default branch
;;;   --name=NAME    base name for the emitted definitions (default: the
;;;                  repository base name without .git)
;;;   --ir=FILE      read lazy.nvim's resolved spec, as scripts/lazy-ir-dump.lua
;;;                  writes it, instead of scanning the configuration sources.
;;;                  This is exact: it yields each plugin's real repository and
;;;                  honours the plugins lazy disabled.
;;;   --plugin-base=URL
;;;                  forge base URL used to fetch plugins (default:
;;;                  https://github.com); a plugin spec `owner/repo' is
;;;                  fetched as URL/owner/repo.  Emitted entries keep the
;;;                  bare `owner/repo', so a non-default base is only useful
;;;                  with a consumer that prefixes the same URL.
;;;   --output=FILE  write the definitions to FILE instead of stdout
;;;   -h, --help     display this help
;;;
;;; lazy-lock.json maps each plugin *name* to its revision, but not to the
;;; forge repository the name comes from.  That repository is recovered either
;;; from lazy.nvim's own resolved spec (--ir) or, as a fallback that needs no
;;; Neovim, by scanning the configuration's specs for the owner/repo each name
;;; refers to.  The two inputs are then combined into:
;;;
;;;   (define NAME (origin ...))         the configuration repository itself
;;;   (define %NAME-plugins (list ...))  one (SHORT REPO COMMIT HASH) entry per
;;;                                      locked plugin, HASH being the nar hash
;;;                                      of the checkout, i.e. the sha256 of a
;;;                                      git-fetch origin.
;;;
;;; Both are ready to paste into a Guix configuration (or into a *-lock.scm
;;; module).  Three cases are reported on stderr and left out: plugins a spec
;;; references that lazy-lock.json does not pin, lock entries no repository is
;;; known for (plugins lazy.nvim installed as another plugin's dependency,
;;; whose repository the configuration never names), and -- with --ir --
;;; plugins lazy.nvim disabled.
;;;
;;; This is the maintained version of the lazy.nvim importer carried by the
;;; navier configuration bundle; it is generic over the configuration
;;; repository and the plugin forge.

(use-modules (guix store)
             (guix git)
             (guix base32)
             (guix build utils)
             (git)
             (ice-9 textual-ports)
             (ice-9 regex)
             (ice-9 match)
             (ice-9 hash-table)
             (json)
             (srfi srfi-1)
             (srfi srfi-37))

(define %prog "lazy-lock-import.scm")

(define %url-rx
  ;; https://HOST/owner/repo -- capture the owner/repo after the forge host.
  (make-regexp "https?://[^/[:space:]]+/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)"))

(define %repo-token-rx
  ;; A bare owner/repo token.
  (make-regexp "[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+"))

(define (slurp file)
  (call-with-input-file file get-string-all))

(define (strip-comments text)
  "Drop Fennel (`;') and Lua (`--') comments from TEXT, line by line."
  (string-join
   (map (lambda (line)
          (let* ((semi (string-index line #\;))
                 (dash (string-contains line "--"))
                 (cut  (cond ((and semi dash) (min semi dash))
                             ((integer? semi) semi)
                             ((integer? dash) dash)
                             (else (string-length line)))))
            (string-take line cut)))
        (string-split text #\newline))
   "\n"))

(define (all-matches rx text)
  "Return every match of RX in TEXT, in order."
  (let loop ((pos 0) (acc '()))
    (let ((m (regexp-exec rx text pos)))
      (if m (loop (match:end m) (cons m acc)) (reverse acc)))))

(define (line-tokens line)
  "Return the owner/repo tokens on LINE.  A plugin may be written bare or as
a URL; URLs are collected first and masked so that their forge host is never
mistaken for an owner."
  (let* ((urls (all-matches %url-rx line))
         (masked (regexp-substitute/global #f %url-rx line 'pre " " 'post)))
    (append (map (lambda (m) (match:substring m 1)) urls)
            (map (lambda (m) (match:substring m))
                 (all-matches %repo-token-rx masked)))))

(define (spec-repositories directory)
  "Return the sorted set of owner/repo tokens referenced by the .fnl and
.lua files under DIRECTORY (comments stripped)."
  (sort
   (delete-duplicates
    (append-map
     (lambda (file)
       (append-map line-tokens
                   (string-split (strip-comments (slurp file)) #\newline)))
     (find-files directory
                 (lambda (file stat)
                   (and (eq? 'regular (stat:type stat))
                        (or (string-suffix? ".fnl" file)
                            (string-suffix? ".lua" file)))))))
   string-ci<?))

(define (split-url url)
  "Split URL into (HOST . PATH), dropping a trailing `.git', query or
fragment.  A URL without a path yields an empty PATH.  Return #f when URL has
no scheme://host shape."
  (let ((scheme (string-contains url "://")))
    (and scheme
         (let* ((rest (substring url (+ scheme 3)))
                (slash (string-index rest #\/)))
           (and (not (string-null? rest))
                (if slash
                    (let* ((host (substring rest 0 slash))
                           (path (substring rest (1+ slash)))
                           (clean (car (string-split (car (string-split path #\?)) #\#))))
                      (and (not (string-null? host))
                           (not (string-null? clean))
                           (cons host
                                 (if (string-suffix? ".git" clean)
                                     (string-drop-right clean 4)
                                     clean))))
                     (cons rest "")))))))

(define (ir-plugin-entries document)
  "Return the plugin entries of the IR DOCUMENT, the JSON document
scripts/lazy-ir-dump.lua writes, as alists."
  (define plugins (assoc-ref document "plugins"))
  (cond ((vector? plugins) (vector->list plugins))
        ((list? plugins) plugins)
        (else '())))

(define (ir-disabled document)
  "Return the list of plugin names DOCUMENT records as disabled."
  (define disabled (assoc-ref document "disabled"))
  (cond ((vector? disabled) (sort (vector->list disabled) string-ci<?))
        ((list? disabled) (sort disabled string-ci<?))
        (else '())))

(define (ir-repositories document base)
  "Return the sorted set of owner/repo paths in the IR DOCUMENT.  Plugins
lazy disabled are absent from it.  Warn once about plugins whose forge is not
BASE's, since emitted entries keep only the owner/repo and BASE says where
they are fetched from."
  (define base-host (match (split-url base) ((host . _) host) (_ #f)))
  (define foreign '())
  (define (plugin-path plugin)
    (match (assoc-ref plugin "url")
      ((? string? url)
       (match (split-url url)
         ((host . path)
          (unless (and base-host (string=? host base-host))
            (set! foreign (cons host foreign)))
          path)
         (_ (format (current-error-port)
                    "~a: ignoring plugin ~a: not a fetchable URL: ~a~%"
                    %prog (assoc-ref plugin "name") url)
            #f)))
      (_ #f)))
  (let* ((paths (sort (delete-duplicates
                       (filter-map plugin-path (ir-plugin-entries document)))
                      string-ci<?))
         (hosts (sort (delete-duplicates foreign) string-ci<?)))
    (unless (null? hosts)
      (format (current-error-port)
              "~a: warning: plugins hosted on ~a will be fetched from ~a~%"
              %prog (string-join hosts ", ") base))
    paths))

(define (lockfile-commits lockfile)
  "Parse LAZY-LOCK.JSON and return an alist of (PLUGIN . COMMIT).  The file
maps each plugin name to its lock metadata; only the commit is kept.  Both the
alist and the hash-table representations guile-json may return are accepted."
  (define parsed (json-string->scm (slurp lockfile)))
  (define entries
    (cond ((hash-table? parsed) (hash-map->list cons parsed))
          ((list? parsed) parsed)
          (else '())))
  (sort (filter-map (match-lambda
                      (((? string? name) . fields)
                       (match (assoc-ref fields "commit")
                         ((? string? commit) (cons name commit))
                         (_ #f)))
                      (_ #f))
                    entries)
        (lambda (a b) (string-ci<? (car a) (car b)))))

(define (nar-hash store directory)
  "Return the nar hash of the store item DIRECTORY in nix-base32, i.e. the
hash `guix hash -rx DIRECTORY' would report."
  (bytevector->nix-base32-string (query-path-hash store directory)))

(define (checkout store url commit)
  "Check URL out into the store at COMMIT, or at the tip of its default
branch when COMMIT is #f, and return (values DIRECTORY COMMIT)."
  (call-with-values
      (lambda ()
        (latest-repository-commit store url
                                  ;; The empty ref means the default branch;
                                  ;; guix resolves it to refs/remotes/origin/HEAD.
                                  #:ref (if commit (cons 'commit commit) '())))
    (lambda (directory resolved) (values directory resolved))))

(define (plugin-entry store base repo commit)
  "Check REPO (owner/repo) out at COMMIT from BASE and return its
(SHORT REPO COMMIT HASH) entry."
  (let ((url (string-append (string-trim-right base #\/) "/" repo)))
    (call-with-values (lambda () (checkout store url commit))
      (lambda (directory resolved)
        (list (basename repo) repo resolved (nar-hash store directory))))))

(define (emit port repository commit name config-hash plugins)
  "Write the Guix definitions for the configuration and its plugins to PORT."
  (format port "
;; Generated by ~a from ~a
;; (configuration commit ~a).

(define ~a
  (let ((commit ~s)
        (revision \"0\"))
    (origin
      (method git-fetch)
      (uri (git-reference
            (url ~s)
            (commit commit)))
      (file-name (git-file-name ~s
                                (git-version \"0.0.0\" revision commit)))
      (sha256
       (base32 ~s)))))

(define %~a-plugins
  (list
"
          %prog repository commit
          name commit repository name config-hash name)
  (for-each (match-lambda
              ((short repo commit hash)
               (format port "   (list ~s ~s ~s\n         ~s)\n"
                       short repo commit hash)))
            plugins)
  (format port "  ))\n"))

(define (usage port)
  (format port "usage: guix repl -- ~a [OPTIONS] REPOSITORY

  --commit=REV   pin the configuration at REV
  --name=NAME    base name for the definitions (default: repository name)
  --ir=FILE      read lazy.nvim's resolved spec (scripts/lazy-ir-dump.lua)
                 instead of scanning the configuration sources
  --plugin-base=URL
                 forge base URL for plugin sources (default: https://github.com)
  --output=FILE  write to FILE instead of stdout
  -h, --help     display this help
" %prog))

(define (run args)
  (let ((repository #f) (commit #f) (name #f) (ir #f)
        (base "https://github.com") (output #f))
    (define options
      (list (option '(#\h "help") #f #f
                    (lambda _ (usage (current-output-port)) (exit 0)))
            (option '("commit") #t #f
                    (lambda (opt opt-name arg seed) (set! commit arg) seed))
            (option '("name") #t #f
                    (lambda (opt opt-name arg seed) (set! name arg) seed))
            (option '("ir") #t #f
                    (lambda (opt opt-name arg seed) (set! ir arg) seed))
            (option '("plugin-base") #t #f
                    (lambda (opt opt-name arg seed) (set! base arg) seed))
            (option '("output") #t #f
                    (lambda (opt opt-name arg seed) (set! output arg) seed))))
    (args-fold args options
               (lambda (opt opt-name arg seed)
                 (format (current-error-port) "~a: unrecognized option `~a'~%"
                         %prog opt-name)
                 (usage (current-error-port))
                 (exit 1))
               (lambda (arg seed)
                 (if repository
                     (begin (format (current-error-port)
                                    "~a: unexpected argument `~a'~%"
                                    %prog arg)
                            (usage (current-error-port))
                            (exit 1))
                     (set! repository arg))
                 seed)
               #t)
    (unless repository
      (usage (current-error-port))
      (exit 1))
    (when (and ir (not (file-exists? ir)))
      (format (current-error-port) "~a: no such IR file: ~a~%" %prog ir)
      (exit 1))
    (let ((name (or name (basename repository ".git"))))
      (with-store store
        ;; The configuration is checked out once; the store already has the
        ;; revision, so its plugin lock and its own hash come for free.
        (call-with-values (lambda () (checkout store repository commit))
          (lambda (directory resolved)
            (let* ((lockfile (string-append directory "/lazy-lock.json"))
                   (lock (if (file-exists? lockfile)
                             (lockfile-commits lockfile)
                             (begin
                               (format (current-error-port)
                                       "~a: ~a has no lazy-lock.json~%"
                                       %prog repository)
                               (exit 1))))
                   ;; With --ir the repositories come from lazy.nvim's own
                   ;; resolved spec instead of being recovered from the
                   ;; configuration sources.
                   (ir-doc (and ir (json-string->scm (slurp ir))))
                   (specs (if ir-doc
                              (ir-repositories ir-doc base)
                              (spec-repositories directory)))
                   (locked (filter (lambda (repo) (assoc-ref lock (basename repo)))
                                   specs))
                   (unlocked (filter (lambda (repo)
                                       (not (assoc-ref lock (basename repo))))
                                     specs))
                   (disabled (if ir-doc
                                 (filter (lambda (name) (assoc-ref lock name))
                                         (ir-disabled ir-doc))
                                 '()))
                   ;; Lock entries no repository is known for: a plugin
                   ;; lazy.nvim installed as another plugin's dependency, or one
                   ;; the IR disabled (reported separately above).
                   (unresolved (filter (lambda (name)
                                         (and (not (member name disabled))
                                              (not (any (lambda (repo)
                                                          (string=? (basename repo)
                                                                    name))
                                                        specs))))
                                        (map car lock)))
                   (plugins (filter-map
                             (lambda (repo)
                               (let* ((sha (assoc-ref lock (basename repo)))
                                      (fail (lambda (reason)
                                              (format (current-error-port)
                                                      "~a: warning: could not \
fetch ~a at ~a~a (omitted)~%"
                                                      %prog repo sha reason)
                                              #f)))
                                 (catch #t
                                   (lambda ()
                                     (plugin-entry store base repo sha))
                                   (lambda (key . args)
                                     (match args
                                       (((? git-error? error) . _)
                                        (fail (string-append ": "
                                              (git-error-message error))))
                                       (_ (fail "")))))))
                             locked)))
              (unless (null? unlocked)
                (format (current-error-port)
                        "~a: warning: specs reference plugins not pinned in \
lazy-lock.json: ~a~%"
                        %prog (string-join unlocked ", ")))
              (unless (null? disabled)
                (format (current-error-port)
                        "~a: warning: plugins lazy.nvim disabled (omitted): ~a~%"
                        %prog (string-join disabled ", ")))
              (unless (null? unresolved)
                (format (current-error-port)
                        "~a: warning: lock entries with no known repository \
(omitted): ~a~%"
                        %prog (string-join unresolved ", ")))
              (if output
                  ;; Write atomically: lockers in this repository replace
                  ;; their output in one rename.
                  (let* ((temporary (string-append output ".tmp"))
                         (port (open-output-file temporary)))
                    (emit port repository resolved name
                          (nar-hash store directory) plugins)
                    (close-port port)
                    (rename-file temporary output)
                    (format (current-error-port) "~a: wrote ~a~%" %prog output))
                  (emit (current-output-port) repository resolved name
                        (nar-hash store directory) plugins)))))))))

(run (cdr (command-line)))
