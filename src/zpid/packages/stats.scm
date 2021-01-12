(define-module (zpid packages stats)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages)
  #:use-module (gnu packages rrdtool)
  #:use-module (gnu packages base)
  #:use-module (gnu packages python)
  #:use-module (gnu packages fonts)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system copy)
  #:use-module (guix gexp)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26))

(define-public psychnotebook-stats
 (package
  (name "psychnotebook-stats")
  (version "0.1")
  (source (origin
       (method git-fetch)
       (uri
        (git-reference
         (url "https://github.com/leibniz-psychology/psychnotebook-deploy.git")
         (commit "cf0e822517d3119d924f2841ebb915b85c9eefbd")))
       (file-name (git-file-name name version))
       (sha256 (base32 "1zq6b9r3ipl9irscqq3z12kfhgb70cww8x7nwbgcs4j6zwisc8rr"))))
  (build-system copy-build-system)
  (arguments
   `(#:install-plan
       '(("tools/stats/" "bin/"))
     #:phases
       (modify-phases %standard-phases
        (add-after 'unpack 'fix-paths
         (lambda* (#:key inputs outputs #:allow-other-keys)
          (substitute* "tools/stats/psychnotebook-stats-plot"
           (("'rrdtool'")
            (string-append "'" (assoc-ref inputs "rrdtool") "/bin/rrdtool'")))
          (substitute* "tools/stats/psychnotebook-stats-update"
           (("psychnotebook-stats-plot")
            (string-append (assoc-ref outputs "out")
             "/bin/psychnotebook-stats-plot")))
          #t)))))
  (inputs
   `(("python" ,python)
     ("rrdtool" ,rrdtool)))
  (propagated-inputs
   `(("font-mononoki" ,font-mononoki)
     ("coreutils", coreutils)))
  (home-page "https://psychnotebook.org")
  (synopsis "Stats plotting for PsychNotebook")
  (description "Stats plotting for PsychNotebook")
  (license license:expat)))

