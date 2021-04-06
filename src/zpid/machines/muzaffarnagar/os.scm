(define-module (zpid machines muzaffarnagar os)
 #:use-module (gnu)
 #:use-module (gnu packages backup)
 #:use-module (guix modules)
 #:use-module (zpid services collectd)
 #:use-module (zpid services stats)
 #:use-module (zpid machines muzaffarnagar network)
 #:use-module (nongnu packages linux)
 #:use-module (nongnu system linux-initrd))

(use-service-modules ssh admin networking base mcron)

(define borg-prune-script
 (program-file "borg-prune.scm"
   (with-imported-modules (source-module-closure '((guix build utils)))
     #~(begin
      (use-modules (guix build utils))
      (for-each
      (lambda (prefix)
        (invoke #$(file-append borg "/bin/borg")
                "prune"
                "--lock-wait=3600" ; Wait if a backup is currently in progress
                "-v"
                "--list"
                "--keep-daily=7" ; Keep last 7 days.
                "--keep-weekly=4" ; Keep last 4 weeks.
                "--keep-monthly=3" ; Keep last 3 months.
                (string-append "--prefix=" prefix "-") ; Prune each prefix separately
                "/storage/backup"))
        '("data" "ldap-psychnotebook" "ldap-config"))))))

(define borg-prune-job
 #~(job "5 4 * * *" #$borg-prune-script #:user "psychnotebook"))

;; Clean up everything we can.
(define garbage-collector-job
  #~(job "5 0 * * *" "guix gc"))

;; Modules required to boot on VMWare.
(define vmware-required-modules
 '(
     ;; LSI storage driver
     "mptspi"
     ;; Graphics
     "vmwgfx"
     ;; Network
     "vmxnet3"))

(define-public os
 (operating-system
  (host-name "muzaffarnagar.psychnotebook.org")
  (timezone "Europe/Berlin")
  (locale "en_US.utf8")

  (kernel linux)
  (initrd microcode-initrd)
  (initrd-modules (append vmware-required-modules %base-initrd-modules))
  (firmware (list linux-firmware))

  (bootloader (bootloader-configuration
               (bootloader grub-bootloader)
               (target "/dev/sda")
               (terminal-outputs '(console))))

  (groups (append (list (user-group (name "psychnotebook"))) %base-groups))
  (users (append (list
                  (user-account
                   (name "ldb")
                   (comment "")
                   (group "users")
                   (password (crypt "changeme" "$6$abc"))
                   (supplementary-groups '("wheel" "netdev" "audio" "video")))
                  (user-account
                   (name "psychnotebook")
                   (comment "Incoming backup user")
                   (group "psychnotebook")))
          %base-user-accounts))

  (file-systems (append (list
                         (file-system
                          (mount-point "/")
                          (device (uuid "f8ecc21d-1625-4452-80bf-ccd0a537bed4"))
                          (type "ext4"))
                         (file-system
                          (mount-point "/storage")
                          (device (uuid "87827802-71bd-42ea-9b56-425f8e515864"))
                          (type "ext4")))
                 %base-file-systems))

  (packages (append (map specification->package '("borg" "nss-certs")) %base-packages))

  (services
   (append
    (list 
     (simple-service 'cleanup mcron-service-type
      (list borg-prune-job garbage-collector-job))
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
         #~(@ (zpid machines muzaffarnagar os) os)))
       (schedule "55 13 * * *")
       (system-expiration (* 1 30 24 60 60)) ; Expire after one month.
       (services-to-restart '(ntpd ssh-daemon guix-daemon mcron))))
     (service ntp-service-type)
     (service openssh-service-type
      (openssh-configuration
       (permit-root-login #f)
       (password-authentication? #f)
       (port-number 2222)
       (authorized-keys
        `(("ldb" ,(local-file "../../../keys/ldb.pub"))
			("psychnotebook" ,(local-file "../../../keys/tiruchirappalli-root.pub"))
         ))))
     static-network-service)
     (modify-services %base-services
      (guix-service-type config =>
       (guix-configuration
        (inherit config)
        (substitute-urls
         (append (list "https://substitutes.guix.psychnotebook.org")
          %default-substitute-urls))
        (authorized-keys
         (append (list (local-file "../../../keys/substitutes.guix.psychnotebook.org.pub"))
          %default-authorized-guix-keys)))))))))

