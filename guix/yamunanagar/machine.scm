;; Heavily inspired by
;; https://code.divoplade.fr/divoplade-site.git/tree/divoplade/services/cuirass.scm

(use-modules
  (gnu)
  (yamunanagar nginx)
  (yamunanagar cron)
  (yamunanagar certbot))
(use-service-modules ssh networking virtualization mcron)
(use-package-modules bootloaders certs ssh)

(operating-system
  (host-name "yamunanagar.psychnotebook.org")
  (timezone "Europe/Berlin")
  (locale "en_US.utf8")

  (bootloader (bootloader-configuration
		(bootloader grub-bootloader)
		(target "/dev/sda")))

  ; XXX: What about the RAID?
  (file-systems (append
		  (list (file-system
			  (device "/dev/sda2")
			  (mount-point "/")
			  (type "ext4")))
		  %base-file-systems))

  (users (append (list (user-account
			 (name "ldb")
			 (comment "")
			 (group "users")
			 (password (crypt "changeme" "$6$abc"))
			 (supplementary-groups '("wheel" "netdev" "audio" "video")))
		       (user-account
			 (name "cms")
			 (comment "")
			 (group "users")
			 (supplementary-groups '("wheel" "netdev" "audio" "video")))
		       (user-account
			 (name "ci")
			 (comment "mcron-based CI user")
			 (group "users")))
		 %base-user-accounts))

  (packages (append (list
		      ;; for HTTPS access
		      nss-certs)
		    %base-packages))

  (services (append (list 
		      (service dhcp-client-service-type)
		      (service openssh-service-type
			       (openssh-configuration
				 (permit-root-login #f)
				 (authorized-keys
				   `(("ldb" ,(local-file "../keys/ldb.pub"))
				     ("cms" ,(local-file "../keys/cms.pub")) ))))
		      (service guix-publish-service-type
			       (guix-publish-configuration
				 (host "127.0.0.1")
				 (port 8082)
				 (compression '(("lzip" 7) ("gzip" 9)))
				 (cache "/var/cache/guix/publish")
				 ;; 1 month
				 (ttl 2592000)))
		      cron-service
		      nginx-service
		      certbot-service)
		    %base-services)))

