Configuration
=============

This sections details the software installed on the production system. It
assumes Ubuntu 20.04 as the host system.

Currently only a single master server without compute separate compute nodes
exists. The following software is installed:

NSCD
^^^^

Must be installed and caching for ``passwd`` and ``group`` must be enabled.
This is a `requirement by guix`__, since it cannot interact with system
sssd (provided by Ubuntu) on its own (library search path different).

__ https://guix.gnu.org/manual/en/guix.html#Name-Service-Switch-1

This configuration is `explicitly not supported
<https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html-single/deployment_guide/index#usingnscd-sssd>`__,
but no workaround is known at this time.


Add ``universe`` to the list of repositories in ``/etc/apt/sources.list``

.. code::

	deb http://archive.ubuntu.com/ubuntu focal main universe
	deb http://archive.ubuntu.com/ubuntu focal-security main
	deb http://archive.ubuntu.com/ubuntu focal-updates main

Update apt and install

.. code:: console

	apt update && apt install nscd

Enable caching by editing ``/etc/nscd.conf``

.. code::

	# essentially disable caching by setting a very low ttl
	enable-cache            passwd          yes
	positive-time-to-live   passwd          1
	negative-time-to-live   passwd          1

	enable-cache            group           yes
	positive-time-to-live   group           1
	negative-time-to-live   group           1

	enable-cache            hosts           no
	enable-cache            services        no
	enable-cache            netgroup        no

Restart the daemon

.. code:: console

	systemctl enable nscd
	systemctl restart nscd

guix
^^^^

Install guix using the instructions provided in its `handbook
<https://guix.gnu.org/manual/en/guix.html#Binary-Installation>`__. Create a
channel configuration in ``/etc/guix/channels.scm``:

.. code:: scheme

	(list
		(channel
			(name 'guix)
			(url "/gnu/channels/guix"))
		(channel
			(name 'zpid)
			(url "/gnu/channels/zpid")))

And populate the two directories with the repositories `guix
<https://github.com/leibniz-psychology/guix>`__ and `guix-zpid
<https://github.com/leibniz-psychology/guix-zpid>`__. Then run ``guix pull``
*twice* as root (the installer does not support the config file above yet) and
restart the daemon with ``systemctl restart guix-daemon``. Clean up the dirt
with ``guix pull -d``.

From the node guix opens an SSH tunnel to the master node’s UNIX domain socket
via a guile interpreter. This binary must be in ``PATH``, thus run as root:

.. code:: console

	guix install guile
	ln -sv /var/guix/profiles/per-user/root/guix-profile/bin/guile /usr/local/bin/

LDAP
^^^^

.. code:: console

	apt install slapd ldap-utils ldapvi

If you’re using the editor ``vi``, it is suggested to use ``ldapvi`` to edit
the LDAP directory. LDAP stores its own configuration as a LDAP directory tree
below ``cn=config``. Only root on the same machine must be able to edit it
using::

	ldapvi -h ldapi:/// -Y EXTERNAL -b cn=config

Add initial configuration and essential user accounts to LDAP:

.. code:: console

	ldapadd -Y EXTERNAL -H ldapi:/// <<EOF
	dn: cn=config
	olcAuthzRegexp: {0}uid=([^,]+),cn=COMPUTE.ZPID.DE,cn=gssapi,cn=auth uid=$1,ou=people,dc=compute,dc=zpid,dc=de
	olcSaslRealm: COMPUTE.ZPID.DE

	dn: olcDatabase={1}mdb,cn=config
	olcSuffix: dc=compute,dc=zpid,dc=de
	olcAccess: {0}to dn.subtree="ou=people,dc=compute,dc=zpid,dc=de" by dn.base="c
	 n=psychnotebook,ou=system,dc=compute,dc=zpid,dc=de" write by * read
	olcAccess: {1}to dn.subtree="ou=group,dc=compute,dc=zpid,dc=de" by dn.base="cn
	 =psychnotebook,ou=system,dc=compute,dc=zpid,dc=de" write by * read
	olcAccess: {2}to dn.subtree="cn=krb5,dc=compute,dc=zpid,dc=de" by dn.base="cn=
	 kdc,ou=system,dc=compute,dc=zpid,dc=de" write by dn.base="cn=kadmin,ou=system
	 ,dc=compute,dc=zpid,dc=de" write by * none
	olcAccess: {3}to * by * read
	olcRootDN: cn=admin,dc=compute,dc=zpid,dc=de

	dn: dc=compute,dc=zpid,dc=de
	objectClass: top
	objectClass: dcObject
	objectClass: organization
	o: compute
	dc: compute

	dn: ou=group,dc=compute,dc=zpid,dc=de
	ou: group
	objectClass: top
	objectClass: organizationalUnit

	dn: ou=people,dc=compute,dc=zpid,dc=de
	ou: people
	objectClass: top
	objectClass: organizationalUnit

	dn: ou=system,dc=compute,dc=zpid,dc=de
	ou: system
	objectClass: top
	objectClass: organizationalUnit

	dn: cn=kdc,ou=system,dc=compute,dc=zpid,dc=de
	cn: kdc
	sn: KDC user
	objectClass: person
	objectClass: top

	dn: cn=kadmin,ou=system,dc=compute,dc=zpid,dc=de
	cn: kadmin
	sn: kadmin user
	objectClass: person
	objectClass: top

	dn: cn=psychnotebook,ou=system,dc=compute,dc=zpid,dc=de
	cn: psychnotebook
	sn: PsychNotebook admin user
	objectClass: person
	objectClass: top
	EOF

And password-protect each of the accounts kdc, kadmin and psychnotebook using

.. code:: console

	for account in kdc kadmin psychnotebook; do
		ldappasswd -S -Y EXTERNAL -H ldapi:/// "cn=${account},ou=system,dc=compute,dc=zpid,dc=de"
	done


Configure LDAP client’s defaults at ``/etc/ldap/ldap.conf``

.. code::

	BASE    dc=compute,dc=zpid,dc=de
	URI     ldap://master

	TLS_CACERT      /etc/ssl/certs/ca-certificates.crt

	SASL_MECH GSSAPI


Kerberos
^^^^^^^^

.. code:: console

	apt install krb5-admin-server krb5-kdc krb5-kdc-ldap krb5-user 

Use ``compute.zpid.de`` as default realm. Ubuntu has a `guide
<https://help.ubuntu.com/lts/serverguide/kerberos-ldap.html>`__.

Kerberos is configured to use `LDAP as its database backend
<http://web.mit.edu/kerberos/krb5-latest/doc/admin/conf_ldap.html>`__. It
stores its data in ``cn=krb5`` and authenticates using ``cn=kdc,ou=system`` and
``cn=kadmin,ou=system``. It should live on the same machine as the LDAP server,
since both need to interact a lot and using ``ldapi://`` reduces round-trip
times.

Install the schema:

.. code:: console

	zcat /usr/share/doc/krb5-kdc-ldap/kerberos.schema.gz > /etc/ldap/schema/kerberos.schema && \
	echo "include /etc/ldap/schema/kerberos.schema" > schema.conf && \
	mkdir output && \
	slapcat -f schema.conf -F output -n 0

Then edit ``output/cn=config/cn=schema/cn={0}kerberos.ldif``, so

.. code::

	dn: cn=kerberoas,cn=schema,cn=config
	cn: kerberos

And remove

.. code::

	structuralObjectClass: olcSchemaConfig
	entryUUID: 873e5b72-09ce-103a-8ea9-a32f15cad81f
	creatorsName: cn=config
	createTimestamp: 20200403081156Z
	entryCSN: 20200403081156.112974Z#000000#000#000000
	modifiersName: cn=config
	modifyTimestamp: 20200403081156Z

from the bottom of the file. Then

.. code:: console

	ldapadd -Y EXTERNAL -H ldapi:/// -f 'output/cn=config/cn=schema/cn={0}kerberos.ldif'

Modify ``/etc/krb5.conf``

.. code::

	[libdefaults]
		default_realm = COMPUTE.ZPID.DE
		rdns = false
		dns_lookup_kdc = true
		dns_lookup_realm = false
		default_ccache_name = KCM:

		# The following krb5.conf variables are only for MIT Kerberos.
		kdc_timesync = 1
		ccache_type = 4
		forwardable = true
		proxiable = true

	[realms]
		COMPUTE.ZPID.DE = {
			kdc = master
			admin_server = master
		}

	[domain_realm]
		.compute.zpid.de = COMPUTE.ZPID.DE

	[dbmodules]
		COMPUTE.ZPID.DE = {
			db_library = kldap
			ldap_kdc_dn = cn=kdc,ou=system,dc=compute,dc=zpid,dc=de
			ldap_kadmind_dn = cn=kadmin,ou=system,dc=compute,dc=zpid,dc=de
			ldap_service_password_file = /etc/krb5kdc/service.keyfile
			ldap_conns_per_server = 5
			ldap_kerberos_container_dn = cn=krb5,dc=compute,dc=zpid,dc=de
			ldap_servers = ldapi:///
		}
	
Modify ``/etc/krb5kdc/kdc.conf``

.. code::

	[kdcdefaults]
		kdc_ports = 750,88

	[realms]
		COMPUTE.ZPID.DE = {
			admin_keytab = FILE:/etc/krb5kdc/kadm5.keytab
			acl_file = /etc/krb5kdc/kadm5.acl
			key_stash_file = /etc/krb5kdc/stash
			kdc_ports = 750,88
			max_life = 10h 0m 0s
			# allow longer renewals
			max_renewable_life = 90d 0h 0m 0s
			#master_key_type = des3-hmac-sha1
			#supported_enctypes = aes256-cts:normal aes128-cts:normal
			default_principal_flags = +preauth
		}

Create list of admin users ``/etc/krb5kdc/kadm5.acl``

.. code::

	usermgrd/master.dev.compute.zpid.de@COMPUTE.ZPID.DE adi

Then create the realm and start the server

.. code:: console

	kdb5_ldap_util stashsrvpw -f /etc/krb5kdc/service.keyfile cn=kdc,ou=system,dc=compute,dc=zpid,dc=de
	kdb5_ldap_util stashsrvpw -f /etc/krb5kdc/service.keyfile cn=kadmin,ou=system,dc=compute,dc=zpid,dc=de
	kdb5_ldap_util create -subtrees cn=krb5,dc=compute,dc=zpid,dc=de -r COMPUTE.ZPID.DE -s -D cn=admin,dc=compute,dc=zpid,dc=de -H ldapi:///

	systemctl enable krb5-kdc krb5-admin-server
	systemctl start krb5-kdc krb5-admin-server

Now add a few required principals for ssh (host/master) and NFS (nfs/master)

.. code:: console

	kadmin.local
	addprinc -randkey ldap/master
	addprinc -randkey host/master
	addprinc -randkey nfs/master
	ktadd nfs/master
	ktadd host/master
	ktadd -k /etc/ldap/keytab
	^C
	chown openldap:openldap /etc/ldap/keytab

Edit ``/etc/defaults/slapd`` to reference LDAP’s keytab

.. code::

	export KRB5_KTNAME=/etc/ldap/keytab

The column krbPrincipalName must be indexed, so add an index to LDAP:

.. code:: console

	ldapadd -Y EXTERNAL -H ldapi:/// <<EOF
	dn: olcDatabase={1}mdb,cn=config
	changetype: modify
	add: olcDbIndex
	olcDbIndex: krbPrincipalName eq
	EOF

SSSD
^^^^

SSSD combines LDAP user database and Kerberos authentication. It is used
`instead of pam_krb5
<https://docs.pagure.org/SSSD.sssd/users/pam_krb5_migration.html>`__
sssd-kcm_ is used to auto-renew tickets and make life with NFS more enjoyable.

.. _sssd-kcm: https://docs.pagure.org/SSSD.sssd/design_pages/kcm.html

.. code:: console

	apt install sssd sssd-kcm sssd-tools

Configure it in :file:`/etc/sssd/sssd.conf`:

.. code::

	[sssd]
		#services = nss, pam
		domains = compute.zpid.de

	[domain/compute.zpid.de]
		#debug_level = 9
		id_provider = ldap
		ldap_uri = ldap://master
		ldap_search_base = dc=compute,dc=zpid,dc=de

		auth_provider = krb5
		krb5_server = master
		krb5_realm = COMPUTE.ZPID.DE
		krb5_validate = true
		#krb5_ccachedir = /tmp
		krb5_keytab = /etc/sssd/krb5.keytab
		krb5_ccname_template = KCM:
		krb5_renewable_lifetime = 90d
		krb5_renew_interval = 10m

Add a new principal and export its keytab:

.. code:: console

	kadmin.local
	addprinc -randkey sssd/master
	ktadd -k /etc/sssd/krb5.keytab sssd/master

Due to the kerberized NFS homes it is not possible to use ``.k5login`` and::

	access_provider = krb5

When logging into account *a* as principal *b* NFS will still reject access,
since principal *b* cannot be mapped to the UNIX user *a*. Set proper
permissions and start the daemon:

.. code:: console

	chmod 600 /etc/sssd/sssd.conf
	systemctl enable sssd sssd-kcm
	systemctl start sssd sssd-kcm

PAM configuration is handled by Ubuntu.

SSH
^^^

Kerberize SSH by adding the following to ``/etc/ssh/sshd_config.d/kerberos.conf``

.. code::

	GSSAPIAuthentication yes
	GSSAPICleanupCredentials yes
	GSSAPIStrictAcceptorCheck yes
	GSSAPIKeyExchange yes

Also allow Kerberos ticket forwarding in ``/etc/ssh/ssh_config``

.. code::

	Host master
		GSSAPIAuthentication yes
		GSSAPIDelegateCredentials yes
		GSSAPIKeyExchange yes


Add every SSH key of every node and master to every host’s :file:`/etc/ssh/ssh_known_hosts`.

NFS
^^^

.. code:: console

	apt install nfs-kernel-server

Configured in :file:`/etc/exports`, but currently not set up.

Security
^^^^^^^^

Ubuntu turns on most of the critical stuff, except for::

	kernel.dmesg_restrict = 1
	kernel.kexec_load_disabled = 1

These are available in :file:`/etc/sysctl.d/98-dmesg.conf` and
:file:`98-kexec.conf` respectively.

Disallows getting a list of users:

.. code:: console

	chmod o-r /home

Enable the firewall to provide at least some protection of our internal
network:

.. code:: console

	ufw allow 22/tcp
	ufw allow 80/tcp
	ufw allow out to 136.199.89.5 port 53 comment 'dns'
	ufw allow out to 136.199.85.125 port 443 comment 'haproxy'
	ufw allow out to 136.199.85.125 port 80 comment 'haproxy'
	ufw deny out to 136.199.85.0/24 comment 'private'
	ufw deny out to 136.199.89.0/24 comment 'private'
	ufw deny out to 136.199.86.0/24 comment 'private'

