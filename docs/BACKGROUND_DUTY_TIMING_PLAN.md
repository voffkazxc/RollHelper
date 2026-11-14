# Ctrl+Tab timing correction

Scope: rollclub and catalog only. All scenario steps, filters, order rules,
other hotkeys, launcher, other brands/addon ZIPs and operator data are protected.

Observed 0.1.71 log: before=Deliveries, middle=Deliveries, after=Deliveries.
Read-only inspection identified RestoTabControl/DevExpress 16.2 and the app's
Ctrl+Tab key handler. No commands were sent to the running Syrve application.

An isolated executable uses that installed tab component with two test pages
and its shortcut handler predicate. Under production SetKeyDelay=-1/-1, the
observed state was zero switches and last KeyData=17 (Ctrl). With 10/10 or
30/30 ms, the actual component switched and reported KeyData=131081 (Ctrl+Tab).
The component has no focus and is hosted in a minimized, non-activating form.

Change: scope 30/30 ms to the addressed Ctrl+Tab helper; restore the caller's
settings in finally. Do not change the foreground SendInput optimization.
Do not suppress the existing page-transition verification.

Tests: test_rollclub_component_timing.py compiles only the test host (not Syrve)
and references DLLs already installed on the test machine. It exercises the
production helper with the entrypoint's timing, verifies six actual page
transitions, the restored -1/-1 settings, unchanged foreground/physical Ctrl,
minimized state and no tab focus. It skips explicitly on machines without the
installed component. The generic native fixture still verifies message/filter/
double-click/cleanup behavior separately. Full booking in Syrve is still an
operator verification, not inferred from these component tests.
