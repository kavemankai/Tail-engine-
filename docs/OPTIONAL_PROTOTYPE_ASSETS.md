# Optional prototype assets

The humanoid characters and animations used by the Last Call demo are exploratory. Tale Engine does not need them, they do not set a visual direction, and a game can replace or remove them.

- `addons/humanoid_kit` and `addons/narrative_characters` came from the supplied `TheStatic-Humanoid-Source.zip`. The kit's source and licence notices are in `addons/humanoid_kit/licenses/`.
- The Episode 0 cast uses them through the adapter in `examples/last_call/humanoid/`. Their fight clips are stand-ins, not matched contact choreography.
- The demo bar is greybox geometry. The Halogen bar environment that was trialled here has been removed from the repository; it remains in git history before the commit that deleted `assets/`, `scenes/` and `scripts/environment/`.

To drop the characters as well, clear the `actor_scene` references in `examples/last_call/episode_0/cast.tres` (an empty value uses the placeholder capsule), then delete the two addons. See [ASSET_SWAP.md](ASSET_SWAP.md) for the actor contract.
