#!/usr/bin/env python3
"""The official terrain layouts, as images.

The geometry is not extractable. The battlefield art is raster — 76 embedded
images on a page — and the only vectors are the deployment zones and the
callout rules. The letter codes and dimensions *are* text, so a layout's
feature inventory and its measurements can be read, but a feature's rotation
appears nowhere, and a map drawn without rotations is a plausible wrong map.

So the page itself is the reference. Each layout is rendered, cropped to the
diagram and quantised, and the app offers it beside its own drawing rather
than pretending to reproduce it.

Usage:  tools/render-layouts.py <event-companion.pdf> <out-dir>
"""
import json
import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INDEX = f'{ROOT}/data/event-companion-layouts.json'
DPI = 120
# The diagram's box on the page, in points, on a 595x842 page: below the two
# mission cards and above the page number.
BOX = (95, 222, 485, 778)


def render(pdf, page, out):
    subprocess.run(['pdftoppm', '-png', '-r', str(DPI), '-f', str(page),
                    '-l', str(page), pdf, '/tmp/layout-page'],
                   check=True, capture_output=True)
    made = next(p for p in sorted(os.listdir('/tmp'))
                if p.startswith('layout-page'))
    with Image.open(f'/tmp/{made}') as im:
        sx, sy = im.size[0] / 595.276, im.size[1] / 841.89
        crop = im.crop((int(BOX[0] * sx), int(BOX[1] * sy),
                        int(BOX[2] * sx), int(BOX[3] * sy)))
        # Quantised: the art is flat colour over photographs of terrain, and
        # 256 colours holds the dimension text legible at a tenth the size.
        crop.convert('RGB').quantize(colors=256, method=Image.MEDIANCUT) \
            .save(out, optimize=True)
    os.remove(f'/tmp/{made}')


def main():
    if len(sys.argv) < 3:
        sys.exit('usage: render-layouts.py <event-companion.pdf> <out-dir>')
    pdf, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    index = json.load(open(INDEX))

    total = 0
    for entry in index['layouts']:
        name = f"{entry['matchup']}-{entry['layout'].lower()}.png"
        at = os.path.join(out_dir, name)
        render(pdf, entry['page'], at)
        size = os.path.getsize(at)
        total += size
        print(f'{name:52} {size // 1024:5} KB', flush=True)
    print(f'\n{len(index["layouts"])} layouts, {total // 1024} KB total '
          f'-> {out_dir}')


if __name__ == '__main__':
    main()
