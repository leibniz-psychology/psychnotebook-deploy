#!/bin/sh

users=`journalctl -o cat -u usermgrd.service -S yesterday -U today | jq -r 'select(.event == "add_user_success") | .data.firstName + " " + .data.lastName + " (" + .data.email + ")"'`
projects=''

projects=`find /storage/public/ -perm -o=r -type f -path '**/.config/workspace.yaml' -ctime '-1' | while read -r L; do
	sed -nre 's#^_id: ([a-z-]+)#https://www.psychnotebook.org/workspaces/\1#gp' "$L" && stat -c '%U' "$L" && echo
done`

if [ -z "$users" ] && [ -z "$projects" ]; then
	# nothing to do
	exit 0
fi

cat <<EOF | /usr/bin/msmtp -t
Subject: [PsychNotebook] Audit logs `date -I`
To: <psychnotebook@leibniz-psychology.org>
From: <donot-reply@psychnotebook.org>
Content-Type: text/plain; charset=utf-8
Content-Disposition: inline
Content-Transfer-Encoding: 8bit

New/deleted users:

$users

New/changed public projects:

$projects

∎
EOF
