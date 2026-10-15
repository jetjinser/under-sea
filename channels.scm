(list (channel
       (name 'guix)
       (url "https://mirror.nju.edu.cn/git/guix.git/")
       (branch "master")
       (commit "d434a41bf79b822bf186e457ec98893acdde78f2")
       (introduction
        (make-channel-introduction
         "9edb3f66fd807b096b48283debdcddccfea34bad"
         (openpgp-fingerprint
          "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))
       (channel
        (name 'nonguix)
        (url "https://gitlab.com/nonguix/nonguix")
        (branch "master")
        (commit "cf5e3b8f9f6a2bc8cfc2039cb5153d625a08da6b")
        (introduction
         (make-channel-introduction
          "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
          (openpgp-fingerprint
           "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))
       (channel
        (name 'guix-hpc)
        (url "https://gitlab.inria.fr/guix-hpc/guix-hpc.git")
        (branch "master")
        (commit "ea7b563768a6d8b264530e9c295bd23bf5086449"))
       (channel
        (name 'guix-science)
        (url "https://codeberg.org/guix-science/guix-science.git")
        (branch "master")
        (commit "ca82743140f7de92a2dcfe2425eb844e7d0e986f")
        (introduction
         (make-channel-introduction
          "b1fe5aaff3ab48e798a4cce02f0212bc91f423dc"
          (openpgp-fingerprint
           "CA4F 8CF4 37D7 478F DA05  5FD4 4213 7701 1A37 8446"))))
       (channel
        (name 'guix-past)
        (url "https://codeberg.org/guix-science/guix-past.git")
        (branch "master")
        (commit "1ef1e5172f2631ee21cfc59656a64be3b5f0f8b3")
        (introduction
         (make-channel-introduction
          "0c119db2ea86a389769f4d2b9c6f5c41c027e336"
          (openpgp-fingerprint
           "3CE4 6455 8A84 FDC6 9DB4  0CFB 090B 1199 3D9A EBB5"))))
       (channel
        (name 'guix-science-nonfree)
        (url "https://codeberg.org/guix-science/guix-science-nonfree.git")
        (branch "master")
        (commit "b9cc745a1d756cf94de355a12d5742c71230fe7d")
        (introduction
         (make-channel-introduction
          "58661b110325fd5d9b40e6f0177cc486a615817e"
          (openpgp-fingerprint
           "CA4F 8CF4 37D7 478F DA05  5FD4 4213 7701 1A37 8446"))))
       (channel
        (name 'guix-hpc-non-free)
        (url "https://gitlab.inria.fr/guix-hpc/guix-hpc-non-free.git")
        (branch "master")
        (commit "ff0bba215fde2d4f8d71264dab77cb4fe9806443")))
