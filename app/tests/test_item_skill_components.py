import unittest

from app.data.database.item_components import ItemComponent
from app.data.database.skill_components import SkillComponent

from app.utilities import str_utils

class ItemSkillComponentTests(unittest.TestCase):
    def setUp(self):
        pass

    def tearDown(self):
        pass

    def test_item_components(self):
        # Test that all item components have 
        # unique nids
        item_components = ItemComponent.__subclasses__()
        nids = {component.nid for component in item_components}
        # self.assertEqual(len(item_components), len(nids), 'Overlapping item component nids!')
        for component in item_components:
            nid = component.nid
            self.assertIn(nid, nids)
            nids.remove(nid)
        #     name = component.__name__
        #     snake_case = str_utils.camel_to_snake(name)
        #     self.assertEqual(nid, snake_case, "%s %s %s" % (nid, name, snake_case))

    def test_skill_components(self):
        # Test that all skill components have 
        # unique nids
        skill_components = SkillComponent.__subclasses__()
        nids = {component.nid for component in skill_components}
        # self.assertEqual(len(skill_components), len(nids), 'Overlapping skill component nids!')
        for component in skill_components:
            nid = component.nid
            self.assertIn(nid, nids)
            nids.remove(nid)
            # name = component.__name__
            # snake_case = str_utils.camel_to_snake(name)
            # self.assertEqual(nid, snake_case, "%s %s %s" % (nid, name, snake_case))

if __name__ == '__main__':
    unittest.main()
