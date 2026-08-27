"""Column-aware text from a PDF, for packs whose grid changes page to page.

A fixed split at half the page width worked for the new-detachment pages and
silently dropped the reprinted codex detachments, which use a narrower
three-column grid on a different page size. So the columns are found rather
than assumed: cover the page width with the words on it, and any vertical
band wide enough that no word crosses it is a gutter.

Reading order is then column by column, which is how these pages are laid
out — a stratagem's WHEN/TARGET/EFFECT block never straddles a gutter.
"""
import re, sys, subprocess, html

WORD = re.compile(
    r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">(.*?)</word>')
PAGE = re.compile(r'<page width="([\d.]+)" height="([\d.]+)">')

MIN_GUTTER = 9.0      # points; narrower than this is word spacing
LINE_TOLERANCE = 3.0  # points; words this close share a line


def pages(pdf, first=None, last=None):
    cmd = ['pdftotext', '-bbox-layout']
    if first:
        cmd += ['-f', str(first), '-l', str(last or first)]
    xml = subprocess.run(cmd + [pdf, '-'], capture_output=True, text=True).stdout
    for chunk in xml.split('<page ')[1:]:
        m = PAGE.match('<page ' + chunk[:80])
        width = float(m.group(1)) if m else 595.0
        words = [(float(a), float(b), float(c), float(d), html.unescape(t))
                 for a, b, c, d, t in WORD.findall(chunk)]
        yield width, words


def gutters(words, width):
    """Vertical bands almost no line of text crosses, as (start, end) points.

    Two things make this less obvious than it sounds.

    A line's extent cannot be taken as its first word to its last: words at
    the same height in two different columns are not one line, and treating
    them as one makes every body line appear to cross the very gutter being
    looked for. So a line covers its words and only the gaps *between* words
    that are narrow enough to be word spacing.

    And the gutter is not required to be clear: a page title and its subtitle
    run the full width above a two-column body, so demanding nothing cross
    found no columns at all on exactly the pages that have them. A handful of
    crossings is allowed — enough for a header, not enough to call a
    single-column page two.
    """
    lines = {}
    for w in words:
        lines.setdefault(round(w[1] / LINE_TOLERANCE), []).append(w)

    allowed = max(2, len(lines) // 20)
    crossings = [0] * (int(width) + 2)
    for group in lines.values():
        group.sort(key=lambda w: w[0])
        spans = []
        for x0, _, x1, _, _ in group:
            if spans and x0 - spans[-1][1] < MIN_GUTTER:
                spans[-1][1] = max(spans[-1][1], x1)
            else:
                spans.append([x0, x1])
        for lo, hi in spans:
            for x in range(max(0, int(lo)),
                           min(len(crossings) - 1, int(hi) + 1)):
                crossings[x] += 1

    out, run = [], None
    for x, n in enumerate(crossings):
        if n <= allowed and run is None:
            run = x
        elif n > allowed and run is not None:
            if x - run >= MIN_GUTTER:
                out.append((run, x))
            run = None
    if run is not None and len(crossings) - run >= MIN_GUTTER:
        out.append((run, len(crossings)))
    # The margins are not gutters.
    return [(a, b) for a, b in out if a > 4 and b < width - 4]


def columns(words, width):
    """Word lists, one per column, left to right."""
    bounds = [0.0]
    for start, end in gutters(words, width):
        bounds.append((start + end) / 2)
    bounds.append(width + 1)
    out = []
    for i in range(len(bounds) - 1):
        lo, hi = bounds[i], bounds[i + 1]
        out.append([w for w in words if lo <= w[0] < hi])
    return [c for c in out if c]


def lay_out(words):
    """One column's words as text, grouped into lines by their baselines."""
    lines = []
    for w in sorted(words, key=lambda w: (w[1], w[0])):
        if lines and abs(lines[-1][0] - w[1]) <= LINE_TOLERANCE:
            lines[-1][1].append(w)
        else:
            lines.append((w[1], [w]))
    return '\n'.join(
        ' '.join(t for *_, t in sorted(ws, key=lambda w: w[0]))
        for _, ws in lines)


BADGE = re.compile(r'^(\d+)CP$')


def document(pdf, first=None, last=None):
    """`[{page, badges, columns}]`, each column a list of `{y, text}` lines.

    Cost badges come out as a column of their own — they sit right-aligned in
    a narrow band with a gutter either side, and the detector cannot know
    that band is not a column. They are pulled out before the split and
    matched back to their stratagem by baseline instead, which also means it
    does not matter that the badge sits left of the name in one layout and
    right of it in another.
    """
    out = []
    for n, (width, words) in enumerate(pages(pdf, first, last), start=first or 1):
        badges = [{'y': w[1], 'x': w[0], 'cp': int(BADGE.match(w[4]).group(1))}
                  for w in words if BADGE.match(w[4])]
        rest = [w for w in words if not BADGE.match(w[4])]
        cols = []
        for col in columns(rest, width):
            lines = []
            for w in sorted(col, key=lambda w: (w[1], w[0])):
                if lines and abs(lines[-1]['y'] - w[1]) <= LINE_TOLERANCE:
                    lines[-1]['words'].append(w)
                else:
                    lines.append({'y': w[1], 'words': [w]})
            cols.append({
                'xMin': min(w[0] for w in col),
                'xMax': max(w[2] for w in col),
                'lines': [
                    {'y': ln['y'],
                     'x': min(w[0] for w in ln['words']),
                     'text': ' '.join(t for *_, t in sorted(ln['words'],
                                                            key=lambda w: w[0]))}
                    for ln in lines
                ],
            })
        out.append({'page': n, 'badges': badges, 'columns': cols})
    return out


if __name__ == '__main__':
    import json
    print(json.dumps(document(sys.argv[1], *(int(a) for a in sys.argv[2:])),
                     indent=1, ensure_ascii=False))
