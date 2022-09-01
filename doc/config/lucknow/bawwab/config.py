SERVER_NAME = 'https://www.psychnotebook.org/api'
DEBUG = True
ACCESS_LOG = False
FORWARDED_SECRET = 'XXX'
KNOWN_HOSTS_PATH = '/etc/ssh/ssh_known_hosts'
RESPONSE_TIMEOUT = 300

# oauth config
KEYCLOAK_BASE = 'https://sso.leibniz-psychology.org/auth'
KEYCLOAK_REALM = 'ZPID'
CLIENT_ID = 'XXX'
CLIENT_SECRET = 'XXX'
SCOPE = ['openid', 'email', 'profile']

DATABASE_URL = 'sqlite:///var/lib/bawwab/db.sqlite3'
# password encryption key, use Fernet.generate_key() to generate one. If you
# change or lose it, you cannot decrypt ssh passwords any more.
DATABASE_PASSWORD_KEY = b'XXX'

LDAP_SERVER = 'ldap://ldap'
LDAP_USER = 'cn=pamtos,ou=system,dc=psychnotebook,dc=org'
LDAP_PASSWORD = 'XXX'
LDAP_TOS_BASE = 'ou=terms,dc=psychnotebook,dc=org'

# Commands to create/delete a user.
USERMGR_CREATE_COMMAND = \
    ['usermgr',
    '--client-principal', 'bawwab/lucknow',
    '--server-principal', 'usermgrd/lucknow',
    '--keytab', '/etc/bawwab/bawwab.keytab',
    'user', 'create']
USERMGR_DELETE_COMMAND = \
    ['usermgr',
    '--server-principal', 'usermgrd/lucknow',
    'user', 'delete']

# location of usermgrd socket
USERMGRD_SOCKET = '/var/run/usermgrd.socket'

SSH_HOST = 'ssh'

EMAIL = dict(
    server="XXX",
    port = 587,
    sender = "donot-reply@psychnotebook.org",
    password = 'XXX',
    )
