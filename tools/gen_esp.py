"""
Builds StarCoreAndCappyMarkers.esp from scratch.

The plugin is deliberately small: two new QUST records, one per collectible type, plus
persistent overrides of the five Star Cores outside the Galactic Zone (see
vanilla_overrides.py - they are temporary refs in vanilla, which Game.GetFormFromFile()
cannot reach while their cell is unloaded). Those overrides are the only reason for the
DLCNukaWorld.esm master; the scripts still resolve every vanilla form at runtime with
Game.GetFormFromFile().

One quest per collectible type, rather than one quest with two objectives, because
Fallout 4 tracks a whole quest: two objectives on a shared quest can only ever be
tracked together.

QUST layout (order matters; taken from xEdit's wbDefinitionsFO4.pas and cross-checked
against DLC04GZMiscObjective):

    EDID, VMAD, FULL, DNAM, NEXT,
    <objectives: QOBJ, FNAM, NNAM, QSTA>,
    ANAM,
    <aliases>

A Ref Collection Alias is NOT a flag - it is its own little array entry, ALCS (alias
id) + ALMI (max initial fill count), sitting immediately BEFORE the ordinary ALST
entry it upgrades. Verified against every collection alias in DLC04GZTrackingQuest.

    python tools/gen_esp.py [out.esp]
"""

import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from esp_writer import TES4_LIGHT, Record, Script, tes4, top_group, vmad, zstring
import vanilla_overrides

PLUGIN_NAME = 'StarCoreAndCappyMarkers.esp'

# 0x800 was the single combined quest shipped by the first build. Both quests get a
# fresh FormID so that old record disappears from an existing save outright, instead
# of surviving with one objective and one alias fewer than the save has baked in.
# Own records carry the index after the masters: 02 since DLCNukaWorld.esm became the
# second master in 1.1.0 (01 before). A save stores plugin names, not this byte, so
# the quests keep their identity across the change.
MASTERS = ['Fallout4.esm', 'DLCNukaWorld.esm']
STARCORE_QUEST_ID = 0x02000810
CAPPY_QUEST_ID = 0x02000811
NEXT_OBJECT_ID = 0x00000812

# ESL-флаг (ESPFE): файл остаётся .esp, но не занимает слот из 254. Условие —
# все свои FormID в диапазоне 0x800..0xFFF; обе записи в нём уже с первой сборки.
ESL = True

# Must match SCCM:MarkerQuestBase.
OBJECTIVE_INDEX = 10
COLLECTION_ALIAS = 0

# QUST DNAM: flags(u16) priority(u8) formVersion(u8) delayTime(f32) type(u32)
QUEST_FLAG_START_GAME_ENABLED = 0x0001
QUEST_TYPE_MISCELLANEOUS = 6
QUEST_PRIORITY = 30

# QUST alias FNAM
ALIAS_FLAG_OPTIONAL = 0x00000002


def quest_dnam(flags, priority, quest_type):
    return struct.pack('<HBBfI', flags, priority, 0, 0.0, quest_type)


def marker_quest(form_id, editor_id, script_name, quest_name, objective_text, alias_name):
    rec = Record(b'QUST', form_id, editor_id)
    # Vanilla omits the fragment/alias trailer entirely when there are neither
    # (see RadioInstituteQuest), so a plain script list is all this needs.
    rec.add(b'VMAD', vmad([Script(script_name)]))
    rec.add(b'FULL', zstring(quest_name))
    rec.add(b'DNAM', quest_dnam(QUEST_FLAG_START_GAME_ENABLED,
                                QUEST_PRIORITY, QUEST_TYPE_MISCELLANEOUS))
    rec.add(b'NEXT', b'')

    rec.add(b'QOBJ', struct.pack('<H', OBJECTIVE_INDEX))
    rec.add(b'FNAM', struct.pack('<I', 0))
    rec.add(b'NNAM', zstring(objective_text))
    # QSTA: alias(i32) flags(u32) keyword(FormID)
    rec.add(b'QSTA', struct.pack('<iII', COLLECTION_ALIAS, 0, 0))

    rec.add(b'ANAM', struct.pack('<I', COLLECTION_ALIAS + 1))

    # Ref Collection Alias: the ALCS/ALMI entry marks the ALST entry that follows.
    rec.add(b'ALCS', struct.pack('<I', COLLECTION_ALIAS))
    rec.add(b'ALMI', struct.pack('<B', 0))
    rec.add(b'ALST', struct.pack('<I', COLLECTION_ALIAS))
    rec.add(b'ALID', zstring(alias_name))
    rec.add(b'FNAM', struct.pack('<I', ALIAS_FLAG_OPTIONAL))
    rec.add(b'VTCK', struct.pack('<I', 0))
    rec.add(b'ALED', b'')
    return rec


def build_quests():
    return [
        marker_quest(STARCORE_QUEST_ID, 'SCCM_StarCoreQuest', 'SCCM:StarCoreMarkers',
                     'Nuka-World: Star Cores',
                     'Find the remaining Star Cores',
                     'SCCM_RemainingStarCores'),
        marker_quest(CAPPY_QUEST_ID, 'SCCM_CappyQuest', 'SCCM:CappyMarkers',
                     'Nuka-World: Hidden Cappys',
                     'Find the remaining hidden Cappys',
                     'SCCM_RemainingCappys'),
    ]


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'build', PLUGIN_NAME)
    quests = build_quests()
    if ESL:
        bad = [q.form_id for q in quests if not 0x800 <= (q.form_id & 0xFFFFFF) <= 0xFFF]
        if bad:
            raise SystemExit('FormID вне диапазона ESL 0x800..0xFFF: %s' % ', '.join('%08X' % v for v in bad))
    # Top groups in the vanilla order: CELL, WRLD, QUST.
    cell_top, wrld_top, override_count = vanilla_overrides.build()
    quest_top = top_group(quests)
    num = override_count + len(quests) + 1
    blob = tes4(MASTERS, num, NEXT_OBJECT_ID, flags=TES4_LIGHT if ESL else 0).to_bytes() \
        + cell_top + wrld_top + quest_top
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'wb') as f:
        f.write(blob)
    print('%s  (%d bytes)' % (out, len(blob)))


if __name__ == '__main__':
    main()
