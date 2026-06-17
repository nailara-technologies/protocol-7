#!/usr/bin/env python3
"""Repair SciTE properties files to use the protocol-7 colour palette."""

import re
import sys
import os
import colorsys
from pathlib import Path

# Project palette
BLUE = '#0647C3'
GREEN = '#47C306'
GOLD = '#C58D07'
PURPLE = '#4427AC'
SLATE = '#46486D'
DARK1 = '#12061B'
DARK2 = '#180324'
DARKEST = '#000011'
DARKBLUE = '#032552'

PALETTE = {BLUE, GREEN, GOLD, PURPLE, SLATE, DARK1, DARK2, DARKEST, DARKBLUE}

# Explicit mapping from each source hex to (foreground, background) project colour.
# A foreground is used for `fore:`, a background for `back:`.
COLOR_MAP = {
    # blacks / near blacks
    '#000000': (GREEN, DARKEST),
    '#000011': (GREEN, DARKEST),
    '#000007': (GREEN, DARKEST),
    '#000013': (GREEN, DARKEST),
    '#000017': (GREEN, DARKEST),
    '#000028': (GREEN, DARKEST),
    '#000032': (GREEN, DARKEST),
    '#000033': (BLUE, DARKBLUE),
    '#000035': (BLUE, DARKBLUE),
    '#000042': (BLUE, DARKBLUE),
    '#000044': (BLUE, DARKBLUE),
    '#000055': (BLUE, DARKBLUE),
    '#000066': (BLUE, DARKBLUE),
    '#00007F': (BLUE, DARKBLUE),
    '#000080': (BLUE, DARKBLUE),
    '#0000C0': (BLUE, DARKBLUE),
    '#0000CC': (BLUE, DARKBLUE),
    '#0000FF': (BLUE, DARKBLUE),
    '#0001D7': (BLUE, DARKBLUE),
    '#001300': (GREEN, DARKEST),
    '#002342': (BLUE, DARKBLUE),
    '#0040A0': (BLUE, DARKBLUE),
    '#006600': (GREEN, DARK1),
    '#0066AA': (BLUE, DARKBLUE),
    '#007090': (BLUE, DARKBLUE),
    '#007F00': (GREEN, DARK1),
    '#007F7F': (GREEN, DARK1),
    '#008000': (GREEN, DARK1),
    '#008080': (GREEN, DARK1),
    '#009988': (GREEN, DARK1),
    '#009F00': (GREEN, DARK1),
    '#00A877': (GREEN, DARK1),
    '#00D0D0': (BLUE, DARK2),
    '#00FEA7': (GREEN, DARK1),
    '#00FF00': (GREEN, DARK1),
    '#00CCEE': (BLUE, DARKBLUE),
    '#00EEFF': (BLUE, DARKBLUE),
    '#00FF00': (GREEN, DARK1),
    '#00FFAA': (GREEN, DARK1),
    '#00FFEE': (BLUE, DARKBLUE),
    '#070426': (BLUE, DARK1),
    '#077777': (GREEN, DARK1),
    '#078F44': (GREEN, DARK1),
    '#07A777': (GREEN, DARK1),
    '#07A7A7': (GREEN, DARK1),
    '#08AAFF': (BLUE, DARKBLUE),
    '#08D842': (GREEN, DARK1),
    '#0F668F': (BLUE, DARKBLUE),
    '#110042': (BLUE, DARKBLUE),
    '#11FF42': (GREEN, DARK1),
    '#130013': (PURPLE, DARK2),
    '#16A7D4': (BLUE, DARKBLUE),
    '#1A075F': (PURPLE, DARK2),
    '#220042': (PURPLE, DARK2),
    '#22FFAA': (GREEN, DARK1),
    '#332288': (PURPLE, DARK2),
    '#333333': (SLATE, DARKEST),
    '#3366FF': (BLUE, DARKBLUE),
    '#37A7F4': (BLUE, DARKBLUE),
    '#37EEFF': (BLUE, DARKBLUE),
    '#3F705F': (GREEN, DARK1),
    '#420023': (GOLD, DARK1),
    '#4400CC': (PURPLE, DARK2),
    '#4411CC': (PURPLE, DARK2),
    '#550088': (PURPLE, DARK2),
    '#57A7F7': (BLUE, DARKBLUE),
    '#606060': (SLATE, DARKEST),
    '#608060': (GREEN, DARK1),
    '#6633FF': (PURPLE, DARK2),
    '#666666': (SLATE, DARKEST),
    '#666688': (SLATE, DARKEST),
    '#6BEFA0': (GREEN, DARK1),
    '#7700CC': (PURPLE, DARK2),
    '#7707FF': (PURPLE, DARK2),
    '#7755FF': (BLUE, DARKBLUE),
    '#78D8FF': (BLUE, DARKBLUE),
    '#7F0000': (GOLD, DARKEST),
    '#7F7F00': (GOLD, DARKEST),
    '#7F7F7F': (SLATE, DARKEST),
    '#7F7FBF': (SLATE, DARK2),
    '#7F7FFF': (SLATE, DARK2),
    '#800000': (GOLD, DARKEST),
    '#800080': (GOLD, DARK2),
    '#808000': (GOLD, DARKEST),
    '#808080': (SLATE, DARKEST),
    '#8080A0': (SLATE, DARK2),
    '#8800FF': (PURPLE, DARK2),
    '#8800AA': (PURPLE, DARK2),
    '#8800FF': (PURPLE, DARK2),
    '#993300': (GOLD, DARKEST),
    '#999999': (SLATE, DARKEST),
    '#A00000': (GOLD, DARKEST),
    '#B06000': (GOLD, DARKEST),
    '#BFBBB0': (SLATE, DARK2),
    '#CC9900': (GOLD, DARKEST),
    '#CCCCE0': (SLATE, DARK2),
    '#CFCFEF': (SLATE, DARK2),
    '#CFEFCF': (GREEN, DARK1),
    '#D0D0F0': (SLATE, DARK2),
    '#DDC0F0': (SLATE, DARK2),
    '#E0F0F0': (SLATE, DARK2),
    '#E700F7': (GOLD, DARK2),
    '#EE0577': (GOLD, PURPLE),
    '#EFFFEF': (GREEN, DARK1),
    '#F0F0FF': (SLATE, DARK2),
    '#FF0000': (GOLD, DARKEST),
    '#FF00FF': (GOLD, DARK2),
    '#FF4477': (GOLD, DARKEST),
    '#FF6666': (GOLD, DARK2),
    '#FF8800': (GOLD, DARKEST),
    '#FFBBB0': (GOLD, DARK2),
    '#FFEFBF': (GOLD, DARK1),
    '#FFEFFF': (SLATE, DARK2),
    '#FFF0F0': (GOLD, DARK1),
    '#FFF8F8': (GOLD, DARK1),
    '#FFFF00': (GOLD, DARK1),
    '#FFFF17': (GOLD, DARK1),
    '#AAAAFF': (PURPLE, DARK2),
    '#AADDFF': (BLUE, DARKBLUE),
    '#DD4444': (GOLD, DARKEST),
    '#E8D8FF': (PURPLE, DARK2),
    # perl.properties specific
    '#0007D0': (BLUE, DARKBLUE),
    '#004000': (GREEN, DARK1),
    '#00A070': (GREEN, DARK1),
    '#00A7D7': (BLUE, DARKBLUE),
    '#00D0A0': (GREEN, DARK1),
    '#600000': (GOLD, DARKEST),
    '#7000FF': (PURPLE, DARK2),
    '#7F007F': (GOLD, DARK2),
    '#90FFFF': (BLUE, DARK2),
    '#A08080': (SLATE, DARK2),
    '#A0FFA0': (GREEN, DARK1),
    '#AF007F': (GOLD, DARK2),
    '#C000C0': (GOLD, DARK2),
    '#C0FFC0': (GREEN, DARK1),
    '#D0A000': (GOLD, DARKEST),
    '#DDD0DD': (SLATE, DARK2),
    '#E0E0E0': (SLATE, DARK2),
    '#E0FFE0': (GREEN, DARK1),
    '#F0E080': (GOLD, DARK1),
    '#FFE0E0': (GOLD, DARK1),
    '#FFE0FF': (SLATE, DARK2),
    '#FFF0D8': (GOLD, DARK1),
    '#FFF0FF': (SLATE, DARK2),
    '#FFFFE0': (GOLD, DARK1),
}

# Normalize keys to upper case
COLOR_MAP = {k.upper(): v for k, v in COLOR_MAP.items()}

# Specific global / UI keys that need intentional project colours.
KEY_OVERRIDES = {
    'caret.fore': GREEN,
    'caret.line.back': DARK1,
    'selection.fore': BLUE,
    'selection.back': DARK1,
    'whitespace.fore': BLUE,
    'error.marker.fore': GOLD,
    'error.marker.back': DARKEST,
    'bookmark.fore': GOLD,
    'bookmark.back': PURPLE,
    'find.mark': GOLD,
    'fold.margin.colour': PURPLE,
    'fold.margin.highlight.colour': DARKEST,
    'edge.colour': DARKBLUE,
}

HEX_RE = re.compile(r'#[0-9a-fA-F]{6}\b')
STYLE_COLOUR_RE = re.compile(r'^(fore|back):(#[0-9a-fA-F]{6})$')


def hex_to_rgb(h):
    h = h.lstrip('#')
    if len(h) == 3:
        h = ''.join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def relative_luminance(hexcol):
    r, g, b = (c / 255.0 for c in hex_to_rgb(hexcol))
    def conv(x):
        if x <= 0.03928:
            return x / 12.92
        return ((x + 0.055) / 1.055) ** 2.4
    return 0.2126 * conv(r) + 0.7152 * conv(g) + 0.0722 * conv(b)


def contrast_ratio(c1, c2):
    l1, l2 = relative_luminance(c1), relative_luminance(c2)
    if l1 < l2:
        l1, l2 = l2, l1
    return (l1 + 0.05) / (l2 + 0.05)


def fallback_light(orig_hex, back_hex):
    """Pick a readable light project colour based on the original foreground hue."""
    r, g, b = (c / 255.0 for c in hex_to_rgb(orig_hex))
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s < 0.15:
        return GREEN
    deg = h * 360
    if 60 <= deg < 200:
        return GREEN
    if 200 <= deg < 300:
        return BLUE
    return GOLD


def map_colour(hexstr, role):
    key = hexstr.upper()
    if key in COLOR_MAP:
        return COLOR_MAP[key][0] if role == 'fore' else COLOR_MAP[key][1]
    # Fall back to returning the original colour but warn later.
    return hexstr


def fix_syntax(line):
    # Negative alpha values
    if 'caret.line.back.alpha=-200' in line:
        line = line.replace('-200', '40')
    if 'bookmark.alpha=-222' in line:
        line = line.replace('-222', '80')
    # style.*.32 has a dot before the font variable
    if re.match(r'^style\.\*\.32=', line):
        line = re.sub(r'\.\$\(font\.base\)', ',$(font.base)', line)
    # colour.other.comment has a trailing comma
    if line.startswith('colour.other.comment=') and line.rstrip().endswith(','):
        line = line.rstrip()[:-1] + '\n'
    return line


def process_file(path):
    path = Path(path)
    text = path.read_text(encoding='utf-8', errors='replace')
    lines = text.splitlines(keepends=True)
    replaced = 0
    unknown = set()
    out_lines = []

    for line in lines:
        # Syntax-level fixes first, so the style parser can see clean tokens.
        line = fix_syntax(line)

        stripped = line.strip()
        if not stripped or stripped.startswith('#') or '=' not in line:
            out_lines.append(line)
            continue

        key, val = line.split('=', 1)
        key = key.rstrip()

        # Global / UI overrides
        if key in KEY_OVERRIDES:
            new_val = HEX_RE.sub(lambda m: KEY_OVERRIDES[key], val)
            replaced += len(HEX_RE.findall(val))
            out_lines.append(f'{key}={new_val}')
            continue

        # Style lines and colour.* variable definitions
        if key.startswith('style.') or key.startswith('colour.'):
            tokens = val.split(',')
            new_tokens = []
            orig_fore = mapped_fore = None
            orig_back = mapped_back = None
            for tok in tokens:
                tok = tok.strip()
                m = STYLE_COLOUR_RE.match(tok)
                if m:
                    role, hexstr = m.group(1), m.group(2)
                    mapped = map_colour(hexstr, role)
                    if role == 'fore':
                        orig_fore = hexstr
                        mapped_fore = mapped
                    else:
                        orig_back = hexstr
                        mapped_back = mapped
                    new_tokens.append(f'{role}:{mapped}')
                else:
                    new_tokens.append(tok)

            val2 = ','.join(t for t in new_tokens if t)

            # Readability fix: ensure foreground is readable against its background.
            # If no background is set, assume the editor default background (darkest).
            back = mapped_back if mapped_back else DARKEST
            if mapped_fore and contrast_ratio(mapped_fore, back) < 3.0:
                fb = fallback_light(orig_fore or mapped_fore, back)
                val2 = re.sub(r'fore:' + re.escape(mapped_fore), f'fore:{fb}', val2)

            out_lines.append(f'{key}={val2}\n')
            continue

        # Other key=value lines that contain a bare colour (e.g. caret.fore)
        def repl(m):
            hexstr = m.group(0)
            role = 'back' if ('.back' in key or 'margin.colour' in key or key == 'caret.line.back') else 'fore'
            mapped = map_colour(hexstr, role)
            if mapped == hexstr and hexstr.upper() not in PALETTE:
                unknown.add(hexstr)
            nonlocal replaced
            replaced += 1
            return mapped

        new_val = HEX_RE.sub(repl, val)
        out_lines.append(f'{key}={new_val}\n')

    path.write_text(''.join(out_lines), encoding='utf-8')
    return replaced, unknown


def sanity_check(path):
    path = Path(path)
    text = path.read_text(encoding='utf-8', errors='replace')
    warnings = []
    # Hex colours not in project palette
    for m in HEX_RE.finditer(text):
        col = m.group(0).upper()
        if col not in PALETTE:
            # Ignore hex inside comments? Still warn.
            line = text[:m.start()].count('\n') + 1
            warnings.append(f'{path}: line {line}: non-palette colour {col}')
    # Trailing commas in colour/style lines
    for i, line in enumerate(text.splitlines(), 1):
        s = line.strip()
        if (s.startswith('style.') or s.startswith('colour.')) and '=' in s:
            _, v = s.split('=', 1)
            if v.rstrip().endswith(','):
                warnings.append(f'{path}: line {i}: trailing comma')
    # Negative alpha
    for i, line in enumerate(text.splitlines(), 1):
        if 'alpha=#' in line:
            continue
        if re.search(r'alpha=-\d+', line):
            warnings.append(f'{path}: line {i}: negative alpha')
    return warnings


def main():
    files = [
        'configuration/backup/.SciTEUser.properties',
        'configuration/backup/scite/perl.properties',
    ]
    for f in files:
        p = Path(f)
        if not p.exists():
            print(f'SKIP: {f} not found', file=sys.stderr)
            continue
        # If file is not valid UTF-8, assume it is still ISO-8859-1 and convert.
        raw = p.read_bytes()
        try:
            raw.decode('utf-8')
        except UnicodeDecodeError:
            bak = p.with_name(p.name + '.bak-latin1')
            if not bak.exists():
                p.rename(bak)
                text = raw.decode('iso-8859-1')
                p.write_text(text, encoding='utf-8')
                print(f'Converted {f} from ISO-8859-1 to UTF-8 (backup {bak})')
            else:
                text = raw.decode('iso-8859-1')
                p.write_text(text, encoding='utf-8')
                print(f'Converted {f} from ISO-8859-1 to UTF-8 (backup already exists)')

        replaced, unknown = process_file(f)
        print(f'{f}: {replaced} colour replacements')
        if unknown:
            print(f'  unknown colours kept as-is: {sorted(unknown)}')

    print('\nSanity check:')
    for f in files:
        warns = sanity_check(f)
        if warns:
            print(f'{f}: {len(warns)} warnings')
            for w in warns[:20]:
                print('  ', w)
            if len(warns) > 20:
                print(f'  ... and {len(warns)-20} more')
        else:
            print(f'{f}: OK')


if __name__ == '__main__':
    main()
