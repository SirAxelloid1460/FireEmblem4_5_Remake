from app.utilities.data import Prefab

class NodeMenuEvent(Prefab):
    def __init__(self, nid):
        self.nid = nid          #This is the unique identifier for the node menu option.
        self.event = None       #The event to be called.
        self.option_name = ''   #Display name of the menu option. This is what's shown in the menu, but the above is the actual event to call.   
        self.visible = False    #Whether the option will appear in the list
        self.enabled = False    #Whether the option can be selected (i.e., if visible but not enabled, will be greyed out)
        
    @classmethod
    def default(cls):
        return cls('0')

