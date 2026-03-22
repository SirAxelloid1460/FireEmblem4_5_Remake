import unittest

from app.constants import WINHEIGHT, WINWIDTH
from app.engine import engine

from ..ui_framework import UIComponent
from ..ui_framework_layout import HAlignment, VAlignment

class UIComponentTests(unittest.TestCase):
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
        self.comp = UIComponent('testing_component', None)
        self.comp.to_surf()

    def test_initialization(self):
        init_comp = UIComponent('component', None)
        # default size should be screensize
        self.assertEqual(init_comp.size, (WINWIDTH, WINHEIGHT))
        # should need to redraw at the beginning
        self.ASSERT_REDRAW_AND_RESET(init_comp, True)
        # after drawing once, should have a cached surf and will no longer redraw
        self.assertEqual(init_comp.should_redraw(), False)
        self.assertNotEqual(init_comp._cached_surf, None)

    def test_change_size(self):
        # after changing size, should redraw
        self.comp.size = (200, 200)
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)
        # if changing size to the same thing, should not redraw
        self.comp.size = (200, 200)
        self.ASSERT_REDRAW_AND_RESET(self.comp, False)
        # and again
        self.comp.size = (150, 150)
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)

    def test_scroll_offset_margin(self):
        # after changing scroll or offset or margin, component should NOT redraw
        # but its parent component should
        child_comp = UIComponent('testing_component', None)
        child_comp.to_surf()

        self.comp.add_child(child_comp)

        child_comp.scroll = (10, 10)
        self.ASSERT_REDRAW_AND_RESET(child_comp, False)
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)
        child_comp.offset = (10, 10)
        self.ASSERT_REDRAW_AND_RESET(child_comp, False)
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)

        child_comp.margin = (0, 0, 1, 1)
        self.ASSERT_REDRAW_AND_RESET(child_comp, False)
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)

    def test_max_dims(self):
        self.comp.max_height = 50
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)
        self.comp.max_height = 50
        self.ASSERT_REDRAW_AND_RESET(self.comp, False)

        self.comp.max_width = 50
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)
        self.comp.max_width = 50
        self.ASSERT_REDRAW_AND_RESET(self.comp, False)

    def test_bg_color(self):
        self.comp.props.bg_color = (25, 25, 25, 25)
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)
        self.comp.props.bg_color = (25, 25, 25, 25)
        self.ASSERT_REDRAW_AND_RESET(self.comp, False)

    def test_alignment(self):
        # aligment should affect the parent, but the component itself
        # should not redraw
        self.comp.props.h_alignment = HAlignment.RIGHT
        self.ASSERT_REDRAW_AND_RESET(self.comp, False)

        self.comp.props.v_alignment = VAlignment.CENTER
        self.ASSERT_REDRAW_AND_RESET(self.comp, False)

    def test_bg(self):
        self.comp.props.bg = engine.create_surface((1, 1), False)
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)

    def test_bg_align(self):
        self.comp.props.bg_align = (HAlignment.LEFT, VAlignment.BOTTOM)
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)
        self.comp.props.bg_align = (HAlignment.LEFT, VAlignment.BOTTOM)
        self.ASSERT_REDRAW_AND_RESET(self.comp, False)

    def test_overflow(self):
        self.comp.overflow = (0, 0, 1, 1)
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)
        self.comp.overflow = (0, 0, 1, 1)
        self.ASSERT_REDRAW_AND_RESET(self.comp, False)

    def test_padding(self):
        self.comp.padding = (0, 0, 1, 1)
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)
        self.comp.padding = (0, 0, 1, 1)
        self.ASSERT_REDRAW_AND_RESET(self.comp, False)

    def test_opacity(self):
        self.comp.props.opacity = 0.5
        self.ASSERT_REDRAW_AND_RESET(self.comp, True)
        self.comp.props.opacity = 0.5
        self.ASSERT_REDRAW_AND_RESET(self.comp, False)

if __name__ == '__main__':
    unittest.main()
