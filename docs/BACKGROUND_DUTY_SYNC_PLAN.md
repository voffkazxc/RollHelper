# Synchronous tab refresh candidate

Scope: rollclub and catalog only. Order selection/open/close, filters, operator
rules, other packages, launcher and user data remain protected.

0.1.73 evidence: some refresh cycles returned before=Deliveries,
middle=Deliveries, after=Delivery clients. A later start began on Delivery
clients while a cached delivery grid still existed. No order activation was
attempted in those failed cycles.

Replace queued ControlSend with a WinForms-specific adapter: synchronous
SendMessageTimeout WM_KEYDOWN/UP with Keys.Control|Keys.Tab in WParam. This is
not a general Win32 virtual-key encoding. The installed WinForms Control builds
KeyEventArgs from this data; the existing Syrve KeyDown handler then selects
the tab. A native WindowsForms class guard rejects other controls. No modifier
key messages or physical keyboard-state changes are made.

Read current native child-page titles and own WS_VISIBLE styles instead of
depending solely on cached UIA page elements. Wait for the outward transition
before sending the return, then wait for the original page. No blind fixed
220/330 ms phase delays. A WinAPI parent/style walk rejects a hidden cached
delivery grid before refresh or reading, without IsOffscreen/Exists polling.

Validation: isolated installed RestoTabControl with a 350 ms handler delay;
the actual production refresh helper performs twenty serialized transitions,
returns to the original tab, remains minimized/unfocused, and has zero form
activations. Native fixtures verify mouse/filter cleanup and rejecting a
non-WinForms refresh target. The installed RestoGrid test verifies active vs
hidden cached grids and the existing Enter activation. Full live application
navigation still needs verification; no claim of a complete live booking is
made. Do not publish a new operator update before choosing the live check or
receiving the operator's preference to test from the launcher himself.
