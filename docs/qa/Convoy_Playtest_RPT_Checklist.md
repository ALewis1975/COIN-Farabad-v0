# Convoy Playtest RPT Confirmation Checklist

Use this short checklist before recording any convoy behavior conclusions from a playtest.

## Required precondition
- Confirm server and mission restarted with the expected `ARC_buildStamp` shown in RPT.

## RPT breadcrumbs to confirm
- Verify convoy startup breadcrumb appears from spawn path:
  - `[ARC][CONVOY][BOOT] ... rolePools=...`
  - `[ARC][CONVOY][BOOT] ... selectedClasses=...`
- Verify convoy startup breadcrumb appears from tick path:
  - `[ARC][CONVOY][BOOT] ... classList=... bridgeMode=... bridgeAssistLead=... bridgeAssistFollowers=...`

## Before logging findings
- Capture the exact RPT lines (copy/paste snippet with timestamp).
- Confirm the task id in logs matches the playtest incident/task under review.
- If breadcrumbs are missing, mark the run **invalid for behavior conclusions** and re-run.

## Record template (paste in test notes)
- Build stamp:
- Task id:
- Role bundle:
- Selected classes:
- Bridge mode / assist flags:
- RPT snippet reference:
