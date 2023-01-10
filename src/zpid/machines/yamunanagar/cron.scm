(define-module (zpid machines yamunanagar cron)
	       #:use-module (gnu)
	       #:use-module (guix gexp)
	       #:use-module (gnu services mcron)
	       #:use-module (gnu services shepherd)
	       ;; for shadow
	       #:use-module (gnu packages admin)
	       #:use-module (zpid packages guix-cran))

;; Collect garbage 5 minutes after midnight every day.
(define garbage-collector-job
  #~(job "5 0 * * *" "guix gc -F 10G"))

(define-public cron-service
 (simple-service 'guix-gc mcron-service-type
  (list garbage-collector-job)))

(define guix-cran-job
  #~(job "0 4 * * *" #$(file-append guix-cran-scripts "/bin/update.sh")
         #:user "guix-cran"))

(define %guix-cran-accounts
  (list
    (user-group (name "guix-cran") (system? #t))
    (user-account
      (name "guix-cran")
      (group "guix-cran")
      (system? #t)
      (comment "User for Guix CRAN updates")
      (home-directory "/var/lib/guix-cran")
      (shell (file-append shadow "/sbin/nologin")))))

(define-public guix-cran-service-type
  (service-type (name 'guix-cran)
                (extensions
                 (list (service-extension mcron-service-type
                                          (const (list guix-cran-job)))
                       (service-extension account-service-type
                                          (const %guix-cran-accounts))))
                (description
                 "Update the Guix CRAN channel")
                (default-value #f)))

