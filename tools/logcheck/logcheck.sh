#!/bin/sh

journalctl -f -o json | python3 extractjournal.py | python3 bufferlines.py -l 1000 -t 300 'python3 journaltoemail.py | msmtp -t'

