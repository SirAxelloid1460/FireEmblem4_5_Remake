from dataclasses import dataclass
from typing import Dict, Optional, Tuple
from functools import lru_cache

from app.engine import engine

@dataclass
class CharGlyph():
    """Class representing a char position and dimension on the sheet"""
    x: int
    y: int
    char_width: int

class BmpFont():
    def __init__(self, png_path: str, idx_path: str, default_color: str = 'default'):
        self.all_uppercase = False
        self.all_lowercase = False
        self.stacked = False
        self.chartable: Dict[str, CharGlyph] = {}
        self.idx_path = idx_path
        self.png_path = png_path
        self.space_offset = 0
        self._width = 8
        self.height = 16
        self.memory: Dict[str, Dict[str, Tuple[engine.Surface, int]]] = {}

        with open(self.idx_path, 'r', encoding='utf-8') as fp:
            for x in fp.readlines():
                words = x.strip().split()
                if words[0] == 'alluppercase':
                    self.all_uppercase = True
                elif words[0] == 'alllowercase':
                    self.all_lowercase = True
                elif words[0] == 'stacked':
                    self.stacked = True
                elif words[0] == 'space_offset':
                    self.space_offset = int(words[1])
                elif words[0] == "width":
                    self._width = int(words[1])
                elif words[0] == "height":
                    self.height = int(words[1])
                else:  # Default to index entry.
                    if words[0] == "space":
                        words[0] = ' '
                    if self.all_uppercase:
                        words[0] = words[0].upper()
                    if self.all_lowercase:
                        words[0] = words[0].lower()
                    self.chartable[words[0]] = CharGlyph(int(words[1]) * self._width,
                                                         int(words[2]) * self.height,
                                                         int(words[3]))

        self.default_color = default_color
        self.surfaces: Dict[str, engine.Surface] = {}
        self.surfaces[default_color] = engine.image_load(self.png_path)
        # engine.set_colorkey(self.surface, (0, 0, 0), rleaccel=True)

    def modify_string(self, string: str) -> str:
        if self.all_uppercase:
            string = string.upper()
        if self.all_lowercase:
            string = string.lower()
        # string = string.replace('_', ' ')
        return string

    @lru_cache()
    def _get_char_from_surf(self, c: str, color: str = None) -> Tuple[engine.Surface, int]:
        if not color:
            color = self.default_color
        if c not in self.chartable:
            cx, cy, cwidth = 0, 0, 8
            print("unknown char: %s" % c)
        else:
            c_info = self.chartable[c]
            cx, cy, cwidth = c_info.x, c_info.y, c_info.char_width
        base_surf = self.surfaces.get(color, self.surfaces['default'])
        char_surf = engine.subsurface(base_surf, (cx, cy, self._width, self.height))
        return (char_surf, cwidth)

    @lru_cache()
    def _get_stacked_char_from_surf(self, c: str, color: str = None) -> Tuple[engine.Surface, engine.Surface, int]:
        if not color:
            color = 'default'
        if c not in self.chartable:
            cx, cy, cwidth = 0, 0, 8
            print("unknown char: %s" % c)
        else:
            c_info = self.chartable[c]
            cx, cy, cwidth = c_info.x, c_info.y, c_info.char_width
        base_surf = self.surfaces.get(color, self.surfaces['default'])
        high_surf = engine.subsurface(base_surf, (cx, cy, self._width, self.height))
        lowsurf = engine.subsurface(base_surf, (cx, cy + self.height, self._width, self.height))
        return (high_surf, lowsurf, cwidth)

    def blit(self, string, surf, pos=(0, 0), color: Optional[str] = None, no_process=False):
        if not color:
            color = self.default_color

        def normal_render(left, top, string: str, bcolor):
            for c in string:
                c_surf, char_width = self._get_char_from_surf(c, bcolor)
                engine.blit(surf, c_surf, (left, top))
                left += char_width + self.space_offset

        def stacked_render(left, top, string: str, bcolor):
            for c in string:
                highsurf, lowsurf, char_width = self._get_stacked_char_from_surf(c, bcolor)
                engine.blit(surf, lowsurf, (left, top))
                engine.blit(surf, highsurf, (left, top))
                left += char_width + self.space_offset

        x, y = pos
        surfwidth, surfheight = surf.get_size()

        string = self.modify_string(string)

        if self.stacked:
            stacked_render(x, y, string, color)
        else:
            normal_render(x, y, string, color)

    def blit_right(self, string, surf, pos, color=None):
        width = self.width(string)
        self.blit(string, surf, (pos[0] - width, pos[1]), color)

    def blit_center(self, string, surf, pos, color=None):
        width = self.width(string)
        self.blit(string, surf, (pos[0] - width//2, pos[1]), color)

    def size(self, string):
        """
        Returns the length and width of a bitmapped string
        """
        return (self.width(string), self.height)

    def width(self, string):
        """
        Returns the width of a bitmapped string
        """
        length = 0
        string = self.modify_string(string)
        for c in string:
            try:
                char_width = self.chartable[c].char_width
            except KeyError as e:
                # print(e)
                # print("%s is not chartable" % c)
                # print("string: ", string)
                char_width = 8
            length += char_width
        return length
