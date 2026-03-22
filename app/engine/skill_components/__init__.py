import os
import importlib

for module in os.listdir(os.path.dirname(__file__)):
    if module == '__init__.py' or module[-3:] != '.py':
        continue
    print("Importing Skill Components in %s..." % module)
    # importlib.import_module(module[:-3], 'app.engine.item_components')
    importlib.import_module('app.engine.skill_components.' + module[:-3])
del module
