import time

from pygame import Surface
from ..premade_components import PlainTextComponent
from ...ui_framework import *
from ..ui_framework_animation import *
from ..ui_framework_layout import *
from ..ui_framework_styling import *
from ..premade_components import *
from ..premade_animations import *

TILEWIDTH, TILEHEIGHT = 16, 16
TILEX, TILEY = 15, 10
WINWIDTH, WINHEIGHT = TILEX * TILEWIDTH, TILEY * TILEHEIGHT

def current_milli_time():
    return round(time.time() * 1000)

class DialogLogDemo(UIComponent):
    def __init__(self, name: str = None, parent: UIComponent = None):
        super().__init__(name=name, parent=parent)
        self.layout_handler = UILayoutHandler(self)
        self.props.layout = UILayoutType.LIST
        self.props.list_style = ListLayoutStyle.COLUMN
        self.props.bg_color = (128, 128, 128, 128)

        self.text_objects: List[PlainTextComponent] = []

        self._init_animations()

    def _init_animations(self):
        scroll_all_the_way = component_scroll_anim(('0%', '0%'), ('0%','100%'), 3000)
        self.save_animation(scroll_all_the_way, 'scroll_all')

    def add_dialogue(self, name, dialog):
        dialog_name = PlainTextComponent('name', None, text=name)
        dialog_name.max_width = '100%'
        dialog_text = PlainTextComponent('text', None, text=dialog)
        dialog_text.max_width = '100%'
        self.text_objects.append(dialog_name)
        self.text_objects.append(dialog_text)
        self.add_child(dialog_name)
        self.add_child(dialog_text)

    def scroll_up_down(self, dist):
        self.scroll = (self.scroll[0], self.scroll[1] + dist)

    def scroll_all(self):
        self.queue_animation(names=['scroll_all'])

    def _reset(self, reason):
        if reason == 'height':
            return
        # Recalculates our own height
        # this automatically triggers whenever we add a child
        self_height = 0
        for text in self.text_objects:
            text_height = text.height
            self_height += text_height
        self.height = max(self_height, self.parent.height)


class ScrollUI():
    def __init__(self):
        self.dialog_log = DialogLogDemo('dialog')
        self.dialog_log.add_dialogue("Eirika", "If it were done when 'tis done, then 'twere well")
        self.dialog_log.add_dialogue("Seth", "It were done quickly: if the assassination")
        self.dialog_log.add_dialogue("Eirika", "Could trammel up the consequence, and catch")
        self.dialog_log.add_dialogue("Seth", "With his surcease success; that but this blow")
        self.dialog_log.add_dialogue("Eirika", "Might be the be-all and the end-all here,")
        self.dialog_log.add_dialogue("Seth", "But here, upon this bank and shoal of time,")
        self.dialog_log.add_dialogue("Eirika", "We'ld jump the life to come. But in these cases")
        self.dialog_log.add_dialogue("Seth", "We still have judgment here; that we but teach")

        self.base_component = UIComponent.create_base_component(WINWIDTH, WINHEIGHT)
        self.base_component.add_child(self.dialog_log)
        self.base_component.name = "base"
        self.base_component.set_chronometer(current_milli_time)

    def scroll_up(self):
        self.dialog_log.scroll_up_down(-10)

    def scroll_down(self):
        self.dialog_log.scroll_up_down(10)

    def scroll_all(self):
        self.dialog_log.scroll_all()

    def draw(self, surf: Surface) -> Surface:
        ui_surf = self.base_component.to_surf()
        surf.blit(ui_surf, (0, 0))
        return surf