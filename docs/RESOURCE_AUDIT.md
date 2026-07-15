# Auditoría de recursos — FE4/FE5 remake

> Generado por `tools/resource_audit.py`. ✅ tenemos · ⬜ falta


## Inventario
- Clases (classes.json): **63**
- Personajes (units.json): **122**
- Items (items.json): **79**
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
- con retrato: **111/122** · sin retrato (11): GenoaGuard, Mana, Radney, Roddlevan, Dimna, Femina, Johan, Johalva, Sharlow, Pahn, Cyas
- con map sprite: **122/122** · sin: —
- con combat anim: **99/122** · sin (23): Alvar, Azel, Eldigan, Elliot, Evan, Evar, Lewyn, Quan, Tailtiu, Voltz, Zain, Coirpre, Oifey, Amid, Linda, Asbel, Fred, Glade, Homer, Miranda, Amalda, Conomor, Delmud
- starting_items colgantes: ninguno ✅
- learned_skills colgantes: ninguno ✅

## Clases — cobertura de assets (63)
- con map sprite: **63/63** · sin: —
- con combat anim base (Generic/Male/Female): **48/63**
  · sin (15): Paladin, Ballistae, Bard, Child, Citizen, DukeKnight, ForrestKnight, GreatKnight, LordKnight, LordLeaf, LordSeliph, Mage, Princess, Queen, Tester
- con retrato genérico: **53/63** · sin: Child, FalconKnight, HighPriestess, LightPriestess, LordLeaf, LordSeliph, Priestess, Tester, Dancer_Lara, Thief

## Integridad de referencias data→data
- units.klass inexistente: ninguno ✅
- class promotes_from/turns_into inexistente: ninguno ✅
