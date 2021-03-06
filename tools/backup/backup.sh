#!/bin/bash
# Back up LDAP and important files. LDAP is backed up up into different
# archives (config data/psychnotebook data) and piped via stdin, so we don’t
# have to create temporary files on the server.

# Setting this, so the repo does not need to be given on the commandline:
export BORG_REPO=ssh://psychnotebook@backup.prd.psychnotebook.org:2222/storage/backup

slapcat \
		-b 'dc=psychnotebook,dc=org' | \
		borg create \
		--verbose \
		--stdin-name 'psychnotebook.ldif' \
		::ldap-psychnotebook-'{now:%Y-%m-%d_%H:%M}' - && \
slapcat \
                -b 'cn=config' | \
                borg create \
                --verbose \
                --stdin-name 'config.ldif' \
                ::ldap-config-'{now:%Y-%m-%d_%H:%M}' - && \
borg create                         \
    --verbose                       \
    ::data-'{now:%Y-%m-%d_%H:%M}'   \
   /storage/home                    \
   /storage/public                  \
   /var/db/bawwab                   \

exit $?
