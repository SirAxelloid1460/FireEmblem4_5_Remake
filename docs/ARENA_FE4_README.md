# Sistema de Arena Estilo Fire Emblem 4

Sistema de arena completamente rediseñado basado en Fire Emblem 4: Genealogy of the Holy War, con lista fija de oponentes por capítulo y eventos especiales al derrotar campeones.

## 📁 Archivos Incluidos

```
ArenaPanel_FE4.gd          - Panel de arena con oponentes fijos
ArenaEventManager.gd       - Sistema de eventos de reclutamiento
```

## 🎮 Diferencias Clave vs Arena Original

### ❌ Sistema Original (Eliminado)
- Oponentes generados aleatoriamente
- Sin progresión entre peleas
- Sin eventos especiales

### ✅ Sistema FE4 (Nuevo)
- **Lista fija de oponentes** por capítulo
- **Progresión gradual** de dificultad
- **Campeones especiales** con corona 👑
- **Eventos de reclutamiento** al derrotar campeones
- **Oponentes derrotados** quedan marcados
- **Armas especiales** en algunos oponentes

## 🏆 Sistema de Oponentes

### Estructura por Capítulo

Cada capítulo tiene 3-5 oponentes fijos que aparecen en orden:

```
Capítulo 1: Prólogo
├─ Novato de Arena (Lv3 Fighter) - 150G
├─ Espadachín Ágil (Lv4 Myrmidon) - 200G
├─ Lancero Experimentado (Lv5 Soldier) - 250G
└─ 👑 Beowolf (Lv7 Mercenary) - 500G ⭐ EVENTO

Capítulo 2:
├─ Caballero Pesado (Lv5 Knight) - 250G
├─ Arquero Certero (Lv6 Archer) - 300G
├─ Caballero Montado (Lv7 Cavalier) - 350G
└─ 👑 Holyn (Lv8 Swordmaster) - 600G ⭐ EVENTO

Capítulo 3:
├─ Mago de Fuego (Lv7 Mage) - 350G
├─ Héroe Veterano (Lv8 Hero) - 400G
├─ Paladín Real (Lv9 Paladin) - 450G
└─ 👑 Lex (Lv10 Warrior) - 700G ⭐ EVENTO
```

### Características de Oponentes

Cada oponente tiene:
- **Nombre único** (no "Gladiador Genérico")
- **Stats fijos** (no RNG)
- **Arma específica** con stats detallados
- **Apuesta fija** en oro
- **EXP fija** al vencer

### Campeones de Arena 👑

Los campeones son especiales:
- Marcados con corona dorada 👑
- Significativamente más fuertes
- Algunas armas especiales (Brave Axe, Killing Edge)
- **Disparan eventos** al ser derrotados

## 🎯 Sistema de Eventos

### Tipos de Eventos

1. **Reclutamiento Pagado**
   - Ejemplo: Beowolf (10,000 oro)
   - El jugador decide si pagar

2. **Reclutamiento Gratis**
   - Ejemplo: Holyn, Lex
   - Se unen automáticamente

3. **Items Especiales**
   - Ejemplo: Ayra's Blade
   - Se añaden al convoy

### Eventos Implementados

#### Beowolf (Capítulo 1)
```gdscript
- Mercenario nivel 7
- Requiere 10,000 oro para reclutar
- Habilidad: Adept (ataque extra aleatorio)
- Viene con Steel Sword
```

#### Holyn (Capítulo 2)
```gdscript
- Swordmaster nivel 8
- Reclutamiento gratis
- Habilidad: Critical (más crit)
- Viene con Killing Edge
```

#### Lex (Capítulo 3)
```gdscript
- Warrior nivel 10
- Reclutamiento gratis
- Habilidad: Paragon (doble EXP)
- Viene con Brave Axe
```

## 📝 Uso del Sistema

### Integrar en CastleBase

```gdscript
# En CastleBase.gd
@onready var arena_event_manager: ArenaEventManager = $ArenaEventManager

func _on_arena_button_pressed():
	hide_all_facility_panels()
	arena_panel.show()
	arena_panel.start_arena(selected_unit, army_gold, current_chapter)
	
	# Conectar señal de eventos
	arena_panel.champion_defeated_event.connect(_on_champion_defeated)

func _on_champion_defeated(chapter: int, event_id: String):
	# Disparar evento
	await arena_event_manager.trigger_arena_event(chapter, event_id)
```

### Manejar Reclutamiento

```gdscript
# Conectar señales del ArenaEventManager
arena_event_manager.unit_recruited.connect(_on_unit_recruited)
arena_event_manager.special_item_obtained.connect(_on_item_obtained)
arena_event_manager.dialogue_triggered.connect(_on_dialogue_triggered)

func _on_unit_recruited(unit_data: Dictionary):
	# Crear unidad desde los datos
	var new_unit = create_unit_from_data(unit_data)
	player_units.append(new_unit)
	update_unit_list()
	
	print("¡%s se ha unido!" % unit_data["name"])

func _on_item_obtained(item_data: Dictionary):
	# Añadir item al convoy
	var new_item = create_item_from_data(item_data)
	convoy_items.append(new_item)
	
	print("¡Obtenido: %s!" % item_data["name"])

func _on_dialogue_triggered(dialogue_sequence: Array):
	# Reproducir diálogos
	await dialogue_box.show_dialogue_sequence(dialogue_sequence)
```

### Añadir Nuevos Campeones

```gdscript
# En ArenaPanel_FE4.gd, función load_arena_opponents()

# Capítulo 4
elif current_chapter == 4:
	arena_opponents = [
		# Oponentes normales...
		
		# Campeón
		{
			"id": "ch4_champion",
			"name": "Tu Campeón",
			"class": "Hero",
			"level": 12,
			"hp": 45,
			"str": 16,
			"skl": 14,
			"spd": 13,
			"def": 10,
			"res": 5,
			"weapon": {
				"name": "Silver Sword",
				"might": 13,
				"hit": 80,
				"weight": 7
			},
			"bet": 800,
			"exp": 160,
			"is_champion": true,
			"event_trigger": "tu_evento_personalizado"
		}
	]
```

### Crear Eventos Personalizados

```gdscript
# En ArenaEventManager.gd

func trigger_arena_event(chapter: int, event_id: String):
	# ... código existente ...
	
	match event_id:
		# ... eventos existentes ...
		
		"tu_evento_personalizado":
			await event_tu_evento()

func event_tu_evento():
	var dialogue = [
		{
			"character": "Campeón",
			"text": "¡Impresionante victoria!",
			"portrait": "res://assets/portraits/campeon.png"
		}
	]
	
	dialogue_triggered.emit(dialogue)
	await get_tree().create_timer(1.0).timeout
	
	# Tu lógica de evento aquí
```

## 🎨 UI del Sistema

### Lista de Oponentes
```
👑 Beowolf - Lv7 Mercenary
   Espadachín Ágil - Lv4 Myrmidon
   Lancero Experimentado - Lv5 Soldier [DERROTADO]
```

- Campeones en **dorado** 👑
- Derrotados en **gris** + deshabilitados
- Normales en blanco

### Preview de Combate
```
[Tu Unidad]
Atk: 15 | Hit: 85 | Crit: 10
x2 ataques

VS

[Beowolf]
Atk: 18 | Hit: 90 | Crit: 15

⚠️ PELIGRO DE MUERTE ⚠️
```

## ⚔️ Sistema de Combate

### Cálculos Precisos

```gdscript
Attack = Str/Mag + Weapon Might
Hit = Weapon Hit + (Skill × 2) + (Luck ÷ 2) - Enemy Avoid
Crit = Weapon Crit + (Skill ÷ 2) - Enemy Luck
Avoid = (Speed × 2) + (Luck ÷ 2)
```

### Doble Ataque
```gdscript
if Attack Speed >= Enemy AS + 4:
	# Atacas dos veces
```

### Armas Brave
```gdscript
if weapon.brave:
	# Siempre atacas dos veces (sin requisito de speed)
```

### Muerte Permanente
Como en FE4, si pierdes en la arena, **tu unidad muere permanentemente**.

## 💡 Tips de Diseño

### Balance de Recompensas

```
Oponente Fácil:   50-200 oro,  30-50 EXP
Oponente Medio:   250-400 oro, 60-80 EXP
Oponente Difícil: 450-700 oro, 90-140 EXP
Campeón:          500-1000 oro, 100-200 EXP + EVENTO
```

### Progresión de Dificultad

Cada capítulo debe tener:
1. **Oponente fácil** (nivel del jugador -2)
2. **Oponentes medios** (nivel del jugador ±0)
3. **Oponente difícil** (nivel del jugador +2)
4. **Campeón** (nivel del jugador +3 a +5)

### Armas Especiales en Campeones

- **Brave Weapons** - Atacan dos veces
- **Killing Edge** - +30 Crit
- **Armas mágicas** - Ignoran Def, usan Res

## 🔧 Configuración Avanzada

### Guardar Progreso de Arena

```gdscript
# En save_game()
var arena_progress = {
	"defeated_opponents": arena_panel.defeated_opponents,
	"triggered_events": arena_event_manager.triggered_events
}

# En load_game()
arena_panel.defeated_opponents = save_data["arena_progress"]["defeated_opponents"]
arena_event_manager.triggered_events = save_data["arena_progress"]["triggered_events"]
```

### Reset entre Capítulos

```gdscript
# Al avanzar de capítulo
func start_new_chapter():
	arena_panel.reset_arena_progress()
	# Los eventos permanecen (no se resetean)
```

## 🎯 Ejemplo de Flujo Completo

```
1. Jugador entra a la arena en Capítulo 1
2. Ve lista: Novato, Espadachín, Lancero, 👑 Beowolf
3. Derrota al Novato → Gana 150G + 30 EXP
4. El Novato aparece en gris [DERROTADO]
5. Salta al Espadachín → Victoria → 200G + 40 EXP
6. Desafía a Beowolf 👑
7. ⚠️ Preview muestra: "PELIGRO DE MUERTE"
8. Jugador decide pelear
9. Victoria contra Beowolf!
10. 🎬 Diálogo de evento se reproduce
11. Opción: "¿Pagar 10,000G para reclutar a Beowolf?"
12. Jugador acepta → Beowolf se une
13. Arena cerrada, Beowolf ahora en la lista de unidades
```

## 🐛 Troubleshooting

### Los oponentes no aparecen
- Verifica que `current_chapter` esté configurado correctamente
- Comprueba que `load_arena_opponents()` se llame en `start_arena()`

### Los eventos no se disparan
- Asegúrate de conectar la señal `champion_defeated_event`
- Verifica que `ArenaEventManager` esté en la escena

### Las unidades reclutadas no aparecen
- Conecta la señal `unit_recruited` del `ArenaEventManager`
- Implementa `_on_unit_recruited()` en `CastleBase`

### Los diálogos no se muestran
- Verifica que tu `DialogueBox` esté configurado
- O implementa un sistema alternativo de diálogos

## 🎮 Mejoras Futuras

- [ ] Animaciones de combate en la arena
- [ ] Rankings de arena (récords por capítulo)
- [ ] Campeones secretos desbloqueables
- [ ] Arena infinita post-juego
- [ ] Modo espectador (ver combates AI vs AI)
- [ ] Torneos especiales con múltiples rondas
- [ ] Items únicos por ganar sin recibir daño
- [ ] Logros por derrotar todos los campeones

¡Tu arena estilo FE4 está completa! 🏆
