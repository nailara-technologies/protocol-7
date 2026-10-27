2026-10-27 azurum host kept suspending to RAM (S3) killing SSH. Culprit chain: GNOME gsd-power idle-suspend -> logind -> systemd. Full runbook + provisioning design notes written to docs/backlog/host-power-management.md. Key facts: mask sleep/suspend/hibernate/hybrid-sleep targets as hard backstop; gsettings org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type/battery-type 'nothing' (needs user session bus, root SSH can't); /proc/acpi/wakeup writes TOGGLE not set; systemd-tmpfiles w-lines dedupe by path so they cannot persist multiple wakeup toggles (and toggle accidents) -- use a guard-based oneshot systemd service instead; device names machine-specific, disable all except RTC AWAC; USB keyboard can't wake with XHCI wakeup off, power button always works. Planned: turn into p7-deps host-power step / installer integration.

#,,..,,.,,..,,...,..,,,,,,.,.,..,,..,,,.,,..,,...,...,...,.,,,,.,,,,.,...,,.,,
#B7TJIG5IBZ4RY4YOD7DBTVC4IZURE6CENMPSBGYUDMDRW35UGZXWDKPAKEFHURUKHKSEZREFRFGZ2
#\\\|OYA7NLM4U6MTTI2TKNIV2SQ2AJMS4WSDWFS6OGNLZRBUVLZLTHH \ / AMOS7 \ YOURUM ::
#\[7]IID3UTHCVSWG4NH5DTV2TH42HUGGQSPSOPE4OHBAHAU4WG5J3ECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
