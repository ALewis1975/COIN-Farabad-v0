# Farabad Tablet 2011 Style (Shell-Only Phase)

## Purpose
This document defines the **visual system** and **interaction semantics** for the ruggedized tablet shell used in Farabad’s 2011-era presentation mode. It is intentionally constrained to shell-level UX behavior and does not modify gameplay routing, permissions, or backend authority.

---

## 1) Rugged Tablet Visual System

### 1.1 Design Intent
- Convey a field-issued, hardened tablet from circa 2011.
- Prioritize legibility under glare/low light and high-stress usage.
- Keep visual language utilitarian, not consumer-polished.

### 1.2 Surface and Frame Language
- **Chassis tone:** dark graphite/olive-black composite.
- **Bezel:** thick protective perimeter with visibly reinforced corners.
- **Edge affordances:** implied screw points, gasket seams, and hardware lip.
- **Damage/wear treatment:** subtle abrasion and edge wear only; avoid dramatic battle damage.

### 1.3 Display Layer
- **Panel look:** matte LCD feel with mild diffusion.
- **Contrast profile:** medium-high contrast for map/table readability.
- **Glare/noise overlays:** very low intensity, static or near-static so content remains primary.
- **Brightness behavior (visual only):** day/night skin deltas may be represented, without introducing new control logic.

### 1.4 Color and Typography
- **Base palette:** muted military neutrals (charcoal, desaturated green, sand accents).
- **Signal colors:**
  - Green/cyan for normal-ready states.
  - Amber for caution/incomplete states.
  - Red for critical alerts only.
- **Type hierarchy:**
  - Header: compact all-caps or semi-condensed technical style.
  - Body/control labels: highly legible sans-serif.
  - Numeric/readout text: monospaced or tabular-figure friendly where precision matters.
- **Typography constraints:** preserve existing label text exactly; style only.

### 1.5 Iconography and Component Styling
- Use line/filled icons that read clearly at small sizes.
- Keep stroke weights consistent across modules.
- Buttons/toggles should appear tactile but restrained (no glossy modern effects).
- Focus/selection states must be clearly visible in both day and night themes.

### 1.6 Motion and Transition Tone
- Minimize animation duration and flourish.
- Prefer quick fades/slides for panel transitions.
- No animation that obscures operational status or introduces ambiguity.

---

## 2) Fixed Interaction Semantics (Shell-Only Phase)

### 2.1 Semantic Freeze
During this phase, interaction semantics are fixed:
- Existing controls keep their current meaning.
- Existing routes keep their current destinations.
- Existing command/trigger outcomes remain unchanged.

### 2.2 Allowed Changes in This Phase
- Visual restyling of shell frame, panels, typography, spacing, and icon treatment.
- Non-semantic micro-interaction polish (timing/easing) that does not change outcomes.
- Readability/accessibility improvements that do not alter control behavior.

### 2.3 Disallowed Changes in This Phase
- Remapping button intent or action sequences.
- Rebinding navigation flows or introducing alternate route targets.
- Altering enable/disable logic, state transitions, or command side effects.
- Adding/removing control capabilities.

### 2.4 Input Model Expectations
- Pointer, keyboard, and currently supported input pathways remain functionally identical.
- Hit targets may be visually adjusted for clarity, but activation semantics must remain equivalent.
- Focus order may be cleaned for readability/accessibility only if it preserves current task flow.

---

## 3) Explicit Non-Goals

The following are explicitly out of scope for this document and phase:

1. **Action-route changes**
   - No redirection of current actions to different handlers, services, or destinations.
   - No creation of new route branches for existing controls.

2. **Authority-model changes**
   - No changes to role-based capabilities, permission gates, or trust boundaries.
   - No changes to ownership of state mutation, command arbitration, or source-of-truth authority.

3. **Backend/contract changes**
   - No API contract changes, payload schema changes, or event protocol redefinitions.

4. **Feature expansion**
   - No net-new operator features disguised as “UI updates.”

---

## 4) Parity Checklist (Current Controls and Labels)

Use this checklist before merge/release to ensure shell-only parity is maintained.

### 4.1 Control Inventory Parity
- [ ] Every previously available control remains present.
- [ ] No new operational control has been introduced.
- [ ] Control grouping (which panel/section a control belongs to) is unchanged.

### 4.2 Label/Text Parity
- [ ] All control labels match current production text exactly.
- [ ] Status/readout terminology is unchanged.
- [ ] Warning/error labels preserve original wording and severity meaning.

### 4.3 Behavior Parity
- [ ] Each control triggers the same action as before.
- [ ] Success/failure states map to the same outcomes.
- [ ] Disabled/locked states appear under the same conditions.

### 4.4 Navigation/Route Parity
- [ ] Existing navigation pathing is unchanged.
- [ ] Back/close/cancel semantics are unchanged.
- [ ] Deep links (if present) resolve to the same destinations.

### 4.5 Input/Focus Parity
- [ ] Keyboard navigation order preserves current operational flow.
- [ ] Shortcut bindings (if any) are unchanged.
- [ ] Pointer/touch activation yields same behavior as pre-style baseline.

### 4.6 State and Authority Safety Checks
- [ ] No new state writer introduced in shell layer.
- [ ] Authority/permission outcomes remain unchanged for all roles.
- [ ] No command execution path bypasses existing guards.

### 4.7 Visual Regression Sanity
- [ ] Text remains legible in day/night variants.
- [ ] Critical alerts remain immediately distinguishable from caution/normal states.
- [ ] Styling changes do not hide/obscure critical controls.

---

## 5) Acceptance Criteria for This Document
- Provides a concrete rugged tablet visual direction for the 2011 style target.
- Freezes shell-phase interaction semantics with clear allowed/disallowed boundaries.
- States non-goals explicitly for action routes and authority model.
- Supplies an actionable parity checklist for controls, labels, and behavior.
