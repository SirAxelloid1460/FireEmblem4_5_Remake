import unittest

from app.constants import WINHEIGHT, WINWIDTH

from ..premade_components.icon_row import IconRow
from ..ui_framework import UIComponent
from .image_comparator import (EXPECTED_DIRECTORY, OUTPUT_DIRECTORY,
                               images_equal, save)


class IconRowUnitTests(unittest.TestCase):
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
        import pygame
        self.testing_string = "Pegasus Knight"
        self.testing_icon = pygame.Surface((16, 16))
        self.testing_icon.fill(pygame.Color(255, 0,0, 255))
        self.comp = IconRow('iconrow', None, text=self.testing_string)
        self.comp.set_icon(self.testing_icon)
        self.comp.to_surf()

    def test_caches_properly(self):
        self.assertEqual(self.comp._total_to_surfs, 3)
        self.comp.to_surf()
        self.assertEqual(self.comp._total_to_surfs, 3)

    def test_text_change(self):
        # should not redraw if text hasn't changed
        self.assertEqual(self.comp.should_redraw(), False)
        self.comp.set_text(self.testing_string)
        self.assertEqual(self.comp.should_redraw(), False)

        # should redraw if text has changed
        self.comp.set_text('lol')
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)
        self.comp.to_surf()
        self.assertEqual(self.comp._total_to_surfs, 5)

    def test_output(self):
        ICON_ROW_NAME = 'IconRowTest_output_test.png'
        save(self.comp.to_surf(), ICON_ROW_NAME)
        self.assertTrue(images_equal(ICON_ROW_NAME))

    def test_text_row_only(self):
        ncomp = IconRow('ironcrow', None, text='testing string')
        ncomp.to_surf()
        self.assertEqual(ncomp._total_to_surfs, 3)

if __name__ == '__main__':
    unittest.main()
