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

.. _import:

Import missing packages
-----------------------

This applies to packages not available in GNU guix yet. guix provides importer
for PyPi and CRAN, see `guix import
<https://guix.gnu.org/manual/en/guix.html#Invoking-guix-import>`__. These make
life alot easier, but they are not guaranteed to work. For example to import
*nlstools* from CRAN navigate to your checkout of the repository `guix-zpid`_,
then run:

.. _guix-zpid: https://github.com/leibniz-psychology/guix-zpid

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
commit`` and push to GitHub with ``git push``.

The same workflow also applies to PyPi, replace ``guix import cran`` with
``guix import pypi`` and ``guix environment`` with

.. code:: console

	guix environment -L . --ad-hoc python-foobar python -- python

Modify default project
----------------------

The workspace command uses the default project at :file:`/etc/mashru3/skel`
when ``workspace create`` is called. To add a new package make sure it is
available in Guix (see import_), then edit
:file:`/etc/mashru3/skel/.config/guix/manifest.scm` and update the cache using:

.. code:: console

	pushd /etc/mashru3/skel/.config/guix
	guix pull -p current
	./current/bin/guix package -m manifest.scm  -p ../../.guix-profile
	popd

Finding broken workspaces
-------------------------

Guix’ garbage collector can break user profiles, if they are not fully
registered as gcroot. The script in :file:`tools/findBrokenWorkspaces.sh` can
find broken workspaces.

Profiles can be registered as gcroot using ``mashru3``:

.. code:: console

	guix repl -- mashru3/scripts/addRoots.scm /path/to/project

Mapping email address to username
---------------------------------

Often people will email us about issues, but we need their UNIX username. It’s easy to map the email address to a username by running:

.. code:: console

	ldapsearch -H ldapi:/// -Y EXTERNAL -b 'ou=people,dc=psychnotebook,dc=org' '(&(mail=user@example.com))' uid 2>/dev/null | grep '^uid:'

Locking and unlocking accounts
------------------------------

Right now accounts can be locked and unlocked by expiring their principals in
Kerberos. To lock the account ``joeuser`` run:

.. code:: bash

	kadmin.local modprinc -expire yesterday joeuser

And to unlock it again run

.. code:: bash

	kadmin.local modprinc -expire never joeuser

Adding message of the day (motd)
--------------------------------

Maintenance and service interruptions can be announced by setting the server’s
message of the day (motd) in :file:`/etc/motd`. It’s a plain-text file and its
contents will be displayed by SSH (via pam) and therefore also by bawwab (which
reads SSH’s banner).

.. _tosupdate:

Update terms of service
-----------------------

The terms of service are part of the deployment documentation, see
:file:`doc/terms`. Therefore you can change these files and apply the following
update to LDAP:

.. code:: console

	effective=202105120000Z
	termspath=`pwd`/doc/terms
	sudo ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
	dn: x-termsId=tosde,ou=terms,dc=psychnotebook,dc=org
	changetype: modify
	replace: x-termsContent
	x-termsContent:< file://$termspath/tos-de.md
	-
	replace: x-termsEffective
	x-termsEffective: $effective

	dn: x-termsId=tosen,ou=terms,dc=psychnotebook,dc=org
	changetype: modify
	replace: x-termsContent
	x-termsContent:< file://$termspath/tos-en.md
	-
	replace: x-termsEffective
	x-termsEffective: $effective

	dn: x-termsId=privacyde,ou=terms,dc=psychnotebook,dc=org
	changetype: modify
	replace: x-termsContent
	x-termsContent:< file://$termspath/privacy-de.md
	-
	replace: x-termsEffective
	x-termsEffective: $effective

	dn: x-termsId=privacyen,ou=terms,dc=psychnotebook,dc=org
	changetype: modify
	replace: x-termsContent
	x-termsContent:< file://$termspath/privacy-en.md
	-
	replace: x-termsEffective
	x-termsEffective: $effective
	-
	EOF

Afterwards all existing SSH sessions for bawwab must be killed. Their session
stays valid until bawwab is restarted, but they cannot use conductor (and thus
start programs), since the latter does not accept the ToS automatically. You
can find the PIDs using:

.. code:: console

	ps aux | grep -e '[0-9] sshd: .*@notty'

