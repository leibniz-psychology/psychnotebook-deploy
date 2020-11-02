Configuration
=============

This sections details the software installed on the production system. It
assumes Ubuntu 20.04 as the host system.

Currently only a single server without compute separate compute nodes
exists. Servers are being named after `Indian cities`_. In the long run we’d
like to move everything to GNU Guix-based servers.

.. _Indian cities: https://en.wikipedia.org/wiki/List_of_cities_in_India_by_population

DNS
^^^

External DNS configuration:

.. code::

	; Main origin and servers.
	$ORIGIN psychnotebook.org
	; Our main server.
	tiruchirappalli IN A 136.199.86.20
	; The previous production server on VMWare, until migration is done.
	visakhapatnam IN A 136.199.85.40
	; Current backup server
	muzaffarnagar IN A 136.199.86.65
	; Production sites
	; Cannot CNAME the TLD, must reference loadbalancer.prd
	@ IN A 136.199.85.125
	www IN CNAME loadbalancer.prd
	*.user IN CNAME loadbalancer.prd

	; production (prd)
	$ORIGIN prd.psychnotebook.org
	; Service aliasas
	; Load balancer
	loadbalancer IN A 136.199.85.125
	; Backup server
	backup IN CNAME muzaffarnagar.psychnotebook.org.
	; Public web services.
	@ IN CNAME bawwab
	www IN CNAME bawwab
	*.user IN CNAME conductor
	; SSH user login
	ssh IN CNAME tiruchirappalli.psychnotebook.org.
	; Authentication
	kdc IN CNAME tiruchirappalli.psychnotebook.org.
	ldap IN CNAME tiruchirappalli.psychnotebook.org.
	; NFS
	nfs IN CNAME tiruchirappalli.psychnotebook.org.
	; Guix master
	guix IN CNAME tiruchirappalli.psychnotebook.org.
	; Conductor web proxy
	conductor IN CNAME tiruchirappalli.psychnotebook.org.
	; Client app
	bawwab IN CNAME tiruchirappalli.psychnotebook.org.

	; staging (stg)
	$ORIGIN stg.psychnotebook.org

	; Service aliasas
	; Public web services
	@ IN CNAME bawwab
	www IN CNAME bawwab
	*.user IN CNAME conductor
	; SSH user login
	ssh IN CNAME visakhapatnam.psychnotebook.org.
	; Authentication
	kdc IN CNAME visakhapatnam.psychnotebook.org.
	ldap IN CNAME visakhapatnam.psychnotebook.org.
	; NFS
	nfs IN CNAME visakhapatnam.psychnotebook.org.
	; Guix master
	guix IN CNAME visakhapatnam.psychnotebook.org.
	; Conductor web proxy
	conductor IN CNAME visakhapatnam.psychnotebook.org.
	; Client app
	bawwab IN CNAME visakhapatnam.psychnotebook.org.

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
                (url "https://git.savannah.gnu.org/git/guix.git")
                (introduction
                  (make-channel-introduction
                    "9edb3f66fd807b096b48283debdcddccfea34bad"
                    (openpgp-fingerprint
                      "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))
        (channel
                (name 'zpid)
                (url "https://github.com/leibniz-psychology/guix-zpid.git")))

Then run ``guix pull`` as root and restart the daemon with ``systemctl restart
guix-daemon``. Clean up the dirt with ``guix pull -d``.

From the node guix opens an SSH tunnel to the master node’s UNIX domain socket
via a guile interpreter. This binary must be in ``PATH``, thus run as root:

.. code:: console

	guix install guile
	ln -sv /var/guix/profiles/per-user/root/guix-profile/bin/guile /usr/local/bin/

Then append

.. code::

	export GUIX_LOCPATH=$GUIX_PROFILE/lib/locale

to ``/etc/profile.d/guixenv.sh``

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
	olcAccess: {1}to dn.subtree="ou=people,dc=psychnotebook,dc=org" by dn.base="cn=psychnotebook,ou=system,dc=psychnotebook,dc=org" write by dn.base="cn=sssd,ou=system,dc=psychnotebook,dc=org" read
	olcAccess: {2}to dn.subtree="ou=group,dc=psychnotebook,dc=org" by dn.base="cn=psychnotebook,ou=system,dc=psychnotebook,dc=org" write by dn.base="cn=sssd,ou=system,dc=psychnotebook,dc=org" read
	olcAccess: {3}to dn.subtree="cn=krb5,dc=psychnotebook,dc=org" by dn.base="cn=kdc,ou=system,dc=psychnotebook,dc=org" write by dn.base="cn=kadmin,ou=system,dc=psychnotebook,dc=org" write by * none
	# SSSD also need to search its DN root
	olcAccess: {4}to dn.base="dc=psychnotebook,dc=org" by dn.base="cn=sssd,ou=system,dc=psychnotebook,dc=org" read
	# Everyone can authenticate (so LDAP password authentication works)
	olcAccess: {5}to * by * auth
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
	EOF

And password-protect each of the accounts kdc, kadmin and psychnotebook using

.. code:: console

	for account in kdc kadmin psychnotebook sssd; do
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

	usermgrd/tiruchirapalli@PSYCHNOTEBOOK.ORG adi

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
	addprinc -randkey ldap/tiruchirapalli
	addprinc -randkey host/tiruchirapalli
	addprinc -randkey nfs/tiruchirapalli
	ktadd nfs/tiruchirapalli
	ktadd host/tiruchirapalli
	ktadd -k /etc/ldap/keytab ldap/tiruchirapalli
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

	apt install sssd sssd-kcm sssd-tools

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
	addprinc -randkey sssd/tiruchirapalli
	ktadd -k /etc/sssd/krb5.keytab sssd/tiruchirapalli

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

Also allow Kerberos ticket forwarding in ``/etc/ssh/ssh_config.d/kerberos.conf``

.. code::

	Host ssh
		GSSAPIAuthentication yes
		GSSAPIDelegateCredentials yes
		GSSAPIKeyExchange yes

Add every SSH key of every node and master to every host’s :file:`/etc/ssh/ssh_known_hosts`.

For bawwab_, password-based authentication must be enabled. Thus set:

.. code::

	PasswordAuthentication yes

Now restart sshd:

.. code:: console

	systemctl restart sshd

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

Local admins
^^^^^^^^^^^^

Add profile admins, which can modify the packages installed in the following sections:

.. code:: console

	groupadd profileadmin
	mkdir /usr/local/profiles
	chmod 775 /usr/local/profiles
	chgrp profileadmin /usr/local/profiles
	usermod -a -G profileadmin <admin user>

clumsy
^^^^^^

.. code:: console

	git clone https://github.com/leibniz-psychology/clumsy.git
	cd clumsy
	guix package -p /usr/local/profiles/clumsy -f contrib/clumsy.scm

	# copy config files
	mkdir /etc/clumsy
	chmod 750 /etc/clumsy
	cp contrib/*.config /etc/clumsy
	# now edit them

	# then configure systemd
	cp contrib/*.service /etc/systemd/system
	# Adjust file paths for ExecStart
	systemctl daemon-reload
	systemctl enable …
	systemctl start …

conductor
^^^^^^^^^

Same procedure:

.. code:: console

	git clone https://github.com/leibniz-psychology/conductor.git
	cd conductor
	guix package -p /usr/local/profiles/conductor -f contrib/conductor.scm
	useradd -r -M -U -d /var/forest conductor
	# make it available globally
	ln -sv ../profiles/conductor/bin/conductor /usr/local/bin/
	ln -sv ../profiles/conductor/bin/conductor-pipe /usr/local/bin/
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
	mkdir /etc/mashru3
	cat <<EOF > /etc/mashru3/config.yaml
	forest: conductor:/var/forest
	EOF
	mkdir -p /etc/mashru3/skel/.config/guix
	# Add default profile packages
	cat <<EOF > /etc/mashru3/skel/.config/guix/manifest.scm
	(specifications->manifest
	 '("glibc-utf8-locales"

	   ;; basic shell utils
	   "bash"
	   "findutils"
	   "coreutils"
	   "grep"
	   "less"
	   "which"
	   ;; SSL-support
	   "nss-certs"

	   "psychnotebook-app-rstudio"
	   "psychnotebook-app-jupyterlab"
	   "psychnotebook-app-rmarkdown"
	   ;; for RMarkdown
	   ;"r-knitr"
	   ;"r-yaml"
	   ;"r-markdown"
	   ;"r-rmarkdown"
	   "texlive"
	   ;; commonly used r packages
	   "r-psych"
	   "r-ggplot2"
	   "r-lattice"
	   "r-foreign"
	   "r-readr"
	   "r-haven"
	   "r-dplyr"
	   "r-tidyr"
	   "r-stringr"
	   "r-forecast"
	   "r-lme4"
	   "r-nlme"
	   "r-nnet"
	   "r-glmnet"
	   "r-caret"
	   "r-xmisc"
	   "r-splitstackshape"
	   "r-tm"
	   "r-quanteda"
	   "r-topicmodels"
	   "r-stm"
	   ;;"r-parallel"
	   "r-dt"
	   "r-nlp"
	   ))
	EOF

Then initialize the profile:

.. code:: console

	pushd /etc/mashru3/skel
	cp /etc/guix/channels.scm .config/guix/channels.scm
	rm .guix-profile
	guix pull -C .config/guix/channels.scm -p .config/guix/current
	.config/guix/current/bin/guix environment -m .config/guix/manifest.scm -r .guix-profile --search-paths

We also need a dummy user with the UID 1000, because that’s the user inside the Guix environment.

.. code:: console

	useradd -M -u 1000 -c 'guix environment dummy user' joeuser

bawwab
^^^^^^

Again, same procedure:

.. code:: console

	git clone https://github.com/leibniz-psychology/bawwab.git
	cd bawwab
	guix package -p /usr/local/profiles/bawwab -f contrib/bawwab.scm
	# also install certificates, which are required to contact SSL SSO
	guix package -p /usr/local/profiles/bawwab -i nss-certs
	# and install trash-cli, which is used by bawwab
	apt install trash-cli

	# create a separate user
	useradd -r -M -U -d /var/db/bawwab bawwab
	# And make sure the www user has access to the socket
	usermod -a -G bawwab www-data

	mkdir /etc/bawwab
	chmod 750 /etc/bawwab
	chgrp bawwab /etc/bawwab
	cp contrib/config.py /etc/bawwab/
	# edit the config file
	# then create database directories
	mkdir /var/db/bawwab
	chmod 770 /var/db/bawwab
	chown bawwab:bawwab /var/db/bawwab

	cp contrib/*.service /etc/systemd/system
	# edit service file again
	systemctl daemon-reload
	systemctl enable bawwab
	systemctl start bawwab

If projects can be located on another partition, a .Trash directory with mode
1777 (writable by anyone, with sticky bot) should be created, so ``trash-cli``
works properly.

nginx
^^^^^

nginx serves as a reverse proxy for all applications.

.. code:: console

	apt install nginx

Then configure it:

.. code:: console

	cat <<EOF > /etc/nginx/sites-available/bawwab
	# redirects to proper domain (no ssl yet)
	server {
		listen      80 default_server;
		listen      [::]:80 default_server;
		server_name prd.compute.zpid.de psychnotebook.org psych-notebook.org www.psych-notebook.org psychnotebooks.org www.psychnotebooks.org;

		location ^~ / {
				return 301 https://www.psychnotebook.org\$request_uri;
		}
	}

	server {
			listen 80;
			listen [::]:80;

			root /usr/local/profiles/bawwab/lib/python3.8/site-packages/bawwab/assets/;

			server_name www.psychnotebook.org www.stg.psychnotebook.org;

			# do not send this header, it’ll default to unix timestamp 0 due to guix
			add_header  Last-Modified  "";
			add_header Cache-Control 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0';
			add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
			add_header Content-Security-Policy-Report-Only "default-src 'self' *.user.psychnotebook.org www.lifp.de; script-src 'self' 'unsafe-inline' 'unsafe-eval' www.lifp.de; report-uri https://www.psychnotebook.org/api/csp";
			expires off;
			etag off;

			# server maintenance
			#return 503;

			location / {
					index /app.html;
					try_files \$uri \$uri/ /app.html;
			}

			location /assets/ {
					alias /usr/local/profiles/bawwab/lib/python3.8/site-packages/bawwab/assets/;
			}

			location /assets/fontawesome/ {
					alias /var/www/fontawesome/;
			}

			location /api/ {
					proxy_set_header Host \$host;
					#proxy_set_header X-Real-IP \$remote_addr;
					proxy_pass http://unix:/run/bawwab/bawwab.socket:/api/;
					proxy_http_version 1.1;
					proxy_set_header Upgrade \$http_upgrade;
					proxy_set_header Connection \$connection_upgrade;
					# reduce latency
					proxy_buffering off;
					proxy_request_buffering off;
					proxy_set_header Forwarded "for=_hidden;proto=https;by=_fooshyair5;host=\$server_name";
			}

			location /stats/ {
					alias /var/www/stats/;
					autoindex on;
			}
	}
	EOF

	cat <<EOF > /etc/nginx/sites-available/conductor
	map \$http_upgrade \$connection_upgrade {
	default upgrade;
	''      close;
	}

	server {
			listen 80;
			listen [::]:80;

			root /nonexistent;

			server_name .user.prd.psychnotebook.org user.stg.psychnotebook.org .user.psychnotebook.org conductor.psychnotebook.org conductor;

			# disable body size limit for applications, which may provide upload functionality
			client_max_body_size 0;

			location / {
				proxy_set_header Host \$host;
				proxy_set_header X-Real-IP \$remote_addr;
				proxy_pass http://unix:/run/conductor/conductor.socket:/;
				proxy_http_version 1.1;
				proxy_set_header Upgrade \$http_upgrade;
				proxy_set_header Connection \$connection_upgrade;

					# reduce latency
					proxy_buffering off;
					proxy_request_buffering off;

					# using CSP
					proxy_hide_header x-frame-options;
					proxy_hide_header content-security-policy;
					add_header Content-Security-Policy "frame-ancestors 'self' https://www.psychnotebook.org;" always;

					add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
			}
	}
	EOF

	cat <<EOF > /etc/nginx/sites-available/localhost
	server {
			listen   localhost:80;
			server_name localhost;

			location /nginx/status {
					stub_status;
			}
	}
	EOF

	ln -sv ../sites-available/bawwab /etc/nginx/sites-enabled/bawwab
	ln -sv ../sites-available/conductor /etc/nginx/sites-enabled/conductor
	ln -sv ../sites-available/localhost /etc/nginx/sites-enabled/localhost
	systemctl restart nginx

collectd
^^^^^^^^

collectd collects statistics.

.. code:: console

	guix package -p /usr/local/profiles/collectd -i collectd

Add the configuration:

.. code:: console

	cat <<EOF > /etc/collectd.conf
	BaseDir "/var/lib/collectd"
	PIDFile "/run/collectd/collectd.pid"
	Interval 10.0

	LoadPlugin curl_json
	LoadPlugin cpu
	LoadPlugin load
	LoadPlugin rrdtool
	LoadPlugin df
	LoadPlugin disk
	LoadPlugin fhcount
	LoadPlugin interface
	LoadPlugin memory
	LoadPlugin nginx
	LoadPlugin processes
	LoadPlugin tcpconns
	LoadPlugin vmem

	<Plugin curl_json>
	<URL "https://conductor/_conductor/status">
		Instance "conductor"
		<Key "requestTotal">
			Type "http_requests"
		</Key>

		<Key "requestActive">
			Type "current_connections"
		</Key>

		<Key "routesTotal">
			Type "current_sessions"
		</Key>

		<Key "broken">
			Type "http_requests"
		</Key>

		<Key "noroute">
			Type "http_requests"
		</Key>

		<Key "unauthorized">
			Type "http_requests"
		</Key>
	</URL>
	</Plugin>

	<Plugin cpu>
		ReportByCpu false
	</Plugin>

	<Plugin disk>
		Disk "sda"
	</Plugin>

	<Plugin df>
		MountPoint "/"
	</Plugin>

	<Plugin interface>
		Interface "ens160"
	</Plugin>

	<Plugin nginx>
		URL "http://localhost/nginx/status"
	</Plugin>

	<Plugin tcpconns>
		LocalPort 80
		LocalPort 22
	</Plugin>
	EOF

Add a systemd unit:

.. code:: console

	cat << EOF > /etc/systemd/system/collectd.service
	[Unit]
	Description=Statistics collection

	[Service]
	ExecStart=/usr/local/profiles/collectd/sbin/collectd -C /etc/collectd.conf -f
	StandardOutput=syslog
	StandardError=syslog
	RuntimeDirectory=collectd/

	[Install]
	WantedBy=multi-user.target
	EOF

	systemctl daemon-reload
	systemctl enable collectd
	systemctl start collectd

Backup
^^^^^^

For psychnotebook, we would like to take the backup of important files of production to backup server daily by 3AM.
Backup server DNS entry is backup.prd.psychnotebook.org.

To accomplish the goal data backup software 'Borg' is used. Details are in `Borg Docs 
<https://borgbackup.readthedocs.io>`__.
To automate the process basically we need a script, systemd service and timer. Systemd service runs the script everyday by 3AM.

In production server:

.. code:: console

	git clone https://github.com/leibniz-psychology/psychnotebook-admin-tools.git
	cp backup/backup.service /etc/systemd/system
	cp backup/backup.timer /etc/systemd/system
	cp backup/backup.sh /usr/local/sbin
	systemctl daemon-reload
	systemctl enable backup.timer
	systemctl start backup.timer

Generate a SSH key for root user.

.. code:: console

   ssh-keygen

Add the following line to ``~/.ssh/authorized_keys`` on the backup server,
replacing ``<public key>`` with root’s public key
(``~/.ssh/id_<something>.pub``).

.. code:: 

   command="borg serve --restrict-to-path /storage/backup",restrict <public key>


In backup server:

Create a new user namely psychnotebook.

.. code:: console

   useradd psychnotebook

Initialise the repository /storage/backup with an empty passphrase and change the owner.

.. code:: console

   borg init --encryption=authenticated-blake2 /storage/backup
   chown -R psychnotebook:psychnotebook /storage/backup

Add the pruning scripts from the admin tools, namely:

.. code:: console

	cp backup/backup-prune.service /etc/systemd/system
	cp backup/backup-prune.timer /etc/systemd/system
	systemctl daemon-reload
	systemctl enable backup-prune.timer
	systemctl start backup-prune.timer

