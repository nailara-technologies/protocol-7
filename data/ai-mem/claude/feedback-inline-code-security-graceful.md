---
name: inline-code-security-graceful
description: inline C [ ~/.7/inline-code ] security work must stay transparent and always functional for the user -- graceful layers, never a lockout
metadata:
  type: feedback
---

owner 2026-11-17 on RCM \ NCW [ data/md/design/INLINE-OBJECT-TRUST.md ] : the user must keep working with inline C objects transparently -- build, edit, rebuild as themselves. every security improvement is a graceful layer on an always-functional base.

**Why:** a security layer that blocks normal use gets circumvented or blocks adoption ; same line as [[warn-dont-restrict-user-choices]].

**How to apply:** strict trust only where keys are held [ signing agent, key-holding processes : pure perl or attested objects only ] ; everywhere else, a missing \ unattested \ root-owned-cache-absent object falls back [ user cache build, or pure perl ] with a WARNING, never a failure. root-owned cache \ chattr +i \ attestation = opt-in tiers that a user build never breaks. no option may leave a process unable to run.

#,,,,,...,..,,...,...,,,,,...,...,..,,..,,,,,,..,,...,...,.,.,,,,,...,...,..,,
#EXGIFORVQYBXMEEBL7ERAB6V4JWVZG32ASWAOSNH65EZKUWOZAD5SWWZRG76NZZQIHOUDGULY74IW
#\\\|IBSVBEVBURS2PZ45MEYYLXIPVXCLMJIY3FKPOXD2KKY3DAJDS4G \ / AMOS7 \ YOURUM ::
#\[7]YC7DKMBRDBMSNOT32CWKMGNPITQD22KZSE7S5YDRUEJROGUCEKDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
