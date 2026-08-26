---
name: project-jobsite-reports-archive-vision
description: "future direction — archive linking sent jobsite application reports to the actual rejection/response emails, for periodic jobcenter proof requirements"
metadata: 
  node_type: memory
  type: project
  originSessionId: 411cf431-5e68-4206-b38a-3f83e0344616
  modified: 2026-07-27T23:01:56.403Z
---

User wants to eventually build an archive combining (a) the CSV/PDF
application reports jobsite already generates and (b) the actual email
communications — especially rejection emails — that prove those
applications happened and concluded. Explicitly "step by step," not a
request for immediate implementation as of 2026-07-28.

**Why:** the jobcenter periodically (roughly every 6 months, tied to their
own automatic invitation cycle) wants to see applications *and*
rejections as proof of active job search. The trigger for this idea: a
real gap surfaced the same day — a rejected posting (Compliance
Solutions GmbH, DevOps Engineer, job id WB2NK/13989040) had fallen out of
jobsite's live tracking entirely between a May application and a July
rejection email, and had to be manually reconstructed from stale local
CSV backups plus a still-present compressed trash archive
(`jobs/trash/<epoch>/<id>.yxz.B32`, decodable via `base32.decode` →
`IO::Uncompress::UnXz` → `YAML::XS::Load`, see
[[reference-jobsite-vax-int-id-scheme]]). An archive tying report
snapshots to source emails would have made that reconstruction
unnecessary.

Two current email sources feeding this, not yet consolidated:
- a ProtonMail account
- a custom mail address on one of their own servers — they intend to
  switch to this one fully once a zenka exists that can read it

**How to apply:** when jobsite/reporting work comes up again, check
whether a mail-reading zenka has been built yet — that's the
prerequisite before real email ingestion into an archive is possible.
Don't assume this is scoped or wanted immediately; the user said "step
by step" — surface it as context, not as a queued task, unless they
explicitly ask to start scoping it.

#,,.,,,.,,,,.,...,.,,,.,.,.,.,.,,,,,.,...,.,.,..,,...,..,,,.,,..,,.,,,,,.,.,.,
#R3OWKGHTSMOWJEEIFXMS2QD377ZRRELWJPZHU57N3UTVQ6IHDJXF57XB6CNF6UFUN4T6BHKQABEUC
#\\\|JTSYPOUNJXKHIQ443VAQZZ7NMUBS546WOZ2Y7JSNRICZ5VVBXEY \ / AMOS7 \ YOURUM ::
#\[7]R77KQNVGPW6GXOYKXVDO2J44GLSUBUAR37NM74MVWN6LA3QBDECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
