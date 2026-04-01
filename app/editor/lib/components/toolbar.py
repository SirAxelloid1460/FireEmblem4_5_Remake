class Toolbar():
    def __init__(self, main_window_toolbar):
        self.main_window_toolbar = main_window_toolbar
        self.actions = []
        
    def clear(self):
        self.actions = []
        self._rerenderToolbar()

    def addAction(self, action, index=None):
        if action in self.actions:
            return
        if index is None or not 0 <= index < len(self.actions):
            self.actions.append(action)
        else:
            self.actions.insert(index, action)
        self._rerenderToolbar()

    def addSeparator(self, index=None):
        if index is None:
            self.actions.append('separator')
        else:
            self.actions.insert(index, 'separator')
        self._rerenderToolbar()
    
    def insertAction(self, action_before, action):
        index_of_before = self.getIndexOfAction(action_before)
        self.addAction(action, index_of_before)
        
    def removeAction(self, index=None, action=None):
        if index is not None and action:
            if self.actions[index] == action:
                self.actions.pop(index)
        elif index:
            if 0 <= index < len(self.actions):
                self.actions.pop(index)
        elif action:
            if action in self.actions:
                self.actions.remove(action)
        self._rerenderToolbar()
            
    def _rerenderToolbar(self):
        self.main_window_toolbar.clear()
        for item in self.actions:
            if item == 'separator':
                self.main_window_toolbar.addSeparator()
            else:
                self.main_window_toolbar.addAction(item)

    def getActionAtIndex(self, index):
        return self.actions[index]
      
    def getIndexOfAction(self, action):
        index = None
        try:
            index = self.actions.index(action)
            return index
        except Exception:
            return index
