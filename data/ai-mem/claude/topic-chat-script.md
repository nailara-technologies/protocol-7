---
name: bin/chat design
description: multi-model file-backed conversation script design, channels, archiving, consensus mode
type: project
originSessionId: 9e81219d-67a4-445c-8e14-06a7463ea31e
---
bin/chat design completed 2026-05-14. design doc at data/md/development/CHAT-SCRIPT-DESIGN.md.

Key decisions:
- history in data/chat/channel/<name>/history — committed to git, syncs across nodes
- :#channel: keyword switches channel, :model: switches model, :all: = consensus broadcast
- caller detection via P7_CHAT_CALLER env var, fallback to /proc/<ppid>/comm
- xz archive on clear (instant, not timer-based), auto-rotation at 512KB threshold
- -wait-reply/-file flags matching coding-task/kimi-task interface
- main channel always present as ambient social space

**Why:** clean standalone consensus test bed before zenki infrastructure is ready; also async inbox between models via file polling.

**How to apply:** implementation is next task for kimi. see CHAT-SCRIPT-DESIGN.md for full spec.

#,,..,,,,,,.,,,.,,,,.,,.,,..,,,..,.,.,...,,,,,..,,...,...,...,,.,,.,.,...,,,.,
#VO47L37VG6XSFV3O2WOTVBCVAWBHITNZRIH4ZXDU26UMCSDAK5AAKQFDWA3DTXP6MA5SDGKI5DYOC
#\\\|AVIZVL6EVO46F7L7VIALIZUCDUYTVIHEH4RLGUSAC6INVKE5DWJ \ / AMOS7 \ YOURUM ::
#\[7]CZZZIJWKHCZ74UEH4C442NHIKYQJNYDYG5JMHZ4MTQCCBJV2DMBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
