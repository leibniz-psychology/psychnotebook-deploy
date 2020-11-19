;; Unused, not working well.

(define-module (yamunanagar cuirass)
	       #:use-module (gnu)
	       #:use-module (guix gexp)
	       #:use-module (gnu services cuirass))

(define %cuirass-specs
  #~(list
  '((#:name . "guix-science")
    (#:load-path-inputs . ("guix"))
    (#:package-path-inputs . ("guix-science"))
    ; Input from which to load proc-file
    (#:proc-input . "guix")
    (#:proc-file . "build-aux/cuirass/gnu-system.scm")
    ; the proc from the file above evaluated
    (#:proc . cuirass-jobs)
    (#:proc-args
     (subset "jasp"
	      "rstudio"
	      "rstudio-server"
	      "python-notebook"
	      "python-jupyterlab")
     (systems "x86_64-linux"))
    (#:inputs . (((#:name . "guix")
		  (#:url . "git://git.savannah.gnu.org/guix.git")
		  (#:load-path . ".")
		  (#:branch . "master")
		  (#:no-compile? . #t))
		 ((#:name . "guix-science")
		  (#:url . "https://github.com/guix-science/guix-science.git")
		  (#:load-path . ".")
		  (#:branch . "master")
		  (#:no-compile? . #t))))
    (#:build-outputs . ()))
  '((#:name . "guix-zpid")
    (#:load-path-inputs . ("guix"))
    (#:package-path-inputs . ("guix-zpid" "guix-science"))
    ; Input from which to load proc-file
    (#:proc-input . "guix")
    (#:proc-file . "build-aux/cuirass/gnu-system.scm")
    ; the proc from the file above evaluated
    (#:proc . cuirass-jobs)
    (#:proc-args
     (subset "rstudio-server-zpid"
	      "psychnotebook-app-rstudio"
	      "psychnotebook-app-rmarkdown"
	      "psychnotebook-app-jupyterlab"
	      "psychnotebook-app-jasp")
     (systems "x86_64-linux"))
    (#:inputs . (((#:name . "guix")
		  (#:url . "git://git.savannah.gnu.org/guix.git")
		  (#:load-path . ".")
		  (#:branch . "master")
		  (#:no-compile? . #t))
		 ((#:name . "guix-science")
		  (#:url . "https://github.com/guix-science/guix-science.git")
		  (#:load-path . ".")
		  (#:branch . "master")
		  (#:no-compile? . #t))
		 ((#:name . "guix-zpid")
		  (#:url . "https://github.com/leibniz-psychology/guix-zpid.git")
		  (#:load-path . ".")
		  (#:branch . "master")
		  (#:no-compile? . #t))))
    (#:build-outputs . ()))))

(define-public cuirass-service
  (service cuirass-service-type
	   (cuirass-configuration
	     (specifications %cuirass-specs)
	     ; Do not build every single dependency.
	     (use-substitutes? #t)
	     ; Build anyway if substitute servers are unreachable.
	     (fallback? #t))))

