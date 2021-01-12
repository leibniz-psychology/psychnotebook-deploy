(define-module (zpid services stats)
  #:use-module (guix records)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gnu services mcron)
  #:use-module (gnu packages monitoring)
  #:use-module (gnu packages admin)
  #:use-module (zpid packages stats)
  #:use-module (gnu system shadow)
  #:use-module (ice-9 match))

(define output-dir "/var/www/stats")
(define service-user "build-stats")

(define psychnotebook-stats-activation
 (with-imported-modules '((guix build utils))
   #~(begin
    (use-modules (guix build utils))
    (let* ((dir #$output-dir)
           (pw  (getpw #$service-user))
           (uid (passwd:uid pw))
           (gid (passwd:gid pw)))
     (mkdir-p dir)
     (chown dir uid gid)
     (chmod dir #o755)))))

;; Update every 15 minutes.
(define psychnotebook-stats-mcron-jobs
 (list #~(job "*/15 * * * *"
   #$(file-append psychnotebook-stats "/bin/psychnotebook-stats-update"))))

(define %psychnotebook-stats-accounts
  (list (user-group (name service-user) (system? #t))
        (user-account
         (name service-user)
         (group service-user)
         (system? #t)
         (comment "psychnotebook stats user")
         (home-directory output-dir)
         (shell (file-append shadow "/sbin/nologin")))))

(define-public psychnotebook-stats-service-type
 (service-type
  (name 'psychnotebook-stats)
  (description "Periodically build stats.")
  (default-value #f)
  (extensions
   (list
    (service-extension account-service-type
     (const %psychnotebook-stats-accounts))
    (service-extension mcron-service-type
     (const psychnotebook-stats-mcron-jobs))
    (service-extension activation-service-type
     (const psychnotebook-stats-activation))))))
