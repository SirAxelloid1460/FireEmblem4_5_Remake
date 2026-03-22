from PyQt5.QtWidgets import QDockWidget


class Dock(QDockWidget):
    def __init__(self, title, parent, visibility_changed_callback=lambda n: None):
        super().__init__(title, parent)
        self.visibilityChanged.connect(self.on_visible)
        self.visibility_changed_callback = visibility_changed_callback

    def on_visible(self, visible):
        if(self.visibility_changed_callback):
            self.visibility_changed_callback(visible)
