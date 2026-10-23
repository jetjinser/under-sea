;;; Neovim with the jetjinser/myrc configuration, its pinned plugin set
;;; and the blink.cmp native fuzzy matcher.

(define-module (under-sea packages myrc)
  #:use-module (gnu)
  #:use-module (gnu packages tree-sitter)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system cargo)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (under-sea packages neovim)
  #:export (neovim/myrc))

(define myrc
  (let ((commit "c17cee33d81d25d1d4c7975153b51b7d879c4271")
        (revision "0"))
    (origin
      (method git-fetch)
      (uri (git-reference
             (url "https://github.com/jetjinser/myrc")
             (commit commit)))
      (file-name (git-file-name "myrc"
                                (git-version "0.0.0" revision commit)))
      (sha256
        (base32 "13fdgnw7rg7ni81n8mqxijv6xvgrz32hvkl5b3mdgvqidq810z8w")))))


(define rust-aho-corasick-1.1.4 (crate-source "aho-corasick" "1.1.4" "00a32wb2h07im3skkikc495jvncf62jl6s96vwc7bhi70h9imlyx"))

(define rust-arrayref-0.3.9 (crate-source "arrayref" "0.3.9" "1jzyp0nvp10dmahaq9a2rnxqdd5wxgbvp8xaibps3zai8c9fi8kn"))

(define rust-arrayvec-0.7.6 (crate-source "arrayvec" "0.7.6" "0l1fz4ccgv6pm609rif37sl5nv5k6lbzi7kkppgzqzh1vwix20kw"))

(define rust-autocfg-1.5.0 (crate-source "autocfg" "1.5.0" "1s77f98id9l4af4alklmzq46f21c980v13z2r1pcxx6bqgw0d1n0"))

(define rust-bincode-2.0.1 (crate-source "bincode" "2.0.1" "0h5pxp3dqkigjwy926a03sl69n9wv7aq4142a20kw9lhn3bzbsin"))

(define rust-bincode-derive-2.0.1 (crate-source "bincode_derive" "2.0.1" "029wmh26hq3hhs1gq629y0frn2pkl7ld061rk23fji8g8jd715dz"))

(define rust-bitflags-2.11.0 (crate-source "bitflags" "2.11.0" "1bwjibwry5nfwsfm9kjg2dqx5n5nja9xymwbfl6svnn8jsz6ff44"))

(define rust-blake3-1.8.3 (crate-source "blake3" "1.8.3" "0b9ay320z90xs5hyk48l1v3208yyvdy3gs3nnlb7xyxkaxyyys14"))

(define rust-bstr-1.12.1 (crate-source "bstr" "1.12.1" "1arc1v7h5l86vd6z76z3xykjzldqd5icldn7j9d3p7z6x0d4w133"))

(define rust-cc-1.2.56 (crate-source "cc" "1.2.56" "1chvh9g2izhqad7vzy4cc7xpdljdvqpsr6x6hv1hmyqv3mlkbgxf"))

(define rust-cfg-if-1.0.4 (crate-source "cfg-if" "1.0.4" "008q28ajc546z5p2hcwdnckmg0hia7rnx52fni04bwqkzyrghc4k"))

(define rust-constant-time-eq-0.4.2 (crate-source "constant_time_eq" "0.4.2" "16zamq60dq80k3rqlzh9j9cpjhishmh924lnwbplgrnmkkvfylix"))

(define rust-cpufeatures-0.2.17 (crate-source "cpufeatures" "0.2.17" "10023dnnaghhdl70xcds12fsx2b966sxbxjq5sxs49mvxqw5ivar"))

(define rust-either-1.15.0 (crate-source "either" "1.15.0" "069p1fknsmzn9llaizh77kip0pqmcwpdsykv2x30xpjyija5gis8"))

(define rust-find-msvc-tools-0.1.9 (crate-source "find-msvc-tools" "0.1.9" "10nmi0qdskq6l7zwxw5g56xny7hb624iki1c39d907qmfh3vrbjv"))

(define rust-frizbee-0.9.0 (crate-source "frizbee" "0.9.0" "1chnc1858gwscn86zfb46l8hgwhvc77wzvgjax22a98wrq6pn7ya"))

(define rust-itertools-0.14.0 (crate-source "itertools" "0.14.0" "118j6l1vs2mx65dqhwyssbrxpawa90886m3mzafdvyip41w2q69b"))

(define rust-libc-0.2.183 (crate-source "libc" "0.2.183" "17c9gyia7rrzf9gsssvk3vq9ca2jp6rh32fsw6ciarpn5djlddmm"))

(define rust-lock-api-0.4.14 (crate-source "lock_api" "0.4.14" "0rg9mhx7vdpajfxvdjmgmlyrn20ligzqvn8ifmaz7dc79gkrjhr2"))

(define rust-memchr-2.8.0 (crate-source "memchr" "2.8.0" "0y9zzxcqxvdqg6wyag7vc3h0blhdn7hkq164bxyx2vph8zs5ijpq"))

(define rust-mlua-0.11.6 (crate-source "mlua" "0.11.6" "1avghh274kzbcz6y9rjpwzp69i82scfhcyihs5bfxrlwlk7nmlyc"))

(define rust-mlua-derive-0.11.0 (crate-source "mlua_derive" "0.11.0" "1cnfvd2pbiwj56xc0zggld7jhjqxgklm0cjl1fsv6kjca7gdsns6"))

(define rust-mlua-sys-0.10.0 (crate-source "mlua-sys" "0.10.0" "1j6zqgr8agiv21gfqflxnjr9xcx35ym91za9wbn2f0jqqxzkl70g" #:snippet (quote (begin (substitute* "Cargo.toml.orig" (("\"lua.*-src\",?") "") (("^lua.*-src.*") "")) (copy-file "Cargo.toml.orig" "Cargo.toml")))))

(define rust-num-traits-0.2.19 (crate-source "num-traits" "0.2.19" "0h984rhdkkqd4ny9cif7y2azl3xdfb7768hb9irhpsch4q3gq787"))

(define rust-parking-lot-0.12.5 (crate-source "parking_lot" "0.12.5" "06jsqh9aqmc94j2rlm8gpccilqm6bskbd67zf6ypfc0f4m9p91ck"))

(define rust-parking-lot-core-0.9.12 (crate-source "parking_lot_core" "0.9.12" "1hb4rggy70fwa1w9nb0svbyflzdc69h047482v2z3sx2hmcnh896"))

(define rust-pkg-config-0.3.32 (crate-source "pkg-config" "0.3.32" "0k4h3gnzs94sjb2ix6jyksacs52cf1fanpwsmlhjnwrdnp8dppby"))

(define rust-proc-macro2-1.0.106 (crate-source "proc-macro2" "1.0.106" "0d09nczyaj67x4ihqr5p7gxbkz38gxhk4asc0k8q23g9n85hzl4g"))

(define rust-quote-1.0.45 (crate-source "quote" "1.0.45" "095rb5rg7pbnwdp6v8w5jw93wndwyijgci1b5lw8j1h5cscn3wj1"))

(define rust-raw-cpuid-11.6.0 (crate-source "raw-cpuid" "11.6.0" "11j1lmrjqqnc43bxkrz0xai1g9piw3z9aap53qsj8cnpb7fd1329"))

(define rust-redox-syscall-0.5.18 (crate-source "redox_syscall" "0.5.18" "0b9n38zsxylql36vybw18if68yc9jczxmbyzdwyhb9sifmag4azd"))

(define rust-regex-1.12.3 (crate-source "regex" "1.12.3" "0xp2q0x7ybmpa5zlgaz00p8zswcirj9h8nry3rxxsdwi9fhm81z1"))

(define rust-regex-automata-0.4.14 (crate-source "regex-automata" "0.4.14" "13xf7hhn4qmgfh784llcp2kzrvljd13lb2b1ca0mwnf15w9d87bf"))

(define rust-regex-syntax-0.8.10 (crate-source "regex-syntax" "0.8.10" "02jx311ka0daxxc7v45ikzhcl3iydjbbb0mdrpc1xgg8v7c7v2fw"))

(define rust-rustc-hash-2.1.1 (crate-source "rustc-hash" "2.1.1" "03gz5lvd9ghcwsal022cgkq67dmimcgdjghfb5yb5d352ga06xrm"))

(define rust-rustversion-1.0.22 (crate-source "rustversion" "1.0.22" "0vfl70jhv72scd9rfqgr2n11m5i9l1acnk684m2w83w0zbqdx75k"))

(define rust-scopeguard-1.2.0 (crate-source "scopeguard" "1.2.0" "0jcz9sd47zlsgcnm1hdw0664krxwb5gczlif4qngj2aif8vky54l"))

(define rust-serde-1.0.228 (crate-source "serde" "1.0.228" "17mf4hhjxv5m90g42wmlbc61hdhlm6j9hwfkpcnd72rpgzm993ls"))

(define rust-serde-core-1.0.228 (crate-source "serde_core" "1.0.228" "1bb7id2xwx8izq50098s5j2sqrrvk31jbbrjqygyan6ask3qbls1"))

(define rust-serde-derive-1.0.228 (crate-source "serde_derive" "1.0.228" "0y8xm7fvmr2kjcd029g9fijpndh8csv5m20g4bd76w8qschg4h6m"))

(define rust-shlex-1.3.0 (crate-source "shlex" "1.3.0" "0r1y6bv26c1scpxvhg2cabimrmwgbp4p3wy6syj9n0c4s3q2znhg"))

(define rust-smallvec-1.15.1 (crate-source "smallvec" "1.15.1" "00xxdxxpgyq5vjnpljvkmy99xij5rxgh913ii1v16kzynnivgcb7"))

(define rust-syn-2.0.117 (crate-source "syn" "2.0.117" "16cv7c0wbn8amxc54n4w15kxlx5ypdmla8s0gxr2l7bv7s0bhrg6"))

(define rust-thiserror-2.0.18 (crate-source "thiserror" "2.0.18" "1i7vcmw9900bvsmay7mww04ahahab7wmr8s925xc083rpjybb222"))

(define rust-thiserror-impl-2.0.18 (crate-source "thiserror-impl" "2.0.18" "1mf1vrbbimj1g6dvhdgzjmn6q09yflz2b92zs1j9n3k7cxzyxi7b"))

(define rust-unicode-ident-1.0.24 (crate-source "unicode-ident" "1.0.24" "0xfs8y1g7syl2iykji8zk5hgfi5jw819f5zsrbaxmlzwsly33r76"))

(define rust-unty-0.0.4 (crate-source "unty" "0.0.4" "1blhyv01qiv5sb72sal3xa1l8nzck3answawxkkiw3fd2x1phjbd"))

(define rust-virtue-0.0.18 (crate-source "virtue" "0.0.18" "1cgp79pzzs117kjlc3jnnkixbyaqri12j40mx2an41qhrymv27h5"))

(define rust-windows-link-0.2.1 (crate-source "windows-link" "0.2.1" "1rag186yfr3xx7piv5rg8b6im2dwcf8zldiflvb22xbzwli5507h"))

(define %blink-cmp-fuzzy-cargo-inputs (list rust-aho-corasick-1.1.4 rust-arrayref-0.3.9 rust-arrayvec-0.7.6 rust-autocfg-1.5.0 rust-bincode-2.0.1 rust-bincode-derive-2.0.1 rust-bitflags-2.11.0 rust-blake3-1.8.3 rust-bstr-1.12.1 rust-cc-1.2.56 rust-cfg-if-1.0.4 rust-constant-time-eq-0.4.2 rust-cpufeatures-0.2.17 rust-either-1.15.0 rust-find-msvc-tools-0.1.9 rust-frizbee-0.9.0 rust-itertools-0.14.0 rust-libc-0.2.183 rust-lock-api-0.4.14 rust-memchr-2.8.0 rust-mlua-0.11.6 rust-mlua-sys-0.10.0 rust-mlua-derive-0.11.0 rust-num-traits-0.2.19 rust-parking-lot-0.12.5 rust-parking-lot-core-0.9.12 rust-pkg-config-0.3.32 rust-proc-macro2-1.0.106 rust-quote-1.0.45 rust-raw-cpuid-11.6.0 rust-redox-syscall-0.5.18 rust-regex-1.12.3 rust-regex-automata-0.4.14 rust-regex-syntax-0.8.10 rust-rustc-hash-2.1.1 rust-rustversion-1.0.22 rust-scopeguard-1.2.0 rust-serde-1.0.228 rust-serde-core-1.0.228 rust-serde-derive-1.0.228 rust-shlex-1.3.0 rust-smallvec-1.15.1 rust-syn-2.0.117 rust-thiserror-2.0.18 rust-thiserror-impl-2.0.18 rust-unicode-ident-1.0.24 rust-unty-0.0.4 rust-virtue-0.0.18 rust-windows-link-0.2.1))



(define %myrc-plugins
  (list
    (list "BQN" "mlochbaum/BQN" "850586c1ef942ac59e9c1be44f570ecfdc6c8a81" "020awywjlxk82wa3zrfkcyzn4rqfq99530zhaa96m9cs717mm2bk")
    (list "blink.cmp" "saghen/blink.cmp" "78336bc89ee5365633bcf754d93df01678b5c08f" "1nz8f8sh4q5dg0nr4jip1hx9sqn6sxim1hvvfi6pwzrldk46jl8b")
    (list "conjure" "Olical/conjure" "f66b3e7f45d325bd556cd785502761e583971920" "0vngan52wy65j6dzaw8gkv58h3b9v1aixbbk353v9zd1b5a3idv7")
    (list "flash.nvim" "folke/flash.nvim" "fcea7ff883235d9024dc41e638f164a450c14ca2" "1xm26117d95qcnx2hpi8g469awmsr8wwdg1bmvipgjkzjys78y54")
    (list "gitsigns.nvim" "lewis6991/gitsigns.nvim" "8d82c240f190fc33723d48c308ccc1ed8baad69d" "06qvrd9hnbr81w7winj53nnd36lg0bw0iqw4jwgi2bryf4h775nv")
    (list "hererocks" "luarocks/hererocks" "5d77b0bafc8b96f82355ca2ce5637c00d78a065c" "13mngvdi2pazfv2b6plm5f5x1qiivsadxvyyr7ghy94wv7cviw62")
    (list "hibiscus.nvim" "udayvir-singh/hibiscus.nvim" "573b37c2f6ed79a6b3e3c6bd18bb305a72db4dc6" "0jxznicig2fx9q4d456kizzvf21qizv8a3lvm6xpgmpan461yzvv")
    (list "image.nvim" "3rd/image.nvim" "365e2ace0f619164ae6fd2f6f1d2807775dd6849" "1238fkyqvx9l65zps066hl16fqlpvq92y7p7n93jf3q3s4zm74z0")
    (list "lazy.nvim" "folke/lazy.nvim" "306a05526ada86a7b30af95c5cc81ffba93fef97" "01kddiq6jidwm0mgpa8xzpq3v3xy0ljs3y55gkwsdh0gwxv283p4")
    (list "marks.nvim" "chentoast/marks.nvim" "f353e8c08c50f39e99a9ed474172df7eddd89b72" "1dxbqla5mjp8r1bar49zk0bsbr0lwfy5nbs4cgm69y3197crp3c6")
    (list "moonbit.nvim" "moonbit-community/moonbit.nvim" "1e935aff3e3c4209ccbcfd90c948655e29131c05" "1dxz4wyw3y05knxmn1mf74c4r5yjkcbmryd4vk1clijymkxfxckw")
    (list "neo-tree.nvim" "nvim-neo-tree/neo-tree.nvim" "84c75e7a7e443586f60508d12fc50f90d9aee14e" "0b6bbryrp7bzvarg97640mxjrdyx8pcd2cna67xsmmpwhpy6aczx")
    (list "nui.nvim" "MunifTanjim/nui.nvim" "de740991c12411b663994b2860f1a4fd0937c130" "0l1ga86dr2rhfjshiicsw3nn03wrhmdqks8v1gn3xmzdgfd2anz3")
    (list "nvim-parinfer" "gpanders/nvim-parinfer" "3968e669d9f02589aa311d33cb475b16b27c5fbb" "01di8kz2xcc2xp1ssgm3w2wc69df1y6yg3ry5m4dmx5sbrabwfc7")
    (list "nvim-treesitter" "nvim-treesitter/nvim-treesitter" "4916d6592ede8c07973490d9322f187e07dfefac" "0wgwbxi6h99fsp901xysm0424lhgrh9fq1nlck02m53qbfs7l11x")
    (list "nvim-web-devicons" "nvim-tree/nvim-web-devicons" "c72328a5494b4502947a022fe69c0c47e53b6aa6" "1aipj96h7qq8s5i3ilfd5www354c7mfnhzqbnx0jzzkwaghpjy52")
    (list "nvim-window-picker" "s1n7ax/nvim-window-picker" "6382540b2ae5de6c793d4aa2e3fe6dbb518505ec" "0zlr1plqsfqc2imzainahhg1d91pfyd2ambj4mlj8b8pjhzciav5")
    (list "oxocarbon.nvim" "nyoom-engineering/oxocarbon.nvim" "a7ba74849a00546a311f8c146320b433900393e7" "0n5i4qyraham6ryblwl5dh0rccwcaznbs91x6pmbc9cx5rqhmmrr")
    (list "plenary.nvim" "nvim-lua/plenary.nvim" "74b06c6c75e4eeb3108ec01852001636d85a932b" "1bms9ihcz2gsk88mr00izxn7sjl1lfc62mk0fy54z20g756c8iwy")
    (list "scribble.vim" "benknoble/scribble.vim" "3079d40a2399c5de5099f53d64d6a0d03bb3f908" "0hi05mcwcillpphf4dq6vffxwwvjzg7g4pjivy6cprji8zqiszvr")
    (list "tangerine.nvim" "arutonee1/tangerine.nvim" "8361df970f9e5811f9abc0bb07eb90f709ca891f" "13hh9l77fza88bc1paa37ir9dmhcvx09bhbvnz3ycf7bggd2yliw")
    (list "vim-apl" "PyGamer0/vim-apl" "beedb4c4928bba6495633f0521655866449439a3" "16w1x91hl6i0fpn4k8x6ry26kf6g28ab98xs59v5ddmlj7izbyvr")
    (list "vim-eunuch" "tpope/vim-eunuch" "e86bb794a1c10a2edac130feb0ea590a00d03f1e" "0l8zjlizraf5md9s7hxb6pr0v115hks6x5ajhhmqznf3jw47vyxy")
    (list "vim-nftables" "nfnty/vim-nftables" "26f8a506c6f3e41f1e4a8d6aa94c9a79a666bbff" "1z5ffgxdq8niggm18qikrh5hl8zs05gdij4z6dfnzy00xvancc40")
    (list "which-key.nvim" "folke/which-key.nvim" "370ec46f710e058c9c1646273e6b225acf47cbed" "0am4yw7lnibgc949qvbsi4a7hqdx6gk209l5vafv5bwcvd4irwxs")
  ))

(define-public blink-cmp-fuzzy
  (package
    (name "blink-cmp-fuzzy")
    (version "0.1.0")
    (source (lazy-plugin-origin (assoc "blink.cmp" %myrc-plugins)))
    (build-system cargo-build-system)
    (arguments
      (list
        #:tests? #f
        #:install-source? #f
        #:phases
        #~(modify-phases %standard-phases
            (add-after 'unpack 'remove-build-script
              (lambda _ (delete-file "build.rs")))
            (replace 'install
              (lambda* (#:key outputs #:allow-other-keys)
                (install-file "target/release/libblink_cmp_fuzzy.so"
                  (string-append (assoc-ref outputs "out") "/lib")))))))
    (inputs %blink-cmp-fuzzy-cargo-inputs)
    (home-page "https://github.com/Saghen/blink.cmp")
    (synopsis "Native fuzzy matcher for the blink.cmp Neovim plugin")
    (description
     "Rust cdylib providing SIMD-accelerated fuzzy matching, frecency and
sorting for the blink.cmp Neovim plugin, compiled against LuaJIT.")
    (license license:expat)))


(define-public neovim/myrc
  (neovim-lazy-package "neovim-myrc" myrc %myrc-plugins
                       #:grammars (list tree-sitter-javascript
                                        tree-sitter-json
                                        tree-sitter-nix
                                        tree-sitter-rust
                                        tree-sitter-scheme
                                        tree-sitter-typescript)
                       #:fuzzy blink-cmp-fuzzy))
