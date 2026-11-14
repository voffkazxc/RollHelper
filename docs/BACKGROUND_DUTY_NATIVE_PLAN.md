# Background duty: restore the complete scenario

Allowed packages: rollclub and catalog only. Launcher, other brands, addon ZIPs,
operator configuration and unrelated hotkeys are protected.

Operator evidence from 0.1.70: a new eligible order was read at 11:31:36;
opening was requested at 11:31:37; no card was detected within four seconds.
Removing Ctrl+Tab refresh changed the original scenario without proving an
equivalent update path. That change must not be treated as complete.

Read-only inspection of Syrve found tabControlMain as a native WinForms tab
container with active panes rather than UIA TabItems. Delivery cells expose
read-only Value and a legacy default action named Focus. Invoking a cell is
not equivalent to the original double click.

Restore refresh twice, exact-number filtering, verifying a single result,
double-clicking that row, conflict check, close and filter cleanup. Address
native HWNDs; derive mouse-message points from live UIA geometry and validate
inside the control client rectangle. Never use desktop Send/Click/WinActivate.
ControlSend uses explicit modifier down/up, as required by its documentation
to avoid sending modifiers to the foreground application.

Refresh completion requires an observed page-title transition and a return to
the original page. Mere acceptance of keyboard messages is not success. Invoke
likewise checks the provider return value. The background reader counts every
row (rather than stopping at the first eligible candidate) so the single-row
filter barrier is real.

Verification: native-message fixture with a minimized target and an unrelated
foreground window; exact message order and client coordinates; no focus or
minimize-state change; profile tests; real-reader row count; syntax and ZIP
checks. Full order booking in Syrve remains an operator test. Do not describe
this candidate as a verified fix before that test succeeds.

Automated results: 32 profile Python tests; 18 AHK helper assertions; native
Win32 fixture with a minimized target, per-thread Ctrl detection, double-click
message order, actual native Edit text entry and cleanup, unchanged foreground
and physical Ctrl state, and refusal to claim refresh without page transition.
Source AHK syntax passes. Full RollClub suite: 94 tests, same four inherited
failures/errors. Live Syrve inspection was read-only: grid/tab HWNDs and client
filter point were obtained without executing refresh or changing an order.
