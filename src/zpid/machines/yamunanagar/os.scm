(define-module (zpid machines yamunanagar os)
 #:use-module (gnu)
 #:use-module (zpid services collectd)
 #:use-module (zpid services stats)
 #:use-module (zpid machines yamunanagar nginx)
 #:use-module (zpid machines yamunanagar ci)
 #:use-module (zpid machines yamunanagar cron)
 #:use-module (zpid machines yamunanagar certbot)
 #:use-module (zpid machines yamunanagar network)
 #:use-module (nongnu packages linux)
 #:use-module (nongnu system linux-initrd))

(use-service-modules ssh networking virtualization mcron admin)
(use-package-modules bootloaders certs ssh)

(define-public yamunanagar-os
 (operating-system
  (host-name "yamunanagar.psychnotebook.org")
  (timezone "Europe/Berlin")
  (locale "en_US.utf8")

  ;; Use non-free kernel for r8169 network driver
  (kernel linux)
  (initrd microcode-initrd)
  (firmware (list linux-firmware))

  (bootloader (bootloader-configuration
                (bootloader grub-bootloader)
                (target "/dev/sda")))

  (file-systems (append
                  (list
                   ;; Use the first disk for the system.
                   (file-system
                          (device "/dev/sda2")
                          (mount-point "/")
                          (type "ext4"))
                   ;; And the second one to store baked nars. This way we can
                   ;; balance disk usage well and either is easily recoverable,
                   ;; so no RAID.
                   (file-system
                          (device "/dev/sdb")
                          (mount-point "/var/cache/guix")
                          (type "ext4")))
                  %base-file-systems))

  (users (append (list (user-account
                         (name "ldb")
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
                                   `(("ldb" ,(local-file "../../../keys/ldb.pub"))))))
                      (service guix-publish-service-type
                               (guix-publish-configuration
                                 (host "127.0.0.1")
                                 (port 8082)
                                 (compression '(("zstd" 19) ("gzip" 9)))
                                 (cache "/var/cache/guix/publish")
                                 ;; Allow up to 200 MiB
                                 (cache-bypass-threshold (* 200 1024 1024))
                                 ;; 1 month
                                 (ttl (* 30 24 60 60))))
                      (service ntp-service-type)
                      (service channel-builder-service-type)
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
                                    #~(@ (zpid machines yamunanagar os) yamunanagar-os)))
                                 (system-expiration (* 1 30 24 60 60)) ; Expire after one month.
                                 (schedule "55 13 * * *")
                                 (services-to-restart '(nginx collectd ntpd guix-publish ssh-daemon mcron))))
                      (service collectd-service-type
                       (collectd-configuration
                        (file (local-file "collectd.conf"))))
                      (service psychnotebook-stats-service-type)
                      static-network-service
                      cron-service
                      nginx-service
                      certbot-service)
                      %base-services))))

