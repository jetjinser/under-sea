;;; Geographic rule data generated from fixed upstream source inputs.
(define-module (under-sea packages dae-data)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages python)
  #:use-module (under-sea packages geosite-lock)
  #:use-module (under-sea packages geoip-lock))

(define %dbip-country-csv
  (origin
    (method url-fetch)
    (uri "https://download.db-ip.com/free/dbip-country-lite-2026-10.csv.gz")
    (sha256 (base16-string->bytevector
             "097426b8ddae89157d444a59ac1847e873f7943c32d52becc4371c8b0273af80"))))

(define-public dae-geoip
  (package
    (name "dae-geoip")
    (version "2026.10-fd96fba")
    (source %geoip-source)
    (build-system gnu-build-system)
    (native-inputs (list go-1.26 python-minimal))
    (arguments
     (list #:substitutable? #f
           #:modules '((guix build gnu-build-system) (guix build utils) (ice-9 match))
           #:phases
           #~(modify-phases %standard-phases
               (delete 'bootstrap)
               (delete 'configure)
               (delete 'check)
               (add-before 'build 'prepare-offline-sources
                 (lambda _
                   (let ((proxy (string-append (getcwd) "/module-proxy")))
                     (for-each
                      (match-lambda
                        ((relative source)
                         (let ((target (string-append proxy "/" relative)))
                           (mkdir-p (dirname target))
                           (copy-file source target))))
                      '#$%geoip-module-files)
                     (setenv "GOPROXY" (string-append "file://" proxy)))
                   (setenv "GOSUMDB" "off")
                   (setenv "GOTOOLCHAIN" "local")
                   (setenv "GOENV" "off")
                   (setenv "GOWORK" "off")
                   (setenv "CGO_ENABLED" "0")
                   (setenv "GOPATH" (string-append (getcwd) "/gopath"))
                   (setenv "GOMODCACHE" (string-append (getcwd) "/modules"))
                   (setenv "GOCACHE" (string-append (getcwd) "/go-cache"))
                   (invoke "python3" #$(local-file "../../scripts/prepare-dae-dbip.py")
                           #$%dbip-country-csv "dbip-cidr")
                   (call-with-output-file "guix-config.json"
                     (lambda (port)
                       (display "{\"input\":[{\"type\":\"text\",\"action\":\"add\",\"args\":{\"inputDir\":\"./dbip-cidr\"}},{\"type\":\"private\",\"action\":\"add\"},{\"type\":\"test\",\"action\":\"add\"}],\"output\":[{\"type\":\"v2rayGeoIPDat\",\"action\":\"output\",\"args\":{\"outputDir\":\"./generated-data\",\"outputName\":\"geoip.dat\"}}]}" port)))))
               (replace 'build
                 (lambda _
                   (invoke "go" "build" "-mod=readonly" "-buildvcs=false" "-trimpath"
                           (string-append "-p=" (number->string (parallel-job-count)))
                           "-o" "geoip-generator" ".")
                   (invoke "./geoip-generator" "-c" "guix-config.json")))
               (replace 'install
                 (lambda _
                   (unless (> (stat:size (stat "generated-data/geoip.dat")) 0)
                     (error "Empty generated GeoIP data"))
                   (install-file "generated-data/geoip.dat"
                                 (string-append #$output "/share/dae"))
                   (install-file "geoip-generator" (string-append #$output "/bin"))
                   (let ((doc (string-append #$output "/share/doc/dae-geoip")))
                     (install-file "LICENSE" doc)
                     (install-file "dbip-cidr.inventory.json" doc)
                     (call-with-output-file (string-append doc "/DB-IP-ATTRIBUTION")
                       (lambda (port)
                         (display "IP Geolocation by DB-IP (https://db-ip.com)\nSource: https://db-ip.com/db/download/ip-to-country-lite\nCSV release: 2026-10\nData license: https://creativecommons.org/licenses/by/4.0/\nChanges: address ranges converted to CIDR text and v2ray GeoIP protobuf.\n" port)))))))))
    (home-page "https://github.com/v2fly/geoip")
    (synopsis "GeoIP routing data generated from DB-IP address range sources")
    (description "This package compiles the official GeoIP generator and
generates geoip.dat from fixed DB-IP CSV address ranges, including upstream
private and test ranges.  The CSV conversion preserves each address range.
Data attribution and conversion inventory are installed with the package.")
    (license (list license:cc-by-sa4.0 license:cc-by4.0))))

(define-public dae-geosite
  (package
    (name "dae-geosite")
    (version "2026.10.04-6377733")
    (source %geosite-source)
    (build-system gnu-build-system)
    (native-inputs (list go-1.25))
    (arguments
     (list #:substitutable? #f
           #:modules '((guix build gnu-build-system) (guix build utils) (ice-9 match))
           #:phases
           #~(modify-phases %standard-phases
               (delete 'bootstrap)
               (delete 'configure)
               (delete 'check)
               (add-before 'build 'prepare-offline-go
                 (lambda _
                   (let ((proxy (string-append (getcwd) "/module-proxy")))
                     (for-each
                      (match-lambda
                        ((relative source)
                         (let ((target (string-append proxy "/" relative)))
                           (mkdir-p (dirname target))
                           (copy-file source target))))
                      '#$%geosite-module-files)
                     (setenv "GOPROXY" (string-append "file://" proxy)))
                   (setenv "GOSUMDB" "off")
                   (setenv "GOTOOLCHAIN" "local")
                   (setenv "GOENV" "off")
                   (setenv "GOWORK" "off")
                   (setenv "CGO_ENABLED" "0")
                   (setenv "GOPATH" (string-append (getcwd) "/gopath"))
                   (setenv "GOMODCACHE" (string-append (getcwd) "/modules"))
                   (setenv "GOCACHE" (string-append (getcwd) "/go-cache"))))
               (replace 'build
                 (lambda _
                   (invoke "go" "build" "-mod=readonly" "-buildvcs=false" "-trimpath"
                           (string-append "-p=" (number->string (parallel-job-count)))
                           "-o" "geosite-generator" ".")
                   (mkdir "generated-data")
                   (invoke "./geosite-generator" "-datapath=./data"
                           "-outputdir=./generated-data" "-outputname=geosite.dat")))
               (replace 'install
                 (lambda _
                   (unless (> (stat:size (stat "generated-data/geosite.dat")) 0)
                     (error "Empty generated geosite data"))
                   (install-file "generated-data/geosite.dat"
                                 (string-append #$output "/share/dae"))
                   (install-file "geosite-generator" (string-append #$output "/bin"))
                   (install-file "LICENSE" (string-append #$output "/share/doc/dae-geosite")))))))
    (home-page "https://github.com/v2fly/domain-list-community")
    (synopsis "Source-generated domain routing data for dae")
    (description "This package compiles the official domain-list-community
generator and generates geosite.dat from its fixed domain rule sources.  The
build uses an offline Go proxy with hash-pinned module sources.  Geographic IP
data is supplied separately; no service is started by this package.")
    (license license:expat)))

(define-public dae-geodata
  (package
    (name "dae-geodata")
    (version "2026.10")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list #:modules '((guix build utils))
           #:builder
           #~(begin
               (use-modules (guix build utils))
               (let ((assets (string-append #$output "/share/dae"))
                     (doc (string-append #$output "/share/doc/dae-geodata")))
                 (mkdir-p assets)
                 (mkdir-p doc)
                 (for-each
                  (lambda (entry)
                    (unless (> (stat:size (stat (cdr entry))) 0)
                      (error "Empty dae geographic data" (car entry)))
                    (symlink (cdr entry) (string-append assets "/" (car entry))))
                  (list
                   (cons "geoip.dat" #$(file-append dae-geoip "/share/dae/geoip.dat"))
                   (cons "geosite.dat" #$(file-append dae-geosite "/share/dae/geosite.dat"))))
                 (symlink #$(file-append dae-geoip "/share/doc/dae-geoip")
                          (string-append doc "/geoip"))
                 (symlink #$(file-append dae-geosite "/share/doc/dae-geosite")
                          (string-append doc "/geosite"))))))
    (home-page "https://github.com/daeuniverse/dae")
    (synopsis "Combined source-generated geographic routing data for dae")
    (description "This package collects source-generated geoip.dat and
geosite.dat in one share/dae directory suitable for DAE_LOCATION_ASSET.  It
retains references to data attribution and licenses.  Updates require new
fixed source inputs and a rebuild, rather than replacing store data in place.")
    (license (list license:expat license:cc-by-sa4.0 license:cc-by4.0))))
