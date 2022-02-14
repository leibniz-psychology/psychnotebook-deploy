#!/bin/sh
# Change passwords for all users registered with bawwab.

export BAWWAB_SETTINGS=/etc/bawwab/config.py
sqlite3 /var/lib/bawwab/db.sqlite3 'select name from user' | while read -r user; do
    password=`pwgen 32 1`
    echo "changing password for $user to $password"
    echo -e "$password\n$password\n" | setsid /usr/local/profiles/bawwab/bin/bawwab-passwd "$user" &&
    echo -e "$password\n$password\n" | setsid kadmin.local cpw "$user" || exit 1
done
