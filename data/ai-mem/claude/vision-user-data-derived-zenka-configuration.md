---
name: vision-user-data-derived-zenka-configuration
description: "general pattern: already-collected user data (contact emails, package profiles, ...) should generate real zenka configuration (smtpd setup, os-pkg installs, ...) contextually and step by step, as clean reusable base primitives, in the context of distributed propagation across instances"
metadata:
  node_type: memory
  type: project
  originSessionId: fee6b203-065d-46ee-9e22-bac7aa31efd1
---

2026-08-31, immediately following [[vision-os-pkg-reproducible-installs]]
in the same conversation — the user drew this connection explicitly
("just like using the already collected contact email address data from
user-edit and users zenki to create actual SMTPD zenka configurations").

## the general pattern

Data already captured in `users`/`user-edit` (declared identity records —
contact email, etc.) or tracked package-install history shouldn't sit
inert — it should be able to **generate real, working zenka
configuration**, contextually:

- contact email address on file → generate an actual working `smtpd`
  zenka config (local or **remote** — the config generation itself isn't
  tied to running on the same host as the data)
- tracked OS package installs, once mapped to session types (see
  [[vision-os-pkg-reproducible-installs]]) → generate the install set a
  new instance needs for a given session type

## explicit constraints from the user

- **step by step** — this is not a "build the generalized engine now"
  request; each instance (smtpd-from-contacts, os-pkg-from-profiles, ...)
  gets built individually, with the generalization emerging from real
  instances rather than being designed upfront
- **in the context of distributed propagation** — this isn't scoped to a
  single local instance generating its own config; the same collected
  data may need to propagate to and configure a **remote** instance too.
  Ties toward the network-as-computer / self-assembling-network themes
  ([[topic-network-as-computer]], [[topic-self-assembling-network]]) —
  config generation should assume more than one host in the picture from
  the start, not be retrofitted for remote later
- **clean base primitives, instantly reusable** — whatever gets built for
  the first instance (e.g. contact-email → smtpd config) should be
  written as a primitive the next instance (e.g. package-profile →
  os-pkg install set) can actually reuse, not a one-off script. The
  "instantly reusable" bar matters more than getting to any one instance
  fast.

## status

Pure vision, nothing implemented, no design decisions made yet on what
the shared primitive layer actually looks like. Don't start building
either instance (smtpd-from-contacts or the os-pkg/profile side)
unprompted — wait for the user to pick a concrete first step.

#,,,,,,,,,,,,,...,.,.,.,,,...,.,,,,..,,..,...,..,,...,...,,,.,.,,,.,,,,..,,.,,
#457UUUNG2CE2YMILSJBNN7HKZV2MO2NLKUHPKVH36AEKMHHNZVJAFXF6LVPOUGB2US72FKOLU3G3A
#\\\|CUCINZA47HVBMNFCHUBVGCO7LCC4TLJGDIZGOHUJMXHARWZWYCZ \ / AMOS7 \ YOURUM ::
#\[7]S2VJMYOUMUBTKBP4LUYHAJGP5U76MTVBXVARTYANND5JFZCFDUBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
