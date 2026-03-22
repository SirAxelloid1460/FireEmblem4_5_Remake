import os, shutil

from app.data.resources.base_catalog import BaseResourceCatalog

class Font():
    def __init__(self, nid, full_path=None):
        self.nid = nid
        self.full_path = full_path  # IDX Path

class FontCatalog(BaseResourceCatalog[Font]):
    datatype = Font
    filetype = '.png'

    # I don't think move image or save are needed right now...
    def move_image(self, icon, loc):
        new_full_path = os.path.join(loc, icon.nid + self.filetype)
        if os.path.abspath(icon.full_path) != os.path.abspath(new_full_path):
            shutil.copy(icon.full_path, new_full_path)
            icon.set_full_path(new_full_path)

    def save(self, loc):
        for font in self:
            self.move_image(font, loc)
