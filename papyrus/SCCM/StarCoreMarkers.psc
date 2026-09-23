Scriptname SCCM:StarCoreMarkers extends SCCM:MarkerQuestBase
{Markers for the Star Cores still out there.

Which cores are left is never tracked by this mod. DLC04GZTrackingQuest holds six
ref-collection aliases (ids 42-47, one per Galactic Zone area) and its own script
calls RemoveRef() the instant a core is taken, so those collections ARE the list of
remaining cores - already correct in a save where the hunt is half done, and unable
to resurrect a core that was already picked up.}

Int Property TRACKING_QUEST = 0x0101E34C AutoReadOnly Hidden	; DLC04GZTrackingQuest
; DLC04GZTrackingQuest alias 2: panels that have been emptied (or locked shut).
Int Property ALIAS_LOCKED_PANELS = 2 AutoReadOnly Hidden

Quest trackingQuest
Int[] coreAliases
Int lastRawCount = -1

Function Resolve()
	trackingQuest = Game.GetFormFromFile(TRACKING_QUEST, NUKAWORLD) as Quest
	Debug.TraceUser(LOG_NAME, "resolved DLC04GZTrackingQuest = " + trackingQuest)

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

Int Function Rebuild(RefCollectionAlias mine)
	If trackingQuest == None
		Return 0
	EndIf

	; No gate on DLC04GZTrackingQuest's stage here on purpose. Its stage 10 (the one
	; that runs SetupStarCoreCollections) is flagged Run On Start, so it should always
	; be done - but if that ever read back false the mod would silently show nothing,
	; which is exactly the failure mode that makes these marker mods look broken. An
	; empty collection already hides the objective, so the check bought nothing.
	Int i = 0
	String zoneCounts = ""
	While i < coreAliases.Length
		RefCollectionAlias zone = trackingQuest.GetAlias(coreAliases[i]) as RefCollectionAlias
		If zone == None
			zoneCounts = zoneCounts + " " + coreAliases[i] + ":none"
		Else
			mine.AddRefCollection(zone)
			zoneCounts = zoneCounts + " " + coreAliases[i] + ":" + zone.GetCount()
		EndIf
		i += 1
	EndWhile
	If mine.GetCount() != lastRawCount
		lastRawCount = mine.GetCount()
		Debug.TraceUser(LOG_NAME, "vanilla core collections:" + zoneCounts \
			+ " => " + lastRawCount + " before filtering")
	EndIf

	; Belt and braces. A core taken before DLC04GZTrackingQuest reached stage 10 is
	; removed from the WRONG collection by the vanilla script (it falls back to
	; GalacticZoneOutsideCores), so it can still be sitting in its zone collection.
	; Such a core is either a disabled loose-core activator or an emptied wall panel,
	; and an emptied panel always lands in LockedStarCorePanels.
	RefCollectionAlias locked = trackingQuest.GetAlias(ALIAS_LOCKED_PANELS) as RefCollectionAlias
	Int n = mine.GetCount()
	While n > 0
		n -= 1
		ObjectReference core = mine.GetAt(n)
		If core == None
			; nothing to remove
		ElseIf core.IsDisabled() || (locked != None && locked.Find(core) > -1)
			mine.RemoveRef(core)
		EndIf
	EndWhile

	Return mine.GetCount()
EndFunction
