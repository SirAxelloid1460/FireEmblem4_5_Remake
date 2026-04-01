import os
import unittest
from random import randint

from app.constants import WINHEIGHT, WINWIDTH

from ..premade_animations.text_animations import (scroll_anim,
                                                  scroll_to_next_line_anim,
                                                  type_line_anim)
from ..premade_components.dialog_text_component import DialogTextComponent
from ..premade_components.plain_text_component import (PlainTextComponent,
                                                       PlainTextLine)
from ..ui_framework import UIComponent
from .image_comparator import (EXPECTED_DIRECTORY, OUTPUT_DIRECTORY,
                               images_equal)


class PlainTextLineTests(unittest.TestCase):
    def ASSERT_REDRAW_AND_RESET(self, comp: UIComponent, val: bool):
        self.assertEqual(comp.should_redraw(), val)
        comp.to_surf()
        # assert that we should never need to redraw after a render
        self.assertEqual(comp.should_redraw(), False)

    @classmethod
    def setUpClass(cls) -> None:
        import pygame
        pygame.init()
        screen = pygame.display.set_mode((WINWIDTH * 2, WINHEIGHT * 2))
        tmp_surf = pygame.Surface((WINWIDTH, WINHEIGHT))
        clock = pygame.time.Clock()

    def setUp(self):
        self.testing_string = "22 chars in this line."
        self.comp = PlainTextLine('line', None, self.testing_string)
        self.comp.to_surf()

    def test_text_change(self):
        # should not redraw if text hasn't changed
        self.assertEqual(self.comp.should_redraw(), False)
        self.comp.set_text(self.testing_string)
        self.assertEqual(self.comp.should_redraw(), False)

        # should redraw if text has changed
        self.comp.set_text('lol')
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)

    def test_font_change(self):
        self.comp.set_font_name('text-brown')
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)

    def test_multiple_draws(self):
        for i in range(randint(52, 100)):
            self.comp.to_surf()
        self.assertEqual(self.comp._times_drawn, 1)

    def test_multiple_draws_2(self):
        for i in range(randint(52, 100)):
            self.comp.to_surf()
        self.comp.set_text('lol')
        for i in range(randint(22, 265)):
            self.comp.to_surf()
        self.assertEqual(self.comp._times_drawn, 2)

    def test_output_image_identical(self):
        import pygame
        TEST_OUTPUT_FILE_NAME = 'PlainTextLine_test_output_image_identical.png'
        pygame.image.save(self.comp.to_surf(), os.path.join(OUTPUT_DIRECTORY, TEST_OUTPUT_FILE_NAME))
        self.assertEqual(images_equal(TEST_OUTPUT_FILE_NAME), True)

class PlainTextComponentTests(unittest.TestCase):
    def ASSERT_REDRAW_AND_RESET(self, comp: UIComponent, val: bool):
        self.assertEqual(comp.should_redraw(), val)
        comp.to_surf()
        # assert that we should never need to redraw after a render
        self.assertEqual(comp.should_redraw(), False)

    @classmethod
    def setUpClass(cls) -> None:
        import pygame
        pygame.init()
        screen = pygame.display.set_mode((WINWIDTH * 2, WINHEIGHT * 2))
        tmp_surf = pygame.Surface((WINWIDTH, WINHEIGHT))
        clock = pygame.time.Clock()

    def setUp(self):
        self.testing_string = ("Lorem ipsum dolor sit amet, consectetur adipiscing elit, "
                               "sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
                               "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris"
                               "nisi ut aliquip ex ea commodo consequat.")
        self.comp = PlainTextComponent('line', None, self.testing_string)
        self.comp.to_surf()

    def test_text_change(self):
        # should not redraw if text hasn't changed
        self.assertEqual(self.comp.should_redraw(), False)
        self.comp.set_text(self.testing_string)
        self.assertEqual(self.comp.should_redraw(), False)

        # should redraw if text has changed
        self.comp.set_text('lol')
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)

    def test_font_change(self):
        self.comp.set_font_name('text-brown')
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)

    def test_multiple_draws(self):
        for i in range(randint(52, 100)):
            self.comp.to_surf()
        self.assertEqual(self.comp._total_to_surfs, 6)

    def test_multiple_draws_2(self):
        # expect 6 to_surfs - five textlines and one textbox
        for i in range(randint(52, 100)):
            self.comp.to_surf()
        self.assertEqual(self.comp._total_to_surfs, 6)
        # expect 3 - drew the new line and box again, plus one from the box's previous draw
        self.comp.set_text('lol')
        for i in range(randint(22, 265)):
            self.comp.to_surf()
        self.assertEqual(self.comp._total_to_surfs, 3)
        self.assertEqual(len(self.comp.children), 1)

    def test_changing_visible_chars(self):
        self.comp.set_number_visible_chars(60) # stops after 'elit, sed', which is 2 lines
        self.comp.to_surf()
        # expect 11 to_surfs. 6 from before, and we redraw lines 2 (incomplete line), 3-5 (now blank)
        # and of course, redraw the text box.
        self.assertEqual(self.comp._total_to_surfs, 11)
        # make sure it looks right
        import pygame
        VISIBLE_CHARS_TEST_FILE_NAME = 'PlainTextComponent_test_output_visible_chars_test.png'
        pygame.image.save(self.comp.to_surf(), os.path.join(OUTPUT_DIRECTORY, VISIBLE_CHARS_TEST_FILE_NAME))
        self.assertEqual(images_equal(VISIBLE_CHARS_TEST_FILE_NAME), True)

    def test_scrolling(self):
        long_testing_string = ("Lorem ipsum dolor sit amet, consectetur adipiscing elit, "
                               "sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
                               "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris"
                               "nisi ut aliquip ex ea commodo consequat1."
                               "Lorem ipsum dolor sit amet, consectetur adipiscing elit, "
                               "sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
                               "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris"
                               "nisi ut aliquip ex ea commodo consequat2."
                               "Lorem ipsum dolor sit amet, consectetur adipiscing elit, "
                               "sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
                               "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris"
                               "nisi ut aliquip ex ea commodo consequat3.")
        long_comp = PlainTextComponent('line', None, long_testing_string)
        long_comp.to_surf()
        long_comp.set_scroll_height(2)
        import pygame
        SCROLLING_TEXT_TEST_FILE_NAME = 'PlainTextComponent_test_output_scroll_test.png'
        pygame.image.save(long_comp.to_surf(), os.path.join(OUTPUT_DIRECTORY, SCROLLING_TEXT_TEST_FILE_NAME))
        self.assertEqual(images_equal(SCROLLING_TEXT_TEST_FILE_NAME), True)

        long_comp.set_scroll_height('100%')
        SCROLL_TEXT_STR_TEST_FILE_NAME = 'PlainTextComponent_test_output_scroll_str_test.png'
        pygame.image.save(long_comp.to_surf(), os.path.join(OUTPUT_DIRECTORY, SCROLL_TEXT_STR_TEST_FILE_NAME))
        self.assertEqual(images_equal(SCROLL_TEXT_STR_TEST_FILE_NAME), True)

class DialogTextComponentTests(unittest.TestCase):
    def ASSERT_REDRAW_AND_RESET(self, comp: UIComponent, val: bool):
        self.assertEqual(comp.should_redraw(), val)
        comp.to_surf()
        # assert that we should never need to redraw after a render
        self.assertEqual(comp.should_redraw(), False)

    @classmethod
    def setUpClass(cls) -> None:
        import pygame
        pygame.init()
        screen = pygame.display.set_mode((WINWIDTH * 2, WINHEIGHT * 2))
        tmp_surf = pygame.Surface((WINWIDTH, WINHEIGHT))
        clock = pygame.time.Clock()

    def setUp(self):
        self.testing_string = ('Lorem ipsum dolor sit amet, consectetur adipiscing elit, {w}'
            'sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. {w}'
            'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris {w}'
            'nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in {w}'
            'reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla{w}'
            'pariatur. Excepteur sint occaecat cupidatat non proident, sunt in {w}'
            'culpa qui officia deserunt mollit anim id est laborum.{w}')
        self.comp = DialogTextComponent('line', None, self.testing_string)
        self.comp.to_surf()

    def test_text_break(self):
        # should not redraw if text hasn't changed
        self.assertEqual(self.comp.should_redraw(), False)
        self.comp.set_text(self.testing_string)
        self.assertEqual(self.comp.should_redraw(), False)

    def test_scroll_not_redraw(self):
        times_drawn_at_start = self.comp._total_to_surfs
        self.assertEqual(times_drawn_at_start, 10) # 9 lines and the component itself

        self.comp.num_visible_chars = len(self.testing_string)
        self.comp.to_surf()
        times_drawn_after_changing_visible = self.comp._total_to_surfs
        self.assertEqual(times_drawn_after_changing_visible, 20) # we redrew the entire thing

        self.comp.set_scroll_height(5)
        self.comp.to_surf()
        times_drawn_after_scroll = self.comp._total_to_surfs
        self.assertEqual(times_drawn_after_scroll, 20) # scroll uses cache

if __name__ == '__main__':
    unittest.main()
