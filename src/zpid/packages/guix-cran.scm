(define-module (zpid packages guix-cran)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages version-control)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system trivial)
  #:use-module (guix gexp)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26))

(define-public guix-cran-scripts
  (let ((commit "6c5838d970353edb0785462dafb5ef76271e4274")
        (revision "0"))
  (package
    (name "guix-cran-scripts")
    (version (git-version "0" revision commit))
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/guix-science/guix-cran-scripts.git")
             (commit commit)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0wzx5f6agx9rji0s173323apw3cjjgyq9i0xfaj6zjgfq8c0lp9y"))))
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((output (assoc-ref %outputs "out"))
                 (bin (string-append output "/bin"))
                 (source (assoc-ref %build-inputs "source"))
                 (import-scm (string-append bin "/import.scm"))
                 (update-sh (string-append bin "/update.sh"))
                 (shell #$(file-append bash-minimal "/bin/bash")))
            (mkdir-p bin)
            (copy-file (string-append source "/import.scm") import-scm)
            ;; No interpreter, cannot use wrap-script.
            ;; Don’t wrap, because it has to be called with `guix repl`
;            (wrap-program import-scm
;                          #:sh shell
;                          `("PATH" ":" prefix (,#$(file-append git "/bin"))))
            (call-with-output-file update-sh
              (lambda (port)
                (display (string-append "#!" shell "\n"
                                        "# Guix CRAN update script.

# Bail out on errors, so we don’t have to && everything.
set -e

# Git should not ask anything.
export GIT_TERMINAL_PROMPT=0
# `guix import cran` needs a proper locale, otherwise it'll fail.
export LANG=C.utf8

pushd output
# Update, in case any manual changes happened.
git pull
popd

# Make sure we only use default Guix channels, no matter how the system
# is configured.
cat <<EOF > channels.scm
%default-channels
EOF
guix pull -C channels.scm -p profile

export GUIX_PROFILE=`pwd`/profile
source $GUIX_PROFILE/etc/profile

mkdir -p cache/{description,contents}
rm -f cache/description/*
guix repl " import-scm " output guix-cran | tee log

pushd output
git push origin --all
popd

rm -f profile profile-*-link channels.scm

exit 0
") port)))
              (chmod update-sh #o555)
              (wrap-program update-sh
                            #:sh shell
                           `("PATH" ":" prefix (,#$(file-append coreutils "/bin")
                                                ,#$(file-append git "/bin"))))))))
    (home-page "https://github.com/guix-science/guix-cran-scripts")
    (synopsis #f)
    (description #f)
    (license license:gpl3+))))

