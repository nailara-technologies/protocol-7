---
name: host-pc-warranty-until-2027-02
description: host pc [ ryzen 7 5700x + rtx 3060, bought via ebay ] has a 3-year full-system seller warranty, ordered 2024-02-17, delivered 2024-02-23 -> expires ~2027-02-17..23 ; check here before living with any hardware defect
metadata:
  type: project
---

host pc [ amd ryzen 7 5700x, nvidia rtx 3060 12gb, bought from an ebay seller ] carries a **3-year warranty on the entire system** from the seller.

- ordered 2024-02-17, delivered 2024-02-23 -> warranty ends ~2027-02-17 / 2027-02-23 [ exact start date per seller terms / invoice ]
- 2026-10-02: seller contacted about the rtx 3060 fan bearing [ noisy at high rpm, wild clicking near max ] ; seller replied same day offering repair of the card alone or the whole pc
- also known defect, to report under the same warranty: all 3 front case fan blue led rings dead for months while fans still spin -> almost certainly a single shared cause [ argb cable/splitter, hub/controller, mobo header, or bios/rgb software ], not 3 independent failures ; side panel not yet opened to check
- the 5700x has **no igpu** : pulling the 3060 for repair leaves no display output -> need a spare cheap card or verify the board boots headless before shipping
- don't open the gpu itself [ fan swap ] before asking the seller -- warranty seals on gpu screws are common
- gpu is a gigabyte card [ subsystem 0x40E2 ] -- manufacturer warranty by serial is a second route ; thermals / fan rpm / 85 % power limit measurements in [[project-2026-10-02-invoke-render-degradation-baseline]]

- 2026-10-02 measured : at 85 % power limit [ 142 W, 77-78 C ] only one isolated click in minutes ; there is a separate grinding/noise mode before clicking, rhythmic 5-7 clicks/s only near 100 % fan -> daily work ok until repair
- plan 2026-10-02 : the secondary fanless system with a real linux install rose sharply in priority -- it is the downtime buffer for shipping the card / pc, and overlaps the planned full-linux migration off wsl

**Why:** the user had forgotten this warranty existed and assumed the defect had to be endured -- a hardware fault should be checked against this date first.
**How to apply:** whenever a hardware defect on this host comes up before ~2027-02, point to the warranty first ; send only the affected part when possible [ drives hold key material and the full work environment ].

#,,..,,..,,,,,..,,,.,,,.,,.,,,.,.,,..,.,,,,,,,..,,...,...,..,,,..,.,.,.,,,,,,,
#JVSVGUQTTDTGFMGWQCNOFGUXHGGIRA3RVBPKZNWE5YZ75WUBQR25J5UA4ZN56NORGPCW5HRL32BPM
#\\\|DRR6WAV47YUCK2545GX6JO5FUDZWETLZ4I5GMB5GXJRMSJLW6PG \ / AMOS7 \ YOURUM ::
#\[7]KB7MXDPNUFQACUIFFL42KVADSV7VTVOVZXFODKPCE7I4JMXJG2DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
