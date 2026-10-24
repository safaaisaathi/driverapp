# 14: Integration rehearsal & real-phone stabilization

**What to build:** End-to-end rehearsal before the Phase-1/3 checkpoints (contract 0.14): Test L1 client-side on a real phone — start a shift on route R with seeded data, confirm a second phone/user-app observer sees the van move within 15 seconds of Start (acceptance criterion 1), a foreign-route user sees nothing, admin panel (other team) sees the same van. Client-side hardening per contract section 6: 60 minutes screen off + locked + battery saver; 2-minute airplane mode (12's criteria); kill-and-reopen resume (acceptance criterion 3); permission flow from clean install. Fix what it finds; this is the branch-merge gate for the parallel wave.

**Blocked by:** 07, 08, 09, 10, 11, 12, 13 (full wave integrated).

**Status:** ready-for-agent

- [ ] Clean-install run: permissions → PIN → Start Shift → tracking, no crash on any screen
- [ ] Acceptance 1: user app shows the van within 15 s (with the other team's user build)
- [ ] Acceptance 3: killing and reopening during a shift resumes tracking without PIN
- [ ] Acceptance 4: 2 minutes airplane mode loses no points after reconnect
- [ ] 60-minute screen-off/locked/battery-saver run keeps the service alive and writes flowing
- [ ] All locally caught regressions fixed; main still runs after merge (0.10)
