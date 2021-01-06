PsychNotebook deployment
========================

Code and documentation for the PsychNotebook deployment.

This repository is an authenticated Guix channel. You can use it with the
following snippet:

.. code:: scheme

	(channel
	  (name 'psychnotebook-deploy)
	  (url "https://github.com/leibniz-psychology/psychnotebook-deploy.git")
	  (introduction
	   (make-channel-introduction
			"02ae8f9f647ab9650bc9211e728841931f25792c"
			(openpgp-fingerprint
			 "CA4F 8CF4 37D7 478F DA05  5FD4 4213 7701 1A37 8446"))))

Please make sure to add this git hook to your repository before pushing:

.. code::

	cat <<EOF > .git/hooks/pre-push
	#!/bin/sh
	exec guix git authenticate 02ae8f9f647ab9650bc9211e728841931f25792c "CA4F 8CF4 37D7 478F DA05  5FD4 4213 7701 1A37 8446"
	exit 127
	EOF
	chmod +x .git/hooks/pre-push

