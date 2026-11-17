class_name TESeason
extends Resource
## An ordered list of episodes played as one story. Choices made in earlier
## episodes stay readable (Story.prior), and listed variables carry forward.

@export var id: StringName
@export var title: String
@export var episodes: Array[TEEpisode] = []
## Variables copied into the next episode. Only names the next episode's
## manifest also declares are carried.
@export var carry_variables: Array[StringName] = []

func index_of(episode: TEEpisode) -> int:
	for i in episodes.size():
		if episodes[i] != null and episodes[i].id == episode.id:
			return i
	return -1

func next_after(episode: TEEpisode) -> TEEpisode:
	var index := index_of(episode)
	if index < 0 or index + 1 >= episodes.size():
		return null
	return episodes[index + 1]
