# legacy debian dependency scripts -- coverage audit

read-only audit of `bin/dependencies/` against the profile-based dependency
system. nothing was changed, nothing was installed, no network commands were
run. classification per distinct action of each legacy script :

- `[ covered ]` -- done by the current system, exact location given
- `[ partly ]` -- done, but incompletely or differently
- `[ missing ]` -- not done anywhere in the current system
- `[ outdated ]` -- suggestion only : likely obsolete, reason given

## current-system anchors used in the tables

| anchor | what it is |
| --- | --- |
| `.deps/profiles.yaml` | the dependency profiles `bin/p7-deps` loads [ minimal :6, runtime :20, network :53, cryptography :65, vault :78, X11-Desktop :94, tools :144, coding :154, zenka-common :159, graphics-matrix :223, opencv :234, basic-remote-server :248, ai-models :260, embeddings :287, amos-term :292, protocol-7-extended :324 ] |
| `src/base.known_dependencies` | module-to-debian mapping + `pm_src` local source list + binary-to-package map [ perlmod section :8-402, binary map :410-427 ] |
| `data/lib-path/pm/AMOS7/deps/module.pm` | `resolve_install` [ :155 ], `install_pm_src` [ :200 ] -- builds `data/lib-path/pm-src/*` copies in a tempdir |
| `data/lib-path/pm/AMOS7/deps/debp.pm` | `probe_apt` [ :24 ], `install_apt` [ :74 ] -- list-form apt, noninteractive |
| `data/lib-path/pm/AMOS7/deps/os_package.pm` | zenki `deps/os/*` scan, `probe_binary` [ backend dispatch ] |
| `data/lib-path/pm/AMOS7/deps/dist_upgr.pm` | `run` [ :12 ] -- full dist-upgrade sequence |
| `data/lib-path/pm/AMOS7/deps/service.pm` | `install` [ :73 ] -- unit, install link, launcher symlinks |
| `bin/p7-deps` | profile check / install / dist-upgrade / service commands |
| `bin/p7-install` | bare-host installer : base packages, checkout, `p7-deps install`, service |
| zenki declarations | `cfg/zenki/<zenka>/deps/p-mod/*` and `deps/os/{deb,bin}/*` + `var/zenki-deps/` [ runtime-owned ] |
| `src/sys-deps.cmd.install` | installs all zenki-declared debian deps via the debian zenka apt bridge |

## 1. install_dependencies.debian.sh

the full / X11 install script.

### apt packages

| item | class | coverage |
| --- | --- | --- |
| mpv | covered | os/bin `cfg/zenki/mpv/deps/os/bin/mpv` -> pkg `mpv` |
| melt | covered | os/bin `cfg/zenki/melt/deps/os/bin/melt` |
| xvfb | covered | os/bin `cfg/zenki/X-11/deps/os/bin/Xvfb` -> `xvfb` via binary map `src/base.known_dependencies:415` |
| fuse3 | covered | profile apt `amos-term` `.deps/profiles.yaml:297` |
| pdftk | outdated | not used anywhere under `src/` -- nothing calls it |
| xnest | covered | os/bin `cfg/zenki/X-11/deps/os/bin/Xnest` -> `xnest` via binary map :418 |
| expect | covered | os/bin `cfg/zenki/udev/deps/os/bin/unbuffer` -> `expect` via binary map :424 |
| ffmpeg | covered | os/bin `cfg/zenki/ffmpeg/deps/os/bin/ffmpeg` |
| compton | missing | the compton zenka has no `deps/os/bin/compton` entry -- binary never declared |
| nxagent | covered | os/bin `cfg/zenki/X-11/deps/os/bin/nxagent` |
| openbox | covered | os/bin `cfg/zenki/openbox/deps/os/bin/openbox` |
| dbus-x11 | outdated | not referenced under `src/` -- nothing launches dbus-x11 |
| hsetroot | covered | os/bin `cfg/zenki/X-11/deps/os/bin/hsetroot` |
| libc6-dev | covered | os/deb `cfg/zenki/debian/deps/os/deb/libc6-dev` |
| mediainfo | missing | the `Mediainfo` perl module is declared [ `cfg/zenki/mediainfo/deps/p-mod/Mediainfo` ], the `mediainfo` cli package is not declared anywhere |
| unclutter | missing | `src/auto-hide.startup` runs the `unclutter` binary, but no zenka declares it as an os dep |
| x11-utils | covered | profile apt `X11-Desktop` `.deps/profiles.yaml:112` |
| notify-osd | covered | profile apt `X11-Desktop` :108 + os/deb `cfg/zenki/cube/deps/os/deb/notify-osd` |
| mupdf-tools | outdated | not used anywhere under `src/` |
| python3-pil | outdated | not used anywhere under `src/` |
| libgtk3-perl | covered | profile apt `X11-Desktop` :101 |
| xserver-xorg | covered | os/bin `Xorg` -> `xserver-xorg` :420 + os/deb `xserver-xorg-core` + profile apt :107 |
| libimlib2-dev | outdated | not referenced under `src/` |
| libnotify-bin | covered | os/bin `notify-send` -> `libnotify-bin` :423 |
| libimager-perl | covered | known deps `Imager::Screenshot` -> `libimager-perl` `src/base.known_dependencies:191` [ screenshot zenka ] |
| libsoup2.4-dev | missing | no profile or known-deps entry ; the `Gtk3::WebKit2` debian list has only `libglib2.0-dev libgtk3-perl libgtk3-webkit2-perl` :266-268 ; only relevant when building `HTTP::Soup` from cpan |
| python3-pygame | outdated | not used anywhere under `src/` |
| xserver-xephyr | covered | os/bin `Xephyr` -> `xserver-xephyr` :419 |
| libtimedate-perl | covered | profile apt `zenka-common` :176 |
| shared-mime-info | covered | known deps `File::MimeInfo::Magic` -> `shared-mime-info` :186-189 |
| libhttp-date-perl | covered | profile apt `zenka-common` :177 + known deps :158 |
| oxygen-icon-theme | outdated | not referenced under `src/` |
| x11-xserver-utils | outdated | not referenced under `src/` [ no xrandr-style calls found ] |
| libdigest-crc-perl | covered | profile apt `zenka-common` + known deps :279-282 |
| libdigest-elf-perl | outdated | `Digest::Elf` is not used anywhere under `src/` |
| libio-stringy-perl | covered | known deps `IO::Scalar` -> `libio-stringy-perl` :167-170 [ download zenka ] |
| libnet-libdnet-perl | covered | profile apt `network` :57 |
| libpoppler-glib-dev | covered | known deps `Poppler` :275-278 [ pdf2html zenka ] |
| libxml-rsslite-perl | outdated | rss ticker no longer uses it : `src/rss.ticker.init_code:23-37` uses an `LWP::UserAgent` fallback, see the note at `src/base.known_dependencies:249-252` ; not declared by the rss-ticker zenka |
| libbsd-resource-perl | covered | profile apt `zenka-common` :161 |
| libdigest-jhash-perl | covered | profile apt `zenka-common` + known deps :272-274 |
| libfile-slurper-perl | outdated | `File::Slurper` is not used anywhere under `src/` |
| libgtk3-webkit2-perl | covered | profile apt `X11-Desktop` :103 |
| libhttp-message-perl | covered | profile apt `zenka-common` + known deps :171-174 |
| libyaml-libyaml-perl | covered | profile apt `runtime` :35 + os/deb `cfg/zenki/cube-13/deps/os/deb/libyaml-libyaml-perl` + known deps :395-398 |
| libconvert-color-perl | covered | profile apt `graphics-matrix` :227 + profile cpan `Convert::Color` |
| libfile-mimeinfo-perl | covered | known deps `File::MimeInfo::Magic` :186-189 |
| libsys-mmap-perl | covered | profile apt `zenka-common` :166 + `amos-term` :296 |
| libfont-freetype-perl | partly | profile cpan `Font::FreeType` `X11-Desktop` :126 installs it from cpan ; the debian package itself is not mapped in known deps |
| liblinux-inotify2-perl | covered | profile apt `zenka-common` + known deps :155-158 |
| libtext-unidecode-perl | covered | known deps `Text::Unidecode` :163-166 |
| libtest-needsdisplay-perl | outdated | `Test::NeedsDisplay` is not used anywhere under `src/` ; current installs use `cpanm -n` [ no tests ] anyway |
| liblwpx-paranoidagent-perl | partly | module covered via profile cpan `LWPx::ParanoidAgent` `zenka-common` :201 [ cpan install ] ; the debian package is not in any profile -- cpan-only on purpose, see known deps :208-209 |
| libio-socket-multicast-perl | covered | profile apt `zenka-common` + known deps :172-175 |

### cpan modules

| item | class | coverage |
| --- | --- | --- |
| IPC::Shm::Simple | covered | profile cpan `zenka-common` :186 + declaration `cfg/zenki/data/deps/p-mod/IPC__Shm__Simple` |
| Glib::Event | covered | known deps :262-265 [ deb `libglib-perl`, cpan fallback ] + declarations `cfg/zenki/osd-logo/deps/p-mod/Glib__Event`, `cfg/zenki/protocol-7-menu/..` |
| HTTP::Soup | covered | declaration `cfg/zenki/web-browser/deps/p-mod/HTTP__Soup` + known deps :160-162 [ cpan ] |
| Image::Hash | covered | profile cpan `graphics-matrix` :232 [ apt `libgd-perl` :228-231 covers its GD build dep ] |
| Poppler | covered | declaration `cfg/zenki/pdf2html/deps/p-mod/Poppler` + known deps :275-278 |
| cpanm --force XML::RSS::Timing | outdated | nothing installs this module anymore : the rss ticker uses the `LWP::UserAgent` fallback `src/rss.ticker.init_code:37` ; there is also no `--force` mechanism in `bin/p7-deps` [ it runs `cpanm -n`, which skips the failing date_conv test entirely ] |
| cpanm --force XML::RSS::TimingBot | outdated | not on cpan : known-deps note `src/base.known_dependencies:249-252` -- replaced by the lwp fallback |
| intel-gpu-tools [ optional, non-raspbian ] | covered | os/bin `intel_gpu_frequency` + `intel_gpu_top` `cfg/zenki/X-11/deps/os/bin/` -> `intel-gpu-tools` :421-422 + os/deb `cfg/zenki/cube/deps/os/deb/intel-gpu-tools` |
| firmware-misc-nonfree [ optional ] | missing | not in any profile, known-deps entry or zenka declaration |

### callers to update at retirement

- `CLAUDE.md:19`
- `CLAUDE.yaml:127` [ `install_full` ] and `CLAUDE.yaml:299`
- `.claude_readme_first/CLAUDE.md:14`
- `read-me/md/README.md:161`
- `data/yaml/todo/base.yaml:1163` [ manual server steps ]
- `data/yaml/docs/workflows/signature-testing-temp-keys.yaml:17` [ the minimal sibling ]
- `data/yaml/coding-tasks/generic-editor-namespace-and-hybrid-zenka.yaml:26`
- `data/ai-mem/claude/project-2026-10-11-servers-dns01-host-config.md:24` [ narrative ]
- `data/tasks/needs-testing/fuse3-migration.md:46` [ historical ]

---

## 2. install_minimal_dependencies.debian.sh

the minimal / server install script. the model the `minimal` +
`basic-remote-server` profiles were built from.

### apt packages -- main block

| item | class | coverage |
| --- | --- | --- |
| gcc | covered | os/bin `cfg/zenki/debian/deps/os/bin/gcc` |
| git | covered | profile apt `minimal` :9 + os/bin |
| make | covered | profile apt `minimal` :11 |
| cpanminus | covered | os/bin `cpanm` declared by most zenki -> `cpanminus` :411 |
| libc6-dev | covered | os/deb `cfg/zenki/debian/deps/os/deb/libc6-dev` |
| libmce-perl | outdated | `MCE` is not used anywhere under `src/` |
| liburi-perl | covered | known deps `URI` :206-209 |
| libclone-perl | covered | profile apt `zenka-common` + known deps :288-291 |
| libevent-perl | covered | known deps `Event` :12-15 |
| libcryptx-perl | covered | profile apt `vault` :82 + `zenka-common` deps via known deps |
| libcrypt-argon2-perl | covered | profile apt `vault` :83 |
| libio-stringy-perl | covered | known deps `IO::Scalar` :167-170 |
| liblist-moreutils-perl | covered | known deps `List::MoreUtils` :69-72 |
| libio-aio-perl | covered | profile cpan `minimal` :13 + known deps :24-27 |
| libjson-xs-perl | covered | profile cpan `minimal` :14 + known deps :143-146 |
| libnet-dns-perl | covered | profile apt `network` :56 + known deps |
| libtimedate-perl | covered | profile apt `zenka-common` :176 |
| libhttp-date-perl | covered | profile apt `zenka-common` :177 |
| liburi-query-perl | partly | the module is covered : profile cpan `URI::QueryParam` `zenka-common` :204 [ part of `URI` ] ; the `liburi-query-perl` debian package itself is not listed -- cpan path covers it |
| libdigest-crc-perl | covered | profile apt `zenka-common` + known deps |
| libdigest-elf-perl | outdated | `Digest::Elf` unused under `src/` |
| libfile-which-perl | covered | known deps :36-39 |
| libfile-finder-perl | outdated | `File::Finder` unused under `src/` |
| libperl-critic-perl | outdated | `Perl::Critic` unused under `src/` and `bin/` |
| libsub-uplevel-perl | outdated | `Sub::Uplevel` unused under `src/` [ it was a test dep of `Test::Exception` ] |
| libbsd-resource-perl | covered | profile apt `zenka-common` :161 |
| libdigest-jhash-perl | covered | profile apt `zenka-common` + known deps |
| libfile-extattr-perl | covered | profile cpan `zenka-common` `File::ExtAttr` :194 + os/deb `cfg/zenki/data/deps/os/deb/libfile-extattr-perl` |
| libfile-slurper-perl | outdated | `File::Slurper` unused under `src/` |
| libhash-flatten-perl | covered | profile apt `zenka-common` + known deps |
| libhttp-message-perl | covered | profile apt `zenka-common` + known deps |
| libyaml-libyaml-perl | covered | profile apt `runtime` :35 |
| libyaml-tiny-perl | covered | profile apt `runtime` :36 + known deps :402-405 |
| libconfig-simple-perl | outdated | `Config::Simple` unused under `src/` |
| libio-socket-ssl-perl | covered | profile cpan `minimal` `IO::Socket::SSL` :14 |
| libtest-requires-perl | outdated | `Test::Requires` unused [ dev test dep ] |
| libppix-utilities-perl | outdated | `PPIx::Utilities` unused -- it was a `Perl::Critic` dependency |
| shared-mime-info | covered | known deps `File::MimeInfo::Magic` :186-189 |
| libtest-exception-perl | outdated | `Test::Exception` unused [ dev test dep ] |
| libtest-sharedfork-perl | outdated | `Test::SharedFork` unused [ dev test dep ] |
| libcurses-perl | missing | `Curses` is used by `src/terminal.curses_ui.*` but the terminal zenka declares no `Curses` p-mod and no profile lists `libcurses-perl` |
| libhash-merge-simple-perl | covered | profile apt `zenka-common` + known deps |
| libproc-processtable-perl | covered | profile cpan `zenka-common` `Proc::ProcessTable` :208 + known deps :151-154 |
| libterm-readline-gnu-perl | outdated | no `Term::ReadLine::Gnu` use found under `src/` |
| libterm-readpassword-perl | outdated | `Term::ReadPassword` unused under `src/` |
| libterm-readkey-perl | covered | profile apt `vault` :85 |
| liblinux-termios2-perl | covered | profile apt `zenka-common` :165 |
| libterm-clui-perl | covered | profile apt `runtime` :37 + known deps :364-367 |
| libcompress-raw-lzma-perl | covered | profile apt `zenka-common` :173 |
| liblwp-protocol-https-perl | missing | `LWP::Protocol::https` is not in any profile or known-deps entry ; `LWP::UserAgent` itself is covered [ `zenka-common` :202 ] |
| libanyevent-http-perl | covered | profile apt `runtime` :28 + `ai-models` :266 |
| libasync-interrupt-perl | covered | profile apt `runtime` :29 [ an `AnyEvent::HTTP` dep ] |
| libguard-perl | covered | profile apt `runtime` :30 [ an `AnyEvent::HTTP` dep ] |
| libclass-accessor-lite-perl | missing | `Class::Accessor::Lite` unused under `src/` but was an `AnyEvent::HTTP` chain dep ; not in any profile -- apt pulls it in as a dependency of `libanyevent-http-perl` itself, so the explicit entry is redundant |
| libio-socket-multicast-perl | covered | profile apt `zenka-common` + known deps |
| libinline-c-perl | covered [ after review ] | CORRECTED : `Inline::C` IS used -- `AMOS7::INLINE` and `AMOS7::CHKSUM::ELF::Inline` [ amos-chksum, the bit tools, src/pager.view.true-int-color ]. now in `src/base.known_dependencies` [ debian libinline-c-perl ] and the `cryptography` profile [ + gcc ] |
| libconst-fast-perl | covered | profile apt `zenka-common` + known deps :361-364 |
| liblwpx-paranoidagent-perl | partly | profile cpan `zenka-common` `LWPx::ParanoidAgent` :201 -- cpan-only, debian package not listed [ see script 1 ] |
| liblinux-inotify2-perl | covered | profile apt `zenka-common` + known deps |
| libio-compress-perl | covered | profile apt `runtime` :27 |
| libcapture-tiny-perl | covered | profile apt `zenka-common` `Capture::Tiny` :187 |
| libfreezethaw-perl | covered | known deps `FreezeThaw` :210-213 + declaration `cfg/zenki/coding/deps/p-mod/Freeze__Thaw` |
| libcrypt-dev | covered | profile apt `zenka-common` :162 |
| libio-compress-lzma-perl | covered | profile apt `zenka-common` :178 |
| libgit-wrapper-perl | covered | known deps `Git::Wrapper` :138-141 [ git zenka ] |
| libconvert-asn1-perl | outdated | `Convert::ASN1` unused under `src/` |
| libdata-uuid-perl | covered | profile apt `zenka-common` :164 |
| libnet-ssh2-perl | covered | profile apt `network` :55 |
| libcrypt-openssl-x509-perl | covered | profile apt `zenka-common` :163 |
| libcrypt-openssl-bignum-perl | outdated | `Crypt::OpenSSL::Bignum` unused under `src/` |
| libcrypt-openssl-random-perl | covered | profile apt `zenka-common` :177 |
| libcrypt-openssl-rsa-perl | covered | profile apt `cryptography` :68 |

### apt packages -- dev block [ `bin/dev/..` ]

| item | class | coverage |
| --- | --- | --- |
| libterm-size-perl | partly | used by `bin/dev/true-false-stats` ; not in any profile or known-deps entry |
| libunicode-string-perl | missing | not used under `src/` ; only `Unicode::MapUTF8` below shows up in a dev script |
| libunicode-maputf8-perl | partly | used by `bin/dev/true-false-stats` ; not in any profile or known-deps entry |

### cpan modules

| item | class | coverage |
| --- | --- | --- |
| Crypt::Ed25519 | covered | profile cpan `cryptography` :71 + pm_src `canary-stability crypt-ed25519` `src/base.known_dependencies:357-360` |
| Digest::Skein | covered | profile cpan `cryptography` :76 + declaration `cfg/zenki/mpv/deps/p-mod/Digest__Skein` |
| Digest::BMW | covered | profile cpan `cryptography` :72 + pm_src `digest-bmw` :351-355 |
| Net::IP::Lite | covered | profile cpan `zenka-common` :205 [ cpan-only, known deps :109-110 ] |
| URI::QueryParam | covered | profile cpan `zenka-common` :204 |
| File::MimeInfo::Magic | covered | profile cpan `zenka-common` :193 |
| Sys::Statistics::Linux::CpuStats | covered | profile apt `libsys-statistics-linux-perl` `zenka-common` :174 [ `CpuStats` ships inside `Sys::Statistics::Linux` ] |
| SigAction::SetCallBack | partly | known deps cpan :27 exists, but no profile entry and no zenka declares it -- unreachable in practice |
| Config::Hosts | covered | declaration `cfg/zenki/download/deps/p-mod/Config__Hosts` |
| Tie::Dir | covered | profile cpan `runtime` :44 + declaration `cfg/zenki/models/deps/p-mod/Tie__Dir` |
| Filesys::Fuse3 | covered | profile cpan `amos-term` :300 [ apt `libfuse3-dev` :298 covers the build headers ] |

### workarounds and config steps

| item | class | coverage |
| --- | --- | --- |
| local crypt-curve25519 build [ fixed `fmul` copy ] + `git clean` of the build tree | covered | pm_src `crypt-curve25519` `src/base.known_dependencies:343-346` ; `install_pm_src` copies to a tempdir and builds there, so the `git clean` hack is no longer needed `data/lib-path/pm/AMOS7/deps/module.pm:200-236` |
| `bin/p7-deps install-service` at the end | covered | `bin/p7-deps install-service` -> `AMOS7::deps::service::install` `data/lib-path/pm/AMOS7/deps/service.pm:73` [ unit compared first, atomic write, daemon-reload -- an improvement over plain `cp` ] |
| `--force`-free `cpanm` default | covered | `bin/p7-deps` runs `cpanm -n` : no tests, so the test-failure overrides are unnecessary |

### callers to update at retirement

- `CLAUDE.md:20`
- `CLAUDE.yaml:126` [ `install_minimal` ] and `CLAUDE.yaml:299` [ `fix` ]
- `.claude_readme_first/CLAUDE.md:17`
- `read-me/md/README.md:147` and `:159`
- `data/yaml/coding-tasks/generic-editor-namespace-and-hybrid-zenka.yaml:26` + `:142`
- `data/yaml/docs/workflows/signature-testing-temp-keys.yaml:17`
- `data/yaml/todo/base.yaml:1163` [ manual server steps ]
- `data/tasks/needs-testing/fuse3-migration.md:46`
- `data/tasks/p7-deps-service-pm-src.md` [ the migration write-up itself ]
- `data/ai-mem/claude/project-2026-10-11-servers-dns01-host-config.md:24`
- `data/md/archive/completed-sessions/SESSION_STATUS_2025-11-29_template-caching-planning.md:89` [ historical ]

---

## 3. cpan_install.debian.sh

the older combined installer [ xvfb + cpanminus + browser stack ].

### apt packages

| item | class | coverage |
| --- | --- | --- |
| xvfb, cpanminus, libevent-perl, libio-aio-perl, libcryptx-perl, libproc-processtable-perl, libdigest-crc-perl, libclone-perl, libtimedate-perl, shared-mime-info, libhash-flatten-perl, libhash-merge-simple-perl, libfreezethaw-perl, libjson-xs-perl, libpoppler-glib-dev, libfile-mimeinfo-perl, libnet-ssh2-perl, libx11-keyboard-perl, liblinux-inotify2-perl, libnet-libdnet-perl, libclass-accessor-lite-perl, libio-stringy-perl, libdigest-jhash-perl, libimager-perl, libfont-freetype-perl, libglib-perl, libgtk3-webkit2-perl, libglib2.0-dev, libx11-protocol-perl | covered | same anchors as scripts 1 and 2 -- see the rows there |
| pciutils | covered | os/bin `lspci` `cfg/zenki/X-11/deps/os/bin/lspci` -> `pciutils` :416 |
| libsdl-perl | covered | profile apt `X11-Desktop` :104-107 [ with a comment explaining the alien-sdl from-source failure it prevents ] |
| libtext-lorem-perl | outdated | unused anywhere under `src/` |
| libx11-protocol-other-perl | covered | known deps `X11::Protocol::WM` / `X11::Protocol::XSetRoot` :300-307 |
| libterm-readpassword-perl, libterm-readline-gnu-perl | outdated | unused under `src/` -- see script 2 |
| libwebkitgtk-dev, gir1.2-webkit-3.0 | outdated | webkit1/gtk3 era packages ; replaced by `libgtk3-webkit2-perl` [ webkit2 ] which is in the `X11-Desktop` profile :103 |
| pkg-config | covered | profile apt `opencv` :239 |
| libgtk-3-dev | outdated | build dep for a from-source `Gtk3` cpan build ; the profile installs the prebuilt `libgtk3-perl` :101 instead |
| libgirepository1.0-dev | partly | not mapped in known deps ; only needed when `Glib::Object::Introspection` [ profile cpan `X11-Desktop` :128 ] builds from source |
| libgraphics-magick-perl | covered | profile apt `X11-Desktop` :100 + `graphics-matrix` :225 |
| libimage-exif-perl | covered | known deps `Image::EXIF` :182-185 |
| libxml-feed-perl | covered | declaration `cfg/zenki/rss-ticker/deps/p-mod/XML__Feed` |
| libxml-rsslite-perl | outdated | rss ticker replaced by the lwp fallback -- see script 1 |
| libsoup2.4-dev | missing | see script 1 |
| libfile-slurper-perl, libtest-needsdisplay-perl, libdigest-elf-perl | outdated | unused under `src/` -- see scripts 1 and 2 |
| libextutils-pkgconfig-perl, libextutils-depends-perl | outdated | build deps for from-source gtk/glib cpan builds ; the prebuilt debian bindings in the profiles make them unnecessary |
| liblwp-useragent-determined-perl | outdated | `LWP::UserAgent::Determined` unused under `src/` |
| gcc, make, libc6-dev, openbox, hsetroot | covered | see scripts 1 and 2 |

### cpan modules and steps

| item | class | coverage |
| --- | --- | --- |
| calls `perlmod_test_fail_overrides.sh` first | outdated | see script 10 -- the override has no consumer anymore |
| Crypt::Curve25519, Crypt::Ed25519, Digest::Skein, Tie::Dir, File::MimeInfo::Magic, Config::Hosts, HTTP::Soup, Poppler, Net::DNS | covered | same anchors as script 2 |
| Mediainfo | covered | declaration `cfg/zenki/mediainfo/deps/p-mod/Mediainfo` |
| Device::Gembird | covered | known deps :336-339 + declaration `cfg/zenki/power/deps/p-mod/Device__Gembird` [ the power zenka also declares `command_line_modules = Device::Gembird` `cfg/zenki/power/start.cfg:13` ] |
| Imager::Screenshot | covered | known deps :191-194 + declaration `cfg/zenki/screenshot/deps/p-mod/Imager__Screenshot` |
| XML::RSS::TimingBot | outdated | not on cpan -- replaced by the lwp fallback `src/base.known_dependencies:249-252` |
| `xvfb-run cpanm Glib::Event Gtk3::WebKit2` | outdated | `bin/p7-deps` runs `cpanm -n` [ no tests ], so no x display is needed for cpan installs ; both modules are covered via known deps and prebuilt debian packages anyway |

### callers to update at retirement

- `CLAUDE.md:21`
- `CLAUDE.yaml:128` [ `cpan_modules` ]
- `.claude_readme_first/CLAUDE.md:20`

---

## 4. cpan.cpanm.sh

the oldest big `xvfb-run cpanm` list.

| item | class | coverage |
| --- | --- | --- |
| `export PERL5LIB=.` for `HTTP::Soup` | missing | `bin/p7-deps` has no per-module env override mechanism ; `HTTP::Soup` itself is covered -- only the build-env workaround is gone |
| Event | covered | profile cpan `minimal` :12 + known deps |
| Clone, Hash::Flatten, Hash::Merge::Simple | covered | profile cpan `zenka-common` :188-190 |
| Term::ReadPassword | outdated | unused under `src/` |
| Term::ReadKey | covered | profile cpan `vault` :96 |
| Term::ReadLine::Perl | outdated | unused under `src/` |
| Proc::ProcessTable, Date::Parse, IO::Socket::Multicast, LWPx::ParanoidAgent, Sys::Filesystem, IO::Scalar, CryptX, Digest::JHash, JSON, JSON::PP, Net::SSH2, Config::Hosts, File::MimeInfo::Magic, LWP::UserAgent, Protocol::WebSocket, X11::Protocol, X11::Keyboard, X11::Protocol::WM, Convert::Color, Linux::Inotify2, FreezeThaw, SDL, Glib::Event, Gtk3::WebKit2, HTTP::Soup, Mediainfo, Device::Gembird, Net::Libdnet::Arp, Crypt::Curve25519, Crypt::Ed25519, Digest::Skein, Digest::CRC, Net::DNS | covered | profiles `minimal` / `zenka-common` / `X11-Desktop` / `vault` / `cryptography` / `network` + known deps + zenki declarations -- anchors in the tables above |
| File::Slurper | outdated | unused under `src/` |
| Crypt::CBC | outdated | unused under `src/` ; `libcryptx-perl` provides the `Crypt::Mode::*` family used instead |
| LWP::Protocol::https | missing | not in any profile or known-deps entry -- see script 2 |
| X11::Tops | outdated | typo-tier entry : not a real cpan distribution, nothing references `X11::Tops` under `src/` |
| Imager::Sreenshot | outdated | typo in the script ; the real `Imager::Screenshot` is covered |
| XML::RSS::TimingBot, XML::RSSLite | outdated | replaced by the lwp fallback -- see script 1 |
| `Module-Build-Pluggable-XSUtil` direct-from-github install | outdated | the upstream repo is a dead gitpan mirror ; the sibling minimal script already notes `libmodule-build-pluggable-perl` as 'no longer found' ; nothing under `src/` needs it |
| `xvfb-run` wrapper around the whole cpanm run | outdated | `cpanm -n` in `bin/p7-deps` needs no display -- see script 3 |
| note : `XML::SAX` anecdote | outdated | historical note only |

### callers to update at retirement

- none found outside `bin/dependencies/` itself [ not referenced in docs, `CLAUDE.md`, or configs ]

---

## 5. cpan.cpanm.minimal.sh

the minimal cpanm list.

| item | class | coverage |
| --- | --- | --- |
| Event, JSON::XS, Crypt::Ed25519, Crypt::Curve25519, Digest::Skein, Digest::CRC, Clone, Hash::Flatten, Hash::Merge::Simple, CryptX, Crypt::Argon2, Date::Parse, Proc::ProcessTable, Digest::JHash, Term::ReadKey | covered | profiles `minimal` / `vault` / `zenka-common` / `cryptography` + known deps + pm_src -- anchors above |
| IO::Handle::Record | outdated | unused under `src/` |
| Term::ReadPassword, Term::ReadLine::Perl | outdated | unused under `src/` -- see script 4 |

### callers to update at retirement

- none found outside `bin/dependencies/` itself

---

## 6. debian_dist_upgrade.sh

the dist-upgrade script.

| item | class | coverage |
| --- | --- | --- |
| noninteractive env block [ `DEBIAN_FRONTEND`, `APT_LISTCHANGES_FRONTEND`, `UCF_FORCE_CONFMISS`, `UCF_FORCE_CONFOLD`, `PAGER` ] | covered | `AMOS7::deps::dist_upgr::run` `data/lib-path/pm/AMOS7/deps/dist_upgr.pm:25-31` |
| `dpkg --force-confold --force-confdef --force-confmiss --force-overwrite --configure -a` recovery | covered | dist_upgr step 'dpkg recovery' :36-39 |
| `apt-get -fy install` recovery | covered | step 'apt-fix install' :40 |
| `apt-get -y` first pass with force-confold/confdef/confmiss | covered | step '<action> pass 1' :41-45 |
| `pam-auth-update --force` | covered | step :46 [ best-effort on failure, an improvement ] |
| `rm -rf /var/cache/apt/mediainfo_tmp*` | covered | step :47 + final cleanup :98 |
| `apt-get update` | covered | step :48 |
| `apt-get -fy` second pass with force-overwrite | covered | step '<action> pass 2' :49-54 |
| `apt-get clean && apt-get -y --purge autoremove` | covered | step :55-57 |
| `rm -rf /root/.cpanm` | covered | final cleanup :98 |
| `source /etc/os-release` banner echo | outdated | cosmetic only ; `detect_os` / `read_os_release` `data/lib-path/pm/AMOS7/deps/os_package.pm:82-139` cover the os identity need |
| `export PATH=/usr/sbin:...` | outdated | `bin/p7-deps` is a real installed tool on `PATH` ; `debp.pm` runs apt list-form without a shell |
| `upgrade` as an alternative action | covered | `bin/p7-deps dist-upgrade [action]` passes the action through `bin/p7-deps` run_dist_upgrade -> `dist_upgr::run($action)` |
| commented-out `dpkg --purge` of rc packages | outdated | was already disabled in the legacy script |

### callers to update at retirement

- `cfg/zenki/v7-zenki/start-set-up.base:21` [ `exec_bin = debian_dist_upgrade.sh` ]
- `cfg/zenki/v7-zenki/start-set-up.remote-server:36`
- `cfg/zenki/v7-zenki/start-set-up.remote-server-lowram:28`
- `cfg/zenki/v7-zenki/start-set-up.local-models:23`
- `cfg/zenki/v7-zenki/start-set-up.browser-test:20` [ added in review -- missed by the audit ]
- `data/yaml/todo/base.yaml:1163` [ manual server steps ]
- `data/ai-mem/claude/project-2026-10-11-servers-dns01-host-config.md:24`
- `data/tasks/completed/sys-deps-zenka.md:29,200` and `sys-deps-zenka-audit.md:37,52` [ historical, describe the replacement ]
- `data/asc/what-AI-thinks/markdown-form/protocol7/docs/p7-startup-guide.md:146` [ generated/ai material ]

note : the five `start-set-up.*` configs are live zenka setup definitions -- at
retirement they either switch to `bin/p7-deps dist-upgrade` or to the
`debian.cmd.*` / sys-deps equivalents.

---

## 7. i386_i686_fix.sh

the 32-bit curve25519 workaround.

| item | class | coverage |
| --- | --- | --- |
| `cpanm https://github.com/anotherlink/crypt-curve25519.git` [ renamed `fmul` fix ] | covered | the same fixed sources ship locally as pm_src `crypt-curve25519` `src/base.known_dependencies:343-346`, built by `install_pm_src` for every profile carrying `Crypt::Curve25519` [ `cryptography` :71 ] |
| 32-bit / i386 target | outdated | i386 era : the repo targets 64-bit debian hosts now [ `cfg/zenki/build/recipes/mediainfo.yaml:29` still maps `i686: i386` for one build recipe, which is a build-arch note, not a host-arch target ] |

### callers to update at retirement

- none found outside `bin/dependencies/` itself

---

## 8. install_browser_zenka_dependencies.sh

the browser-zenka installer.

### apt packages

| item | class | coverage |
| --- | --- | --- |
| apt-get update first | partly | `debp::install_apt` does not run `apt-get update` before installing [ it retries on failure and invalidates its cache after ] ; `bin/p7-deps dist-upgrade` and `p7-install` cover update moments, but a profile install on a stale index has no explicit refresh |
| pciutils, cpanminus, libevent-perl, libproc-processtable-perl, libio-aio-perl, libclone-perl, libhash-flatten-perl, libhash-merge-simple-perl, libjson-xs-perl, libio-socket-multicast-perl, libtimedate-perl, gcc, make, libdigest-crc-perl, libc6-dev, libglib-perl, libx11-protocol-perl, libx11-protocol-other-perl, libx11-keyboard-perl, liblinux-inotify2-perl, openbox, hsetroot, xvfb, libgtk3-webkit2-perl, libcryptx-perl, libhttp-message-perl, libhttp-date-perl, libglib2.0-dev | covered | same anchors as scripts 1-3 |
| libterm-readpassword-perl, libterm-readline-gnu-perl | outdated | unused under `src/` |
| libfile-slurper-perl, libtest-needsdisplay-perl, libdigest-elf-perl | outdated | unused under `src/` |
| libclass-accessor-lite-perl | missing | see script 2 [ redundant in practice : pulled in by `libanyevent-http-perl` ] |
| libextutils-pkgconfig-perl, libextutils-depends-perl | outdated | from-source build deps -- see script 3 |
| libsoup2.4-dev | missing | see script 1 |

### cpan modules and steps

| item | class | coverage |
| --- | --- | --- |
| Crypt::Ed25519, Digest::Skein, Glib::Event | covered | see script 2 |
| local crypt-curve25519 + `git clean` | covered | pm_src -- see script 2 [ tempdir build, no tree cleanup needed ] |
| cpanm --force XML::RSS::Timing | outdated | see script 1 |
| `PERL5LIB=. PERL_USE_UNSAFE_INC=1 cpanm HTTP::Soup` | missing | the env workarounds have no equivalent in `bin/p7-deps` ; the module itself is covered -- only the build-env handling differs |
| `useradd -m -r nailara` | outdated | the service unit runs as `User=root` `data/lib-path/systemd/system/Protocol-7.service` ; per-zenka unix users are handled through `auth.setup.usr.*` in the cube config, not a fixed `nailara` account |

### callers to update at retirement

- the header of `install_dependencies.debian.sh:4` points at this script [ 'see install_browser_agent_dependencies.sh' ]
- no doc / config references found outside `bin/dependencies/`

---

## 9. llama-server-vision.sh

not a dependency installer at all -- a service launcher wrapper for the
llama-server text endpoint + mtmd-cli vision subprocess. it installs nothing.

| item | class | coverage |
| --- | --- | --- |
| model search paths, mmproj detection, log dir, `LD_LIBRARY_PATH`, exec of `llama-server-cuda` | missing [ out of deps scope ] | nothing in the profile system covers or should cover this : it is runtime service wiring, equivalent to what zenki `start.cfg` / `exec_bin` declarations do |
| dependency aspect [ cuda llama build ] | missing [ out of deps scope ] | the binary comes from `bin/build-scripts/llama-cpp/build-llama-server-cuda-flashattn.sh` per `cfg/zenki/coding/zenka.v7:161-165` -- a build script, not a package dep |
| launcher as a whole | outdated [ suggestion ] | looks superseded : the repo history records the `llama-server-vision` zenka renamed to `llama-vision` on 2026-01-01 [ `data/src-review/base.list.subroutines/history:866` ] and the current vision path is the `lm-vision` zenka [ `cfg/zenki/lm-vision/` ] with `cmd.analyze_image` ; no `cfg/` or `src/` reference to this script was found |

### callers to update at retirement

- `bin/test-scripts/test-json-cleanup.pl:22` and `test-simple-cleanup.pl:18` call `p7c llama-server-vision.analyze_image`
- `bin/test-scripts/TESTING_GUIDE.md:140`
- `data/md/coding-tasks/2026-08-05-task-archive-audit-results.md:120` [ notes the http backend replaced the binary-rebuild approach ]
- various `data/yaml/docs/*` and `data/md/documentation/*` mention the zenka name

note : retire this one in a separate decision -- it does not belong to the
dependency-scripts question even though it lives in the same directory.

---

## 10. perlmod_test_fail_overrides.sh

the forced-install override.

| item | class | coverage |
| --- | --- | --- |
| `cpanm -f XML::RSS::Timing` [ rt.cpan.org #129058, date_conv test failure ] | outdated | the module has no consumer anymore : the rss ticker uses the `LWP::UserAgent` fallback `src/rss.ticker.init_code:23-37` and the known-deps note records that `XML::RSS::TimingBot` is not on cpan `src/base.known_dependencies:249-252` ; `bin/p7-deps` runs `cpanm -n` anyway, so a forced-install mechanism is unnecessary |

### callers to update at retirement

- `bin/dependencies/cpan_install.debian.sh:31` [ its only caller ]

---

## summary -- what blocks retirement, ordered by importance

1. [ ] **live zenka setup configs still `exec_bin` the dist-upgrade script** :
   the five `cfg/zenki/v7-zenki/start-set-up.*` files call
   `debian_dist_upgrade.sh` directly. `bin/p7-deps dist-upgrade` covers every
   step the script did [ `AMOS7::deps::dist_upgr` ], so this is a config edit,
   not a functionality gap. until it is done, deleting the script breaks the
   base / remote-server setup flows.
2. [ ] **doc and onboarding references** : `CLAUDE.md`, `CLAUDE.yaml`,
   `.claude_readme_first/CLAUDE.md`, `read-me/md/README.md`,
   `data/yaml/todo/base.yaml:1163` and two `data/yaml/coding-tasks` files
   still tell humans and agents to run the legacy installers. they must point
   at `bin/p7-install` / `bin/p7-deps install <profile>` first, or every new
   host and every ai session keeps re-anchoring on the old path.
3. [ ] **`compton`, `unclutter`, `mediainfo` cli binaries undeclared** :
   used by the compton zenka, `src/auto-hide.startup` and the mediainfo
   zenka, but no `deps/os/bin` entry exists. one-line declarations each, or
   three silent runtime gaps after retirement.
4. [ ] **`firmware-misc-nonfree` optional install gone** : only relevant on
   non-raspbian hosts with hardware needing non-free firmware ; decide
   whether any current host still needs it before dropping.
5. [ ] **`libcurses-perl` / `Curses` gap** : `src/terminal.curses_ui.*` uses
   it, nothing declares it -- a pre-existing hole the legacy script used to
   paper over.
6. [ ] **small missing deb entries, all low-risk** : `libsoup2.4-dev` +
   `liblwp-protocol-https-perl` + `libgirepository1.0-dev` [ only needed for
   from-source cpan builds ], `libinline-c-perl` [ inline build compiler ],
   `libclass-accessor-lite-perl` [ redundant via apt deps ], the
   `bin/dev/true-false-stats` pair [ `libterm-size-perl`,
   `libunicode-maputf8-perl` ].
7. [ ] **env-workaround loss is accepted, not restored** : `PERL5LIB=.`,
   `PERL_USE_UNSAFE_INC=1` for `HTTP::Soup` and the `xvfb-run` cpanm wrapper
   have no p7-deps equivalent ; harmless because `cpanm -n` + prebuilt debian
   bindings removed the need -- noted so nobody re-adds them by reflex.
8. [ ] **`llama-server-vision.sh` needs a separate retirement decision** :
   it is a service launcher, not a dep installer, and appears superseded by
   the `lm-vision` zenka ; its callers are test scripts and docs.
9. [x] **everything else is covered or outdated** : all dist-upgrade steps,
   the service-unit install, the pm-src curve25519/ed25519/bmw builds, the
   i386 fmul fix [ via local pm-src ], the test-failure force overrides [
   modules dropped ], useradd nailara [ unit runs as root ], and the bulk of
   both apt lists [ profiles + known deps + zenki declarations ].

## counts per class

counts of the distinct classified items across all ten tables above :

| class | count |
| --- | --- |
| covered | 139 |
| partly | 9 |
| missing | 16 [ of which 2 are the out-of-deps-scope llama-server-vision rows ] |
| outdated | 63 |

[ 229 classified rows in total ; bundled rows where the table says 'same
anchors as scripts 1 and 2' count once per bundle.]

net of the suggestion-only `[ outdated ]` rows, the retirement blockers are
the 9 `[ partly ]` and 14 in-scope `[ missing ]` items, and only three of
those are runtime-relevant : the undeclared `compton` / `unclutter` /
`mediainfo` binaries and the `Curses` gap [ items 3 and 5 in the summary ].
the rest are deb entries for from-source builds plus doc/config re-anchors.

#,,,,,.,,,,,.,,,,,...,,,.,.,.,.,,,...,,.,,,..,..,,...,...,,.,,.,.,,..,.,,,.,.,
#67FB5QU5TEN4UOIQKTCXFC5J7WKM374Z34PYZH3XYSXAJAOSI2YDU4Q5SC4IPN34MTSVWSSNSDDAA
#\\\|T5GHRUTHFT335FGIKAZF3JXKDGURC57QXWID4CQDJGMBCIWMZEU \ / AMOS7 \ YOURUM ::
#\[7]BQMUYAWMUGY2F6DBTUPNHL2ADFYYNEY4L4UU3X2SAHMXF6K62MDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
