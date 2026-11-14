# Native Enter activation for RollClub duty

Scope: rollclub and catalog only. Refresh, filtering, exact-number/single-row
checks, conflict handling, close/cleanup and unrelated packages/hotkeys/data
remain protected.

Observed 0.1.72 log: refresh transitions and the single-order filter succeeded;
two attempted native double clicks at client (63,86) ended in card_timeout.

Read-only code inspection found that the installed RestoGrid's double-click
handler derives its hit test from the real Cursor.Position. Therefore native
mouse messages with correct client coordinates are not equivalent to a real
double click when the cursor stays in another application. The same component
handles Enter by raising ContextAction EDIT. DeliveryOrderGridControl routes
that action to the same EditFocusedRow path used by a real double click.

Change only activation: validate the row number, select that cell with one
addressed native click, wait/check cancellation, validate its number again, and
send addressed Enter with local 30/30 timing and finally restore caller settings.
Keep actual card detection as the success criterion. No cursor movement,
foreground activation or global keyboard injection is added.

Test: SyrveGridFixture hosts the installed RestoGrid with two dummy records,
one excluded by the number filter. Its only EDIT callback records the dummy
number; no Syrve order/controller/server is started. The fixture begins on the
filter row, is minimized and has no focus. The test reproduces the failed
double click with the real cursor outside the control, then executes the
production helper and verifies exactly one EDIT for the filtered number. It
also rejects a mismatched number and checks original timing, focus and minimized
state. The user can move the real cursor during the test; activation must not
depend on it being over the hidden grid.

This verifies the installed grid component, not a full live booking. The latter
remains an operator check. Installed program files are not modified.
