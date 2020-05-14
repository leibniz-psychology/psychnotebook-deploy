Tasks
=====

This page lists routine admin tasks.

Idle session culling
--------------------

Most users will start their programs and never stop them explicitly. Some
programs do support automatic shutdown when idle:

RStudio
	.. code::

		--session-timeout-minutes=60
		--session-disconnected-timeout-minutes=60
JupyterLab
	.. code::

		--NotebookApp.shutdown_no_activity_timeout=3600
		--MappingKernelManager.cull_idle_timeout=3600
		--MappingKernelManager.cull_interval=300

Sometimes this does not work and applications need to be stopped manually. The
best way to figure out which ones are old is to run:

.. code:: console

	ps aux | grep -i conductor-pipe-real

and then kill the oldest ones. This should also terminate the corresponding
application, which can be verified using tools like ``pstree``.

Other methods for culling were investagated. ``ktwkd`` could in theory collect
data for every process from ``/proc/<pid>/{io,stat}``, determine if the process
tree of a user has been idle for a given time (i.e. no CPU usage or I/O) and
send it a SIGTERM.  Unfortunately the Linux kernel lacks per-process accounting
of network activity, rendering this method unreliable, because a process might
be network-heavy, but not use a lot of CPU time or generate disk I/O.

Adding new packages
-------------------

Right now only one profile exists for all project. That makes it easy to add
new packages to all user’s workspaces. It also means there is a lot potential
to break things unfortunately. *This will change in the future!*

First add the name of the package to ``/gnu/manifests/psychnotebook.scm``, then
run

.. code:: console

	# make sure your guix command is current
	guix pull
	source ~/.config/guix/current/etc/profile
	# then update the profile
	guix package -p /var/guix/profiles/psychnotebook/2020-04-04 \
			-m /gnu/manifests/psychnotebook.scm --allow-collisions

If anything goes wrong, you can always roll back to a previous version with
``--switch-generation``.

