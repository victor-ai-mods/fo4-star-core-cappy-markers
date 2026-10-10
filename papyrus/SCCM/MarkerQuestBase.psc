Scriptname SCCM:MarkerQuestBase extends Quest
{Shared plumbing for the collectible marker quests.

Each collectible type gets its OWN quest rather than its own objective on a shared one,
because Fallout 4 tracks a whole quest, not a single objective - two objectives on one
quest can only ever be tracked together.

A concrete quest supplies three things: Resolve() to look up whatever vanilla forms it
needs, Wanted() to list the things still left to find (empty until the vanilla quest
has actually sent the player looking for them), and Label() for the log.}

; Must match the QUST records built by tools/gen_esp.py.
Int Property OBJECTIVE = 10 AutoReadOnly Hidden
Int Property COLLECTION_ALIAS = 0 AutoReadOnly Hidden

Float Property POLL_INTERVAL = 8.0 AutoReadOnly Hidden
Int Property POLL_TIMER = 1 AutoReadOnly Hidden

String Property NUKAWORLD = "DLCNukaWorld.esm" AutoReadOnly Hidden
; DLC04NukaWorldLocation: the parent of every location a Star Core or a hidden Cappy
; sits in - the park itself, all its interiors and the separate Nuka-Town market world.
Int Property NUKAWORLD_LOCATION = 0x01008060 AutoReadOnly Hidden

; Diagnostics land in Logs\Script\User\SCCM.0.log when Papyrus user logging is on in
; the ini; with it off these calls are a no-op. Written only on change, never per poll.
String Property LOG_NAME = "SCCM" AutoReadOnly Hidden

Int lastCount = -1
Location parkLocation
; Mirror of the collection alias, so a poll compares arrays inside the VM and touches
; the alias only for what actually changed - no RemoveAll() and refill every poll.
ObjectReference[] shown

Event OnInit()
	Bootstrap()
EndEvent

Event Actor.OnPlayerLoadGame(Actor akSender)
	; Re-arm after a load, and pick up any change made by a script update.
	Bootstrap()
EndEvent

Function Bootstrap()
	; Returns false when the log is already open, e.g. after loading a save - the
	; result is not worth gating on.
	Debug.OpenUserLog(LOG_NAME)
	parkLocation = Game.GetFormFromFile(NUKAWORLD_LOCATION, NUKAWORLD) as Location
	Resolve()
	RegisterForRemoteEvent(Game.GetPlayer() as Actor, "OnPlayerLoadGame")
	ReadBackShown()
	lastCount = -1		; log the next count, whatever it is
	; Once per load wherever the player is, so a script update shows up straight away.
	Refresh()
	CancelTimer(POLL_TIMER)
	StartTimer(POLL_INTERVAL, POLL_TIMER)
EndFunction

Event OnTimer(Int aiTimerID)
	If aiTimerID == POLL_TIMER
		; Nothing can be picked up outside Nuka-World, so whatever the last refresh left
		; in the collection is still right there.
		If parkLocation == None || Game.GetPlayer().IsInLocation(parkLocation)
			Refresh()
		EndIf
		StartTimer(POLL_INTERVAL, POLL_TIMER)
	EndIf
EndEvent

Function ReadBackShown()
	; The mirror is rebuilt from the collection itself: a save made by 1.1.x has a
	; filled collection and no mirror at all.
	RefCollectionAlias mine = GetAlias(COLLECTION_ALIAS) as RefCollectionAlias
	shown = new ObjectReference[0]
	If mine == None
		Return
	EndIf
	Int i = 0
	Int n = mine.GetCount()
	While i < n
		ObjectReference ref = mine.GetAt(i)
		If ref != None
			shown.Add(ref)
		EndIf
		i += 1
	EndWhile
EndFunction

Function Refresh()
	RefCollectionAlias mine = GetAlias(COLLECTION_ALIAS) as RefCollectionAlias
	If mine == None
		Return
	EndIf
	If shown == None
		; A 1.1.x save whose timer fires before OnPlayerLoadGame reached Bootstrap().
		ReadBackShown()
	EndIf
	ObjectReference[] wanted = Wanted()

	Int i = shown.Length
	While i > 0
		i -= 1
		If wanted.Find(shown[i]) < 0
			mine.RemoveRef(shown[i])
			shown.Remove(i)
		EndIf
	EndWhile
	i = 0
	While i < wanted.Length
		If shown.Find(wanted[i]) < 0
			mine.AddRef(wanted[i])
			shown.Add(wanted[i])
		EndIf
		i += 1
	EndWhile

	; Without abForce the HUD announces the objective only the first time it appears -
	; not after every load and not after every pickup.
	Bool show = shown.Length > 0
	If show != IsObjectiveDisplayed(OBJECTIVE)
		SetObjectiveDisplayed(OBJECTIVE, show)
	EndIf

	If shown.Length != lastCount
		lastCount = shown.Length
		Debug.TraceUser(LOG_NAME, Label() + " remaining: " + lastCount)
	EndIf
EndFunction

; ------------------------------------------------- supplied by the concrete quest

Function Resolve()
EndFunction

ObjectReference[] Function Wanted()
	Return new ObjectReference[0]
EndFunction

String Function Label()
	Return "?"
EndFunction
