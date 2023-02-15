import asyncio, re, sys, json
from functools import partial

bawwabIgnoreEvents = {'connmgr.cleanup.alive',
		'bawwab.filesystem.fileop',
		'bawwab.process.message',
		'bawwab.session.expire',
		'bawwab.session.login.start',
		'bawwab.session.login.success',
		'bawwab.user.create',
		'connmgr.cleanup.purge',
		'connmgr.cleanup.start',
		'bawwab.session.delete',
		'bawwab.user.delete',
		}
def matchBawwab (s):
	try:
		o = json.loads (s)
	except json.decoder.JSONDecodeError:
		return True
	e = o.get ('event')
	message = o.get ('message')
	return e in bawwabIgnoreEvents \
			or (e.startswith ('logging.') and o.get ('level') == 'info') \
			or (e == 'bawwab.app.error' and o.get ('status') in {'nonexistent', 'notfound', 'unauthenticated'}) \
			or (e == 'logging.sanic.error' and message == 'Websocket timed out waiting for pong') \
			or (e == 'logging.asyncio' and 'coro=<WebsocketFrameAssembler.get()' in message)

def matchUsermgrd (s):
	try:
		o = json.loads (s)
	except json.decoder.JSONDecodeError:
		return True
	level = o.get ('level')
	return level in {'info'}

matchMkhomedird = matchUsermgrd
matchConductor = matchUsermgrd
matchNscdflushd = matchUsermgrd

filter = [
	# SSHd also runs in user slices, so match _COMM.
	#({'_COMM': 'sshd'},
	({"SYSLOG_IDENTIFIER": "sshd", "_TRANSPORT": "syslog"},
		[
		r'^Bad packet length \d+\. \[preauth\]$',
		r'^Accepted (gssapi-keyex|publickey|keyboard-interactive/pam) for [^ ]+ from [^ ]+ port \d+ ssh2',
		r'^Authorized to [^,]+, krb5 principal [^ ]+ \(krb5_kuserok\)$',
		r'^Connection (reset|closed) by ((invalid|authenticating) user [^ ]* )?[^ ]+ port \d+ \[preauth\]$',
		r'^Disconnected from ((authenticating |invalid )?user [^ ]* )?[^ ]+ port \d+( \[preauth\])?$',
		r'^Disconnected from user [^ ]+ [^ ]+ port \d+',
		r'^Disconnecting (invalid|authenticating) user [^ ]* [^ ]+ port \d+: Too many authentication failures \[preauth\]',
		r'^error: kex_exchange_identification: ',
		r'^error: maximum authentication attempts exceeded for (invalid user )?[^ ]* from [^ ]+ port \d+ ssh2 \[preauth\]$',
		r'^error: PAM: Authentication failure for (illegal user )?[^ ]+ from ',
		r'^error: Protocol major versions differ: \d+ vs\. \d+$',
		r'^Failed keyboard-interactive/pam for invalid user [^ ]+ from [^ ]+ port \d+ ssh2',
		r'^Failed (password|none) for (invalid user )?[^ ]+ from [^ ]+ port \d+ ssh2$',
		r'^Invalid user [^ ]* from [^ ]+ port \d+$',
		r'^PAM \d+ more authentication failures?; ',
		r'^PAM service\(sshd\) ignoring max retries\; \d+ > \d+',
		r'^pam_sss\(sshd:auth\): authentication success; ',
		r'^pam_sss\(sshd:auth\): received for user .+?: 10 \(User not known to the underlying authentication module\)$',
		r"^pam_tos\(sshd:account\): (user agreed to tos|search failed No such object|user has agreed to '[^']+'|setting agreed version to \d+Z)$",
		r'^pam_unix\(sshd:auth\): check pass; user unknown$',
		r'^pam_unix\(sshd:session\): session closed for user ',
		r'^pam_unix\(sshd:session\): session opened for user [^ ]+ by \(uid=\d+\)$',
		r'^pam_(unix|sss)\(sshd:auth\): authentication failure; ',
		r'^Postponed keyboard-interactive for invalid user [^ ]+ from [^ ]+ port \d+ ssh2 \[preauth\]',
		r'^Received disconnect from [^ ]+ port \d+',
		r'^Received disconnect from [^ ]+ port \d+',
		r'^Unable to negotiate with [^ ]+ port \d+: no matching (cipher|key exchange method|host key type) found\. Their offer: [^ ]+ \[preauth\]$',
		r'^ssh_dispatch_run_fatal: Connection from [^ ]+ port \d+: ',
		]),
	({'_COMM': '(sd-pam)'},
		[
		r'pam_unix\(systemd-user:session\): session closed for user '
		]),
	({'_SYSTEMD_CGROUP': '/system.slice/guix-daemon.service'},
		[
		'^accepted connection from pid \d+, user .+$',
		'^spurious SIGPOLL$',
		]),
	({'_SYSTEMD_CGROUP': '/system.slice/conductor.service'}, matchConductor),
	({'_SYSTEMD_CGROUP': '/system.slice/bawwab.service'}, matchBawwab),
	({'_SYSTEMD_CGROUP': '/system.slice/usermgrd.service'}, matchUsermgrd),
	({'_SYSTEMD_CGROUP': '/system.slice/mkhomedird.service'}, matchMkhomedird),
	({'_SYSTEMD_CGROUP': '/system.slice/nscdflushd.service'}, matchNscdflushd),
	({'_SYSTEMD_CGROUP': '/system.slice/sssd.service'},
		[
		r"^Client '[^']+' not found in Kerberos database$",
		]),
	({'_SYSTEMD_CGROUP': '/system.slice/sssd-pam.service'},
		[
		'^Shutting down$',
		'^Starting up$',
		]),
	({'_SYSTEMD_CGROUP': '/system.slice/sssd-nss.service'},
		[
		'^Shutting down$',
		'^Starting up$',
		r'^Enumeration requested but not enabled$',
		]),
	({'_SYSTEMD_CGROUP': '/system.slice/sssd-pac.service'},
		[
		'^Shutting down$',
		'^Starting up$',
		]),
	({'_SYSTEMD_CGROUP': '/system.slice/sssd-kcm.service'},
		[
		'^Shutting down$',
		'^Starting up$',
		]),
	({'_SYSTEMD_CGROUP': '/system.slice/krb5-kdc.service'},
		[
		r'^TGS_REQ \(\d+ etypes \{[^}]+\}\) .+?: ISSUE: authtime \d+, etypes \{[^}]+\}, [^ ]+ for [^ ]+$',
		r'^AS_REQ \(\d+ etypes \{[^}]+\}\) .+?: (NEEDED_PREAUTH|CLIENT_NOT_FOUND|ISSUE): ',
		]),
	({'_SYSTEMD_CGROUP': '/system.slice/cron.service'},
		[
		r'^pam_unix\(cron:session\): session (opened|closed) for user [^ ]+',
		r'^\([^)]+\) CMD \(.*\)$',
		r'^no dictionary update necessary.$',
		]),
	({'_SYSTEMD_CGROUP': '/system.slice/backup.service'},
		[
		r'^Creating archive at ',
		r'^Keeping archive ',
		r'^Pruning archive ',
		]),
	# Sends messages not only through cgroup for some reason.
	({'_SYSTEMD_UNIT': 'psychnotebook-stats-collect.service'},
		[
		r'^No dictionary file specified, continuing without one.$',
		r'^0 Success: \d+ value has been dispatched.',
		]),
	({'_SYSTEMD_UNIT': 'audit-mail.service'},
		[
		r".+? host=.+? tls=on auth=on user=donot-reply@psychnotebook.org from=donot-reply@psychnotebook.org recipients=psychnotebook@leibniz-psychology.org mailsize=\d+ smtpstatus=250 smtpmsg='[^']+' exitcode=EX_OK",
		]),
	({'_SYSTEMD_CGROUP': '/system.slice/slapd.service'},
		[
		r'^slap_global_control: unrecognized control: [0-9.]+$',
		r'^get_(filter|ssa): conn \d+ unknown attribute type=sudoHost \(17\)',
		r'^connection_input: conn=\d+ deferring operation: pending operations$',
		]),
	({"_SYSTEMD_UNIT": "nginx.service"},
		[
		r'SSL_do_handshake',
		r'recv\(\) failed \(104: Connection reset by peer\)'
		]),
	({'_SYSTEMD_CGROUP': '/system.slice/systemd-logind.service'},
		[
		r'^New session \d+ of user .+?\.$',
		r'^Removed session \d+\.$',
		r'^Session \d+ logged out. Waiting for processes to exit.$',
		]),
	({'_SYSTEMD_CGROUP': '/system.slice/fstrim.service'},
		[
		r' trimmed on /dev',
		]),
	({'_SYSTEMD_CGROUP': '/system.slice/logcheck.service'},
		[
		r'exitcode=EX_OK',
		]),
	# Generic systemd messages.
	({"SYSLOG_IDENTIFIER": "systemd"},
		[
		r'^Listening on .+\.$',
		r'^(Closed|Finished|Stopped|Reached|Removed) .+\.$',
		r'^Stopping .+\.\.\.$',
		r'^.+?\.(socket|service|mount|scope): Succeeded\.$',
		r'^Startup finished in \d+ms\.$',
		r'^pam_unix\(systemd-user:session\): session opened for user [^ ]+ by \(uid=\d+\)$',
		]),
	({'_COMM': '(systemd)'},
		[
		r'^pam_unix\(systemd-user:session\): session opened for user [^ ]+ by \(uid=\d+\)$',
		]),
	({'_SYSTEMD_CGROUP': '/system.slice/nscd.service'},
		[
		r'\d+ monitoring (file|directory) `[^`]+` \(\d+\)',
		]),
	({'_SYSTEMD_CGROUP': '/init.scope'},
		[
		r'^.+?.service: Succeeded.$',
		r'^Starting .+?\.\.\.$',
		r'^(Started|Finished) .+?\.$',
		r'^Created slice User Slice of UID \d+\.$',
		]),
	({'SYSLOG_IDENTIFIER': 'kadmin.local'},
		[
		r'^No dictionary file specified, continuing without one.$',
		]),
	({"SYSLOG_IDENTIFIER": "cracklib"},
		[
		r'^no dictionary update necessary\.$',
		]),
	({'UNIT': 'mdcheck_continue.service'},
		[
		r'^Condition check resulted in MD array scrubbing - continuation being skipped.$',
		]),
	({'_TRANSPORT': 'kernel'},
		[
		r'^\[UFW BLOCK\] ',
		]),
	]

def match (r, s):
	for x in r:
		if x.search (s):
			return True
	return False

newfilter = []
for (m1, m2) in filter:
	try:
		r = [re.compile (x) for x in iter (m2)]
		newfilter.append ((m1, partial (match, r)))
	except TypeError:
		# Already a function.
		newfilter.append ((m1, m2))
filter = newfilter

while True:
	l = sys.stdin.readline ()
	if not l:
		break
	obj = json.loads (l)

	message = obj.get ('MESSAGE')
	if not message:
		continue

	m2matched = False
	for (m1, m2) in filter:
		m1matched = True
		for k in m1.keys ():
			if obj.get (k) != m1[k]:
				m1matched = False
				break
		if m1matched:
			m2matched = m2 (message)
			if m2matched:
				break

	if not m2matched:
		json.dump (obj, sys.stdout)
		sys.stdout.write ('\n')
		sys.stdout.flush ()

