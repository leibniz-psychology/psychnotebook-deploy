Incidents
=========

Sometimes things just go wrong. But that’s okay if you learn from them.

2021-12-10
----------

What happened:
    Class was unable to work with a shared project.
Why:
    - At 10:50pm the project’s Guix was upgraded, pointing the Guix channel at a very recent commit ``13bc332ed597ca44c746ddc821910037107ceade`` from the same day. This took 5 minutes. In the meantime:
    - At 10:51pm the project was trashed and re-created under the same(!) path.
    - at 10:53pm new packages were added to the project and RStudio was run.
    - At 10:55pm the upgrade of the original project finished with an error, replacing the new project’s :file:`channels.scm`, but failing to delete :file:`.cache/mashru3.ensureGuix.lock`, which did not exist in the new project.
    - ``guix gc`` cronjob kicked in on 10th December at 4am, removing stale links from ``gcroots/auto`` to profile versions 27 and 28 – probably from the original project.
    - On December 10th around 9:30am the project was shared with students, copied and started. Due to the overwritten channels file the profile had to be rebuilt, causing the server to request substitutes from our substitute server. It had built the output on December 9 at around 10:20pm already and thus started to build a nar for rstudio-server-zpid, but returned a (temporary) failure in the meantime.
    - The main server thus tried to build rstudio-server-zpid itself until manual intervention.
Lessons learned:
    - nars should be pre-baked to avoid building packages on the main server.
    - Deleting a project should stop all processes operating on it.
    - mashru3 should not overwrite any file that changed and abort with an error instead.

2022-01-12
----------

What happened:
    It was noticed that the ``su`` command could be executed by *any user*
    and *without any password*.
Why:
    It looks like Ubuntu does not restrict the root user in any way if a
    password in :file:`/etc/shadow` is absent:

    .. code::

        root::18515:0:99999:7:::

    Thus this change was exploitable by *any PsychNotebook* user to gain
    root access.

    (Last change would be :math:`18515 \cdot 24 \cdot 60 \cdot 60` → 2020-09-10).

    The file was last touched

    .. code::

          File: /etc/shadow
        Modify: 2021-09-29 09:29:50.533640346 +0200
        Change: 2021-09-29 09:29:50.533640346 +0200

          File: /etc/shadow-
        Access: 2021-09-29 09:29:50.000000000 +0200
        Modify: 2021-09-29 09:29:50.000000000 +0200
        Change: 2021-09-29 09:29:50.533640346 +0200

    At the same time there was an OS update running, so it probably touched
    the file, but it’s unclear whether it also modified it or not.

    .. code::

        2021-09-29 09:28:57 startup packages configure
        […]
        2021-09-29 09:30:49 status installed linux-image-5.4.0-88-generic:amd64 5.4.0-88.99

    :file:`/etc/shadow-`, which is probably a backup file, also had no
    password. Although the root account was manually disabled after noticing,
    it is unclear when the change occured and who made it. The server
    logs only go back until October 19th, i.e. before the file was
    changed. Although there are no entries pointing to anyone using ``su``
    since then, there is insufficient data to verify it has not been
    exploited. There are no snapshots of an earlier state of the machine
    available to further investigate the time of change. ``debsums`` shows
    no changed checksums, ``rkhunter`` and ``unhide`` were both negative.
Lessons learned:
    The machine was reinstalled, all user passwords changed, all local
    account’s passwords changed, permissions and ACL’s on user directories
    reset.

    ``su`` was configured using pam so only users in the wheel group can
    use it, while assigning nobody to this group, since we’re using
    ``sudo`` instead.

    In the future critical services (LDAP, Kerberos, Web) should be moved
    to a different, non-user-accessible machine.

    .. Obviously. Duh.

