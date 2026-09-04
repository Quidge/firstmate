# Fork-sync test evidence

## Merge topology

Target commit:

```text
278fdbcddf26d1e0fb89620b9dc80aa6e8e39aaf
parents 4fb1525718eab8e38e59c5ac028a0e1810a832d6 8f7b79c77c2198a71a01082215227a64500015e3
subject Merge upstream/main into fork main (fork sync 0904)
parent-count 2
upstream-parent 8f7b79c77c2198a71a01082215227a64500015e3
upstream-commits-since-merge-base 51
first-parent-contained yes
upstream-parent-contained yes
```

The graph starts with a real merge node and retains the upstream commit chain:

```text
*   278fdbc Merge upstream/main into fork main (fork sync 0904)
|\
| * 8f7b79c fix(teardown): conclude parked runs advanced past task copy (#3704)
| * a5c64a0 feat: add verified Gemini crewmate runtime (#3695)
| * d43e610 fix(bin): prevent false missed-reply escalations (#3697)
| * 3c1e86d fix(bin): close pending-reply decisions via resolve-key (#3696)
| * efbeb4f fix: restart every live second mate after updates (#3690)
```

`git show --remerge-diff` identified exactly the intended content conflicts in `README.md` and `docs/watcher-continuity.md`. The resolved README keeps `/careen`, adopts upstream's `/updatefirstmate` contract, and composes upstream's `/bearings` wording with the fork-only `lavish` mode. The watcher document retains upstream's reload/pre-turn/rebind coverage and the fork's benign concurrent-restart stand-down coverage.

## Executable behavior

Focused public behavior tests produced these end-user-relevant results:

```text
ok - Pi session transitions auto-arm through a generation owner across /new /resume /fork/reload, stale callbacks, and quit
ok - Pi session replacement auto-arms and carries its in-flight actionable close
ok - Pi replacement handoff tokens stay unique across fresh modules
ok - watch restart attaches to a verified live peer and stands down benignly when that peer later ends
ok - a benign concurrent re-arm that attaches to a verified live peer stands down (not FAILED) when the peer ends
ok - arm reports FAILED and exits non-zero when no fresh watcher can be confirmed
ok - T6 an already-current live secondmate is still restarted
ok - T6b an already-current mate with an unprovable runtime is steered, not claimed as reloaded
ok - build injects the payload, binds any-origin, then arms the source
ok - build establishes the Lavish session before binding and arming
ok - rebuild refreshes the board in place without double-arming
```

Commands:

```text
bash tests/fm-pi-watch-extension.test.sh
bash tests/fm-watcher-lock.test.sh
bash tests/fm-update.test.sh
umask 077; bash tests/fm-bearings-board.test.sh
```

The first bearings-board attempt inherited a permissive shell umask and was correctly rejected because the synthetic state root was not private. Re-running under the product's required private-directory mode passed.
