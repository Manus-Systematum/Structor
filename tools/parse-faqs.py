#!/usr/bin/env python3
"""The FAQ section of each Faction Pack, as question-and-answer pairs.

Nothing is interpreted. A FAQ answers a question about how two rules interact
— *can I use this ability while embarked?* — and the answer is usually one
word. There is no record in the app for that to correct, and trying to derive
one would be the app adjudicating rather than quoting. They are carried as
text, per faction, for a player to read at the table.

The shape is regular: `Q:` opens, `A:` answers, and either can wrap over
several lines. Both are read from the FAQ section's own pages, which the
contents page names.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pdf_columns  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = f'{ROOT}/data/faction-pack-faqs.json'
DOTS = '\x08�.─—–'

# The heading a pack uses, and everything that can follow it.
FAQ_HEADS = ('faqs', 'faq')
TOP_LEVEL = ('detachments', 'datasheets', 'rules updates', 'legends datasheets',
             'imperial armour datasheets', 'faqs', 'faq')


def contents(raw):
    at = pdf_columns.word_x(raw[0], 'CONTENTS')
    rows = pdf_columns.rows_right_of(raw[0], at) if at is not None \
        else pdf_columns.page_lines(raw[0])
    out = []
    for row in rows:
        m = re.match(r'^(.+?)[' + DOTS + r']{3,}\s*(\d+)?\s*$', row.strip())
        if m and m.group(2):
            out.append((m.group(1).strip().lower(), int(m.group(2))))
    return out


def faq_pages(raw, doc):
    """The pages the FAQ section covers.

    Most packs do not list it on the contents page — it sits at the end of the
    Rules Updates section — so the `FAQS` heading is looked for on the page
    instead, and the section runs from there to the next top-level heading.
    """
    listed = contents(raw)
    tops = sorted({p for name, p in listed if name in TOP_LEVEL})
    start = next((p for name, p in listed if name in FAQ_HEADS), None)

    if start is None:
        for page in doc:
            for col in page['columns']:
                if any(line['text'].strip().upper().startswith('FAQ')
                       and len(line['text'].strip()) <= 5
                       for line in col['lines']):
                    start = page['page']
                    break
            if start:
                break
    if start is None:
        # The Event Companion sets its heading as a vertical sidebar, so the
        # words `CHAPTER APPROVED MISSION DECK FAQS` arrive one per line down
        # the page and no heading is found. Fall back to the shape itself:
        # `Q:` and `A:` are unambiguous, and a page with neither yields
        # nothing anyway.
        return [page['page'] for page in doc]
    after = [p for p in tops if p > start]
    return list(range(start, (min(after) if after else len(doc)) + 1))


def pairs(lines):
    """`[{question, answer}]` from lines that open with `Q:` and `A:`."""
    out, where = [], None
    for line in lines:
        text = line.strip()
        if not text:
            continue
        if re.match(r'^Q\s*[:.]', text):
            out.append({'question': re.sub(r'^Q\s*[:.]\s*', '', text),
                        'answer': ''})
            where = 'question'
        elif re.match(r'^A\s*[:.]', text) and out:
            out[-1]['answer'] = re.sub(r'^A\s*[:.]\s*', '', text)
            where = 'answer'
        elif re.fullmatch(r"[^a-z]{4,}", text):
            # A shouted line is a heading, and the answer before it has
            # ended. Without this the last answer on a page ran on into the
            # datasheet printed after it — `No. ORCA DROPSHIP M T SV W 20"…`.
            where = None
        elif out and where:
            out[-1][where] = (out[-1][where] + ' ' + text).strip()
    return [q for q in out if q['question'] and q['answer']]


def main():
    cache = sys.argv[sys.argv.index('--cache') + 1] \
        if '--cache' in sys.argv else None
    if not cache:
        sys.exit('usage: parse-faqs.py --cache <dir>')

    out = {}
    for name in sorted(os.listdir(cache)):
        if not name.endswith('.json'):
            continue
        # The Event Companion carries the Chapter Approved Mission Deck's own
        # questions, which belong to no faction. Its ERRATA section reads
        # `None.` in this version — there are no card amendments to apply, and
        # that is worth having recorded rather than looking unparsed.
        if name.startswith('_') and name != '_event-companion.json':
            continue
        pack = 'core' if name == '_event-companion.json' else name[:-5]
        raw = json.load(open(os.path.join(cache, name)))
        doc = pdf_columns.lay_out_pages(raw)
        wanted = set(faq_pages(raw, doc))
        if not wanted:
            continue
        lines = []
        for page in doc:
            if page['page'] not in wanted:
                continue
            for col in page['columns']:
                lines.extend(line['text'] for line in col['lines'])
        found = pairs(lines)
        if found:
            out[pack] = found
            print(f'{pack:24} {len(found):3} questions', flush=True)

    with open(OUT, 'w') as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
        f.write('\n')
    print(f'\n{sum(len(v) for v in out.values())} questions -> {OUT}')


if __name__ == '__main__':
    main()
