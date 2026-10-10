Scriptname SCCM:StarCoreMarkers extends SCCM:MarkerQuestBase
{Markers for the Star Cores still out there.

Which cores are left is never tracked by this mod. DLC04GZTrackingQuest holds six
ref-collection aliases (ids 42-47, one per Galactic Zone area) and its own script
calls RemoveRef() the instant a core is taken, so those collections ARE the list of
remaining cores - already correct in a save where the hunt is half done, and unable
to resurrect a core that was already picked up.

The sixth of them, 47 GalacticZoneOutsideCores, is the exception: it has no fill data
at all in DLCNukaWorld.esm and is only ever used as the fallback bucket a core reports
to when it belongs to no zone collection. It stays empty forever, so the five cores
outside the Galactic Zone - the "[n] in other park sectors" line on the Star Control
terminal, which is read off the DLC04GZ_StarCores_Outside* globals instead - have to
be named here by hand.

Nothing is shown before "Star Control" (DLC04GZMainQuest) reaches stage 50, the point
where the mainframe tells the player it needs Star Cores.}

Int Property TRACKING_QUEST = 0x0101E34C AutoReadOnly Hidden	; DLC04GZTrackingQuest
; DLC04GZTrackingQuest alias 2: panels that have been emptied (or locked shut).
Int Property ALIAS_LOCKED_PANELS = 2 AutoReadOnly Hidden
Int Property MAIN_QUEST = 0x0101E34A AutoReadOnly Hidden	; DLC04GZMainQuest, "Star Control"
; "In order to restart it, I need to find a component it calls a Star Core."
Int Property STAGE_FIND_CORES = 50 AutoReadOnly Hidden

Quest trackingQuest
Quest mainQuest
Int[] coreAliases
ObjectReference[] outsideCores
Int lastRawCount = -1

Function Resolve()
	trackingQuest = Game.GetFormFromFile(TRACKING_QUEST, NUKAWORLD) as Quest
	mainQuest = Game.GetFormFromFile(MAIN_QUEST, NUKAWORLD) as Quest
	Debug.TraceUser(LOG_NAME, "resolved DLC04GZTrackingQuest = " + trackingQuest \
		+ ", DLC04GZMainQuest = " + mainQuest)

	; The five cores outside the Galactic Zone. DLC04GZ_StarCores_OutsideTotal is 5 and
	; these are exactly the DLC04GZExternalStarCore* refs of DLCNukaWorld.esm; none of
	; them is initially disabled or has an enable parent, so IsDisabled() means "taken"
	; for the four loose ones, and the one wall panel lands in LockedStarCorePanels.
	; In vanilla all five are TEMPORARY refs, which GetFormFromFile() cannot reach
	; while their cell is unloaded - the plugin overrides them as persistent for that
	; (tools/vanilla_overrides.py). Without that override these come back None.
	outsideCores = new ObjectReference[5]
	outsideCores[0] = Game.GetFormFromFile(0x01031995, NUKAWORLD) as ObjectReference	; 02 Dry Rock Gulch
	outsideCores[1] = Game.GetFormFromFile(0x010319CE, NUKAWORLD) as ObjectReference	; 03 Bottling Plant
	outsideCores[2] = Game.GetFormFromFile(0x010319CF, NUKAWORLD) as ObjectReference	; 04 Nukacade
	outsideCores[3] = Game.GetFormFromFile(0x010319D6, NUKAWORLD) as ObjectReference	; 05 Junkyard (panel)
	outsideCores[4] = Game.GetFormFromFile(0x01054CA8, NUKAWORLD) as ObjectReference	; 06 Nuka-Town Market
	Debug.TraceUser(LOG_NAME, "resolved outside cores = " + outsideCores)

	coreAliases = new Int[6]
	coreAliases[0] = 42		; GalacticZoneExteriorCores
	coreAliases[1] = 43		; GalacticZoneNukaGalaxyCores
	coreAliases[2] = 44		; GalacticZoneTheaterCores
	coreAliases[3] = 45		; GalacticZoneVaultTecCores
	coreAliases[4] = 46		; GalacticZoneBattlezoneCores
	coreAliases[5] = 47		; GalacticZoneOutsideCores

	lastRawCount = -1
EndFunction

String Function Label()
	Return "star cores"
EndFunction

ObjectReference[] Function Wanted()
	ObjectReference[] left = new ObjectReference[0]
	If trackingQuest == None || mainQuest == None || !mainQuest.GetStageDone(STAGE_FIND_CORES)
		Return left
	EndIf

	; Belt and braces in Keep(): a core taken before DLC04GZTrackingQuest reached stage
	; 10 is removed from the WRONG collection by the vanilla script (it falls back to
	; GalacticZoneOutsideCores), so it can still be sitting in its zone collection.
	; Such a core is either a disabled loose-core activator or an emptied wall panel,
	; and an emptied panel always lands in LockedStarCorePanels.
	RefCollectionAlias locked = trackingQuest.GetAlias(ALIAS_LOCKED_PANELS) as RefCollectionAlias

	Int raw = 0
	Int[] zoneCounts = new Int[coreAliases.Length]
	Int i = 0
	While i < coreAliases.Length
		RefCollectionAlias zone = trackingQuest.GetAlias(coreAliases[i]) as RefCollectionAlias
		zoneCounts[i] = -1
		If zone != None
			Int n = zone.GetCount()
			zoneCounts[i] = n
			raw += n
			Int j = 0
			While j < n
				Keep(left, zone.GetAt(j), locked)
				j += 1
			EndWhile
		EndIf
		i += 1
	EndWhile
	; Alias 47 above is always empty (see the script header), so the cores outside the
	; Galactic Zone come from the hand-written list. Adding them unconditionally is
	; safe: Keep() drops the ones already taken, exactly as for the rest.
	i = 0
	While i < outsideCores.Length
		Keep(left, outsideCores[i], locked)
		i += 1
	EndWhile

	If raw != lastRawCount
		lastRawCount = raw
		String counts = ""
		i = 0
		While i < coreAliases.Length
			counts = counts + " " + coreAliases[i] + ":" + zoneCounts[i]
			i += 1
		EndWhile
		Debug.TraceUser(LOG_NAME, "vanilla core collections:" + counts \
			+ " + " + outsideCores.Length + " outside => " + left.Length + " left")
	EndIf
	Return left
EndFunction

Function Keep(ObjectReference[] left, ObjectReference core, RefCollectionAlias locked)
	If core == None || core.IsDisabled() || (locked != None && locked.Find(core) > -1)
		Return
	EndIf
	If left.Find(core) < 0
		left.Add(core)
	EndIf
EndFunction
