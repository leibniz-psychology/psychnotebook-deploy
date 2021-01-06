Security
========

Admins must use either a password protected SSH key or a YubiKey to access
servers. It is also advised to use the YubiKey as 2nd factor for your Google
Account.

YubiKey
-------

Use as SSH key
^^^^^^^^^^^^^^

See https://developers.yubico.com/PGP/SSH_authentication/

Unblock PIN
^^^^^^^^^^^

If you entered the wrong PIN multiple times run

.. code::

	$ gpg --card-edit
	gpg/card> admin
	Admin-Befehle sind erlaubt
	gpg/card> passwd
	gpg: OpenPGP Karte Nr. D2760001240103040006113430890000 erkannt

	1 - change PIN
	2 - unblock PIN
	3 - change Admin PIN
	4 - set the Reset Code
	Q - quit

	Ihre Auswahl? 2

Enter admin pin and new pin.

External resources
------------------

`OWASP Cheat Sheet Series`_
	Web application security recommendations.

.. _OWASP Cheat Sheet Series: https://cheatsheetseries.owasp.org/

