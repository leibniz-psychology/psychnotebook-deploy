(define-module (yamunanagar cron)
	       #:use-module (gnu)
	       #:use-module (guix gexp)
	       #:use-module (gnu services mcron))

;; Collect garbage 5 minutes after midnight every day.
(define garbage-collector-job
  #~(job "5 0 * * *"
         "guix gc -F 10G"))

(define-public cron-service
	       (service mcron-service-type
			(mcron-configuration
			  (jobs (list garbage-collector-job)))))
