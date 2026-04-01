class MenuBar():
    def __init__(self, main_window_menu_bar):
        self.main_window_menu_bar = main_window_menu_bar
        self.menus = {}

    def addMenu(self, menu):
        self.main_window_menu_bar.addMenu(menu)
        self.menus[menu.title()] = menu

    def getMenu(self, title):
        return self.menus[title]
