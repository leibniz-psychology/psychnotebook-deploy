(define-module (yamunanagar cron)
	       #:use-module (gnu)
	       #:use-module (guix gexp)
	       #:use-module (gnu services mcron))

;; lifted from https://web.fdn.fr/~lcourtes/pastebin/mcron-build-jobs.html
(define channels
  (scheme-file "channels-for-build-jobs.scm"
	       #~(append
		   (list (channel
			   (name 'guix-science)
			   (url "https://github.com/guix-science/guix-science.git")
			   (introduction
			     (make-channel-introduction
			       "b1fe5aaff3ab48e798a4cce02f0212bc91f423dc"
			       (openpgp-fingerprint
				 "CA4F 8CF4 37D7 478F DA05  5FD4 4213 7701 1A37 8446"))))
			 (channel
			   (name 'guix-zpid)
			   (url "https://github.com/leibniz-psychology/guix-zpid.git")
			   ))
		   %default-channels)))

(define manifest
  (scheme-file "manifest-for-build-jobs.scm"
	       #~(specifications->manifest
		   ;; guix-science
		   '("jasp"
		     "rstudio"
		     "rstudio-server"
		     "python-notebook"
		     "python-jupyterlab"
		     ;; guix-zpid
		     "rstudio-server-zpid"
		     "psychnotebook-app-rstudio"
		     "psychnotebook-app-rmarkdown"
		     "psychnotebook-app-jupyterlab"
		     "psychnotebook-app-jasp"))))

(define build-jobs
  #~(job '(next-minute)
               (string-append "guix time-machine -C " #$channels
                              " -- build --timeout=7200 --keep-going -m "
                              #$manifest
                              " --no-grafts")
	       #:user "ci"))

;; Collect garbage 5 minutes after midnight every day.
(define garbage-collector-job
  #~(job "5 0 * * *"
         "guix gc -F 1G"))

(define-public cron-service
	       (service mcron-service-type
			(mcron-configuration
			  (jobs (list build-jobs garbage-collector-job)))))
