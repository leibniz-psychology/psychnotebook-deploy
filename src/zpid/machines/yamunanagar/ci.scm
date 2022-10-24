;;; A simple continuous channel builder shepherd service (instead of mcron,
;;; which would run multiple jobs at the same time if they are too slow to finish
;;; until the next one is started)

(define-module (zpid machines yamunanagar ci)
	       #:use-module (gnu)
	       #:use-module (guix gexp)
	       #:use-module (guix modules)
	       #:use-module (gnu services shepherd)
	       ;; for shadow
	       #:use-module (gnu packages admin)
	       ;; for guix
	       #:use-module (gnu packages package-management)
	       #:use-module (ice-9 match))

;; lifted from https://web.fdn.fr/~lcourtes/pastebin/mcron-build-jobs.html
;; Should be part of the service configuration
(define channels
  (scheme-file "channels-for-build-jobs.scm"
           #~(append
           (list
             (channel
               (name 'guix-science)
               (url "https://github.com/guix-science/guix-science.git")
               (introduction
                 (make-channel-introduction
                   "b1fe5aaff3ab48e798a4cce02f0212bc91f423dc"
                   (openpgp-fingerprint
                 "CA4F 8CF4 37D7 478F DA05  5FD4 4213 7701 1A37 8446"))))
             (channel
               (name 'guix-zpid)
               (url "https://github.com/leibniz-psychology/guix-zpid.git"))
             (channel
               (name 'guix-cran)
               (url "https://github.com/guix-science/guix-cran.git")))
           %default-channels)))

(define manifest
  (scheme-file "manifest-for-build-jobs.scm"
    #~(begin
      (use-modules (guix discovery)
                   (gnu packages)
                   (guix modules)
                   (guix utils)
                   (guix packages))
      (let* ((modules (all-modules (%package-module-path)))
             (packages (fold-packages
                         (lambda (p accum)
                           (let ((mod (file-name->module-name (location-file (package-location p)))))
                             (if (member (car mod) '(guix-cran guix-science zpid))
                               (cons p accum)
                               accum)))
                         '() modules)))
        (packages->manifest packages)))))

(define channel-builder-shepherd-service
  (lambda (config)
    (match config
       (#f
        (let* ((code (with-imported-modules
               (source-module-closure '((guix build utils)))
               #~(begin
                   ;; for invoke
                   (use-modules (guix build utils))
                   (define (loop)
                 (system* #$(file-append guix "/bin/guix")
                     "time-machine"  "-C" #$channels
                     "--" "build" "--fallback" "--timeout=7200" "--keep-going" "-M" "4"
                          "--no-substitutes"
                          "-m" #$manifest)
                   ;; Make sure substitutes are available by requesting them once from guix-publish.
                   (system* #$(file-append guix "/bin/guix")
                     "time-machine"  "-C" #$channels
                     "--"
                     "weather"
                     "--substitute-urls=https://substitutes.guix.psychnotebook.org"
                     "-m" #$manifest)
                 (sleep 60)
                 (loop))
                   (loop))))
           (runner (program-file "channel-builder-runner" code)))

          (list (shepherd-service
              (provision '(channel-builder))
              (documentation "Run the channel builder")
              (requirement '(user-processes networking))
              (start #~(make-forkexec-constructor
                 (list #$runner)
                 #:user "channelbuilder"
                 #:group "channelbuilder"
                 #:log-file "/var/log/channel-builder.log"))
              (stop #~(make-kill-destructor)))))))))

(define %channel-builder-accounts
  (list (user-group (name "channelbuilder") (system? #t))
	(user-account
         (name "channelbuilder")
         (group "channelbuilder")
         (system? #t)
         (comment "Build user for channels")
         (home-directory "/var/cache/channelbuilder")
         (shell (file-append shadow "/sbin/nologin")))))

(define-public channel-builder-service-type
  (service-type (name 'channel-builder)
                (extensions
                 (list (service-extension shepherd-root-service-type
                                          channel-builder-shepherd-service)
                       (service-extension account-service-type
                                          (const %channel-builder-accounts))))
                (description
                 "Simple channel building CI service")
                (default-value #f)))

