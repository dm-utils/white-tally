class_name TallyStrings
extends RefCounted
## Dutch and English texts (design 10.6). Registered with WhiteText; kit keys not listed keep the kit default.

const TEXT := {
	"nl": {
		"count": "Zetten: %d",
		"count_final": "Zetten in oplossing: %d",
		"solved": "Leeg in %d zetten (par %d) · %s",
		"perfect": "Precies par!",
		"hint": "Wissel of schuif stenen. Een groep verdwijnt als hij precies zo groot is als zijn getal.",
		"dead_end": "Geen zet meer mogelijk. Neem terug of begin opnieuw.",
		"best_route": "Beste route",
		"share_line": "White Tally #%d · %s zetten (par %s)",
	},
	"en": {
		"count": "Moves: %d",
		"count_final": "Moves in solution: %d",
		"solved": "Cleared in %d moves (par %d) · %s",
		"perfect": "Exactly par!",
		"hint": "Swap or slide tiles. A group vanishes when its size equals its number.",
		"dead_end": "No move left. Undo or restart.",
		"best_route": "Best route",
		"share_line": "White Tally #%d · %s moves (par %s)",
	},
}
