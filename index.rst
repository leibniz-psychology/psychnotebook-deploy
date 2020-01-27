compute.zpid.de admin documentation
===================================

.. toctree::
	:hidden:

	configuration

compute.zpid.de is a general-purpose compute cluster for end-users. It
consists of a master server providing NFS, Kerberos, LDAP, guix-daemon as well
as clumsy_ and conductor_. Compute nodes run user-supplied interactive jobs via
SSH. The following graph shows all components of the system.

.. _clumsy: https://github.com/leibniz-psychology/clumsy
.. _conductor: https://github.com/leibniz-psychology/conductor

.. graphviz:: sysarch.gv
	:caption: System overview

External documentation:

- `guix manual`_ and `guix cookbook`_

.. _guix manual: https://guix.gnu.org/manual/en/guix.html
.. _guix cookbook: https://guix.gnu.org/cookbook/en/guix-cookbook.html


