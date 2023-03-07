#!/bin/bash
# Back up LDAP and important files. LDAP is backed up up into different
# archives (config data/psychnotebook data) and piped via stdin, so we don’t
# have to create temporary files on the server.

# Setting this, so the repo does not need to be given on the commandline:
export BORG_REPO=ssh://u287355@backup.prd.psychnotebook.org:23/./psychnotebook-backup

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
   /var/lib/bawwab                   && \
borg prune --list --keep-weekly=8 --keep-monthly=6 --keep-daily=14 --glob-archives='data-*' && \
borg prune --list --keep-weekly=8 --keep-monthly=6 --keep-daily=14 --glob-archives='ldap-psychnotebook-*' && \
borg prune --list --keep-weekly=8 --keep-monthly=6 --keep-daily=14 --glob-archives='ldap-config-*' && \
borg compact

exit $?
