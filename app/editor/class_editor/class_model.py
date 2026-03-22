from PyQt5.QtGui import QIcon, QPixmap
from PyQt5.QtCore import Qt

from app.data.resources.resources import RESOURCES

from app.utilities.data import Data
from app.data.database.database import DB

from app.extensions.custom_gui import DeletionDialog

from app.editor import timer

from app.editor.custom_widgets import ClassBox
from app.editor.base_database_gui import DragDropCollectionModel
from app.editor.map_sprite_editor import map_sprite_model
from app.editor.combat_animation_editor import combat_animation_model

from app.data.database import klass

from app.utilities import str_utils

def get_map_sprite_icon(klass_obj, num=0, current=False, team='player', variant=None):
    res = None
    if variant:
        res = RESOURCES.map_sprites.get(klass_obj.map_sprite_nid + variant)
    if not variant or not res:
        res = RESOURCES.map_sprites.get(klass_obj.map_sprite_nid)
    if not res:
        return None
    if not res.standing_pixmap:
        res.standing_pixmap = QPixmap(res.stand_full_path)
    pixmap = res.standing_pixmap
    pixmap = map_sprite_model.get_basic_icon(pixmap, num, current, team)
    return pixmap

def get_combat_anim_icon(klass_obj):
    if not klass_obj.combat_anim_nid:
        return None
    return combat_animation_model.get_combat_anim_icon(klass_obj.combat_anim_nid)

class ClassModel(DragDropCollectionModel):
    display_team = 'player'

    def data(self, index, role):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole:
            klass = self._data[index.row()]
            text = klass.nid
            return text
        elif role == Qt.DecorationRole:
            klass = self._data[index.row()]
            num = timer.get_timer().passive_counter.count
            if hasattr(self.window, 'view') and self.window.view:
                active = index == self.window.view.currentIndex()
            else:
                active = False
            pixmap = get_map_sprite_icon(klass, num, active, self.display_team)
            if pixmap:
                return QIcon(pixmap)
            else:
                return None
        return None

    def delete(self, idx):
        # check to make sure nothing else is using me!!!
        klass = self._data[idx]
        nid = klass.nid
        affected_units = [unit for unit in DB.units if unit.klass == nid]
        affected_classes = [k for k in DB.classes if k.promotes_from == nid or nid in k.turns_into]
        affected_ais = [ai for ai in DB.ai if ai.has_unit_spec("Class", nid)]
        affected_levels = [level for level in DB.levels if any(unit.klass == nid for unit in level.units)]
        if affected_units or affected_classes or affected_ais or affected_levels:
            if affected_units:
                affected = Data(affected_units)
                from app.editor.unit_editor.unit_model import UnitModel
                model = UnitModel
            elif affected_classes:
                affected = Data(affected_classes)
                model = ClassModel
            elif affected_ais:
                affected = Data(affected_ais)
                from app.editor.ai_editor.ai_model import AIModel
                model = AIModel
            elif affected_levels:
                affected = Data(affected_levels)
                from app.editor.global_editor.level_menu import LevelModel
                model = LevelModel
            msg = "Deleting Class <b>%s</b> would affect these objects" % nid
            swap, ok = DeletionDialog.get_swap(affected, model, msg, ClassBox(self.window, exclude=klass), self.window)
            if ok:
                self.on_nid_changed(nid, swap.nid)
            else:
                return
        # Delete watchers
        super().delete(idx)

    def on_nid_changed(self, old_nid, new_nid):
        if not new_nid:
            return
        for unit in DB.units:
            if unit.klass == old_nid:
                unit.klass = new_nid
        for k in DB.classes:
            if old_nid and k.promotes_from == old_nid:
                k.promotes_from = new_nid
            k.turns_into = [new_nid if elem == old_nid else elem for elem in k.turns_into]
        for ai in DB.ai:
            ai.change_unit_spec("Class", old_nid, new_nid)
        for level in DB.levels:
            for unit in level.units:
                if unit.klass == old_nid:
                    unit.klass = new_nid

    def create_new(self):
        nids = [d.nid for d in self._data]
        nid = name = str_utils.get_next_name("New Class", nids)
        movement_group = DB.mcost.unit_types[0]
        bases = {k: 0 for k in DB.stats.keys()}
        growths = {k: 0 for k in DB.stats.keys()}
        growth_bonus = {k: 0 for k in DB.stats.keys()}
        promotion = {k: 0 for k in DB.stats.keys()}
        max_stats = {stat.nid: stat.maximum for stat in DB.stats}
        wexp_gain = {weapon_nid: DB.weapons.default() for weapon_nid in DB.weapons.keys()}
        new_class = klass.Klass(
            nid, name, "", 1, movement_group, None, [], [], 20,
            bases, growths, growth_bonus, promotion, max_stats,
            [], wexp_gain)
        new_class.fields = []
        DB.classes.append(new_class)
        return new_class
