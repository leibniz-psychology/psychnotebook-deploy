;; nginx may fail to start without let’s encrypt certificates

(define-module (yamunanagar nginx)
	       #:use-module (gnu)
	       #:use-module (guix gexp)
	       #:use-module (gnu services web))

(define-public nginx-service
               (service nginx-service-type
                        (nginx-configuration
                          (upstream-blocks
                            (list
                              (nginx-upstream-configuration
                                (name "publish")
                                (servers (list "localhost:8082")))))
                          (server-blocks
                            (list
                              (nginx-server-configuration
                                (server-name '("substitutes.guix.psychnotebook.org"))
                                (listen '("443 ssl"))
                                (ssl-certificate
                                  "/etc/letsencrypt/live/yamunanagar.psychnotebook.org/fullchain.pem")
                                (ssl-certificate-key
                                  "/etc/letsencrypt/live/yamunanagar.psychnotebook.org/privkey.pem")
                                (locations
                                  (list
                                    (nginx-location-configuration
                                      (uri "/")
                                      (body (list "proxy_pass http://publish;")))))))))))

