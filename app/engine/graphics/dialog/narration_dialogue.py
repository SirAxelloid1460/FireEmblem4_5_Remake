from __future__ import annotations
from app.engine.sound import get_sound_thread
import app.engine.graphics.ui_framework as uif
from app.engine import engine

from typing import List, TYPE_CHECKING, Tuple
from app.constants import COLORKEY, WINHEIGHT

if TYPE_CHECKING:
    from app.engine.engine import Surface

from app.engine.sprites import SPRITES
from app.engine import config as cf

class NarrationDialogue(uif.UIComponent):
    def __init__(self, name: str, parent: uif.UIComponent = None, anim_duration: int = 3000):
        super().__init__(name=name, parent=parent)
        self.anim_duration = anim_duration

        self.queued_text: List[Tuple[str, str]] = []
        self.acknowledged: bool = False

        # TODO This should be configurable instead of magic number
        self.text_vertical_offset = 35
        self.text_horizontal_area = 200
        self.text_horizontal_margin = 20

        # initialize the animated top bar and bottom text area
        # create the box sprite
        narration_window_sprite: Surface = SPRITES.get('narration_window').convert()
        top_height = narration_window_sprite.get_height() // 2
        bottom_height = narration_window_sprite.get_height() - top_height
        width = narration_window_sprite.get_width()

        top_sprite = engine.subsurface(narration_window_sprite, (0, 0, width, top_height))
        bottom_sprite = engine.subsurface(narration_window_sprite, (0, top_height, width, bottom_height))
        engine.set_colorkey(top_sprite, COLORKEY)
        engine.set_colorkey(bottom_sprite, COLORKEY)

        self.top_bar: uif.UIComponent = uif.UIComponent.from_existing_surf(top_sprite)
        self.top_bar.props.v_alignment = uif.VAlignment.TOP
        self.top_bar.name = 'narration_window_top_bar'

        self.bot_text_area: uif.UIComponent = uif.UIComponent.from_existing_surf(bottom_sprite)
        self.bot_text_area.props.v_alignment = uif.VAlignment.BOTTOM
        self.bot_text_area.name = 'narration_window_bot_area'

        self._init_textbox_animations()

        # initialize the text component
        self.text: uif.DialogTextComponent = uif.DialogTextComponent('narration_text')
        self.text.props.max_width = self.text_horizontal_area
        self.text.margin = (self.text_horizontal_margin, self.text_horizontal_margin, self.text_vertical_offset, 0)

        self._init_text_animations()

        self.bot_text_area.add_child(self.text)

        self.add_child(self.top_bar)
        self.add_child(self.bot_text_area)

    def _init_textbox_animations(self):
        anim_duration = self.anim_duration
        fade_out = uif.fade_anim(1, 0.2, anim_duration, True, uif.InterpolationType.LOGARITHMIC, skew=0.1)
        fade_in = uif.fade_anim(0.2, 1, anim_duration, False, uif.InterpolationType.LOGARITHMIC, skew=3)

        log_interp = uif.InterpolationType.LOGARITHMIC
        translate_offscreen_down = \
            uif.translate_anim((0, 0), (0, WINHEIGHT/2), disable_after=True, duration=anim_duration, interp_mode=log_interp, skew=0.1) + fade_out
        translate_onscreen_up = \
            uif.translate_anim((0, WINHEIGHT/2), (0, 0), duration=anim_duration, interp_mode=log_interp, skew=3) + fade_in

        translate_offscreen_up = \
            uif.translate_anim((0, 0), (0, -WINHEIGHT/2), disable_after=True, duration=anim_duration, interp_mode=log_interp, skew=0.1) + fade_out
        translate_onscreen_down = \
            uif.translate_anim((0, -WINHEIGHT/2), (0, 0), duration=anim_duration, interp_mode=log_interp, skew=3) + fade_in

        self.top_bar.save_animation(translate_offscreen_up, '!exit')
        self.top_bar.save_animation(translate_onscreen_down, '!enter')

        self.bot_text_area.save_animation(translate_offscreen_down, '!exit')
        self.bot_text_area.save_animation(translate_onscreen_up, '!enter')

    def _init_text_animations(self):
        # init dialogue sound 'anim'
        def play_sound(c: uif.DialogTextComponent, anim_time, delta_time):
            play_sound.time_since_last_sound += delta_time
            if cf.SETTINGS['talk_boop'] and play_sound.time_since_last_sound > 32:
                play_sound.time_since_last_sound = 0
                get_sound_thread().play_sfx('Talk_Boop')

        play_sound.time_since_last_sound = 0

        dialog_sound = uif.UIAnimation(do_anim=play_sound)

        write_line = uif.type_line_anim(time_per_char=25) + dialog_sound
        self.text.save_animation(write_line, 'play_text')

    def write_next_line(self):
        if self.done_writing_current_text() and not self.done_writing_all_text():
            # done with current line, load next line
            self.push_text(*self.queued_text.pop(0))
        elif self.done_writing_current_text() and self.done_writing_all_text():
            # we're waiting on player acknowledgement to continue
            self.acknowledged = True
            self.text.set_should_draw_cursor(False)
        else:
            # write the next part of the current line
            self.text.queue_animation(names=['play_text'])

    def push_text(self, narrator: str, text: str):
        self.acknowledged = False
        self.text.set_should_draw_cursor(True)
        if not self.done_writing_current_text():
            self.queued_text.append((narrator, text))
        else:
            self.text.set_text(text)
            self.text.set_number_visible_chars(0)
            self.text.queue_animation(names=['play_text'])

    def hurry_up(self, event):
        if self.enabled:
            if event == 'SELECT' or event == 'RIGHT' or event == 'DOWN':
                # text is currently writing
                if not self.text_is_waiting():
                    # skip to the end
                    self.text.skip_next_animation()
                # text is at a wait point
                elif self.text_is_waiting():
                    # queue next line
                    self.write_next_line()

    def text_is_waiting(self) -> bool:
        """Is the dialogue box currently waiting for a go-ahead?
        """
        return self.text.is_waiting()

    def done_writing_current_text(self) -> bool:
        """Has the dialogue box finished its current text?
        """
        return self.text.is_done() and not self.text.is_animating()

    def done_writing_all_text(self) -> bool:
        """has the dialogue box finished all queued text?
        """
        return self.done_writing_current_text() and len(self.queued_text) == 0

    def finished(self) -> bool:
        return self.done_writing_all_text() and self.acknowledged

    # testing
    def write_a_line(self):
        text = (
            '"Lorem ipsum dolor sit amet, consectetur adipiscing elit, {w}'
            'sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. {w}'
            'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris {w}'
            'nisi ut aliquip ex ea commodo consequat.'
        )
        self.push_text(text)

    def to_surf(self, no_cull=False, should_not_cull_on_redraw=True) -> engine.Surface:
        return super().to_surf(no_cull=no_cull, should_not_cull_on_redraw=should_not_cull_on_redraw)