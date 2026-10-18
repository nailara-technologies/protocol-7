# device database : optional dependencies, auto-install on use

brief [ 2026-10-18, user ]. almost every element exists already -- this
joins them : known devices, what they need, and installing it when a
device is actually used.

## the elements that exist

- **static detection** : `bin/p7-deps detect-hw` [ AMOS7::deps::hw_detect,
  in progress ] -- kernel firmware requests, module firmware lists, pci \
  usb ids, gpu \ cpu vendor, device-tree model
- **live detection** : the udev zenka -- `cfg/zenki/udev/rules-set-up.*`
  patterns [ U2F-tokens, air-mice ] with insert \ remove actions
- **privileged install** : the generic root runner
  [ AMOS7::deps::root_runner, `install <pkgs>` over the line protocol,
  names re-checked in root, path checks before require ]
- **profiles** : `.deps/profiles.yaml` [ hw-* profiles, e.g.
  hw-thinkpad-sandybridge ]

## the device database

one entry per known device or device class :

```
name        : U2F-key-black
match       : usb 1ea8:f025              [ or pci id, pci class, modalias,
                                           device-tree model ]
category    : security-token
deps        : [ packages or a profile ]  [ optional -- only when present ]
udev        : rules-set-up.U2F-tokens    [ its live patterns, if any ]
install     : never | notify | auto      [ default : notify ]
```

- the udev rule set-ups stay the live side ; an entry points to them
  instead of duplicating their patterns
- detect-hw reads the database too : a 4th evidence class,
  **known device present**
- tokens never fully integrated so far [ user ] -- the database is where
  that integration starts : which packages, what for [ pam login \ sudo :
  libpam-u2f + pamu2fcfg ; fido2 ssh keys : fido2-tools, libfido2-1 ;
  webauthn only : udev permissions ] -- decided per use, not guessed

## the main use case [ user ]

an owner -- a user or an organization -- ALLOWS a class or group of
devices in general [ e.g. "our u2f tokens", "our label printers" ]. not
every host needs them, or has needed them yet : each host installs
lazily, on first use. so the policy is per owner and device group, not
per host :

```
allow       : security-token \ U2F-key-*   [ a class or a group of entries ]
owner       : <user or org>                [ signed by its key -- the same
                                             delegation shape as host-root ]
scope       : all hosts | a host group
install     : notify | auto
```

PINNED to specific devices [ user ] : the signed allowance can name
single devices, not only a model. the pin's strength depends on what
the device can prove :
- serial number [ udev ID_SERIAL_SHORT ] : raises the bar, but usb
  descriptors can be faked -- convenience, not proof
- cryptographic identity : a fido \ u2f token can PROVE it is the
  registered one [ challenge-response with its credential key ; the
  attestation certificate names the model ] -- an unspoofable pin
- storage : the N7FS disk-id [ signed init record inside the store ]
- devices with their OWN storage [ user : e.g. the mobile router's
  storage ] can carry distinguishing material with enough bits -- a
  signed identity record like the N7FS disk-id. it cannot be forged
  [ signature ], but it can be CLONED with the storage : strong against a
  spoofed id, weaker against a full copy -- combine with what the device
  reports itself [ serial, mac ] and keep `auto` for proven pins
  -- and ROTATED on each use [ user ] : the host writes fresh material
  to the device after every verified use and keeps only its checksum.
  a clone holds the material of the moment it was copied : the first
  side to be used after the copy advances, the other is then stale and
  exposed on its next use -- cloning becomes DETECTABLE [ the same idea
  as rolling codes and fido signature counters ]. needs the rotation to
  be atomic [ write new, verify, then retire old -- the vault write order ]
  FORENSICS [ user ] : no history needed -- the material can carry its
  own signed rotation timestamp, so stale material dates itself ; the
  forensics zenka correlates that time with the hosts' logs [ when the
  copy was made, which hosts saw the device ]. signed, so a clone cannot
  alter it ; a MISSING timestamp is as invalid as a failed signature
  check [ fail closed ]. possibly overkill -- optional.
the CIRCLE [ user ] : a challenge needs software to answer it -- the
very thing to be installed. broken by keeping the verifier in the base :
- fido \ u2f tokens speak plain HID [ usbhid is in every kernel, no
  extra driver ] ; a minimal u2f authenticate over /dev/hidraw* is small
  [ ctap1 \ u2f : channel init, one apdu, an ecdsa p-256 signature ] --
  CryptX [ already a base dependency ] verifies p-256. so protocol-7
  carries its own verifier, nothing to install before the proof
- hidraw access for the verifying zenka comes from the udev zenka's own
  rules -- also base, not part of what gets installed
- fallback for devices without such a base verifier : staged trust --
  the serial pin may install ONLY the verifier, the proven pin the rest

the pin decides the trust level of the trigger : a proven pin can allow
`auto`, a serial-only pin is better kept at `notify`.

packages kept READY by probability -> already the osf-cache zenka's job
[ data/md/design/OSF-CACHE-ZENKA.md : hash-verified holdings ] : the
allowed groups' packages are cached ahead, so an auto-install on first
use is fast and works offline. the device database only says what an
allowed group needs ; osf-cache decides what to hold.

## auto-install on use

the udev zenka sees the device inserted -> looks up its entry -> deps
missing ?
- `notify` : log \ desktop hint, nothing installed
- `auto` : sends `install <pkgs>` to the root runner, reports the result

safety [ a usb device can claim any vendor \ product id ] :
- packages come ONLY from the signed database entry -- nothing from the
  device is ever used as a name or a path
- `auto` is opt-in per entry, `notify` the default
- once per entry and boot [ a device plugged in repeatedly does not loop ]
- the root runner's own checks stay in force [ name syntax re-checked in
  root, no shell ]
- every auto-install logged with the device that triggered it

## order

1. detect-hw lands [ kimi, running ]
2. database format + loader, entries for the known tokens, air mice, the
   thinkpads, the gpu vendors ; detect-hw reads it
3. udev zenka : lookup on insert, `notify`
4. `auto` through the root runner, with the safety rules above
5. later : X-11.gpu_vendor from the same hardware detection

#,,.,,,.,,,..,..,,.,.,,.,,,,.,.,,,..,,,,.,.,.,..,,...,...,...,,..,..,,,,.,.,.,
#4N3AZMGU35THBXI77GCBGH6T3T52325OWWBHRBJROTDYORVRMOTBFMMPURVGHDZWALQMDEUQSO6F6
#\\\|UYOEZEPMECDPVZZ66VGDDD7MYEPLSGIYD3B4TLK5VQBNWCQ46IH \ / AMOS7 \ YOURUM ::
#\[7]GRGNUNUO7IW2JXN76MS7D2BX64R4PHMPCZBL7E32GFJCPDW2NGAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
