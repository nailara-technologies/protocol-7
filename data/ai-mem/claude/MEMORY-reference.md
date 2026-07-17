# MEMORY-reference — Reference & Settled Conventions

durable how-to knowledge and settled rules. Reference: zenka catalog (site-yaml, git-watch,
fetch-files, usb-backup), tool/SHM architecture, tls-acme, invoke-model-manager, unicode repair,
core patterns/templates. Settled conventions: cube auth prefix, .cmd. reply contract, send.local
vs base., timer/config gotchas, file-io API, deferred-init callbacks, C25519 config paths.

## Reference
- [unicode-encoding-repair](reference-unicode-encoding-repair.md), [patterns](topic-patterns.md), [coding-zenka-templates](topic-coding-zenka-templates.md) — UTF8 fix; core patterns
- [tool-shm-architecture](topic-tool-shm-architecture.md), [tool-suggestions](topic-tool-suggestions.md), [language-detection](topic-language-detection.md) — SHM+mmap vision; 30 langs
- [site-yaml-zenka](topic-site-yaml-zenka.md), [site-yaml-web-research](topic-site-yaml-web-research.md), [usb-backup-zenka](topic-usb-backup-zenka.md) — URL→YAML; web research; udev→restore
- [git-watch-zenka](topic-git-watch-zenka.md), [reasoning-design-templates](topic-reasoning-design-templates.md) — force-push detection; 7 viz designs
- [harmonic-silence-active-cancellation](topic-harmonic-silence.md), [key-tree-ring-routing](topic-key-tree-ring-routing.md) — waveform-cancellation; namespace=key-tree, rings=keys
- [fetch-files-zenka](topic-fetch-files-zenka.md), [tls-acme](topic-tls-acme.md), [amos7-p7-loader](topic-amos7-p7-loader.md) — huggingface.* LIVE; SNI/SSL/ACME
- [invoke-model-management](topic-invoke-model-management.md), [invoke-model-manager](topic-invoke-model-manager.md) — uuid vs verbose; Term::Clui planned
- [image-archive-system](topic-image-archive-system.md), [base-curve-system](topic-base-curve-system.md) — vision-scored storage; base.curve.* animation
- [friction-visualization](topic-friction-visualization.md), [searchable-index-and-visualization](topic-searchable-index-and-visualization.md), [migration](topic-migration.md) — checksum-indexed dataspace; KVM/Debian migration

## Settled conventions
- [cube-auth-name-collision](feedback-cube-auth-name-collision.md) — names matching `(declare|select)-<word>` broke auth; mandatory auth. prefix
- [zenka shutdown end_code](feedback-zenka-shutdown-end-code-callback.md), [gtk ondemand zenka startup](feedback-gtk-ondemand-zenka-startup.md) — `push <callbacks.end_code>` not $SIG{}; gtk needs Gtk3->init first
- [cmd reply must be string](feedback-cmd-data-must-be-string.md) — .cmd. routines must return {mode=>true|false, data=>STRING}
- [kimi reload baseline noise](feedback-kimi-reload-baseline-noise.md), [kimi v7 console hint](feedback-kimi-v7-console-hint.md) — check baseline first; console at `/dev/shm/.7/STDOUT/NIW7OAQ`
- [File Creation](feedback-file-io-api.md), [version files every commit](feedback-version-files-every-commit.md) — no fake signature stub; version files ride every commit
- [tile openbox dep redundant](feedback-tile-openbox-dependency-redundant.md), [base. prefix stripped](feedback-base-prefix-stripped.md) — use `send.local`
- [.cmd. segment stripped](feedback-cmd-segment-stripped.md), [filter-repo prefix](feedback-filter-repo-amend.md), [P7 data nesting](feedback-p7-data-nesting.md) — .cmd. callable w/o segment; <a.b.c>=$data{a}{b}{c}
- [s_warn single-arg](feedback-s-warn-single-arg.md), [access grant scope](feedback-access-grant-scope.md) — plain `warn` for single-msg; "no perm" needs whitelist only
- [ondemand zenka start checklist](feedback-ondemand-zenka-start-checklist.md), [devmod leave disabled](feedback-devmod-leave-disabled.md) — start-file recipe; leave devmod eval/exec commented
- [timer undef interval](feedback-timer-undef-interval.md), [each+continue+keys](feedback-each-continue-keys.md) — undef after/interval=max-rate; `continue{keys %h}` = infinite loop
- [ntime](feedback-ntime.md), [eval-code no angle-brackets](feedback-eval-code-no-angle-brackets.md), [zenka config relative paths](feedback-zenka-config-relative-paths.md) — cfg needs <system.root_path>
- [Cross-zenka](feedback-cross-zenka-deferred-reply.md), [Access control](feedback-buffer-access-control.md), [httpd](feedback-httpd-deferred-reply.md) — httpd never loads plugin.web.*
- [Timer Args](feedback-timer-module-args.md), [Deferred Init](feedback-deferred-init.md) — push onto system.callbacks.initialized
- [config reload clobber](feedback-config-reload-clobber.md), [route-send command format](feedback-route-send-command-format.md) — `reload config/all` overwrites runtime; no cube. prefix
- [user-perfectionism-and-pace](user-perfectionism-and-pace.md) — "done" means perfectly smooth; let solo tuning passes run

#,,.,,..,,.,,,,,,,,,.,.,.,,,,,..,,.,,,,.,,..,,..,,...,...,.,,,,,.,.,,,,..,.,.,
#ZM5SGUYJDTULYHR2ZMIGXH3UGV4J5QEK3MMYU47S3LTAISXWD3TAIJVJFX3PCNY63A432V3HNR4IE
#\\\|AUIVAGDYXI6IZR43JH2UUPFXLJYP344ZETHDSC7BOK5YR4J5D6U \ / AMOS7 \ YOURUM ::
#\[7]3CWBGYJRXCCWFIUIVFZWY43BKS2SQMPCTZHAYWCPB5AINA5NMWBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
