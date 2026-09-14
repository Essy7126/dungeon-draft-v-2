"""Small explicit OpenRaster reader for the flat concept correction probe.

Reject unsupported stacks rather than silently flattening different semantics.
PNG layers and their offsets inside the supplied ORA are the only image inputs.
"""
import io, zipfile, xml.etree.ElementTree as ET
from pathlib import Path
from PIL import Image


def read_layers(path):
    with zipfile.ZipFile(path) as archive:
        root = ET.fromstring(archive.read('stack.xml'))
        stack = root.find('stack')
        if stack is None or any(node.tag != 'layer' for node in stack):
            raise ValueError('This probe requires a flat layer stack')
        size = int(root.attrib['w']), int(root.attrib['h'])
        layers = []
        for layer in reversed(list(stack)):
            if layer.get('visibility', 'visible') != 'visible':
                continue
            if layer.get('composite-op', 'svg:src-over') != 'svg:src-over' or float(layer.get('opacity', 1)) != 1:
                raise ValueError('Only opaque normal layer blending is supported')
            image = Image.open(io.BytesIO(archive.read(layer.attrib['src']))).convert('RGBA')
            layers.append((layer.attrib['name'], image, (int(layer.get('x', 0)), int(layer.get('y', 0)))))
        if len({name for name, _, _ in layers}) != len(layers):
            raise ValueError('Layer names must be unique')
        return size, layers


def render(path):
    size, layers = read_layers(path)
    output = Image.new('RGBA', size)
    for _, image, xy in layers:
        output.alpha_composite(image, xy)
    return output


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    render(args.source).save(args.output)
