# Kitchen availability and preorders

Scope: rollclub and catalog only. Launcher, RollHouse, addon ZIPs, Ctrl+F4,
order entry, F1/Ctrl+Enter, time calculations, KML and operator settings remain
protected. The selected presentation is a full card next to the existing pult,
visible immediately; do not enlarge the main pult.

Observed source CSV has separate STOP and STOP WORKSHOP columns. The old
generic stop matcher overwrites the product column with the workshop column.
It also ignores all hourly columns after Terminal. Those cells carry explicit
green/yellow/red/white circle markers, so no image/color approximation is needed.

Current Dragomanova source: delivery center/far preorder mode, pickup standard,
Tempura workshop stop, Pepsi 0.33 Black product stop, yellow 21 and green 22.
Only explicitly green/yellow slots are eligible for display; red/gray/blank or
unknown values must not be promoted to availability. Keep open and limited
slots distinct, preserve their source times, and report unknown/missing data.

The original developer sync source was read from the server workspace and
matches the published 0.1.74 package byte-for-byte after newline normalization.
Promote it to versioned brand-local source before editing, then make both build
paths use that source. Do not patch an installed package or write real UserData
while testing. Sync tests write only temporary INI files.

Checks: shuffled headers, independent stop columns, all four colors, unknown
states, no available slots, missing headers, Unicode and INI roundtrip, custom
KML preservation, actual current CSV, AHK formatting and real GUI geometry at
100/125/150% scale and small work areas. Verify owned-card visibility/close,
source syntax, package contents/checksum and protected manifest entries. Keep
live Sheet read-only. Do not start operational RollHelper or change orders.
