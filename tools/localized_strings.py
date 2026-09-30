"""
STRINGS files of this (localized) plugin: Strings/StarCoreAndCappyMarkers_<lang>.*

Why the plugin is localized at all: see vanilla_overrides.py - the WRLD/CELL records it
copies from DLCNukaWorld.esm carry their names as string ids, and a localized plugin
looks those ids up in its OWN string files. So every language gets:
  - the copied vanilla names, same ids, bytes taken as is from
    DLCNukaWorld_<lang>.STRINGS inside `DLCNukaWorld - Main.ba2` at build time (the
    encoding differs per language - cp1251 for ru - so nothing is decoded);
  - this mod's own texts (quest names, objectives) under ids from OWN_ID_BASE.
Languages = whatever the DLC archive has strings for (11 in the Steam game).

File format: count(u32) dataSize(u32), count x (id u32, offset u32), then data.
  .STRINGS                 - zero-terminated strings;
  .DLSTRINGS / .ILSTRINGS  - u32 length (with the zero) before each string.
Quest FULL and NNAM both live in .STRINGS (checked against every NNAM in
DLCNukaWorld.esm), so the other two tables are shipped empty: the game opens all three.
"""

import os
import re
import struct

from ba2 import BA2

NUKAWORLD_MAIN_BA2 = r'D:\Games\Fallout 4\Data\DLCNukaWorld - Main.ba2'

# Vanilla name ids are small (< 0x10000 in DLCNukaWorld.esm); own ids stay clear of them.
OWN_ID_BASE = 0x00100001

_NAME = re.compile(r'^strings/dlcnukaworld_([a-z]+)\.strings$')


def _read_raw(blob):
    """id -> raw bytes (no zero) of a zero-terminated .STRINGS table."""
    count = struct.unpack_from('<I', blob, 0)[0]
    data = 8 + count * 8
    out = {}
    for i in range(count):
        sid, off = struct.unpack_from('<II', blob, 8 + i * 8)
        pos = data + off
        out[sid] = blob[pos:blob.index(b'\x00', pos)]
    return out


def _write(table, length_prefixed):
    directory = []
    data = []
    size = 0
    for sid in sorted(table):
        raw = table[sid] + b'\x00'
        if length_prefixed:
            raw = struct.pack('<I', len(raw)) + raw
        directory.append(struct.pack('<II', sid, size))
        data.append(raw)
        size += len(raw)
    return struct.pack('<II', len(table), size) + b''.join(directory) + b''.join(data)


class OwnStrings:
    """Hands out ids for the mod's own texts while the records are being built."""

    def __init__(self):
        self.texts = {}

    def id(self, text):
        sid = OWN_ID_BASE + len(self.texts)
        self.texts[sid] = text.encode('ascii')
        return sid


def write_all(out_dir, plugin_stem, vanilla_ids, own, archive=NUKAWORLD_MAIN_BA2):
    """Writes the three tables for every language; returns the list of languages."""
    clash = set(vanilla_ids) & set(own.texts)
    if clash:
        raise SystemExit('id строк мода совпали с ванильными: %s' % ', '.join('%X' % i for i in clash))
    ba2 = BA2(archive)
    langs = sorted(m.group(1) for m in map(_NAME.match, ba2.names()) if m)
    if not langs:
        raise SystemExit('в %s нет Strings/DLCNukaWorld_*.STRINGS' % archive)
    os.makedirs(out_dir, exist_ok=True)
    for lang in langs:
        vanilla = _read_raw(ba2.read('strings/dlcnukaworld_%s.strings' % lang))
        missing = [i for i in vanilla_ids if i not in vanilla]
        if missing:
            raise SystemExit('DLCNukaWorld_%s.STRINGS: нет строк %s' % (lang, ', '.join('%X' % i for i in missing)))
        table = {i: vanilla[i] for i in vanilla_ids}
        table.update(own.texts)
        base = os.path.join(out_dir, '%s_%s.' % (plugin_stem, lang))
        for ext, blob in (('STRINGS', _write(table, False)),
                          ('DLSTRINGS', _write({}, True)),
                          ('ILSTRINGS', _write({}, True))):
            with open(base + ext, 'wb') as f:
                f.write(blob)
    return langs
