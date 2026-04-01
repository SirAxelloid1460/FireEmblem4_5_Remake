from app.utilities import str_utils
from app.data.resources.base_catalog import ManifestCatalog

class Animation():
    def __init__(self, nid, full_path=None):
        self.nid = nid
        self.full_path = full_path
        self.image = None

        self.frame_x, self.frame_y = 1, 1
        self.num_frames = 1
        self.speed = 75

    def set_full_path(self, full_path):
        self.full_path = full_path

    def save(self):
        s_dict = {}
        s_dict['nid'] = self.nid
        s_dict['frame_x'] = self.frame_x
        s_dict['frame_y'] = self.frame_y
        s_dict['num_frames'] = self.num_frames
        if str_utils.is_int(self.speed):
            s_dict['speed'] = str(self.speed)
        else:
            s_dict['speed'] = ','.join([str(_) for _ in self.speed])
        return s_dict

    @classmethod
    def restore(cls, s_dict):
        self = cls(s_dict['nid'])
        self.frame_x = s_dict['frame_x']
        self.frame_y = s_dict['frame_y']
        self.num_frames = s_dict['num_frames']
        if str_utils.is_int(s_dict['speed']):
            self.speed = int(s_dict['speed'])
        else:
            self.speed = [int(_) for _ in s_dict['speed'].split(',')]
        return self

class AnimationCatalog(ManifestCatalog[Animation]):
    manifest = 'animations.json'
    title = 'animations'
    datatype = Animation
