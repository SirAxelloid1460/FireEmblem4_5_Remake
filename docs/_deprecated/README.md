# Código en cuarentena (redundante)

Estos archivos se retiraron del proyecto activo el **2026-06-03** al unificar la
redundancia de UI de castillo. Tienen extensión `.gd.txt` para que **Godot los
ignore** (no se compilan), pero quedan recuperables (el proyecto no es repo git).

## Decisión

Existían **dos familias paralelas** de UI de castillo:

- **Canónica (se conserva):** `CastleBase` + `castle_base.tscn` + set **`*Panel`**
  (`ShopPanel`, `ArenaPanel`, `ConvoyPanel`, `BlacksmithPanel`, `FortuneTellerPanel`,
  `PromotionPanel`). Es lo documentado en `CASTLE_README.md` y el flujo
  `MainMenu → CastleBase → load_chapter()`.
- **Redundante (aquí):** `CastlePreparation` + set **`*Menu`**. Más rica en lógica en
  algunos puntos, pero sin escena ni enganche al flujo del juego, y usaba el modelo de
  oro individual (`personal_gold`) que está **abandonado** (el oro es pool global `party_gold`).

## Lógica portada antes de retirar

- `FortuneTellerMenu.get_growth_rates` (tablas de growth) → **portado** a `FortuneTellerPanel`.
- `PromotionPanel.get_promotion_data` ahora delega en `PromotionSystem` (fuente única;
  se eliminó la tabla de promociones duplicada del panel).
- `ShopMenu`: sin lógica única que valiera la pena (ShopPanel tiene más items y usa oro global).

## Archivos

| Archivo | Reemplazado por |
|---|---|
| CastlePreparation.gd.txt | `CastleBase.gd` |
| UnitListPanel / LocationMenu / PreparationMenu / InfoPopup .gd.txt | (sub-paneles de CastlePreparation) |
| UnitManagerMenu.gd.txt | (era de CastlePreparation; creado para el bloqueador #4) |
| ShopMenu.gd.txt | `ShopPanel.gd` |
| ArenaMenu.gd.txt / CastleArenaPanel.gd.txt | `ArenaPanel.gd` (FE4) |
| ConvoyMenu.gd.txt | `ConvoyPanel.gd` + `ConvoySystem.gd` |
| BlacksmithMenu.gd.txt | `BlacksmithPanel.gd` |
| FortuneTellerMenu.gd.txt | `FortuneTellerPanel.gd` |
| PromotionMenu.gd.txt | `PromotionPanel.gd` + `PromotionSystem.gd` |

## Pendiente (no bloqueante)

- Los nodos `*Panel` de `castle_base.tscn` son placeholders vacíos: falta construir su
  estructura interna de nodos y asignarles el script para que queden funcionales.
- `PromotionMenu` tenía **promociones ramificadas** (varias opciones por clase). Si se
  quiere esa feature, hay que ampliar `PromotionSystem` (hoy es single-path) y recuperarla de aquí.
