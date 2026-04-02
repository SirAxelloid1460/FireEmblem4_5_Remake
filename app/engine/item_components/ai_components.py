from app.data.database.item_components import ItemComponent, ItemTags

class NoAI(ItemComponent):
    nid = 'no_ai'
    desc = "Adding this component prevents the AI from trying to use the item. This is important for sequence items, which the AI is unable to handle."
    tag = ItemTags.BASE

    def ai_priority(self, unit, item, target, move):
        return -1

    def ai_targets(self, unit, item) -> set:
        return set()
