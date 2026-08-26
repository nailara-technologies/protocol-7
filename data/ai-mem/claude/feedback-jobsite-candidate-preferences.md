---
name: feedback-jobsite-candidate-preferences
description: how to weigh compensation vs. stability and where the hard line on exploitative pay sits, when giving job-search/salary advice or tuning the jobsite LLM assessment profile
metadata:
  type: feedback
---

When advising on job applications or salary asks, or tuning
`/etc/protocol-7/jobsite/profile.txt` (external `/etc` path, not repo-tracked —
edit it directly there, never copy its content into a repo-tracked file):

**Steady income outweighs matching top-of-market pay.** Do not default to
benchmarking offers against what 25 years of seniority "should" command
elsewhere — reliable employment is the win condition right now, not maximizing
the number. This was an explicit, deliberate correction to the jobsite
assessment pipeline (`profile.txt`'s `Compensation` section), not just
personal-advice framing — the LLM assessor was scoring compensation down
whenever it was below senior-market rate, which actively worked against what
actually matters to the user.

**But exploitative or unstable pay is still a hard line, not a soft
preference.** Below-market is fine *if the pay is otherwise acceptable and
livable* — don't collapse that distinction. This isn't abstract caution; it's
tied to real past harm, so don't soften it when giving advice or when it comes
up in profile-tuning discussions.

**How to apply**: when discussing a specific salary number to ask for, anchor
toward the upper-middle of whatever market estimate exists (not the ceiling,
not the floor), state one number rather than a range, and factor in any
explicit signal in the posting (e.g. "außertariflich"/off-scale pay) that
suggests real room above a generic estimate. When a job scores low purely on
compensation-vs-seniority grounds, that's a signal the *assessment* needs
recalibrating, not that the job should be dismissed.

**Company blacklisting**: for a company the user has made a firm, settled
decision about (e.g. a full past-employer sweep), prefer the deterministic
`jobsite.blacklist-add <company>` checksum mechanism over relying on
`profile.txt` prose and hoping the LLM infers the exclusion correctly from a
posting's text every time.

#,,..,..,,,,,,.,,,.,.,..,,.,,,..,,,..,.,.,,..,..,,...,...,..,,..,,.,.,,,.,,,.,
#IF3ONEIXS5FQIYZSK6KMZA6XL2DMTOUAGM5NOGQTTAHEI2HGYEERFONGHUX3JIBVEW2AMJIV6ML7O
#\\\|JF7HJMBS4LJWZ2HWIGVFYMZKKJLSK3C63NVKBYLX2SKQNRJOCUV \ / AMOS7 \ YOURUM ::
#\[7]IDACHG5JCEKDW5OJ5UZFRRTHVD4AN2VFSX6OA7SWXBSVSBJTLIBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
