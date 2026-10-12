---
name: readkey-raw-mode-leaves-icrnl
description: Term::ReadKey ReadMode(4) leaves the tty's icrnl flag on -- pasted "\r\n" arrives as two line feeds ; cause of the 'interlaced empty lines' on WSL \ Windows Terminal pastes, fixed 2026-10-12
metadata:
  type: feedback
---

`Term::ReadKey::ReadMode(4)` [ raw ] does NOT clear `icrnl` on this
system : the tty driver still turns every "\r" into "\n", so a Windows
Terminal paste [ crlf line endings ] reaches the program as "\n\n" -- one
empty line after every pasted line. no terminal setting fixes it, it is
the program's tty mode. confirmed and fixed 2026-10-12 in
AMOS7::TERM::Editor [ commit efaf3f29b ] : `_disable_icrnl` [ core
POSIX::Termios ] right after ReadMode(4), ReadMode(0) restores on exit ;
plus bracketed paste [ "\e[?2004h", block insert, line endings
normalised ] and "\r\n" as one enter without it. the user confirmed the
interlacing is gone.

**Why:** the symptom looked like a terminal or WSL problem and had
resisted every settings change ; the second cause [ the editor took "\r"
and "\n" each as enter ] alone would not have explained it.

**How to apply:** any raw-mode key reader [ nshell, menus, new editors ]
: clear icrnl after ReadMode(4), or reuse AMOS7::TERM::Editor's reader.
when pasted text shows doubled line breaks, check the tty flags first
[ `stty -a` inside the program's mode ], not the terminal settings.

#,,,,,,,,,,,,,.,,,,.,,,,,,.,.,...,.,,,,,,,.,,,..,,...,...,..,,,,.,...,...,,.,,
#DYGLQQLU4LFEAQFZKZSFAIQKWIIIUYGJY6TRGA6Y2EEPLE4VJHW7K476THJZAS77TTMTTIIB7II44
#\\\|3IRS6D6AX54Q7W6P4DPL56UI2KSNABUAQURXGOR3YFV5UJUPZK7 \ / AMOS7 \ YOURUM ::
#\[7]BDAA26KPCYJE5H64YYECDBVUVHMRESQMMJESTOOXQDYTJTDZJUDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
