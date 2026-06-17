# Sistemas de Level Up y Promoción - Fire Emblem Style

Pantallas animadas de subida de nivel y promoción estilo Fire Emblem clásico.

## 📁 Archivos Incluidos

```
LevelUpScreen.gd           - Pantalla de level up con animaciones
PromotionScreen.gd         - Pantalla de promoción con efectos
level_promotion_screens.tscn - Escenas de ambas pantallas
```

## 🎮 Sistema de Level Up

### Características
- ✅ **Animación de stats** - Cada stat se revela una por una
- ✅ **Colores diferenciados** - Verde para ganancias, gris para sin ganancia
- ✅ **Efectos de brillo** - Las stats ganadas parpadean
- ✅ **Sistema de RNG** - Basado en tasas de crecimiento
- ✅ **Salteable** - Presiona Accept/Cancel para saltar
- ✅ **Sonidos** - Hooks para SFX personalizados

### Uso Básico

```gdscript
# 1. Añadir la escena a tu juego
var level_up_screen = preload("res://scenes/level_up_screen.tscn").instantiate()
add_child(level_up_screen)

# 2. Calcular ganancias de stats
var growth_rates = {
	"hp": 80,   # 80% probabilidad
	"str": 50,  # 50% probabilidad
	"skl": 60,
	"spd": 70,
	"def": 40,
	"res": 30,
	"lck": 40,
	"mag": 20
}

var gains = LevelUpScreen.calculate_stat_gains(unit, growth_rates)
# Resultado: {"hp": 1, "str": 0, "skl": 1, "spd": 1, ...}

# 3. Aplicar ganancias a la unidad
LevelUpScreen.apply_stat_gains(unit, gains)

# 4. Mostrar pantalla
await level_up_screen.show_level_up(unit, gains)

# 5. La pantalla se cierra automáticamente
```

### Integración con Combate

```gdscript
# En tu sistema de combate, cuando una unidad gana EXP:

func gain_experience(unit: Unit, exp: int):
	unit.experience += exp
	
	while unit.experience >= 100:
		# Level up!
		unit.experience -= 100
		unit.level += 1
		
		# Calcular y mostrar
		var gains = LevelUpScreen.calculate_stat_gains(unit, unit.growth_rates)
		LevelUpScreen.apply_stat_gains(unit, gains)
		
		await show_level_up_screen(unit, gains)

func show_level_up_screen(unit: Unit, gains: Dictionary):
	var screen = preload("res://scenes/level_up_screen.tscn").instantiate()
	add_child(screen)
	await screen.show_level_up(unit, gains)
	screen.queue_free()
```

### Tasas de Crecimiento por Clase

```gdscript
# Ejemplo: Definir growth rates en tu Unit
class Unit:
	var growth_rates: Dictionary = {}
	
	func _init():
		match unit_class:
			"Lord":
				growth_rates = {
					"hp": 80, "str": 50, "mag": 10, "skl": 60,
					"spd": 60, "lck": 60, "def": 40, "res": 30
				}
			"Fighter":
				growth_rates = {
					"hp": 90, "str": 60, "mag": 0, "skl": 50,
					"spd": 40, "lck": 40, "def": 30, "res": 10
				}
			"Mage":
				growth_rates = {
					"hp": 50, "str": 10, "mag": 70, "skl": 50,
					"spd": 50, "lck": 40, "def": 20, "res": 60
				}
```

## 🌟 Sistema de Promoción

### Características
- ✅ **Animación dramática** - Flash blanco, partículas, shake
- ✅ **Comparación de stats** - Antes/Después lado a lado
- ✅ **Flecha de transformación** - Clase antigua → Clase nueva
- ✅ **Bonuses destacados** - Muestra "+2", "+3" en verde
- ✅ **Sistema completo** - 13 clases promocionables incluidas
- ✅ **Reset de nivel** - Vuelve a nivel 1 (estilo FE clásico)

### Uso Básico

```gdscript
# 1. Verificar si puede promocionar
if PromotionSystem.can_promote(unit):
	
	# 2. Obtener datos de promoción
	var promo_data = PromotionSystem.promote_unit(unit)
	# Esto ya aplica los bonuses a la unidad
	
	# 3. Mostrar pantalla
	var screen = preload("res://scenes/promotion_screen.tscn").instantiate()
	add_child(screen)
	
	await screen.show_promotion(
		unit,
		promo_data["old_class"],
		promo_data["new_class"],
		promo_data["bonuses"]
	)
	
	screen.queue_free()
```

### Integración con Castle Base

```gdscript
# En CastleBase.gd, función _on_promotion_button_pressed()

func _on_promotion_button_pressed():
	if not selected_unit:
		show_message("Selecciona una unidad primero")
		return
	
	if not PromotionSystem.can_promote(selected_unit):
		show_message("%s no puede promocionar todavía (Requiere nivel 20)" % selected_unit.unit_name)
		return
	
	# Confirmar promoción
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "¿Promocionar a %s?" % selected_unit.unit_name
	confirm.title = "Confirmar Promoción"
	add_child(confirm)
	confirm.popup_centered()
	
	var confirmed = await confirm.confirmed
	if not confirmed:
		confirm.queue_free()
		return
	
	confirm.queue_free()
	
	# Realizar promoción
	var promo_data = PromotionSystem.promote_unit(selected_unit)
	
	# Mostrar pantalla
	var screen = preload("res://scenes/promotion_screen.tscn").instantiate()
	add_child(screen)
	
	await screen.show_promotion(
		selected_unit,
		promo_data["old_class"],
		promo_data["new_class"],
		promo_data["bonuses"]
	)
	
	screen.queue_free()
	
	# Actualizar UI
	update_unit_details(selected_unit)
	update_unit_list()
	
	show_message("¡%s ha sido promocionado a %s!" % [
		selected_unit.unit_name,
		promo_data["new_class"]
	])
```

## 📊 Clases y Promociones Incluidas

```
CLASES BASE → CLASES PROMOCIONADAS

Lord → Master Lord
  HP+3, Str+2, Mag+1, Skl+2, Spd+2, Def+2, Res+2

Cavalier → Paladin
  HP+4, Str+2, Skl+2, Spd+2, Def+2, Res+1

Knight / Armor Knight → General
  HP+5, Str+3, Skl+2, Spd+1, Def+3, Res+2

Myrmidon → Swordmaster
  HP+3, Str+1, Skl+3, Spd+3, Lck+1, Def+1, Res+1

Fighter / Mercenary → Hero
  HP+4, Str+3, Skl+2, Spd+2, Def+2, Res+1

Soldier → Halberdier
  HP+4, Str+2, Skl+2, Spd+2, Def+2, Res+1

Archer → Sniper
  HP+3, Str+2, Skl+3, Spd+2, Def+1, Res+1

Mage → Sage
  HP+3, Mag+3, Skl+2, Spd+2, Def+1, Res+3

Priest / Cleric → Bishop
  HP+4, Mag+2, Skl+2, Spd+2, Lck+1, Def+1, Res+3

Pegasus Knight → Falcon Knight
  HP+3, Str+1, Mag+1, Skl+2, Spd+3, Lck+1, Def+1, Res+2

Wyvern Rider → Wyvern Lord
  HP+5, Str+3, Skl+2, Spd+2, Def+3, Res+1
```

## 🎨 Personalización

### Cambiar Colores

```gdscript
# En LevelUpScreen.gd
const STAT_GAIN_COLOR = Color(0.3, 1.0, 0.3)  # Verde
const STAT_NO_GAIN_COLOR = Color(0.7, 0.7, 0.7)  # Gris
const LEVEL_UP_COLOR = Color(1.0, 0.9, 0.5)  # Dorado

# En PromotionScreen.gd
@export var flash_color: Color = Color(1, 1, 1, 0.8)  # Blanco
```

### Ajustar Timings

```gdscript
# LevelUpScreen.gd
@export var stat_reveal_delay: float = 0.15  # Tiempo entre cada stat
@export var total_display_time: float = 3.0  # Tiempo total visible

# PromotionScreen.gd
@export var promotion_duration: float = 4.0  # Duración total
```

### Añadir Sonidos

```gdscript
# En LevelUpScreen.gd
func play_level_up_sound():
	sfx_player.stream = preload("res://assets/audio/sfx/level_up.wav")
	sfx_player.play()

func play_stat_gain_sound():
	sfx_player.stream = preload("res://assets/audio/sfx/stat_gain.wav")
	sfx_player.play()

# En PromotionScreen.gd
func play_promotion_sound():
	var sfx = AudioStreamPlayer.new()
	sfx.stream = preload("res://assets/audio/sfx/promotion.wav")
	add_child(sfx)
	sfx.play()
```

### Añadir Nuevas Promociones

```gdscript
# En PromotionScreen.gd, clase PromotionSystem
static var promotions = {
	# ... promociones existentes ...
	
	"Tu Clase": {
		"promoted_class": "Tu Clase Promocionada",
		"bonuses": {
			"hp": 4, "str": 2, "mag": 1, "skl": 2,
			"spd": 2, "lck": 0, "def": 2, "res": 1
		}
	}
}
```

## 🎯 Ejemplo de Flujo Completo

### Durante Combate

```gdscript
# Al final de una batalla
func on_battle_end():
	for unit in player_units:
		if unit.participated_in_battle:
			var exp_gained = calculate_exp(unit)
			await process_experience_gain(unit, exp_gained)

func process_experience_gain(unit: Unit, exp: int):
	unit.experience += exp
	
	# Mostrar barra de EXP aumentando (opcional)
	await show_exp_bar_animation(unit, exp)
	
	# Verificar level ups
	while unit.experience >= 100:
		unit.experience -= 100
		unit.level += 1
		
		# Calcular ganancias
		var gains = LevelUpScreen.calculate_stat_gains(unit, unit.growth_rates)
		LevelUpScreen.apply_stat_gains(unit, gains)
		
		# Mostrar pantalla
		await show_level_up(unit, gains)
		
		# Verificar promoción automática en nivel 20
		if unit.level == 20 and PromotionSystem.can_promote(unit):
			await prompt_promotion(unit)
```

### En el Castle

```gdscript
# Promoción manual en el castillo
func on_promote_unit(unit: Unit):
	if not PromotionSystem.can_promote(unit):
		return
	
	# Promocionar
	var promo_data = PromotionSystem.promote_unit(unit)
	
	# Mostrar animación
	await show_promotion(unit, promo_data)
	
	# Actualizar UI del castillo
	refresh_unit_list()
```

## 💡 Tips de Diseño

### 1. Balance de Growth Rates

```
Total recomendado: ~300-400 puntos

Clase física:
HP: 80, Str: 50, Skl: 50, Spd: 50, Def: 40, Res: 20 = 290

Clase mágica:
HP: 50, Mag: 60, Skl: 50, Spd: 50, Def: 20, Res: 50 = 280

Clase tanque:
HP: 90, Str: 60, Skl: 40, Spd: 30, Def: 60, Res: 20 = 300
```

### 2. Nivel de Promoción

```gdscript
# Opción 1: FE clásico - Nivel 20 fijo
if unit.level >= 20:
	can_promote = true

# Opción 2: FE moderno - Nivel 10+ con item
if unit.level >= 10 and has_promotion_item:
	can_promote = true
```

### 3. Caps de Stats

```gdscript
# Añadir caps para evitar stats excesivos
func apply_stat_gains(unit: Unit, gains: Dictionary):
	unit.max_hp = min(unit.max_hp + gains.get("hp", 0), 60)
	unit.strength = min(unit.strength + gains.get("str", 0), 30)
	unit.speed = min(unit.speed + gains.get("spd", 0), 30)
	# etc...
```

## 🐛 Troubleshooting

### Las pantallas no aparecen
- Verifica que las escenas estén en las rutas correctas
- Asegúrate de usar `await` al llamar a las funciones
- Comprueba que modulate.a no sea 0

### Las stats no se actualizan
- Llama a `apply_stat_gains()` antes de mostrar la pantalla
- Verifica que los growth_rates estén en el rango 0-100

### La animación se ve cortada
- Ajusta `stat_reveal_delay` y `total_display_time`
- Verifica que el panel tenga suficiente espacio

### Los sonidos no se reproducen
- Carga los archivos de audio en las rutas correctas
- Descomenta el código de reproducción

¡Tus pantallas de Level Up y Promoción están listas! ⭐
