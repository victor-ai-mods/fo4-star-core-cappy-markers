Scriptname NWCM:MarkerQuestBase extends Quest
{Shared plumbing for the collectible marker quests.

Each collectible type gets its OWN quest rather than its own objective on a shared one,
because Fallout 4 tracks a whole quest, not a single objective - two objectives on one
quest can only ever be tracked together.

A concrete quest supplies three things: Resolve() to look up whatever vanilla forms it
needs, Rebuild() to fill this quest's ref-collection alias 0 with the things still left
to find, and Label() for the log.}

; Must match the QUST records built by tools/gen_esp.py.
Int Property OBJECTIVE = 10 AutoReadOnly Hidden
Int Property COLLECTION_ALIAS = 0 AutoReadOnly Hidden

Float Property POLL_INTERVAL = 8.0 AutoReadOnly Hidden
Int Property POLL_TIMER = 1 AutoReadOnly Hidden

String Property NUKAWORLD = "DLCNukaWorld.esm" AutoReadOnly Hidden

; Diagnostics land in Logs\Script\User\NWCM.0.log when Papyrus user logging is on in
; the ini; with it off these calls are a no-op. Written only on change, never per poll.
String Property LOG_NAME = "NWCM" AutoReadOnly Hidden

Int lastCount = -1

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
	Resolve()
	RegisterForRemoteEvent(Game.GetPlayer() as Actor, "OnPlayerLoadGame")
	lastCount = -1		; force the next Refresh() to publish, whatever it finds
	Refresh()
	CancelTimer(POLL_TIMER)
	StartTimer(POLL_INTERVAL, POLL_TIMER)
EndFunction

Event OnTimer(Int aiTimerID)
	If aiTimerID == POLL_TIMER
		Refresh()
		StartTimer(POLL_INTERVAL, POLL_TIMER)
	EndIf
EndEvent

Function Refresh()
	RefCollectionAlias mine = GetAlias(COLLECTION_ALIAS) as RefCollectionAlias
	If mine == None
		Return
	EndIf
	mine.RemoveAll()
	Int remaining = Rebuild(mine)

	; Only touch the objective when something actually changed - SetObjectiveDisplayed
	; with force pops the "objective updated" HUD message, so once per pickup rather
	; than once per poll.
	If remaining != lastCount
		lastCount = remaining
		SetObjectiveDisplayed(OBJECTIVE, remaining > 0, true)
		Debug.TraceUser(LOG_NAME, Label() + " remaining: " + remaining)
	EndIf
EndFunction

; ------------------------------------------------- supplied by the concrete quest

Function Resolve()
EndFunction

Int Function Rebuild(RefCollectionAlias mine)
	Return 0
EndFunction

String Function Label()
	Return "?"
EndFunction
