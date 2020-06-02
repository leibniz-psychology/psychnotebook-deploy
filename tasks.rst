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

Import
++++++

If the software you want to install is already packaged for guix this step is
not necessary. Otherwise you’ll need to package it. guix provides importer for
PyPi and CRAN, see `guix import
<https://guix.gnu.org/manual/en/guix.html#Invoking-guix-import>`__. These make
life alot easier, but they are not guaranteed to work. For example to import
*nlstools* from CRAN navigate to your checkout of the repository guix-zpid,
then run:

.. code:: console

	guix import cran -r nlstools >> zpid/packages/cran.scm

Edit the license field of the package to include the prefix ``license:``, then
try to build it with:

.. code:: console

	guix build -L . r-nlstools

To make sure the package actually works, add it to an environment and try to
load it inside R:

.. code:: console

	guix environment -L . --ad-hoc r-nlstools r -- R
	# (now inside R)
	library(nlstools)

If that works you’re probably good to go. Commit the new package with ``git
commit``, push to GitHub with ``git push`` and update the copy at
``/gnu/channels/zpid``.

The same workflow also applies to PyPi, replace ``guix import cran`` with
``guix import pypi`` and ``guix environment`` with

.. code:: console

	guix environment -L . --ad-hoc python-foobar python -- python

Profiles
++++++++

First add the name of the package to ``/gnu/manifests/psychnotebook.scm``.
Include a comment why you’re adding the package. Then run

.. code:: console

	# make sure your guix command is current
	guix pull
	source ~/.config/guix/current/etc/profile
	# then update the profile
	guix package -p /var/guix/profiles/psychnotebook/$DATE \
			-m /gnu/manifests/psychnotebook.scm --allow-collisions

Replace ``$DATE`` with the version of the profile. When changing ``$DATE``,
you’ll also need to update the symlink in ``/etc/skel``, so new workspaces will
use this updated profile:

.. code:: console

	rm /etc/skel/.guix-profile
	ln -sv /var/guix/profiles/psychnotebook/%DATE% /etc/skel/.guix-profile

Only do that if you introduced substantial changes to the environment, i.e.
changed a package. Adding new packages does not qualify for a ``$DATE`` change.
If anything goes wrong, you can always roll back to a previous version with
``--switch-generation``.

