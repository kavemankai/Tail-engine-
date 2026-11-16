# Asset sources and licence manifest

All bundled character and skeletal animation source assets are by Quaternius,
released under [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/).
The source archives' licence text is included next to this manifest.

| Bundled asset | Source | Local processing |
|---|---|---|
| `source/Superhero_Male_FullBody.gltf` and matching BIN | [Universal Base Characters Standard](https://quaternius.itch.io/universal-base-characters), supplied ZIP, Godot–UE folder | Replaced texture-dependent materials with neutral PBR colours. Runtime hides the eyebrow cards. Geometry, weights, and source armature retained. |
| `source/Superhero_Female_FullBody.gltf` and matching BIN | Same Standard pack and folder | Same processing. |
| `source/ual.glb` | [Universal Animation Library](https://quaternius.itch.io/universal-animation-library), downloaded through the official Itch.io free download, `Unreal-Godot/UAL1_Standard.glb` | Original GLB. Tracks compiled into portable libraries after Godot import and humanoid retargeting. |
| `source/ual_rm.glb` | Same official UAL Standard ZIP, `Unreal-Godot/UAL1_Standard_RM.glb` | Original GLB. Used for the separate root-motion library. |
| `source/ual2.glb` | [Universal Animation Library 2](https://quaternius.itch.io/universal-animation-library-2), downloaded from the [author's OpenGameArt upload](https://opengameart.org/content/universal-animation-library-2), `Unreal-Godot/UAL2_Standard.glb` | Original GLB. Tracks compiled into the same portable libraries. |

Source archive SHA-256 checksums

- Universal Base Characters Standard — `fdbf1804c90dfc1ea03e992bff7da2dfd1a79318e13270a660180f9308455f40`
- Universal Animation Library Standard — `cc73fc4e495b82958207316596317a3f40b9fa38065bde1027937452da537724`
- Universal Animation Library 2 Standard — `ec0e40d6d78fe9aaad59e322f40865a8675c22f0745e291622e54520391a9217`

The supplied free character archive contains the Superhero models. The Regular
variants were unavailable in that archive. Their athletic proportions remain
visible despite the neutral materials. The body meshes contain 12,566 (male)
and 12,812 (female) triangles, plus 768 triangles per actor for eyes. An older
[Animated Men pack](https://quaternius.com/packs/animatedmen.html) offers FBX,
OBJ, and Blender sources, which would require a separate profile and validation
pass. No second mesh reduction or re-skinning pipeline was added.

The 2,000–5,000 triangle target warrants a separate deformation pass. Other
Universal Animation Library mannequins inspected also exceeded 13,000 triangles.
The shipping skin weights and meshes were preserved for this build.
