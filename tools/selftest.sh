#!/bin/zsh
# Runs the in-app self-test against a fresh store in /tmp. Exit code 0 when every check passed.
set -u
rm -rf ~/Library/Saved\ Application\ State/com.sanderrobijns.reach.savedState
store=/tmp/Reach-self.store
rm -f $store $store-shm $store-wal
# A run takes about a minute; a hang ends as a failure instead of a stuck session.
APP_STORE=$store timeout -s KILL 300 ~/Applications/Reach.app/Contents/MacOS/Reach --selftest
code=$?
(( code == 137 )) && print "SELFTEST HUNG: killed after 300 s"
exit $code
