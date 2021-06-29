#!/bin/bash

find /storage/public -type l -name '.guix-profile' | while read -r L; do
		dest=`readlink -e "$L"`
		if [ -z "$dest" ]; then
				#echo "$L"
				base=`dirname "$L"`
				user=`stat -c '%U' "$base"`
				command="workspace -d $base -v run"
				echo su -l -c "\"$command\"" "$user"
		fi
done

