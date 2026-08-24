---
name: topic-powershell-native-toast-notifications
description: working native Windows toast notification backend for WSL-hosted zenki, built via the powershell zenka (AUMID registration + COM shortcut registration + local icon caching + selectable icon tags) -- bypasses X11/dbus/notify-osd entirely
metadata:
  type: reference
---

built 2026-08-24 as the practical resolution to [[topic-smtpd-actionable-
mail-channels-notify]]'s problem 3 (notify-osd/dunst can't reliably render
popups on this WSLg host even once dbus/notify-osd are fully online and
correctly wired). Rather than keep debugging X11/compositor behavior, this
uses `powershell.exe` (already WSL-interop-reachable via `src/powershell.
exec`) to fire native Windows toast notifications directly -- no X11, no
dbus, no notify-osd/dunst dependency chain at all.

**files**: `src/powershell.init_code` (one-time AUMID+shortcut setup, icon
map + cache), `src/powershell.notify` (generic toast helper), `src/
powershell.notify_from_args` (shared arg-parsing + icon-tag extraction,
mirrors `notify.cmd.loves`'s quoting convention), `src/powershell.cmd.
notify-msg` (generic command, `p7` icon default) and `src/powershell.cmd.
notify-loves-it` (thin wrapper, `loves-it` icon default) as the two
concrete commands built on it so far, `src/powershell.util.
extract_icon_tag` (the `::icon:<name>::` prefix-tag mechanism).

## the four things that had to be solved, in the order discovered

1. **branding**: an unpackaged script calling `[Windows.UI.Notifications.
   ToastNotificationManager]::CreateToastNotifier('some-string')` shows the
   toast attributed to "Windows PowerShell" (or double-toasts, if you
   borrow PowerShell's own real AUMID
   `{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\
   powershell.exe` as a workaround -- confirmed live, don't reuse that
   trick). Fixed by registering a REAL custom AUMID via registry:
   `HKCU:\Software\Classes\AppUserModelId\<aumid>` with a `DisplayName`
   value. This alone is enough for correct title/attribution text.

2. **large per-notification image** (`<image placement='appLogoOverride'
   .../>` in the toast XML): does NOT reliably load from a
   `\\wsl.localhost\<distro>\...` UNC path, confirmed by direct test (fails
   silently, no image, no error). Must be a genuine windows-local file.
   Resolved by caching icons into `$env:LOCALAPPDATA\protocol-7\` once at
   init time. `Copy-Item` in PowerShell CAN read the UNC source path fine
   (only the toast image *loader* refuses it), so the whole cache step runs
   windows-side in one script -- no perl-side file copy needed for the
   init-time icons (though `powershell.notify` itself still has a fallback
   copy-if-missing path for icons not pre-cached at init).

3. **small attribution icon** (shown next to the DisplayName in Action
   Center): registry-only `IconUri` on the AUMID key does NOT make this
   show up, confirmed live even after restarting `explorer.exe` (which
   *does* force a re-read of AUMID registrations generally, and also
   revealed `explorer.exe` is involved in desktop compositing -- all
   translucency briefly vanished during its restart). The actually
   load-bearing fix: create a real Start Menu shortcut
   (`$env:APPDATA\Microsoft\Windows\Start Menu\Programs\<aumid>.lnk`) and
   set the AUMID via `IShellLinkW`/`IPropertyStore` COM interop (PROPERTYKEY
   `{9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3},5`), not just the registry key.
   The registry `DisplayName`/`IconUri` are kept too (officially documented
   minimum), but the shortcut+property-store path is what actually makes
   the icon appear on this Windows version. Full C# interop is embedded in
   `powershell.init_code`'s `Add-Type` block -- compiled and ran clean on
   first real attempt (no vtable-order crash), but treat any edit to those
   interface declarations as high-risk: wrong COM vtable order corrupts the
   call, doesn't throw a clean error.

4. **selectable icon per notification**: user-requested `::icon:<name>::`
   optional leading tag on the raw command text (e.g. `::icon:p7::title
   message`), resolved against `<powershell.icons>` (`p7` = nailara logo,
   `loves-it` = loves.png), falling back to the calling command's own
   default when absent/unknown. Implemented as a small reusable helper
   (`powershell.util.extract_icon_tag`) called before the existing
   quote-based title/message parsing.

**command naming, settled 2026-08-24**: one generic command
(`powershell.cmd.notify-msg`, `p7` icon by default) plus thin wrapper
commands per notable icon (`powershell.cmd.notify-loves-it`, `loves-it`
default) -- both just call the shared `powershell.notify_from_args` with a
different `default_icon`, so adding another wrapper is a ~10-line file.
User's stated plan: the `loves-it` artwork (currently a static PNG) is
expected to be amended later with "elf-avatar" renderings extracted from
an existing corpus of tens of thousands of text-to-image generations,
gated on categorization/categorized-storage tooling built on the
`lm-vision` zenka -- not started, no scope yet, just don't be surprised
when `loves-it`'s icon file changes identity later.

**icon design bar for future custom icons, 2026-08-24**: applies beyond
just `loves-it` -- `notify.cmd.message`/`.warn`/`.info`/`.msg_reload`
(both the powershell-toast and `dunst` backends) still use generic
default icons, not ugly but visibly generic. Deliberately deferred, not
urgent -- explicit design bar for whenever this gets picked up: suitable
quality, non-default symbology, unambiguous (must still read clearly as
what it represents) yet psychedelic (fits this project's visual
aesthetic, not corporate-flat). User expects this as "a more relaxed
weekend session" task, likely once a native desktop is available again
(rather than this WSL dev environment) for actually producing/reviewing
the artwork.

## gotchas worth remembering

- PowerShell's WinRT type-literal syntax `[Namespace.Type, AssemblyName,
  ContentType = WindowsRuntime]` cannot be split across lines AT ALL --
  neither a bare newline nor an explicit backtick continuation is accepted
  inside it, confirmed by direct test (both produce parser errors). These
  3 lines in `powershell.notify`'s toast template are the one deliberate
  exception to the project's line-width convention; don't "fix" them.
- ordinary C# method signatures (unlike the PS WinRT literal above) wrap
  freely -- no restriction there, used to bring `powershell.init_code`'s
  embedded `IShellLinkW` interface declaration under the line-width limit.
- the toast XML template uses a PowerShell single-quoted here-string
  (`@'...'@`), not double-quoted (`@"..."@`) -- title/message text can come
  from untrusted sources (e.g. mail subjects via a future smtpd
  integration) and a double-quoted here-string WOULD interpolate `$vars`/
  backticks in that content, a real injection surface. Single-quoted
  here-strings don't interpolate at all, so only XML-entity escaping
  (`&`/`<`/`>`) is needed on the untrusted text, not PowerShell escaping.
  PowerShell single-quote escaping (`''`) is still needed for values
  embedded OUTSIDE the here-string in ordinary `'...'` string literals
  (the AUMID, the local icon path).
- `-EncodedCommand` (base64 UTF-16LE) sidesteps both the nested-quoting
  hell of building a large multi-line script through several layers of
  shell/Perl/PowerShell quoting AND the script-file execution-policy
  restriction (`.ps1` files need to be signed or policy-exempted;
  `-Command`/`-EncodedCommand` don't count as "running a script file" and
  aren't subject to that check) -- used during live iteration on this
  feature, not something the shipped code needs (the shipped code passes
  scripts via `-Command` through `open3`, which also isn't a script file).

## related, not yet done

[[topic-smtpd-actionable-mail-channels-notify]]'s channels-based redesign
(smtpd publishing an event rather than calling a notify target directly)
is still the right long-term shape for cross-host delivery -- this
powershell-toast backend is what a *local* WSL-hosted subscriber to that
channel would eventually call, not a replacement for the pub/sub design.
The `dunst` task ([[dunst-notify-zenka]]) remains relevant for pure-Linux
(non-WSL) desktop deployments where there's no Windows host to hand
notifications to.

related: [[topic-smtpd-actionable-mail-channels-notify]], [[dunst-notify-zenka]]

#,,,.,...,.,.,,,.,...,...,.,,,,,,,,,,,,,,,,,.,..,,...,...,,,,,..,,,,.,,,,,,..,
#SCOUEI6AJFML7UUZNMDSSSO4B5AKTZMFN4N6FMGRX4GJRAIYB2OCTZ4Q7QTTR2JXB7D2XHMHEKFHU
#\\\|WJ7WPPENHSJT6KRJENFV3Y765NNDYVAJ2J37B6EN5PP642KNVFR \ / AMOS7 \ YOURUM ::
#\[7]SJHWH7QJSDTQSQWYVPCMNLD3USOZ5AYQNI7LEPKDL53XREMKAIBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
