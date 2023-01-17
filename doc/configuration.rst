Configuration
=============

Servers are being named after `Indian cities`_. In the long run we’d like to
move everything to GNU Guix-based servers.

.. _Indian cities: https://en.wikipedia.org/wiki/List_of_cities_in_India_by_population

DNS
---

External DNS configuration:

.. literalinclude:: config/psychnotebook.org.zone
	:language: zone

lucknow
-------

The main production server running Ubuntu 20.04.

General
^^^^^^^

The resolver needs to be configured to look at subdomains of
``prd.psychnotebook.org`` for services and :file:`/etc/hosts` must contains a line like

.. code-block::

	<ip-address> lucknow lucknow.psychnotebook.org

Otherwise Kerberos will have issues using the wrong hostname with hostbased principals.

We also limit retention of logs.

.. code::

	cp doc/config/lucknow/systemd/{resolved.conf,journald.conf} /etc/systemd/

Change the ``UMASK`` in :file:`/etc/login.defs` to ``027`` instead of
``022``, so other users do not have default file access.

NSCD
^^^^

Must be installed and caching for ``passwd`` and ``group`` must be enabled.
This is a `requirement by guix`__, since it cannot interact with system
sssd (provided by Ubuntu) on its own (library search path different).

__ https://guix.gnu.org/manual/en/guix.html#Name-Service-Switch-1

This configuration is `explicitly not supported
<https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html-single/deployment_guide/index#usingnscd-sssd>`__,
but no workaround is known at this time.

Install

.. code:: console

	apt install nscd

Enable caching by adding ``/etc/nscd.conf``, then restart the daemon:

.. code-block:: bash

	cp doc/config/lucknow/nscd.conf /etc/
	systemctl enable nscd
	systemctl restart nscd

guix
^^^^

Install guix using the instructions provided in its `handbook
<https://guix.gnu.org/manual/en/guix.html#Binary-Installation>`__. Create a
channel configuration in ``/etc/guix/channels.scm``:

.. code-block:: bash

	cp doc/config/lucknow/guix/channels.scm /etc/guix/

Add our substitute server by appending the follownig to :file:`/etc/systemd/system/guix-daemon.service`’s ``ExecStart``

.. code:: systemd

	--substitute-urls='https://substitutes.guix.psychnotebook.org https://ci.guix.gnu.org https://bordeaux.guix.gnu.org'

Authorize the substitute key:

.. code:: console

	guix archive --authorize < src/keys/substitutes.guix.psychnotebook.org.pub

Then restart, pull and restart again:

.. code:: console

	systemctl daemon-reload
	systemctl restart guix-daemon
	guix pull
	systemctl restart guix-daemon

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

	ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
	dn: cn=config
	changetype: modify
	replace: olcAuthzRegexp
	olcAuthzRegexp: {0}uid=([^,]+),cn=PSYCHNOTEBOOK.ORG,cn=gssapi,cn=auth uid=$1,ou=people,dc=psychnotebook,dc=org
	-
	replace: olcSaslRealm
	olcSaslRealm: PSYCHNOTEBOOK.ORG

	dn: olcDatabase={1}mdb,cn=config
	changetype: modify
	replace: olcSuffix
	olcSuffix: dc=psychnotebook,dc=org
	-
	replace: olcAccess
	# Allow access to root
	olcAccess: {0}to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break
	olcAccess: {1}to dn.subtree="ou=people,dc=psychnotebook,dc=org" attrs=x-acceptedTermsEffective by dn.base="cn=pamtos,ou=system,dc=psychnotebook,dc=org" write
	olcAccess: {2}to dn.subtree="ou=terms,dc=psychnotebook,dc=org" by dn.base="cn=pamtos,ou=system,dc=psychnotebook,dc=org" read
	olcAccess: {3}to dn.subtree="ou=people,dc=psychnotebook,dc=org" by dn.base="cn=psychnotebook,ou=system,dc=psychnotebook,dc=org" write by dn.base="cn=sssd,ou=system,dc=psychnotebook,dc=org" read by dn.base="cn=pamtos,ou=system,dc=psychnotebook,dc=org" read
	olcAccess: {4}to dn.subtree="ou=group,dc=psychnotebook,dc=org" by dn.base="cn=psychnotebook,ou=system,dc=psychnotebook,dc=org" write by dn.base="cn=sssd,ou=system,dc=psychnotebook,dc=org" read
	olcAccess: {5}to dn.subtree="cn=krb5,dc=psychnotebook,dc=org" by dn.base="cn=kdc,ou=system,dc=psychnotebook,dc=org" write by dn.base="cn=kadmin,ou=system,dc=psychnotebook,dc=org" write by * none
	# SSSD also need to search its DN root
	olcAccess: {6}to dn.base="dc=psychnotebook,dc=org" by dn.base="cn=sssd,ou=system,dc=psychnotebook,dc=org" read
	# Everyone can authenticate (so LDAP password authentication works)
	olcAccess: {7}to * by * auth
	-
	replace: olcRootDN
	olcRootDN: cn=admin,dc=psychnotebook,dc=org

	# make sure ldap returns an unlimited amount of results for paged queries,
	# so sssd works correctly with large number of groups per user (for
	# example)
	dn: olcDatabase={-1}frontend,cn=config
	changetype: modify
	replace: olcSizeLimit
	olcSizeLimit: unlimited

	dn: dc=psychnotebook,dc=org
	objectClass: top
	objectClass: dcObject
	objectClass: organization
	o: psychnotebook
	dc: psychnotebook

	dn: ou=group,dc=psychnotebook,dc=org
	ou: group
	objectClass: top
	objectClass: organizationalUnit

	dn: ou=people,dc=psychnotebook,dc=org
	ou: people
	objectClass: top
	objectClass: organizationalUnit

	dn: ou=system,dc=psychnotebook,dc=org
	ou: system
	objectClass: top
	objectClass: organizationalUnit

	dn: cn=kdc,ou=system,dc=psychnotebook,dc=org
	cn: kdc
	sn: KDC user
	objectClass: person
	objectClass: top

	dn: cn=kadmin,ou=system,dc=psychnotebook,dc=org
	cn: kadmin
	sn: kadmin user
	objectClass: person
	objectClass: top

	dn: cn=psychnotebook,ou=system,dc=psychnotebook,dc=org
	cn: psychnotebook
	sn: PsychNotebook admin user
	objectClass: person
	objectClass: top

	dn: cn=sssd,ou=system,dc=psychnotebook,dc=org
	cn: sssd
	sn: SSSD user
	objectClass: person
	objectClass: top

	dn: cn=pamtos,ou=system,dc=psychnotebook,dc=org
	cn: pamtos
	sn: pam_tos user
	objectClass: person
	objectClass: top
	EOF

And password-protect each of the accounts kdc, kadmin and psychnotebook using

.. code:: console

	for account in kdc kadmin psychnotebook sssd pamtos; do
		ldappasswd -S -Y EXTERNAL -H ldapi:/// "cn=${account},ou=system,dc=psychnotebook,dc=org"
	done


Configure LDAP client’s defaults at ``/etc/ldap/ldap.conf``

.. code::

	BASE    dc=psychnotebook,dc=org
	URI     ldap://ldap

	TLS_CACERT      /etc/ssl/certs/ca-certificates.crt

	SASL_MECH GSSAPI

Kerberos
^^^^^^^^

.. code:: console

	apt install krb5-admin-server krb5-kdc krb5-kdc-ldap krb5-user 

Use ``PSYCHNOTEBOOK.ORG`` as default realm. Ubuntu has a `guide
<https://help.ubuntu.com/lts/serverguide/kerberos-ldap.html>`__.

Kerberos is configured to use `LDAP as its database backend
<http://web.mit.edu/kerberos/krb5-latest/doc/admin/conf_ldap.html>`__. It
stores its data in ``cn=krb5`` and authenticates using ``cn=kdc,ou=system`` and
``cn=kadmin,ou=system``. It should live on the same machine as the LDAP server,
since both need to interact a lot and using ``ldapi://`` reduces round-trip
times.

.. _install-ldap-schema:

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
		default_realm = PSYCHNOTEBOOK.ORG
		rdns = true
		dns_lookup_kdc = true
		dns_lookup_realm = true
		default_ccache_name = KCM:
		ignore_acceptor_hostname = true

		# The following krb5.conf variables are only for MIT Kerberos.
		kdc_timesync = 1
		ccache_type = 4
		forwardable = true
		proxiable = true

	[realms]
		PSYCHNOTEBOOK.ORG = {
			kdc = kdc
			admin_server = kdc
		}

	[domain_realm]
		.psychnotebook.org = PSYCHNOTEBOOK.ORG

	[dbmodules]
		PSYCHNOTEBOOK.ORG = {
			db_library = kldap
			ldap_kdc_dn = cn=kdc,ou=system,dc=psychnotebook,dc=org
			ldap_kadmind_dn = cn=kadmin,ou=system,dc=psychnotebook,dc=org
			ldap_service_password_file = /etc/krb5kdc/service.keyfile
			ldap_conns_per_server = 5
			ldap_kerberos_container_dn = cn=krb5,dc=psychnotebook,dc=org
			ldap_servers = ldapi:///
		}

.. quirks[

And also add this to :file:`/etc/environment`, which is picked up by
``pam_env`` and overrides SSH’s hardcoded ``FILE:`` token store:

.. code::

	KRB5CCNAME=KCM:

.. ]quirks

Modify ``/etc/krb5kdc/kdc.conf``

.. code::

	[kdcdefaults]
		kdc_ports = 750,88

	[realms]
		PSYCHNOTEBOOK.ORG = {
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

	usermgrd/lucknow@PSYCHNOTEBOOK.ORG adi

Then create the realm and start the server

.. code:: console

	kdb5_ldap_util stashsrvpw -f /etc/krb5kdc/service.keyfile cn=kdc,ou=system,dc=psychnotebook,dc=org
	kdb5_ldap_util stashsrvpw -f /etc/krb5kdc/service.keyfile cn=kadmin,ou=system,dc=psychnotebook,dc=org
	kdb5_ldap_util create -subtrees cn=krb5,dc=psychnotebook,dc=org -r PSYCHNOTEBOOK.ORG -s -D cn=admin,dc=psychnotebook,dc=org -H ldapi:///

	systemctl enable krb5-kdc krb5-admin-server
	systemctl start krb5-kdc krb5-admin-server

Now add a few required principals for ssh (host/master) and NFS (nfs/master).
If ``kadmin.local`` does not work yet, because no KCM was found, comment out
``default_ccache_name`` in ``/etc/krb5.conf`` for now.

.. code:: console

	kadmin.local
	addprinc -randkey ldap/lucknow
	addprinc -randkey host/lucknow
	addprinc -randkey nfs/lucknow
	ktadd nfs/lucknow
	ktadd host/lucknow
	ktadd -k /etc/ldap/keytab ldap/lucknow
	^D
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

Just to be safe, restart LDAP and Kerberos.

.. code:: console

	systemctl restart krb5-kdc slapd

SSSD
^^^^

SSSD combines LDAP user database and Kerberos authentication. It is used
`instead of pam_krb5
<https://docs.pagure.org/SSSD.sssd/users/pam_krb5_migration.html>`__
sssd-kcm_ is used to auto-renew tickets and make life with NFS more enjoyable.

.. _sssd-kcm: https://docs.pagure.org/SSSD.sssd/design_pages/kcm.html

.. code:: console

	apt install sssd sssd-kcm sssd-tools libnss-sss libpam-sss

Configure it in :file:`/etc/sssd/sssd.conf`:

.. code::

	[sssd]
		#services = nss, pam
		domains = psychnotebook.org

	# for clumsy
	[nss]
		entry_negative_timeout = 1

	[domain/psychnotebook.org]
		#debug_level = 9
		id_provider = ldap
		ldap_uri = ldap://ldap
		ldap_search_base = dc=psychnotebook,dc=org
		ldap_default_bind_dn = cn=sssd,ou=system,dc=psychnotebook,dc=org
		ldap_default_authtok = <password here>

		auth_provider = krb5
		krb5_server = kdc
		krb5_realm = PSYCHNOTEBOOK.ORG
		krb5_validate = true
		#krb5_ccachedir = /tmp
		krb5_keytab = /etc/sssd/krb5.keytab
		krb5_ccname_template = KCM:
		krb5_renewable_lifetime = 90d
		krb5_renew_interval = 10m

Add a new principal and export its keytab:

.. code:: console

	kadmin.local
	addprinc -randkey sssd/lucknow
	ktadd -k /etc/sssd/krb5.keytab sssd/lucknow

Due to the kerberized NFS homes it is not possible to use ``.k5login`` and::

	access_provider = krb5

When logging into account *a* as principal *b* NFS will still reject access,
since principal *b* cannot be mapped to the UNIX user *a*. Set proper
permissions and start the daemon:

.. code:: console

	chmod 600 /etc/sssd/sssd.conf
	systemctl enable sssd sssd-kcm
	systemctl start sssd sssd-kcm

PAM configuration is handled by Ubuntu, but we need to enable it in :file:`nssswitch.conf`:

.. code-block:: bash

	cp doc/config/lucknow/nssswitch.conf /etc

PAM
^^^

.. No need to pay attention to pam-auth-update, which only touches common-* files.

Install the ``pam_tos`` module:

.. code:: console

	git clone https://github.com/leibniz-psychology/pam_tos.git
	cd pam_tos
	sudo apt install libpam0g-dev libldap2-dev
	make
	sudo make install SECURITYDIR=/lib/x86_64-linux-gnu/security

Add its configuration:

.. code:: console

	cat <<EOF > /etc/pam-tos.conf
	baseDn ou=terms,dc=psychnotebook,dc=org
	userDnFormat uid=%s,ou=people,dc=psychnotebook,dc=org
	ldapUri ldap://ldap
	bindDn cn=pamtos,ou=system,dc=psychnotebook,dc=org
	bindPassword <password here>
	EOF

Add the schema from :file:`pam-tos.schema` to OpenLDAP, see :ref:`above
<install-ldap-schema>`. Also enable the following option in
:file:`/etc/ssh/sshd_config`:

.. code::

	ChallengeResponseAuthentication yes

Add some terms of service (you can :ref:`change them later <tosupdate>`):

.. code:: console

	ldapadd -Y EXTERNAL -H ldapi:/// <<EOF
	dn: ou=terms,dc=psychnotebook,dc=org
	ou: terms
	objectClass: top
	objectClass: organizationalUnit

	dn: x-termsId=tosde,ou=terms,dc=psychnotebook,dc=org
	objectClass: top
	objectClass: x-termsAndConditions
	x-termsId: tosde
	x-termsKind: tos
	x-termsLanguage: de
	x-termsContent: placeholder
	x-termsEffective: 197001010000Z

	dn: x-termsId=tosen,ou=terms,dc=psychnotebook,dc=org
	objectClass: top
	objectClass: x-termsAndConditions
	x-termsId: tosen
	x-termsKind: tos
	x-termsLanguage: en
	x-termsContent: placeholder
	x-termsEffective: 197001010000Z

	dn: x-termsId=privacyde,ou=terms,dc=psychnotebook,dc=org
	objectClass: top
	objectClass: x-termsAndConditions
	x-termsId: privacyde
	x-termsKind: privacy
	x-termsLanguage: de
	x-termsContent: placeholder
	x-termsEffective: 197001010000Z

	dn: x-termsId=privacyen,ou=terms,dc=psychnotebook,dc=org
	objectClass: top
	objectClass: x-termsAndConditions
	x-termsId: privacyen
	x-termsKind: privacy
	x-termsLanguage: en
	x-termsContent: placeholder
	x-termsEffective: 197001010000Z
	EOF

Add the following account line to :file:`/etc/pam.d/sshd` to activate the
module:

.. code::

	@include common-auth
	…
	account    required     pam_tos.so  config=/etc/pam-tos.conf
	…
	@include common-account

SSH
^^^

Kerberize SSH by adding the following to ``/etc/ssh/sshd_config.d/kerberos.conf``

.. code::

	GSSAPIAuthentication yes
	GSSAPICleanupCredentials yes
	GSSAPIStrictAcceptorCheck yes
	GSSAPIKeyExchange yes

Also allow Kerberos ticket forwarding in ``/etc/ssh/ssh_config.d/kerberos.conf``

.. code::

	Host ssh
		GSSAPIAuthentication yes
		GSSAPIDelegateCredentials yes
		GSSAPIKeyExchange yes

Add every SSH key of every node and master to every host’s :file:`/etc/ssh/ssh_known_hosts`.

For bawwab_, password-based authentication must be enabled. We also need
more than the default ten sessions per connection. Thus set:

.. code::

	PasswordAuthentication yes
	MaxSessions 1000

Now restart sshd:

.. code:: console

	systemctl restart sshd

.. Not applicable right now:

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

Enable the firewall to protect LDAP and Kerberos server, which cannot
be bound to localhost.

.. code:: console

	ufw default deny incoming
	ufw default allow outgoing
	ufw allow ssh
	ufw allow http
	ufw allow https
	ufw enable

Local admins
^^^^^^^^^^^^

Add profile admins, which can modify the packages installed in the following sections:

.. code:: console

	groupadd profileadmin
	mkdir /usr/local/profiles
	chmod 775 /usr/local/profiles
	chmod g+s /usr/local/profiles
	chgrp profileadmin /usr/local/profiles
	usermod -a -G profileadmin <admin user>

clumsy
^^^^^^

.. code:: console

	git clone https://github.com/leibniz-psychology/clumsy.git
	cd clumsy
	guix package -p /usr/local/profiles/clumsy -f contrib/clumsy.scm
	pushd /usr/local/bin
	ln -sv ../profiles/clumsy/bin/usermgr .
	popd

	# Create config files
	mkdir /etc/clumsy
	chmod 750 /etc/clumsy

	cp doc/config/lucknow/clumsy/* /etc/clumsy/
	kadmin.local ktadd -k /etc/clumsy/usermgrd.keytab usermgr/lucknow

	# then configure systemd
	cp contrib/*.service /etc/systemd/system
	# Adjust file paths for ExecStart and Environment
	systemctl daemon-reload
	for service in mkhomedird nscdflushd usermgrd; do
		systemctl enable $service
		systemctl start $service
	done

You should also populate :file:`/etc/skel`, so Ubuntu does not show its legal
info to new users. We cannot disable ``pam_motd``, because we *want* to show a
motd to users.

.. code:: console

	mkdir -p /etc/skel/.cache
	touch /etc/skel/.cache/motd.legal-displayed

conductor
^^^^^^^^^

Same procedure:

.. code:: console

	git clone https://github.com/leibniz-psychology/conductor.git
	cd conductor
	guix package -p /usr/local/profiles/conductor -f contrib/conductor.scm
	useradd -r -M -U -d /nonexistent conductor
	# make it available globally
	ln -sv ../profiles/conductor/bin/conductor /usr/local/bin/
	# make sure nginx can access it
	usermod -a -G conductor www-data

	cp contrib/*.service /etc/systemd/system
	# edit service file again
	systemctl daemon-reload
	systemctl enable conductor
	systemctl start conductor

mashru3
^^^^^^^

Similar procedure:

.. code:: console

	git clone https://github.com/leibniz-psychology/mashru3.git
	cd mashru3
	guix package -p /usr/local/profiles/mashru3 -f contrib/mashru3.scm
	# make the command available globally
	ln -sv ../profiles/mashru3/bin/workspace /usr/local/bin/

	# configuration
	rsync -av doc/config/lucknow/mashru3/ /etc/mashru3/
	chgrp -Rv profileadmin /etc/mashru3/skel
	chmod -Rv g+s /etc/mashru3/skel

Then initialize the profile:

.. code:: console

	pushd /etc/mashru3/skel
	guix pull -p .config/guix/current
	.config/guix/current/bin/guix package -m .config/guix/manifest.scm -p .guix-profile -i tini
	guix pull -d .config/guix/current
	.config/guix/current/bin/guix package -d -p .guix-profile

We also need a dummy user with the UID 1000, because that’s the user inside the Guix environment.

.. code:: console

	useradd -M -u 1000 -c 'guix environment dummy user' joeuser

borg
^^^^

Bawwab_ needs a working installation of ``borg``:

.. code:: console

    guix package -p /usr/local/profiles/borg -i borg
    pushd /usr/local/bin && ln -sv ../profiles/borg/bin/borg && popd

bawwab
^^^^^^

Again, same procedure:

.. code-block:: bash

	git clone https://github.com/leibniz-psychology/bawwab.git
	cd bawwab
	# also install certificates, which are required to contact SSL SSO
	guix package -p /usr/local/profiles/bawwab -L contrib/guix -i bawwab nss-certs trash-cli
	pushd /usr/local/bin && ln -sv ../profiles/bawwab/bin/trash && popd

	# create a separate user
	useradd -r -M -U -d /var/lib/bawwab bawwab
	# And make sure the www user has access to the socket
	usermod -a -G bawwab www-data

	mkdir /etc/bawwab
	chmod 750 /etc/bawwab
	chgrp bawwab /etc/bawwab
	cp doc/config/lucknow/bawwab/config.py /etc/bawwab/

	kadmin.local ktadd -k /etc/bawwab/bawwab.keytab bawwab/lucknow
	chown root:bawwab /etc/bawwab/bawwab.keytab
	chmod 640 /etc/bawwab/bawwab.keytab

Edit the config file, making sure ``SERVER_NAME`` is set to
``'https://www.psychnotebook.org/api'``.  Then create database directories:

.. code-block:: bash

	mkdir /var/lib/bawwab
	chmod 770 /var/lib/bawwab
	chown bawwab:bawwab /var/lib/bawwab

	cp contrib/*.service /etc/systemd/system
	# edit service file again
	systemctl daemon-reload
	systemctl enable bawwab
	systemctl start bawwab

If projects can be located on another partition, a .Trash directory with mode
1777 (writable by anyone, with sticky bot) should be created, so ``trash-cli``
works properly.

bawwab-client
^^^^^^^^^^^^^

.. code-block:: bash

	git clone https://github.com/leibniz-psychology/bawwab-client.git
	cd bawwab-client
	# Install into same profile as bawwab, because they only work as a unit.
	guix package -p /usr/local/profiles/bawwab -L contrib/guix -i bawwab-client

nginx
^^^^^

nginx serves as a reverse proxy for all applications.

.. code-block:: bash

	# Install nginx
	apt install nginx

	# Then install the ngx_brotli module by manually compiling it.
	apt install libgd-dev libxslt1-dev libssl-dev libpcre3-dev
	git clone https://github.com/google/ngx_brotli.git
	pushd ngx_brotli
	apt-get source nginx
	pushd nginx-$version
	./configure `nginx -V 2>&1 | sed -nre 's/configure arguments: //p'` --add-dynamic-module=`pwd`/../
	make modules
	mkdir -p /usr/local/lib/nginx/modules/
	cp objs/{ngx_http_brotli_filter_module.so,ngx_http_brotli_static_module.so} /usr/local/lib/nginx/modules/
	popd
	popd

Then copy the nginx configuration itself:

.. code-block:: bash

	rsync -av doc/config/lucknow/nginx/ /etc/nginx/

Replace the secret for the ``Forwarded`` header with the secret you’re
using for bawwab_’s ``FORWARDED_SECRET``.

Then apply the changes:

.. code-block:: bash

	systemctl restart nginx

collectd
^^^^^^^^

collectd collects statistics.

.. code:: console

	guix package -p /usr/local/profiles/collectd -i collectd

Add the configuration to :file:`/etc/collectd.conf`.

.. literalinclude:: collectd.conf

Add a systemd unit:

.. code:: console

	cp doc/config/lucknow/systemd/system/collectd.service /etc/systemd/system/
	systemctl daemon-reload
	systemctl enable collectd
	systemctl start collectd

Enable statistics collection:

	systemctl enable --now psychnotebook-stats-collect

Backups
^^^^^^^

To automate the process basically we need a script, systemd service and timer.
Systemd service runs the script everyday by 3AM.

In production server:

.. code:: console

	cp tools/backup/backup.service /etc/systemd/system
	cp tools/backup/backup.timer /etc/systemd/system
	cp tools/backup/backup.sh /usr/local/sbin
	systemctl daemon-reload
	systemctl enable backup.timer
	systemctl start backup.timer

Generate a SSH key for root user.

.. code:: console

   ssh-keygen

Auditing
--------

.. code-block:: bash

	apt install msmtp
	cp tools/audit/audit-mail.sh /usr/local/sbin/
	cp tools/audit/audit-mail.{service,timer} /etc/systemd/system

	cat > /root/.msmtprc <<EOF
	defaults

	logfile -
	tls on
	port 587

	account default
	host mail3.web-server.biz
	from donot-reply@psychnotebook.org
	auth on
	user XXX
	password XXX
	EOF
	chmod 600 /root/.msmtprc
	systemctl enable --now audit-mail.timer

yamunanagar
-----------

Substitutes for guix-science and guix-zpid channels. Hosted at Hetzner and
configured with guix, see `machine config`_. Currently an mcron
job frequently pulls from these channels and builds any changes. Statistics are
available at https://yamunanagar.psychnotebook.org/stats/localhost/

.. _machine config: https://github.com/leibniz-psychology/psychnotebook-deploy/blob/master/src/zpid/machines/yamunanagar/


