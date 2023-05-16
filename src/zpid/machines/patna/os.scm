(define-module (zpid machines patna os)
 #:use-module (gnu)
 #:use-module (gnu services linux)
 #:use-module (zpid services collectd)
 #:use-module (zpid services stats)
 #:use-module (zpid machines patna nginx)
 #:use-module (zpid machines patna ci)
 #:use-module (zpid machines patna cron)
 #:use-module (zpid machines patna certbot)
 #:use-module (nongnu packages linux)
 #:use-module (nongnu system linux-initrd))

(use-service-modules ssh networking virtualization mcron admin)
(use-package-modules bootloaders certs ssh)

(define-public patna-os
 (operating-system
  (host-name "patna.psychnotebook.org")
  (timezone "Europe/Berlin")
  (locale "en_US.utf8")

  ;; Use non-free kernel for r8169 network driver
  (kernel linux)
  (initrd microcode-initrd)
  (firmware (list linux-firmware))

  (bootloader (bootloader-configuration
                (bootloader grub-bootloader)
                (targets '("/dev/disk/by-id/nvme-SAMSUNG_MZQLB1T9HAJR-00007_S439NA0NA01459"))))

  (file-systems (append
                  (list
                   ;; Use the first disk for the system.
                   (file-system
                          (device (uuid "f8bc357d-a7f4-4cf8-9b82-1d87a00757b2"))
                          (mount-point "/")
                          (type "ext4"))
                   ;; And the second one to store baked nars. This way we can
                   ;; balance disk usage well and either is easily recoverable,
                   ;; so no RAID.
                   (file-system
                          (device (uuid "4409eee4-6580-4fe9-9b74-253ac53c668b"))
                          (mount-point "/var/cache/guix")
                          (type "ext4")))
                  %base-file-systems))

  (users (append (list (user-account
                         (name "ldb")
                         (comment "")
                         (group "users")
                         (password (crypt "changeme" "$6$abc"))
                         (supplementary-groups '("wheel" "netdev" "audio" "video")))
                       (user-account
                         (name "jb")
                         (comment "")
                         (group "users")
                         (password (crypt "changeme" "$6$abc"))
                         (supplementary-groups '("wheel" "netdev" "audio" "video")))
                       (user-account
                         (name "mko")
                         (comment "")
                         (group "users")
                         (password (crypt "changeme" "$6$abc"))
                         (supplementary-groups '("wheel" "netdev" "audio" "video"))))
                 %base-user-accounts))

  (packages (append (list
                      ;; for HTTPS access
                      nss-certs)
                    %base-packages))

  (services (append (list 
                      (service openssh-service-type
                               (openssh-configuration
                                 (permit-root-login #f)
                                 (password-authentication? #f)
                                 (port-number 2222)
                                 (authorized-keys
                                   `(("ldb" ,(local-file "../../../keys/ldb.pub"))
                                     ("mko" ,(local-file "../../../keys/mko.pub"))
                                     ("jb" ,(local-file "../../../keys/jb.pub"))))))
                      (service guix-publish-service-type
                               (guix-publish-configuration
                                 (host "127.0.0.1")
                                 (port 8082)
                                 (compression '(("zstd" 19) ("gzip" 9)))
                                 (cache "/var/cache/guix/publish")
                                 ;; Allow up to 200 MiB
                                 (cache-bypass-threshold (* 200 1024 1024))
                                 ;; 1 year
                                 (ttl (* 365 24 60 60))))
                      (service ntp-service-type)
                      (service channel-builder-service-type)
                      (service guix-cran-service-type)
                      (service unattended-upgrade-service-type
                               (unattended-upgrade-configuration
                                (channels #~(cons* (channel
                                                    (name 'psychnotebook-deploy)
                                                    (url "https://github.com/leibniz-psychology/psychnotebook-deploy.git")
                                                    (introduction
                                                     (make-channel-introduction
                                                      "02ae8f9f647ab9650bc9211e728841931f25792c"
                                                      (openpgp-fingerprint
                                                       "CA4F 8CF4 37D7 478F DA05  5FD4 4213 7701 1A37 8446"))))
                                             %default-channels))
                                 (operating-system-file
                                  (scheme-file "config.scm"
                                    #~(@ (zpid machines patna os) patna-os)))
                                 (system-expiration (* 1 30 24 60 60)) ; Expire after one month.
                                 (schedule "55 13 * * *")
                                 (services-to-restart '(nginx collectd ntpd guix-publish ssh-daemon mcron))))
                      (service collectd-service-type
                       (collectd-configuration
                        (file (local-file "collectd.conf"))))
                      (service rasdaemon-service-type
                        (rasdaemon-configuration
                          (record? #t)))
                      (service psychnotebook-stats-service-type)
                      (service static-networking-service-type
                        (list
                          (static-networking
                            (addresses
                              (list (network-address
                                      (device "enp41s0")
                                      (value "94.130.12.62/26"))
                                    (network-address
                                      (device "enp41s0")
                                      (ipv6? #t)
                                      (value "2a01:4f8:10b:106e::2/64"))))
                            (routes
                              (list (network-route
                                      (destination "default")
                                      (device "enp41s0")
                                      (gateway "94.130.12.1"))
                                    (network-route
                                      (destination "default")
                                      (device "enp41s0")
                                      (ipv6? #t)
                                      (gateway "fe80::1"))))
                            (name-servers '("2a01:4ff:ff00::add:2"
                                            "2a01:4ff:ff00::add:1"
                                            "185.12.64.1"
                                            "185.12.64.2")))))
                      cron-service
                      nginx-service
                      certbot-service)
                      (modify-services %base-services
                        (guix-service-type config =>
                          (guix-configuration
                            (inherit config)
                            (extra-options '("--cache-failures")))))))))

