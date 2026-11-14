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
made.

## Authorized live validation

The operator authorized exactly the outward/return navigation and minimized
Syrve. The initial read-only preflight could not find the tab through the UIA
root: mainControl/panelContainer do not expose their descendants when minimized.
Direct HWND-based UIA attachment still exposes the actual tab and grid.

Added bounded cold native HWND discovery by stable AutomationId, in AHK and the
background Python reader. Native cache validation does not use IsOffscreen or
Exists. Card/close lookup also gets the same native fallback when descendants
are suppressed. No absolute HWND is configured in production.

The authorized live check then returned:

    before=Доставки| middle=Клиенты доставки| after=Доставки|
    state_before=-1 state_after=-1 foreground_unchanged=1

No order was opened or modified. A separate read-only cold-reader check with a
fresh in-memory bridge succeeded while that actual window was minimized,
reading five rows through the native grid binding. Installed code/server files
were not patched or restarted. Full live booking remains unverified.
