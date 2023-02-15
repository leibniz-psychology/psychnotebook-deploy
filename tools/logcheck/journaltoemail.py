import json, sys
from datetime import datetime
from email.message import EmailMessage

content = ''
raw = ''
for l in sys.stdin:
	o = json.loads (l)
	t = datetime.utcfromtimestamp (int (o['__REALTIME_TIMESTAMP'])/1000/1000)
	message = o.get ('MESSAGE')
	pid = o.get ('_PID')
	comm = o.get ('_COMM') or o.get ('_EXE')
	content += f'{t} {comm}[{pid}]: {message}\n'
	raw += l

msg = EmailMessage()
msg.add_attachment(content, disposition='inline')
msg.add_attachment(raw, disposition='inline')

# me == the sender's email address
# you == the recipient's email address
msg['Subject'] = f'Log messages'
msg['From'] = 'PsychNotebook Logs <donot-reply@psychnotebook.org>'
msg['To'] = 'ldb@leibniz-psychology.org'

sys.stdout.buffer.write (msg.as_bytes ())

