# arm awareness : p7-deps, p7-install, x11 zenka

status : notes, test device = raspberry pi 4 model B [ 2026-11-18 ]

protocol-7 ran on a raspberry pi 10+ years ago ; the tools grew x86-only since.
today p7-deps knows the os [ AMOS7::deps::os_package ] but not the cpu
architecture.

## p7-deps

- profiles gain an optional `arch:` filter [ e.g. `arch: [ amd64 ]` on intel-microcode,
  cuda, gpu builds ] ; a filtered package is shown as `not for <arch>`, never missing
- `detect-hw` [ AMOS7::deps::hw_detect ] reads /proc/device-tree/model : a raspberry
  pi gives a `hw-<name>` profile with its firmware \ tools [ raspi-firmware or
  rpi-eeprom, libraspberrypi-bin for vcgencmd ]
- inline C \ RCM builds : check they compile on aarch64 [ no x86 flags assumed ]
- first full run of `p7-deps install minimal` on the pi lists the real gaps

## p7-install

- same arch detection ; the p7c \ p-7-r static build on aarch64

## x11 zenka

- gfx driver detection : the pi 4 uses vc4 \ v3d [ kms ] instead of intel \ amd \ nvidia
- whatever x11 picks per driver [ resolution profiles, gpu checks ] gets an arm \ vc4 branch

## mpv zenka

- hardware decoding on the pi 4 : hevc through the v4l2 stateless decoder
  [ `--hwdec=drm` \ `v4l2request`, needs a matching mpv \ ffmpeg build ], h264 through
  `v4l2m2m` [ `--hwdec=v4l2m2m-copy` ] ; no vaapi \ vdpau \ nvdec there
- `--vo=gpu` with `--gpu-context=drm` or x11egl ; 4k only for hevc, h264 tops out at 1080p
- mpv zenka : choose hwdec per platform [ detect, fall back to software with a log
  line ], never a hard-coded vaapi \ nvdec
- p7-deps : the mpv \ ffmpeg packages that carry these decoders on arm64

## rules

style per CLAUDE.md ; no sha, no json for hand-editable files ; format-code -c.

## later : image installer zenka [ owner idea 2026-11-18 ]

appliance images per role [ pi relay \ beamer + media \ blind holder.. ] :
- base os image [ raspberry pi os lite 64-bit for the pi ] + protocol-7 + role profile
  [ p7-deps profiles, zenki set, power drivers ] written to sd \ usb \ disk
- NO keys in the image : host-root and user keys are made on first boot, the new host
  enrolls and the owner approves its pin [ same path as any new host ]
- first-boot config [ hostname, ssh pubkey, network ] from a small file on the boot
  partition, removed after use
- built and verified with AMOS \ BMW checksums of the image
- the pi bring-up done by hand first becomes the recipe for the first appliance

- existing appliance reminders : cfg/appliances/<Name>/asc/ [ AMOS7_YOURUM.DARKSUN_DEDUPLICATION_NETWORK terminal banner, Torektra.system_security full name ] -- one dir per appliance ; the role profile \ recipe would live there too
- recipes = plain p7 config files : cfg/appliances/<Name>/role.cfg, pulled in by [load_config_file:'appliances/<Name>/role.cfg'] from a zenka.v7 or nested [ shared parts e.g. appliances/common/pi4.cfg ] ; the image zenka reads them at runtime from its own subs too -- one description for image and running host
- standalone install scripts read the same tree : needs a small AMOS7 config reader [ none found in AMOS7 yet ] for plain keys + nested load_config_file ; [sub:..] calls inside a recipe are listed, not run, outside a zenka -- keep recipes mostly plain keys

#,,.,,,..,,,.,,,.,,.,,,,,,.,.,,.,,,,,,..,,...,..,,...,...,..,,..,,.,,,,.,,,.,,
#3YGPVN3J2IWYBSBYWR7WQPPMTI3ELV2WRJW2JE3HC67QHB4HPWCNIFYVOSITJ5AALD3KPRC2ACLZ4
#\\\|NKN4TYPZ4NUVGOUTHSEW7FN4G2BWDIXHO5E7IJ4ZVVHKT5COP2Q \ / AMOS7 \ YOURUM ::
#\[7]LX7PUROAB57CYRYSYUFU22DTGIFM7OM5UVL742YTPJDS7LLJKSCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
