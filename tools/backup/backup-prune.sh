#!/bin/sh

export BORG_REPO=/storage/backup
for prefix in data- ldap-psychnotebook- ldap-config; do
        borg prune -v --list --keep-daily=7 --keep-weekly=4 --keep-monthly=3 --prefix="$prefix"
done

