(define-module (zpid machines patna certbot)
	       #:use-module (gnu)
	       #:use-module (guix gexp)
	       #:use-module (gnu services certbot))

(define %nginx-deploy-hook
  (program-file
    "nginx-deploy-hook"
    #~(let ((pid (call-with-input-file "/var/run/nginx/pid" read)))
        (kill pid SIGHUP))))

(define-public certbot-service
               (service certbot-service-type
                        (certbot-configuration
                          (email "ldb@leibniz-psychology.org")
                          (certificates
                            (list
                              (certificate-configuration
                                (domains '("patna.psychnotebook.org" "substitutes.guix.psychnotebook.org"))
                                (deploy-hook %nginx-deploy-hook)))))))
