Configuration
=============

This sections details the software installed.

Both
----

Configuration valid for both, master and compute nodes.

SSSD
^^^^

SSSD combines LDAP user database and Kerberos authentication. It is used
`instead of pam_krb5
<https://docs.pagure.org/SSSD.sssd/users/pam_krb5_migration.html>`__

.. code:: bash

	apt install sssd sssd-kcm sssd-tools
	systemctl enable sssd sssd-kcm

Configured in :file:`/etc/sssd/sssd.conf`, uses its own kerberos keytab to
authenticate, see :file:`/etc/sssd/krb5.keytab`. Both files must not be
world-readable.

In :file:`/etc/krb5.conf` the following options must be set to use KCM::

	default_ccache_name = KCM:

sssd-kcm_ can auto-renew tickets and make life with NFS more enjoyable. To turn
that on set in :file:`/etc/sssd/sssd.conf`::

    krb5_renewable_lifetime = 90d
    krb5_renew_interval = 10m

.. _sssd-kcm: https://docs.pagure.org/SSSD.sssd/design_pages/kcm.html

PAM
^^^

Configured in :file:`/etc/pam.d/common-*` to use SSSD. Users must exist on the
master as well, so :program:`guix` can `ssh into master <compute-guix_>`__ and
communicate with :program:`guix-daemon`.

LDAP
^^^^

LDAP clients use :file:`/etc/ldap/ldap.conf`, must be configured to use Kerberos.

NSCD
^^^^

.. code:: bash

	apt install nscd

Must be installed and caching for ``passwd`` and ``group`` must be enabled.
This is a `requirement by guix`__, since it cannot interact with system
sssd (provided by Ubuntu) on its own (library search path different).

This configuration is `explicitly not supported
<https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html-single/deployment_guide/index#usingnscd-sssd>`__,
but no workaround is known at this time.

__ https://guix.gnu.org/manual/en/guix.html#Name-Service-Switch-1

Security
^^^^^^^^

Ubuntu turns on most of the critical stuff, except for::

	kernel.dmesg_restrict = 1
	kernel.kexec_load_disabled = 1

These are available in :file:`/etc/sysctl.d/98-dmesg.conf` and
:file:`98-kexec.conf` respectively.

Master
------

This configuration applies to the master server only.

guix
^^^^

From the node guix opens an SSH tunnel to the master node’s UNIX domain socket
via a guile interpreter. This binary must be in ``PATH``.

.. code:: bash

	guix install guile
	ln -sv /var/guix/profiles/per-user/root/guix-profile/bin/guile /usr/local/bin/

Kerberos
^^^^^^^^

.. code:: bash

	apt install krb5-admin-server krb5-kdc krb5-kdc-ldap krb5-user 

Kerberos uses `LDAP as database backend
<http://web.mit.edu/kerberos/krb5-latest/doc/admin/conf_ldap.html>`__, stores
its data in ``cn=krb5`` and authenticates using ``cn=kdc,ou=system`` and
``cn=kadmin,ou=system``. It should live on the same machine as the LDAP server,
since both need to interact a lot and using ``ldapi://`` reduces round-trip
times.

LDAP
^^^^

.. code:: bash

	apt install slapd

If you’re using the editor ``vi``, it is suggested to use ``ldapvi`` to edit
the LDAP directory. LDAP stores its own configuration as a LDAP directory tree
below ``cn=config``. Only root on the same machine must be able to edit it
using::

	ldapvi -h ldapi:/// -Y EXTERNAL -b cn=config

See ``olcAccess`` for ``olcDatabase={0}config,cn=config``.

The admin user is ``cn=admin,dc=compute,dc=zpid,dc=de`` (``olcRootDN``). Its
password is hard-coded into LDAP’s config.

By default users can change their ldap password with ``ldappasswd``.

NFS
^^^

.. code:: bash

	apt install nfs-kernel-server

Configured in :file:`/etc/exports`

Security
^^^^^^^^

- `chmod o-r /home`, disallows getting a list of users

Compute node
------------

The following configuration applies to compute nodes only.

.. _compute-guix:

guix
^^^^

.. code:: bash

	ln -sv /var/guix/profiles/per-user/root/current-guix/bin/guix /usr/local/bin/guix

libssh does not support hashed hostnames in known_hosts, thus the master’s SSH
key is distributed to each compute node on :file:`/etc/ssh/ssh_known_hosts`.

:program:`guix-daemon` is not run on the compute nodes. Instead
``GUIX_DAEMON_SOCKET=ssh://master.compute.zpid.de`` must be set
in :file:`/etc/environment`, so :program:`guix` connects to the master server
via SSH. This also needs a patched guix installation, until 38541_ is merged.

.. _38541: https://issues.guix.gnu.org/issue/38541


autofs
^^^^^^

.. code:: bash

	apt install autofs nfs-common

Auto-mounts NFS shares :file:`/gnu`, :file:`/var/guix` and :file:`/home`.
Configured in :file:`/etc/auto.master` and :file:`/etc/auto.guix`.

Kerberos
^^^^^^^^

.. code:: bash

	apt install krb5-user

