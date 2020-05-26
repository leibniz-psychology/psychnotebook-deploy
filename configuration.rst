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

	# make sure ldap returns an unlimited amount of results for paged queries,
	# so sssd works correctly with large number of groups per user (for
	# example)
	dn: olcDatabase={-1}frontend,cn=config
	changetype: modify
	replace: olcSizeLimit
	olcSizeLimit: unlimited

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

	cp contrib/*.service /etc/systemd/system
	# edit service file again
	systemctl daemon-reload
	systemctl enable conductor
	systemctl start conductor

bawwab
^^^^^^

Again, same procedure:

.. code:: console

	git clone https://github.com/leibniz-psychology/bawwab.git
	cd bawwab
	guix package -p /usr/local/profiles/bawwab -f contrib/bawwab.scm

	mkdir /etc/bawwab
	chmod 750 /etc/bawwab
	cp contrib/config.py /etc/bawwab/
	# edit the config file

	cp contrib/*.service /etc/systemd/system
	# edit service file again
	systemctl daemon-reload
	systemctl enable bawwab
	systemctl start bawwab

nginx
^^^^^

nginx serves as a reverse proxy for all applications.

.. code:: console

	apt install nginx

Then configure it:

.. code:: console

	cat <<EOF > /etc/nginx/sites-available/bawwab
	server {
			listen 80;
			listen [::]:80;

			root /nonexistent;

			server_name www.dev.compute.zpid.de;

			location / {
				proxy_set_header Host $host;
				proxy_set_header X-Real-IP $remote_addr;
				proxy_pass http://unix:/run/bawwab/bawwab.socket:/;
				proxy_http_version 1.1;
				proxy_set_header Upgrade $http_upgrade;
				proxy_set_header Connection $connection_upgrade;
				# reduce latency
				proxy_buffering off;
				proxy_request_buffering off;
			}
	}
	EOF

	cat <<EOF > /etc/nginx/sites-available/conductor
	map $http_upgrade $connection_upgrade {
	default upgrade;
	''      close;
	}

	server {
			listen 80 default_server;
			listen [::]:80 default_server;

			root /nonexistent;

			server_name .userapp.local;

			location / {
				proxy_set_header Host $host;
				proxy_set_header X-Real-IP $remote_addr;
				proxy_pass http://unix:/run/conductor/conductor.socket:/;
				proxy_http_version 1.1;
				proxy_set_header Upgrade $http_upgrade;
				proxy_set_header Connection $connection_upgrade;
				# reduce latency
				proxy_buffering off;
				proxy_request_buffering off;

				# Alter CSP, so we can embed into iframes
				proxy_hide_header x-frame-options;
				proxy_hide_header content-security-policy;
				add_header Content-Security-Policy "frame-ancestors 'self' https://www.psychnotebook.org;" always;
			}
	}
	EOF

	ln -sv ../sites-available/bawwab /etc/nginx/sites-enabled/bawwab
	ln -sv ../sites-available/conductor /etc/nginx/sites-enabled/conductor
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
	<URL "https://user.psychnotebook.org/_conductor/status">
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
	<URL "https://www.psychnotebook.org/api/status">
		Instance "bawwab"
		<Key "session/active10m">
			Type "current_sessions"
		</Key>

		<Key "user/total">
			Type "users"
		</Key>
		<Key "user/anonymous">
			Type "users"
		</Key>
		<Key "user/login1d">
			Type "users"
		</Key>

		<Key "workspace/total">
			Type "objects"
		</Key>

		<Key "application/total/all">
			Type "objects"
		</Key>
		<Key "application/active1d/jupyterlab">
			Type "objects"
		</Key>
		<Key "application/active1d/rstudio">
			Type "objects"
		</Key>
		<Key "application/active1d/all">
			Type "objects"
		</Key>
		<Key "application/activeNow">
			Type "current_sessions"
		</Key>

		<Key "status/collecttime">
			Type "response_time"
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

