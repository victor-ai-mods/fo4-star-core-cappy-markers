"""
Persistent overrides of the five Star Cores outside the Galactic Zone.

Why they are needed: in DLCNukaWorld.esm these five refs (DLC04GZExternalStarCore02..06)
are TEMPORARY references. A temporary ref only exists in memory while its cell is
loaded, so Game.GetFormFromFile() returns None for it anywhere else and the marker
script has nothing to put in its collection. Every ref the mod can mark from afar
(the hidden Cappys, the Galactic Zone cores held by vanilla aliases) is persistent.

The fix is the same thing xEdit does when the Persistent flag is ticked: override
the REFR with flag 0x400 set, under a copy of its parent records.

  interior ref:  CELL top group > block (2) > sub-block (3) > CELL > children (6)
                 > persistent children (8) > REFR
  exterior ref:  WRLD top group > WRLD > world children (1) > the world's PERSISTENT
                 cell > children (6) > persistent children (8) > REFR

An exterior ref is moved into the world's persistent cell rather than kept in its own
exterior cell: DLCNukaWorld.esm itself has persistent-children groups (type 8) only
under the persistent cells of its worldspaces, never under an exterior cell.

Everything is copied byte for byte out of the installed DLCNukaWorld.esm at build time,
so nothing vanilla lives in this repository. FormIDs need no remapping: the output
plugin's masters are [Fallout4.esm, DLCNukaWorld.esm] and DLCNukaWorld.esm's own
masters are [Fallout4.esm], so index 00 and 01 mean the same file in both.

The copied WRLD and CELL records keep their FULL names byte for byte, and those are
NOT text: DLCNukaWorld.esm is localized, so a FULL is a 4-byte id into
DLCNukaWorld_<lang>.STRINGS. That is why this plugin is localized too and ships its own
STRINGS files carrying the same ids (see localized_strings.py). Dropping FULL is no way
out either: an override without a name blanks it, and the game then shows the default
"Wasteland" on load doors and in save names. build() returns the ids it copied.
"""

import struct
import zlib

NUKAWORLD_ESM = r'D:\Games\Fallout 4\Data\DLCNukaWorld.esm'

# DLC04GZExternalStarCore02..06 - must match outsideCores in StarCoreMarkers.psc.
OUTSIDE_CORES = (0x01031995, 0x010319CE, 0x010319CF, 0x010319D6, 0x01054CA8)

REC_PERSISTENT = 0x00000400
REC_COMPRESSED = 0x00040000

GRUP_WORLD_CHILDREN = 1
GRUP_INTERIOR_BLOCK = 2
GRUP_INTERIOR_SUBBLOCK = 3
GRUP_EXTERIOR_BLOCK = 4
GRUP_EXTERIOR_SUBBLOCK = 5
GRUP_CELL_CHILDREN = 6
GRUP_CELL_PERSISTENT = 8

_REC = struct.Struct('<4sIIIIHH')
_GRUP = struct.Struct('<4sIIIQ')


def _grup(label, gtype, body):
    return _GRUP.pack(b'GRUP', len(body) + 24, label, gtype, 0) + body


def _raw_record(buf, pos):
    size = _REC.unpack_from(buf, pos)[1]
    return buf[pos:pos + 24 + size]


def _persistent(raw_refr):
    flags = struct.unpack_from('<I', raw_refr, 8)[0]
    return raw_refr[:8] + struct.pack('<I', flags | REC_PERSISTENT) + raw_refr[12:]


def _full_id(raw):
    """String id held in a copied record's FULL, or None if it has no name."""
    flags = _REC.unpack_from(raw, 0)[2]
    body = raw[24:]
    if flags & REC_COMPRESSED:
        body = zlib.decompress(body[4:])
    pos = 0
    while pos + 6 <= len(body):
        tag, n = struct.unpack_from('<4sH', body, pos)
        if tag == b'FULL':
            return struct.unpack_from('<I', body, pos + 6)[0]
        pos += 6 + n
    return None


def _strip(raw, drop):
    """A copied record minus the subrecords in `drop` (OFST/CLSZ of a WRLD: cell
    offsets into DLCNukaWorld.esm itself, meaningless inside another file)."""
    sig, size, flags, fid, rev, ver, unk = _REC.unpack_from(raw, 0)
    body = raw[24:]
    if flags & REC_COMPRESSED:
        body = zlib.decompress(body[4:])
        flags &= ~REC_COMPRESSED
    out = []
    pos = 0
    big = None
    while pos < len(body):
        tag, n = struct.unpack_from('<4sH', body, pos)
        pos += 6
        if tag == b'XXXX':
            big = struct.unpack_from('<I', body, pos)[0]
            pos += n
            continue
        if big is not None:
            n, big = big, None
        payload = body[pos:pos + n]
        pos += n
        if tag in drop:
            continue
        if n > 0xFFFF:
            out.append(struct.pack('<4sHI', b'XXXX', 4, n) + struct.pack('<4sH', tag, 0))
        else:
            out.append(struct.pack('<4sH', tag, n))
        out.append(payload)
    body = b''.join(out)
    return _REC.pack(sig, len(body), flags, fid, rev, ver, unk) + body


class _Scan:
    """One pass over the CELL and WRLD top groups of DLCNukaWorld.esm."""

    def __init__(self, path, wanted):
        with open(path, 'rb') as f:
            self.buf = f.read()
        self.wanted = set(wanted)
        self.interior = []   # (block, subblock, cell_fid, raw_cell, raw_refr)
        self.exterior = []   # (world_fid, raw_refr)
        self.worlds = {}     # world_fid -> raw WRLD
        self.pcells = {}     # world_fid -> raw persistent CELL
        buf = self.buf
        pos = _REC.size + _REC.unpack_from(buf, 0)[1]
        while pos + 24 <= len(buf):
            _, size, label, gtype, _ = _GRUP.unpack_from(buf, pos)
            if label in (0x4C4C4543, 0x444C5257):        # 'CELL', 'WRLD'
                self._walk(pos + 24, pos + size, {})
            pos += size

    def _walk(self, start, end, ctx):
        buf = self.buf
        pos = start
        last = None
        while pos + 24 <= end:
            sig, size, label, gtype = struct.unpack_from('<4sIII', buf, pos)
            if sig == b'GRUP':
                sub = dict(ctx)
                if gtype == GRUP_WORLD_CHILDREN:
                    sub['world'] = label
                elif gtype == GRUP_INTERIOR_BLOCK:
                    sub['block'] = label
                elif gtype == GRUP_INTERIOR_SUBBLOCK:
                    sub['subblock'] = label
                elif gtype in (GRUP_EXTERIOR_BLOCK, GRUP_EXTERIOR_SUBBLOCK):
                    sub['exterior'] = True
                elif gtype == GRUP_CELL_CHILDREN and last is not None:
                    sub['cell'] = last
                self._walk(pos + 24, pos + size, sub)
                pos += size
                continue
            flags, fid = label, gtype     # a record header: sig size FLAGS FORMID
            if sig == b'WRLD':
                self.worlds[fid] = _raw_record(buf, pos)
            elif sig == b'CELL':
                last = (fid, _raw_record(buf, pos))
                if 'world' in ctx and 'exterior' not in ctx and flags & REC_PERSISTENT:
                    self.pcells[ctx['world']] = last[1]
            elif sig == b'REFR' and fid in self.wanted:
                raw = _raw_record(buf, pos)
                if 'world' in ctx:
                    self.exterior.append((ctx['world'], raw))
                else:
                    cell_fid, raw_cell = ctx['cell']
                    self.interior.append((ctx['block'], ctx['subblock'], cell_fid, raw_cell, raw))
            pos += 24 + size


def build(path=NUKAWORLD_ESM, wanted=OUTSIDE_CORES):
    """Returns (cell_top_group, wrld_top_group, record_count, name_string_ids)."""
    scan = _Scan(path, wanted)
    found = [struct.unpack_from('<I', r, 12)[0] for *_, r in scan.interior] + \
            [struct.unpack_from('<I', r, 12)[0] for _, r in scan.exterior]
    missing = set(wanted) - set(found)
    if missing:
        raise SystemExit('в %s не найдены REFR: %s' % (path, ', '.join('%08X' % v for v in sorted(missing))))

    count = 0
    copied = []    # every WRLD/CELL copied as a parent record

    # Interiors: block > sub-block > cell, each level merged.
    tree = {}
    for block, subblock, cell_fid, raw_cell, raw_refr in scan.interior:
        cell = tree.setdefault(block, {}).setdefault(subblock, {}).setdefault(cell_fid, [raw_cell, []])
        cell[1].append(_persistent(raw_refr))
    blocks = []
    for block in sorted(tree):
        subs = []
        for subblock in sorted(tree[block]):
            cells = []
            for cell_fid, (raw_cell, refs) in sorted(tree[block][subblock].items()):
                persistent = _grup(cell_fid, GRUP_CELL_PERSISTENT, b''.join(refs))
                copied.append(raw_cell)
                cells.append(raw_cell + _grup(cell_fid, GRUP_CELL_CHILDREN, persistent))
                count += 1 + 2 + len(refs)
            subs.append(_grup(subblock, GRUP_INTERIOR_SUBBLOCK, b''.join(cells)))
            count += 1
        blocks.append(_grup(block, GRUP_INTERIOR_BLOCK, b''.join(subs)))
        count += 1
    cell_top = _grup(0x4C4C4543, 0, b''.join(blocks))
    count += 1

    # Exteriors: every ref goes into its world's persistent cell.
    by_world = {}
    for world, raw_refr in scan.exterior:
        by_world.setdefault(world, []).append(_persistent(raw_refr))
    worlds = []
    for world in sorted(by_world):
        if world not in scan.pcells:
            raise SystemExit('у мира %08X не найдена persistent-ячейка' % world)
        raw_pcell = scan.pcells[world]
        pcell_fid = struct.unpack_from('<I', raw_pcell, 12)[0]
        refs = by_world[world]
        persistent = _grup(pcell_fid, GRUP_CELL_PERSISTENT, b''.join(refs))
        copied += [raw_pcell, scan.worlds[world]]
        children = raw_pcell + _grup(pcell_fid, GRUP_CELL_CHILDREN, persistent)
        worlds.append(_strip(scan.worlds[world], (b'OFST', b'CLSZ')) + _grup(world, GRUP_WORLD_CHILDREN, children))
        count += 1 + 1 + 1 + 2 + len(refs)
    wrld_top = _grup(0x444C5257, 0, b''.join(worlds))
    count += 1

    name_ids = sorted({i for i in map(_full_id, copied) if i is not None})
    return cell_top, wrld_top, count, name_ids
