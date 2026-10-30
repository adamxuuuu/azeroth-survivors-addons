# Icon mapping data

Reference: [kex0/AZSSpellMeter](https://github.com/kex0/AZSSpellMeter), revision `115f7b8450e4f187624cc9bd89f5fa592d856fd9`.

`IconData.lua` contains factual name-to-texture and localized-name records, re-serialized from the reference addon's client database records (`Icons.lua`, `SpellNames.lua`) and custom talent / equipment associations (`EXTRA_ICONS`). It does not include the reference addon's meter implementation or any image assets. Credit to kex0 for documenting these associations.

Only database spell names used by the game's localization map, plus custom sources and generic damage sources, are retained: 557 canonical icon records and 6,788 localized aliases. Textures are loaded from the client's existing `Interface\Icons` resources. AZS Spell Meter does not need to be installed.

Resolution also uses live data and action bar tooltips; a source such as `item: spell` resolves its spell suffix before its item prefix. Newly added or unidentified sources can still fall back to the question-mark icon. The combined “Other” row deliberately uses the generic book icon because it represents several sources.

Regression checks cover Chinese passive names, equipment-trigger composite names, bare icon filenames, and a runtime question-mark value falling back to a known static association. Browser testing of every mapped texture has not been performed.
