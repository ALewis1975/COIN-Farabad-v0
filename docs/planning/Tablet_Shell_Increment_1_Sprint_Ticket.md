# Sprint Ticket — Tablet Shell Increment 1 (First Visible Shell Pass)

## Ticket ID
TSH-INC1

## Objective
Deliver the first user-visible tablet shell increment for the Farabad Console with a ruggedized 2011 look while preserving existing action-route behavior.

## Explicit Deliverables
1. **New frame/bezel style**
   - Apply updated chassis/bezel treatment to the console shell so the dialog visually reads as a rugged field tablet.
   - Includes bezel/background/title framing updates only (no workflow or routing changes).
2. **Top status strip (NET/GPS/BATT/SYNC)**
   - Add a persistent top status strip with four labeled indicators: `NET`, `GPS`, `BATT`, and `SYNC`.
   - Indicators are display-only in this increment (readout text/color only).
3. **Updated typography/contrast tokens**
   - Introduce/standardize typography and contrast styling tokens used by shell elements (title, strip labels, main panel contrast pairings).
   - Ensure readability improvements are applied across shell-level text surfaces.
4. **No action-route behavior change**
   - Existing primary/secondary actions and tab routing remain functionally identical to baseline.
   - No destination, handler, or permission-path changes are allowed in this increment.

## In Scope
- Visual shell presentation of the Farabad Console dialog.
- Top strip display controls and shell-level style application.
- UI paint/refresh logic needed strictly for status-strip presentation.

## Out of Scope
- Any remap of primary/secondary action routes.
- Any backend/state-authority/API changes.
- New operator capabilities or command semantics.

## Exact Files Expected to Change
### `functions/ui/`
- `functions/ui/fn_uiConsoleOnLoad.sqf`
- `functions/ui/fn_uiConsoleRefresh.sqf`
- `functions/ui/fn_uiConsoleDashboardPaint.sqf`

### Dialog config
- `config/CfgDialogs.hpp`

> Scope guard: no additional files should be modified for this ticket unless scope expansion is explicitly approved.

## Acceptance Criteria (User-Visible Outcomes)
1. When opening the Farabad Console, users immediately see a visibly updated rugged tablet frame/bezel treatment compared with baseline.
2. A top status strip is visible at the top of the console and shows all four labels (`NET`, `GPS`, `BATT`, `SYNC`) at all times while the dialog is open.
3. Shell typography and contrast are visibly updated so title/labels/content panels are easier to read in normal gameplay viewing conditions.
4. Clicking any existing tab, primary action, or secondary action produces the same destination and behavior as before this increment.
5. No existing control label text is changed in meaning; visual styling may change, but operational wording and flow remain intact.

## Verification Notes
- Compare before/after console screenshots for shell-only visual deltas.
- Run behavior smoke checks for tab switching and primary/secondary actions to confirm route parity.
