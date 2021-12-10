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
