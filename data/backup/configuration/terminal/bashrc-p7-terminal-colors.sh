# p7 palette terminal colors — bashrc snippet
#
# install on a fresh machine: append this file's contents to ~/.bashrc
# (after the "enable color support of ls" block), and drop eza-theme.yml
# at ~/.config/eza/theme.yml (mkdir -p ~/.config/eza first).
#
# ls stays plain GNU coreutils on purpose, so `ls -lart` never breaks —
# eza's -t flag means "which timestamp to show", not "sort by time" like
# GNU ls, so eza can't be a drop-in `ls` alias. ll/la are the themed
# eza-powered listings instead; they get full permission/date/size/user
# coloring that plain ls has no LS_COLORS keys for at all.
#
# palette source: data/gfx/palette/protocol-7-palette.md,
# data/color-themes/p7-blue.yaml. eza-theme.yml in this directory is the
# canonical copy of ~/.config/eza/theme.yml — the LS_COLORS block below is
# kept in sync with it by hand (same hex values), since eza lets
# LS_COLORS/EZA_COLORS override its own theme.yml for the base file-kind
# keys (di/ln/ex/pi/so/bd/cd/or) and extension globs.

alias ll='eza -la --header --group'
alias la='eza -a'
alias lt='eza -la --header --group --sort=modified --time-style=long-iso'

_p7_ls_colors="fi=38;2;68;39;172"          # regular files — purple
_p7_ls_colors+=":di=01;38;2;6;71;195"      # directories — blue
_p7_ls_colors+=":ln=01;38;2;21;78;180"     # symlinks — lighter blue
_p7_ls_colors+=":or=01;38;2;106;36;129"    # broken symlinks — red
_p7_ls_colors+=":ex=01;38;2;57;156;5"      # executables — green
_p7_ls_colors+=":pi=38;2;158;113;6;48;2;24;3;36"       # pipes — gold on dark plum
_p7_ls_colors+=":so=01;38;2;21;78;180;48;2;24;3;36"    # sockets — blue on dark plum
_p7_ls_colors+=":bd=01;38;2;158;113;6;48;2;24;3;36"    # block devices — gold on dark plum
_p7_ls_colors+=":cd=01;38;2;174;124;7;48;2;24;3;36"    # char devices — brighter gold on dark plum
for _p7_ext in aac au flac m4a mid midi mka mp3 mpc ogg ra wav oga opus spx xspf; do
    _p7_ls_colors+=":*.${_p7_ext}=02;38;2;21;78;180"   # audio files — dim blue (was raw ANSI cyan)
done
export LS_COLORS="${LS_COLORS}:${_p7_ls_colors}"
unset _p7_ls_colors _p7_ext
