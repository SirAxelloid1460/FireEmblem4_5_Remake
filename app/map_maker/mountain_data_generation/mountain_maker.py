from collections import Counter

from PyQt5.QtGui import QImage

from app.editor.tile_editor.autotiles import PaletteData

from app.constants import TILEWIDTH, TILEHEIGHT
DIRECTIONS = ('left', 'right', 'up', 'down')

class QuadPaletteData():
    def __init__(self, im: QImage):
        topleft_rect = (0, 0, TILEWIDTH//2, TILEHEIGHT//2)
        self.topleft = PaletteData(im.copy(*topleft_rect))
        topright_rect = (TILEWIDTH//2, 0, TILEWIDTH//2, TILEHEIGHT//2)
        self.topright = PaletteData(im.copy(*topright_rect))
        bottomleft_rect = (0, TILEHEIGHT//2, TILEWIDTH//2, TILEHEIGHT//2)
        self.bottomleft = PaletteData(im.copy(*bottomleft_rect))
        bottomright_rect = (TILEWIDTH//2, TILEHEIGHT//2, TILEWIDTH//2, TILEHEIGHT//2)
        self.bottomright = PaletteData(im.copy(*bottomright_rect))

class MountainQuadPaletteData(QuadPaletteData):
    def __init__(self, im: QImage, coord: tuple):
        super().__init__(im)
        self.coord = coord
        self.rules = {}
        for direction in DIRECTIONS:
            self.rules[direction] = Counter()

def similar(p1: QuadPaletteData, p2: MountainQuadPaletteData, must_match=4) -> bool:

    def similar_fast(p1: list, p2: list) -> int:
        """
        Attempts to compare the pattern of the tiles, not the actual values themselves
        """
        mapping_to = {}
        mapping_fro = {}
        for i, j in zip(p1, p2):
            if i == j:
                mapping_to[i] = j
                mapping_fro[j] = i
            elif (i in mapping_to and j != mapping_to[i]) or (j in mapping_fro and i != mapping_fro[j]):
                return TILEWIDTH * TILEHEIGHT
            else:
                mapping_to[i] = j
                mapping_fro[j] = i
        return 0

    topleft_similar = similar_fast(p1.topleft.palette, p2.topleft.palette) == 0
    topright_similar = similar_fast(p1.topright.palette, p2.topright.palette) == 0
    bottomleft_similar = similar_fast(p1.bottomleft.palette, p2.bottomleft.palette) == 0
    bottomright_similar = similar_fast(p1.bottomright.palette, p2.bottomright.palette) == 0
    num_match = sum((topleft_similar, topright_similar, bottomleft_similar, bottomright_similar))
    return num_match >= must_match

def get_mountain_coords(fn) -> set:
    if fn.endswith('main.png'):
        topleft = {(0, 11), (0, 12), (1, 11), (1, 12), (1, 12), (2, 12), (3, 11), (3, 12)}
        main = {(x, y) for x in range(17) for y in range(13, 20)}
        # (18, 18) is a duplicate of (15, 17)
        right = {(17, 14), (17, 15), (17, 16), (17, 17), (17, 18), (17, 19), (18, 16), (18, 17), (18, 19)}
        bottomleft = {(4, 22), (5, 22), (0, 26), (0, 27), (0, 28), (1, 26), (1, 27), (2, 27), (3, 27)}
        bottom = {(x, y) for x in range(6, 12) for y in range(20, 25)}
        bottomright = {(12, 22), (13, 22), (14, 22), (15, 22), (12, 23), (13, 23), (14, 23), (15, 23), (16, 23), (12, 24), (13, 24), (13, 25), (15, 20), (16, 20), (17, 20), (18, 20), (17, 21), (18, 21)}
        # extra = {(0, 6), (1, 6), (2, 6)}
        extra = {(0, 5), (14, 21)}
        return topleft | main | right | bottomleft | bottom | bottomright | extra
    return set()

# def get_mountain_groups() -> list:
#     black_bottomright_group_a = ((16, 13), (16, 14))
#     black_right_group_a = ((16, 15), (17, 14), (16, 16))
#     black_topright_group = ((17, 15), (17, 16), (17, 17), (17, 19))
#     black_black_bottomright_group_b = ((16, 17), (16, 18))
#     black_right_group_b = ((17, 18), (16, 20))
#     black = ((12, 13), (12, 14), (12, 15), (13, 13), (13, 14))
#     black_white_a = ((9, 17), (10, 18))
#     white = ((12, 16), (12, 17), (12, 18), (12, 19), (11, 16), (11, 17), (11, 18), (11, 19), (10, 17), (4, 19), (13, 16))
#     mountain_top_a = ((2, 18), (3, 18), (4, 18))
#     mountain_top_b = ((2, 15), (3, 15), (4, 15), (5, 15), (4, 22), (5, 22), (6, 22), (3, 19), (2, 19))
#     mountain_top_c = ((2, 14), (3, 14), (0, 19), (1, 19))
#     diagonal_black_white = ((6, 18), (6, 17))
#     white_bottomleft = ((8, 17), (8, 16), (7, 16), (6, 16), (2, 17), (3, 17), (5, 17), (18, 17))
#     white_topleft = ((0, 11), (0, 12), (15, 20), (15, 18), (16, 23), (13, 23))
#     mountain = ((0, 17), (1, 17), (15, 19))
#     mountain2 = ((0, 16), (1, 16), (0, 18), (1, 18))
#     straight_ridge = ((6, 13), (7, 13), (8, 13), (9, 13), (10, 13), (11, 13), (11, 14), (10, 14), (9, 16), (10, 16))
#     cross_ridge = ((6, 14), (7, 14), (8, 14), (9, 14), (10, 15), (11, 15))
#     a = ((2, 16), (3, 16), (4, 16), (5, 16))
#     bottom = ((13, 18), (14, 17), (18, 16))
#     b = ((15, 17), (17, 21))
#     c = ((15, 23), (14, 18))
#     d = ((14, 14), (15, 14))
#     e = ((9, 18), (7, 19))
#     f = ((0, 13), (1, 13))
#     g = ((4, 14), (5, 14))
#     h = ((3, 13), (2, 13))
#     littletop = ((7, 23), (6, 23), (6, 24), (14, 21))
#     left_right = ((8, 23), (8, 24), (9, 21))
#     loner = ((7, 21), (7, 22))
#     right = ((9, 23), (9, 24), (16, 21))
#     i = ((6, 15), (7, 15))
#     little_black_top_right = ((16, 19), (15, 21))
#     k = ((10, 23), (13, 24))
#     all_groups = [black_bottomright_group_a, black_right_group_a, black_topright_group, black_black_bottomright_group_b, black_right_group_b,
#                   black, black_white_a, white, mountain_top_a, mountain_top_b, mountain_top_c, diagonal_black_white, white_bottomleft,
#                   white_topleft, mountain, mountain2, straight_ridge, cross_ridge, a, bottom, b, c, d, e, f, g, h, littletop,
#                   left_right, loner, right, i, little_black_top_right, k]
#     # Confirm they all have unique elements, no shared coords
#     for a, b in itertools.combinations(all_groups, 2):
#         assert len(set(a) & set(b)) == 0, ("%s, %s" % (a, b))
#     return all_groups

def load_mountain_palettes(fn, coords) -> dict:
    palettes = {}
    image = QImage(fn)
    for coord in coords:
        rect = (coord[0] * TILEWIDTH, coord[1] * TILEHEIGHT, TILEWIDTH, TILEHEIGHT)
        palette = image.copy(*rect)
        d = MountainQuadPaletteData(palette, coord)
        palettes[coord] = d
    return palettes

def assign_rules(palette_templates: dict, fns: list):
    print("Assign Rules")
    for fn in fns:
        print("Processing %s..." % fn)
        image = QImage(fn)
        num_tiles_x = image.width() // TILEWIDTH
        num_tiles_y = image.height() // TILEHEIGHT
        image_palette_data = {}
        for x in range(num_tiles_x):
            for y in range(num_tiles_y):
                rect = (x * TILEWIDTH, y * TILEHEIGHT, TILEWIDTH, TILEHEIGHT)
                palette = image.copy(*rect)
                d = QuadPaletteData(palette)
                image_palette_data[(x, y)] = d
        
        best_matches = {} # Position: Mountain Template match
        for position, palette in image_palette_data.items():
            mountain_match = is_present(palette, palette_templates)
            if mountain_match:
                best_matches[position] = mountain_match
        # print({k: v.coord for k, v in best_matches.items()})

        for position, mountain_match in best_matches.items():
            # Find adjacent positions
            left = position[0] - 1, position[1]
            right = position[0] + 1, position[1]
            up = position[0], position[1] - 1
            down = position[0], position[1] + 1
            left_palette = best_matches.get(left)
            right_palette = best_matches.get(right)
            up_palette = best_matches.get(up)
            down_palette = best_matches.get(down)
            # determine if those positions are in palette_templates
            # If they are, mark those coordinates in the list of valid coords
            # If not, mark as end validity
            if left[0] >= 0:
                if left_palette:
                    mountain_match.rules['left'][left_palette.coord] += 1
                else:
                    mountain_match.rules['left'][None] += 1
            if right[0] < num_tiles_x:
                if right_palette:
                    mountain_match.rules['right'][right_palette.coord] += 1
                else:
                    mountain_match.rules['right'][None] += 1
            if up[1] >= 0:
                if up_palette:
                    mountain_match.rules['up'][up_palette.coord] += 1
                else:
                    mountain_match.rules['up'][None] += 1
            if down[1] < num_tiles_y:
                if down_palette:
                    mountain_match.rules['down'][down_palette.coord] += 1
                else:
                    mountain_match.rules['down'][None] += 1

def is_present(palette: QuadPaletteData, palette_templates: dict) -> MountainQuadPaletteData:
    MUST_MATCH = 4
    for coord, mountain in palette_templates.items():
        if similar(palette, mountain, MUST_MATCH):
            return mountain
    return None

def remove_connections_that_only_appear_once(mountain_palettes: dict):
    for palette in mountain_palettes.values():
        for direction in DIRECTIONS:
            palette.rules[direction] = {k: v for k, v in palette.rules[direction].items() if v > 1}
    return mountain_palettes

def remove_infrequent_palettes(mountain_palettes: dict):
    # Remove palettes that don't appear very often
    useless_limit = 30
    for coord in list(mountain_palettes.keys()):
        palette = mountain_palettes[coord]
        # Only bother with the ones that actually have rules
        if sum(palette.rules['left'].values()) >= useless_limit or \
                sum(palette.rules['right'].values()) >= useless_limit or \
                sum(palette.rules['up'].values()) >= useless_limit or \
                sum(palette.rules['down'].values()) >= useless_limit:
            pass
        else:
            del mountain_palettes[coord]
    # Now delete connections
    remaining_coords = mountain_palettes.keys()
    for palette in mountain_palettes.values():
        for direction in DIRECTIONS:
            palette.rules[direction] = {k: v for k, v in palette.rules[direction].items() if k in remaining_coords or k is None}
    return mountain_palettes

def remove_adjacent_palettes(mountain_palettes: dict):
    # Make it so that no coord can connect to itself
    for coord, palette in mountain_palettes.items():
        for direction in DIRECTIONS:
            palette.rules[direction] = {k: v for k, v in palette.rules[direction].items() if k != coord}
    return mountain_palettes

def fuse(mountain_palettes: dict, parent: tuple, child: tuple):
    assert parent != child
    if parent in mountain_palettes and child in mountain_palettes:
        parent_palette = mountain_palettes[parent]
        child_palette = mountain_palettes[child]
        for direction in DIRECTIONS:
            parent_palette.rules[direction].update(child_palette.rules[direction])
        # Replace connections to child with parent
        for coord, palette in mountain_palettes.items():
            for direction in DIRECTIONS:
                if child in palette.rules[direction]:
                    if parent in palette.rules[direction]:
                        palette.rules[direction][parent] += palette.rules[direction][child]
                    else:
                        palette.rules[direction][parent] = palette.rules[direction][child]
        del mountain_palettes[child]
    else:
        print("Could not find both ", parent, " and ", child, " in mountain_palettes")
    return mountain_palettes

def fuse_bright_palettes(mountain_palettes: dict):
    fuse(mountain_palettes, (1, 13), (0, 13))  # Fuse (0, 13) into (1, 13)
    fuse(mountain_palettes, (3, 13), (2, 13))
    fuse(mountain_palettes, (5, 13), (4, 13))
    fuse(mountain_palettes, (1, 14), (0, 14))
    fuse(mountain_palettes, (3, 14), (2, 14))
    fuse(mountain_palettes, (5, 14), (4, 14))
    fuse(mountain_palettes, (1, 16), (0, 16))
    fuse(mountain_palettes, (1, 17), (0, 17))
    fuse(mountain_palettes, (1, 18), (0, 18))
    fuse(mountain_palettes, (1, 19), (0, 19))
    fuse(mountain_palettes, (8, 13), (7, 13))
    fuse(mountain_palettes, (8, 13), (6, 13))
    fuse(mountain_palettes, (8, 13), (9, 13))
    fuse(mountain_palettes, (8, 13), (10, 14))
    fuse(mountain_palettes, (8, 13), (11, 14))
    fuse(mountain_palettes, (8, 13), (3, 12))
    fuse(mountain_palettes, (8, 14), (7, 14))
    fuse(mountain_palettes, (8, 14), (6, 14))
    fuse(mountain_palettes, (8, 14), (9, 14))
    fuse(mountain_palettes, (8, 14), (10, 15))
    fuse(mountain_palettes, (8, 14), (11, 15))
    fuse(mountain_palettes, (5, 15), (2, 15))
    fuse(mountain_palettes, (5, 15), (3, 15))
    fuse(mountain_palettes, (5, 15), (4, 15))
    fuse(mountain_palettes, (5, 16), (2, 16))
    fuse(mountain_palettes, (5, 16), (3, 16))
    fuse(mountain_palettes, (5, 16), (4, 16))
    fuse(mountain_palettes, (8, 17), (6, 16))
    fuse(mountain_palettes, (8, 17), (7, 16))
    fuse(mountain_palettes, (8, 17), (8, 16))
    fuse(mountain_palettes, (5, 17), (2, 17))
    fuse(mountain_palettes, (5, 17), (3, 17))
    fuse(mountain_palettes, (4, 18), (2, 18))
    fuse(mountain_palettes, (4, 18), (3, 18))
    fuse(mountain_palettes, (3, 19), (2, 19))
    fuse(mountain_palettes, (9, 15), (8, 15))
    fuse(mountain_palettes, (10, 16), (9, 16))
    fuse(mountain_palettes, (6, 22), (4, 22))
    fuse(mountain_palettes, (6, 22), (5, 22))
    fuse(mountain_palettes, (8, 18), (6, 21))
    # Bright sheets
    fuse(mountain_palettes, (12, 16), (11, 16))
    fuse(mountain_palettes, (12, 16), (10, 17))
    fuse(mountain_palettes, (12, 16), (11, 17))
    fuse(mountain_palettes, (12, 16), (12, 17))
    fuse(mountain_palettes, (12, 16), (11, 18))
    fuse(mountain_palettes, (12, 16), (12, 18))
    fuse(mountain_palettes, (12, 16), (11, 19))
    fuse(mountain_palettes, (12, 16), (12, 19))
    fuse(mountain_palettes, (12, 16), (4, 19))

    return mountain_palettes

if __name__ == '__main__':
    import os, sys, glob
    try:
        import cPickle as pickle
    except ImportError:
        import pickle

    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)

    tileset = 'app/map_maker/palettes/westmarch/main.png'
    mountain_coords = get_mountain_coords(tileset)

    mountain_palettes = load_mountain_palettes(tileset, mountain_coords)
    mountain_data_dir = glob.glob('/app/map_maker/mountain_data_generation/maps_with_mountains/*.png')
    # home_dir = os.path.expanduser('~')
    # mountain_data_dir = glob.glob(home_dir + '/Pictures/Fire Emblem/MapReferences/custom_mountain_data/*.png')
    # Stores rules in the palette data itself
    assign_rules(mountain_palettes, mountain_data_dir)
    # mountain_palettes = remove_adjacent_palettes(mountain_palettes)
    mountain_palettes = fuse_bright_palettes(mountain_palettes)
    mountain_palettes = remove_connections_that_only_appear_once(mountain_palettes)
    mountain_palettes = remove_infrequent_palettes(mountain_palettes)

    print("--- Final Rules ---")
    final_rules = {coord: mountain_palette.rules for coord, mountain_palette in mountain_palettes.items()}
    to_watch = []
    for coord, rules in sorted(final_rules.items()):
        print("---", coord, "---")
        if rules['left']:
            print('left', rules['left'])
        if rules['right']:
            print('right', rules['right'])
        if rules['up']:
            print('up', rules['up'])
        if rules['down']:
            print('down', rules['down'])

    print("Number of Coordinates:", len(final_rules))
    print("Number of Rules: ", sum(sum(len(mountain_palette[direction]) for direction in DIRECTIONS) for mountain_palette in final_rules.values()))

    data_loc = 'app/map_maker/mountain_data_generation/mountain_data.p'
    with open(data_loc, 'wb') as fp:
        pickle.dump(final_rules, fp)
