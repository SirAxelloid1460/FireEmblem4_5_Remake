from app.utilities import str_utils
from app.utilities.data import Data
from app.data.database.database import DB

from app.extensions.custom_gui import ComboBox, PropertyBox, DeletionDialog
from app.extensions.list_dialogs import MultiAttrListDialog
from app.extensions.list_models import MultiAttrListModel

from app.data.database.supports import SupportRank

class SupportRankMultiModel(MultiAttrListModel):
    def delete(self, idx):
        # Check to make sure nothing else is using this rank
        element = DB.support_ranks[idx]
        affected_affinities = [affinity for affinity in DB.affinities if
                               any(bon.support_rank == element.nid for bon in affinity.bonus)]
        affected_support_pairs = [support_pair for support_pair in DB.support_pairs if
                                  any(req.support_rank == element.nid for req in support_pair.requirements)]
        if affected_affinities or affected_support_pairs:
            if affected_affinities:
                affected = Data(affected_affinities)
                from app.editor.support_editor.affinity_model import AffinityModel
                model = AffinityModel
            elif affected_support_pairs:
                affected = Data(affected_support_pairs)
                from app.editor.support_editor.support_pair_model import SupportPairModel
                model = SupportPairModel
            msg = "Deleting Support Rank <b>%s</b> would affect these objects." % element.nid
            combo_box = PropertyBox("Support Rank", ComboBox, self.window)
            objs = [rank for rank in DB.support_ranks if rank.nid != element.nid]
            combo_box.edit.addItems([rank.nid for rank in objs])
            obj_idx, ok = DeletionDialog.get_simple_swap(affected, model, msg, combo_box)
            if ok:
                swap = objs[obj_idx]
                for affinity in affected_affinities:
                    affinity.bonus.swap_rank(element.nid, swap.nid)
                for support_pair in affected_support_pairs:
                    support_pair.requirements.swap_rank(element.nid, swap.nid)
            else:
                return
        super().delete(idx)

    def create_new(self):
        nids = DB.support_ranks.keys()
        nid = str_utils.get_next_name("Support Rank", nids)
        new_support_rank = SupportRank(nid)
        DB.support_ranks.append(new_support_rank)
        return new_support_rank

    def on_attr_changed(self, data, attr, old_value, new_value):
        if attr == 'nid':
            self._data.update_nid(data, new_value)
            for affinity in DB.affinities:
                affinity.bonus.swap_rank(old_value, new_value)
            for support_pair in DB.support_pairs:
                support_pair.requirements.swap_rank(old_value, new_value)

class SupportRankDialog(MultiAttrListDialog):
    @classmethod
    def create(cls):
        def deletion_func(model, index):
            return model.rowCount() > 1

        return cls(DB.support_ranks, "Support Rank",
                   ("nid",), SupportRankMultiModel, (deletion_func, None, None))
