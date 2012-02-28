Affinity setup

This directory contains the setup program for each platform.
Before installing, please visit http://affinitydb.org, where
you will find the documentation as well as an online demo.

Currently, setup fetches and builds everything from the source.
A few preliminary steps are required:

 * the user must have a personal github account properly configured
 * the user must be a sudoer (/etc/sudoers)

Then do:

      curl -s -k -B https://raw.github.com/affinitydb/setup/master/linux/setup.sh > affinity_setup.sh
      bash affinity_setup.sh

This procedure should work on linux and OSX.
A few confirmations will be requested during installation.

Presently, no automatic setup is provided for Windows or ARM-based devices.
These will be provided in a later release. In the meantime, it's possible to
clone, build and run all projects manually.
