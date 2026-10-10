Scriptname SCCM:CappyMarkers extends SCCM:MarkerQuestBase
{Markers for the hidden Cappys of "Cappy in a Haystack" that are still unfound.

Each of the 10 placed DLC04MS01CappyActivator refs sets its own stage on DLC04MS01
when the player finds it (110, 115, 120 ... 155), so GetStageDone() answers per Cappy
straight out of the save - nothing to track separately.

DLC04MS01 is Start Game Enabled, so IsRunning() is true from the very first minute of
any game with Nuka-World installed; 1.1.x gated on it and showed the Cappys long
before Sierra ever asked for them. The real start of the hunt is stage 100.}

Int Property CAPPY_QUEST = 0x01000806 AutoReadOnly Hidden	; DLC04MS01
; "Sierra Petrovita asked for my help in finding 10 Hidden Cappy images in the park."
Int Property STAGE_HUNT_GIVEN = 100 AutoReadOnly Hidden

Quest cappyQuest
ObjectReference[] cappyRefs
Int[] cappyStages

Function Resolve()
	cappyQuest = Game.GetFormFromFile(CAPPY_QUEST, NUKAWORLD) as Quest
	Debug.TraceUser(LOG_NAME, "resolved DLC04MS01 = " + cappyQuest)

	cappyStages = new Int[10]
	cappyStages[0] = 110	; Nuka-Town USA
	cappyStages[1] = 115	; Bottling Plant
	cappyStages[2] = 120	; Dry Rock Gulch 1
	cappyStages[3] = 125	; Dry Rock Gulch 2
	cappyStages[4] = 130	; Galactic Zone 1
	cappyStages[5] = 135	; Galactic Zone 2
	cappyStages[6] = 140	; Kiddie Kingdom 1
	cappyStages[7] = 145	; Kiddie Kingdom 2
	cappyStages[8] = 150	; Safari Adventure 1
	cappyStages[9] = 155	; Safari Adventure 2

	cappyRefs = new ObjectReference[10]
	cappyRefs[0] = Game.GetFormFromFile(0x01015569, NUKAWORLD) as ObjectReference
	cappyRefs[1] = Game.GetFormFromFile(0x01015A82, NUKAWORLD) as ObjectReference
	cappyRefs[2] = Game.GetFormFromFile(0x01015A89, NUKAWORLD) as ObjectReference
	cappyRefs[3] = Game.GetFormFromFile(0x01015A8C, NUKAWORLD) as ObjectReference
	cappyRefs[4] = Game.GetFormFromFile(0x01015A8F, NUKAWORLD) as ObjectReference
	cappyRefs[5] = Game.GetFormFromFile(0x01015A92, NUKAWORLD) as ObjectReference
	cappyRefs[6] = Game.GetFormFromFile(0x01015A95, NUKAWORLD) as ObjectReference
	cappyRefs[7] = Game.GetFormFromFile(0x01015A98, NUKAWORLD) as ObjectReference
	cappyRefs[8] = Game.GetFormFromFile(0x01015A9B, NUKAWORLD) as ObjectReference
	cappyRefs[9] = Game.GetFormFromFile(0x01015A9E, NUKAWORLD) as ObjectReference
EndFunction

String Function Label()
	Return "hidden cappys"
EndFunction

ObjectReference[] Function Wanted()
	ObjectReference[] left = new ObjectReference[0]
	; Not before Sierra hands out the hunt, and nothing once the quest is over.
	If cappyQuest == None || !cappyQuest.GetStageDone(STAGE_HUNT_GIVEN) \
			|| !cappyQuest.IsRunning() || cappyQuest.IsCompleted()
		Return left
	EndIf

	Int i = 0
	While i < cappyRefs.Length
		If cappyRefs[i] != None && !cappyQuest.GetStageDone(cappyStages[i])
			left.Add(cappyRefs[i])
		EndIf
		i += 1
	EndWhile
	Return left
EndFunction
