#!/usr/bin/env python3
"""The Rules Updates section of each Faction Pack, as structured errata.

Every pack ends with a section of corrections to rules the codex already
published — army rules, detachment rules, enhancements, stratagems, datasheet
abilities, weapon profiles, keywords. They are written to a regular shape:

    ARMY RULES                      <- a category, shouted
    For the Greater Good            <- the subject
    Change to:                      <- the directive
    'If your Army Faction is ...'   <- the new wording, quoted

    KAUYON DETACHMENT
    Photon Grenades Stratagem, When Section
    Change to:
    '...'

    DATASHEETS
    Devilfish, Hammerhead Gunship, Piranhas - Keywords Section
    Add 'FRAME'.

A subject can carry bullets instead, one per part of the datasheet it edits:

    Riptide Battlesuit
    - Nova Charge Ability
      Change to:
      '...'

This reads them out. It does not decide what they apply to — that is
`make-update.py`'s job, and it is the part that can be wrong in a way nobody
notices, so the two are kept apart.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = f'{ROOT}/data/faction-pack-updates.json'

# `Change to:`, `Add the following Faction Abilities section:`, `Change 3" to
# 6".`, `Change profiles to:` — the verb is always first and always one of a
# short list.
DIRECTIVE = re.compile(
    r'^(Change|Add|Remove|Replace|Delete)\b(?P<rest>.*)$')

# A category is shouted. Testing for "no lowercase" rather than `isupper()`
# lets through the apostrophes and digits in `MONT'KA DETACHMENT`.
SHOUTED = re.compile(r'^[^a-z]{3,}$')

# Shouted is not enough. Quoted wording contains shouted keyword lists, and a
# weapon profile is a shouted table — both sit in the middle of an entry and
# neither heads anything.
TABLE = re.compile(r'^(RANGE|M\b|\d)')


def is_category(text):
    return (
        SHOUTED.match(text) is not None
        and len(text) <= 60
        and not TABLE.match(text)
        and not text.endswith((',', '.', '’', "'", ':'))
        and '"' not in text
    )

BULLET = re.compile(r'^[▪●•◦\-]\s*(?P<rest>.+)$')

# Section names that end the updates and begin something else.
ENDS = ('LEGENDS DATASHEETS', 'DATASHEETS UPDATED', 'CONTENTS')


def sections(doc):
    """Every contents entry, as `{name, page}` — not only the detachments."""
    if not doc:
        return []
    dots = '\x08�.─—–'
    out = []
    for col in doc[0]['columns']:
        for line in col['lines']:
            m = re.match(r'^(.+?)[' + dots + r']{3,}\s*(\d+)\s*$',
                         line['text'].strip())
            if m:
                out.append({'name': m.group(1).strip(), 'page': int(m.group(2))})
    return out


def page_range(doc):
    """The pages the Rules Updates section covers, from the contents page."""
    listed = sections(doc)
    at = next((s for s in listed
               if s['name'].lower().startswith('rules updates')), None)
    if at is None:
        return None
    after = [s['page'] for s in listed if s['page'] > at['page']]
    last = min(after) - 1 if after else max(p['page'] for p in doc)
    return at['page'], last


def section_lines(doc):
    """The Rules Updates section's lines, in reading order."""
    span = page_range(doc)
    if span is None:
        return []
    first, last = span
    out = []
    for page in doc:
        if not first <= page['page'] <= last:
            continue
        for col in page['columns']:
            for raw in col['lines']:
                text = raw['text'].strip()
                if text:
                    out.append({'text': text, 'page': page['page']})
    return out


def is_directive(line):
    """A line that says what to do, rather than one being quoted.

    Quoted wording routinely contains sentences that begin `Add 1 to ...`, so
    a line already inside a quotation is never a directive.
    """
    text = line['text']
    if text[:1] in '‘\'"':
        return False
    return DIRECTIVE.match(text) is not None


def entries(doc):
    """The section's corrections, in the order they are printed.

    Segmented by looking ahead to the directives rather than by streaming
    state. Streaming could not tell where a quotation ended — an apostrophe
    and a closing quote are the same character, so `your opponent's` looks
    exactly like the end of a quote — and every entry after the first
    inherited the subject of the one before it. The directives are
    unambiguous, so they are found first and everything else is placed
    relative to them.
    """
    lines = section_lines(doc)
    marks = [i for i, line in enumerate(lines) if is_directive(line)]
    if not marks:
        return []

    def heading_before(at):
        for i in range(at, -1, -1):
            text = lines[i]['text']
            if is_category(text) and text not in ('UPDATES',):
                # A shouted line inside somebody's quoted wording is not a
                # heading — `STORM GUARDIANS, WARLOCK CONCLAVE.'` is the tail
                # of a keyword list, and a weapon profile row is a table.
                if any(m < i for m in marks) and i < max(marks):
                    following = next((m for m in marks if m > i), None)
                    if following is not None and following - i > 3:
                        continue
                return text
        return None

    def subject_at(at):
        """The lines naming what the directive edits: the line above it, and
        the datasheet above that when the pack has bulleted its parts."""
        parts = []
        i = at - 1
        while i >= 0 and len(parts) < 2:
            text = lines[i]['text']
            if is_directive(lines[i]) or is_category(text):
                break
            parts.insert(0, BULLET.sub(lambda m: m.group('rest'), text).strip())
            # Only a bulleted part looks upward for the datasheet it belongs
            # to; an ordinary subject is one line.
            if not BULLET.match(text):
                break
            i -= 1
        return ' - '.join(p for p in parts if p)

    out = []
    for k, at in enumerate(marks):
        line = lines[at]
        directive = line['text']
        subject = subject_at(at)
        if not subject:
            continue

        # `Add 'FRAME'.` and `Change 9" to 8".` say it all on their own line;
        # `Change to:` opens a quotation that runs to the next entry — and it
        # is not always alone on its line. Some packs set the quotation
        # immediately after the colon, and some drop the colon altogether, so
        # the verb is what decides rather than the punctuation.
        opens = directive.rstrip().endswith(':') \
            or re.match(r'^Change to\b', directive) is not None
        if opens:
            stop = len(lines)
            if k + 1 < len(marks):
                # Up to the next entry's subject, and not into the heading
                # above it either: a category line left inside the body put
                # `RAD-ZONE CORPS DETACHMENT Rad-bombardment Detachment` on
                # the end of the rule before it.
                nxt = marks[k + 1]
                back = nxt - 1
                while back > at and BULLET.match(lines[back]['text']):
                    back -= 1
                while back > at and is_category(lines[back - 1]['text']):
                    back -= 1
                stop = max(at + 1, back)
            # Whatever followed the colon on the directive's own line is the
            # start of the quotation, not part of the instruction.
            inline = re.sub(r'^Change to:?\s*', '', directive).strip()
            body = ' '.join([inline] + [l['text'] for l in lines[at + 1:stop]]) \
                if inline else ' '.join(l['text'] for l in lines[at + 1:stop])
        else:
            body = directive

        if body.strip():
            out.append({
                'category': heading_before(at),
                'subject': subject,
                'directive': directive,
                'text': body.strip(),
                'page': line['page'],
            })
    return out


def main():
    cache = sys.argv[sys.argv.index('--cache') + 1] \
        if '--cache' in sys.argv else None
    if not cache:
        sys.exit('usage: parse-rules-updates.py --cache <dir>')

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import pdf_columns

    out = {}
    for name in sorted(os.listdir(cache)):
        if not name.endswith('.json'):
            continue
        pack = name[:-5]
        doc = pdf_columns.lay_out_pages(
            json.load(open(os.path.join(cache, name))))
        found = entries(doc)
        if found:
            out[pack] = found
            print(f'{pack:26} {len(found):4} corrections', flush=True)

    with open(OUT, 'w') as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
        f.write('\n')
    print(f'\n{sum(len(v) for v in out.values())} corrections -> {OUT}')


if __name__ == '__main__':
    main()
