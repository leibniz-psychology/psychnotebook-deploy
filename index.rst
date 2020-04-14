compute.zpid.de admin documentation
===================================

.. toctree::
	:hidden:

	configuration

compute.zpid.de is a general-purpose compute cluster for end-users. It provides
shared volumes through NFS, user authentication via Kerberos, LDAP and clumsy_,
a guix installation as well as reverse proxying via conductor_. Users can log
in via SSH or a web interface (bawwab_).

.. _clumsy: https://github.com/leibniz-psychology/clumsy
.. _conductor: https://github.com/leibniz-psychology/conductor
.. _bawwab: https://github.com/leibniz-psychology/bawwab

.. graphviz:: sysarch.gv
	:caption: System overview

External documentation:

- `guix manual`_ and `guix cookbook`_

.. _guix manual: https://guix.gnu.org/manual/en/guix.html
.. _guix cookbook: https://guix.gnu.org/cookbook/en/guix-cookbook.html


