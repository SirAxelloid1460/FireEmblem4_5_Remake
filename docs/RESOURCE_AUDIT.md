# Auditoría de recursos — FE4/FE5 remake

> Generado por `tools/resource_audit.py`. ✅ tenemos · ⬜ falta


## Inventario
- Clases (classes.json): **61**
- Personajes (units.json): **122**
- Items (items.json): **67**
- Armas (weapons.json): **134**
- Skills (skills.json): **97**
- Retratos de personaje: **249**
- Retratos extra (NPC): **18**
- Retratos genéricos de clase: **57**
- Map sprites (stand): **153**
- Carpetas de combat anim: **126**
- Pistas de música (assets/music): **492**
- SFX (assets/sfx): **438**
- Tilesets: **2**

## Personajes — cobertura de assets (122)
- con retrato: **111/122** · sin retrato (11): GenoaGuard, Mana, Radney, Dalvin, Dimna, Femina, Johan, Johalva, Sharlow, Perne, Cyas
- con map sprite: **122/122** · sin: —
- con combat anim: **100/122** · sin (22): Alvar, Azel, Eldigan, Elliot, Eve, Evar, Lewyn, Quan, Tailtiu, Voltz, Zain, Oifey, Amid, Linda, Asbel, Fred, Glade, Homer, Miranda, Amalda, Conomor, Delmud
- starting_items colgantes: ninguno ✅
- learned_skills colgantes: ninguno ✅

## Clases — cobertura de assets (60, excl. debug: Tester)
- con map sprite: **60/60** · sin: —
- con combat anim base (Generic/Male/Female): **47/60**
  · sin (13): Paladin, Ballistae, Bard, Citizen, DukeKnight, ForrestKnight, GreatKnight, LordKnight, LordLeaf, LordSeliph, Mage, Princess, Queen
- con retrato genérico: **53/60** · sin: FalconKnight, HighPriestess, LightPriestess, LordLeaf, LordSeliph, Priestess, Thief

## Integridad de referencias data→data
- units.klass inexistente: ninguno ✅
- class promotes_from/turns_into inexistente: ninguno ✅
