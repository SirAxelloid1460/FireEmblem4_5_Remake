#! /usr/bin/env python3
# -*- coding: utf-8 -*-

from PyQt5.QtGui import QPalette, QColor
from PyQt5.QtCore import Qt

WHITE = QColor(255, 255, 255)
BLACK = QColor(0, 0, 0)
RED = QColor(255, 0, 0)
PRIMARY = QColor(53, 53, 53, 232)
SECONDARY = QColor(35, 35, 35, 232)
TERTIARY = QColor(42, 130, 218, 232)
HIGHLIGHT = QColor(84, 85, 81, 232)
DISABLED = QColor(128, 128, 128)

DISPRIMARY = QColor(54, 57, 63)
DISSECONDARY = QColor(47, 49, 54)
#DISTERTIARY = QColor(57, 60, 67)
DISTERTIARY = QColor(78, 82, 92)
DISHIGHLIGHT = QColor(32, 34, 37)
GRAY = QColor(230, 230, 225)
DARKGRAY = QColor(188, 188, 188)

TRANSPRIMARY = QColor(53, 53, 53, 232)
TRANSSECONDARY = QColor(35, 35, 35, 232)
TRANSTERTIARY = QColor(42, 130, 218, 232)
TRANSHIGHLIGHT = QColor(84, 85, 81, 232)

BLUEPRIMARY = QColor(81, 95, 107, 232)
BLUESECONDARY = QColor(69, 66, 89, 232)
BLUETERTIARY = QColor(128, 143, 137, 232)
BLUEHIGHLIGHT = QColor(248, 248, 240, 232)

# SKYPRIMARY = QColor(50, 150, 200, 232)
SKYPRIMARY = QColor(44, 44, 119, 232)
SKYSECONDARY = QColor(75, 125, 200, 232)
SKYTERTIARY = QColor(25, 25, 100, 245)
SKYHIGHLIGHT = QColor(100, 175, 255, 232)

PURPLEPRIMARY = QColor(50, 50, 100, 232)
PURPLESECONDARY = QColor(100, 100, 125, 232)
PURPLETERTIARY = QColor(28, 12, 28, 245)
PURPLEHIGHLIGHT = QColor(175, 175, 200, 232)

base_palette = QPalette()

def css_rgb(color, a=False):
    """Get a CSS `rgb` or `rgba` string from a `QtGui.QColor`."""
    return ("rgba({}, {}, {}, {})" if a else "rgb({}, {}, {})").format(*color.getRgb())

class QLightPalette(QPalette):
    """Dark palette for a Qt application meant to be used with the Fusion theme."""
    def __init__(self, *__args):
        super().__init__(*__args)
        self.highlight_color = DARKGRAY

    def set_stylesheet(self, app):
        """Static method to set the tooltip stylesheet to a `QtWidgets.QApplication`."""
        app.custom_style_sheet = ""
        tooltip = ("QToolTip {{"
                   "color: {white};"
                   "background-color: {tertiary};"
                   "border: 1px solid {white};"
                   "}}".format(white=css_rgb(WHITE), tertiary=css_rgb(TERTIARY)))
        scrollbar = (
            "QScrollBar:vertical {{"
            "    border: 0px solid {secondary};"
            "    background: transparent;"
            "    width: 8px;    "
            "    margin: 0px 0px 0px 0px;"
            "}}"
            "QScrollBar:horizontal {{"
            "    border: 0px solid {secondary};"
            "    background: transparent;"
            "    height: 8px;    "
            "    margin: 0px 0px 0px 0px;"
            "}}"
            "QScrollBar::handle {{"
            "    background: {secondary};"
            "    border: 1px solid {secondary};"
            "    border-radius: 4px;"
            "}}"
            "QScrollBar::add-line:vertical {{"
            "    height: 0px;"
            "    subcontrol-position: bottom;"
            "    subcontrol-origin: margin;"
            "}}"
            "QScrollBar::sub-line:vertical {{"
            "    height: 0 px;"
            "    subcontrol-position: top;"
            "    subcontrol-origin: margin;"
            "}}"
            "QScrollBar::add-line:horizontal {{"
            "    width: 0px;"
            "    subcontrol-position: right;"
            "    subcontrol-origin: margin;"
            "}}"
            "QScrollBar::sub-line:horizontal {{"
            "    width: 0 px;"
            "    subcontrol-position: left;"
            "    subcontrol-origin: margin;"
            "}}".format(white=css_rgb(WHITE), secondary=css_rgb(self.highlight_color)))

        # app.custom_style_sheet += tooltip
        app.custom_style_sheet += scrollbar

    def set_app(self, app):
        """Set the Fusion theme and this palette to a `QtWidgets.QApplication`."""
        app.setStyle("Fusion")
        # app.setPalette(self)
        app.setPalette(app.style().standardPalette())
        self.set_stylesheet(app)

class QDarkPalette(QLightPalette):
    """Dark palette for a Qt application meant to be used with the Fusion theme."""
    def __init__(self, *__args):
        super().__init__(*__args)
        self.highlight_color = HIGHLIGHT

        # Set all the colors based on the constants in globals
        self.setColor(QPalette.Window, PRIMARY)
        self.setColor(QPalette.WindowText, WHITE)
        self.setColor(QPalette.Base, SECONDARY)
        self.setColor(QPalette.AlternateBase, PRIMARY)
        self.setColor(QPalette.ToolTipBase, WHITE)
        self.setColor(QPalette.ToolTipText, WHITE)
        self.setColor(QPalette.Text, WHITE)
        self.setColor(QPalette.Button, PRIMARY)
        self.setColor(QPalette.ButtonText, WHITE)
        self.setColor(QPalette.BrightText, RED)
        self.setColor(QPalette.Link, TERTIARY)
        self.setColor(QPalette.Highlight, TERTIARY)
        self.setColor(QPalette.HighlightedText, BLACK)

        self.setColor(QPalette.Disabled, QPalette.WindowText, DISABLED)
        self.setColor(QPalette.Disabled, QPalette.Text, DISABLED)
        self.setColor(QPalette.Disabled, QPalette.ButtonText, DISABLED)

    def set_app(self, app):
        """Set the Fusion theme and this palette to a `QtWidgets.QApplication`."""
        app.setStyle("Fusion")
        app.setPalette(self)
        self.set_stylesheet(app)

class QDiscordPalette(QDarkPalette):
    def __init__(self, *__args):
        super().__init__(*__args)
        self.highlight_color = DISHIGHLIGHT

        # Set all the colors based on the constants in globals
        self.setColor(QPalette.Window, DISPRIMARY)
        self.setColor(QPalette.WindowText, GRAY)
        self.setColor(QPalette.Base, DISSECONDARY)
        self.setColor(QPalette.AlternateBase, DISPRIMARY)
        self.setColor(QPalette.ToolTipBase, WHITE)
        self.setColor(QPalette.ToolTipText, GRAY)
        self.setColor(QPalette.Text, GRAY)
        self.setColor(QPalette.Button, DISPRIMARY)
        self.setColor(QPalette.ButtonText, WHITE)
        self.setColor(QPalette.BrightText, RED)
        self.setColor(QPalette.Link, TERTIARY)
        self.setColor(QPalette.Highlight, DISTERTIARY)
        self.setColor(QPalette.HighlightedText, WHITE)

        self.setColor(QPalette.Disabled, QPalette.WindowText, DISABLED)
        self.setColor(QPalette.Disabled, QPalette.Text, DISABLED)
        self.setColor(QPalette.Disabled, QPalette.ButtonText, DISABLED)

class QDarkBGPalette(QDarkPalette):
    """Dark palette for a Qt application meant to be used with the Fusion theme."""
    def __init__(self, *__args):
        super().__init__(*__args)
        self.highlight_color = TRANSHIGHLIGHT

        # Set all the colors based on the constants in globals
        self.setColor(QPalette.Window, TRANSPRIMARY)
        self.setColor(QPalette.WindowText, WHITE)
        self.setColor(QPalette.Base, TRANSSECONDARY)
        self.setColor(QPalette.AlternateBase, TRANSPRIMARY)
        self.setColor(QPalette.ToolTipBase, WHITE)
        self.setColor(QPalette.ToolTipText, WHITE)
        self.setColor(QPalette.Text, WHITE)
        self.setColor(QPalette.Button, TRANSPRIMARY)
        self.setColor(QPalette.ButtonText, WHITE)
        self.setColor(QPalette.BrightText, RED)
        self.setColor(QPalette.Link, TRANSTERTIARY)
        self.setColor(QPalette.Highlight, TRANSTERTIARY)
        self.setColor(QPalette.HighlightedText, BLACK)

        self.setColor(QPalette.Disabled, QPalette.WindowText, DISABLED)
        self.setColor(QPalette.Disabled, QPalette.Text, DISABLED)
        self.setColor(QPalette.Disabled, QPalette.ButtonText, DISABLED)

class QBlueBGPalette(QDarkPalette):
    """Dark palette for a Qt application meant to be used with the Fusion theme."""
    def __init__(self, *__args):
        super().__init__(*__args)
        self.highlight_color = BLUEHIGHLIGHT

        # Set all the colors based on the constants in globals
        self.setColor(QPalette.Window, BLUEPRIMARY)
        self.setColor(QPalette.WindowText, WHITE)
        self.setColor(QPalette.Base, BLUESECONDARY)
        self.setColor(QPalette.AlternateBase, BLUEPRIMARY)
        self.setColor(QPalette.ToolTipBase, WHITE)
        self.setColor(QPalette.ToolTipText, WHITE)
        self.setColor(QPalette.Text, WHITE)
        self.setColor(QPalette.Button, BLUEPRIMARY)
        self.setColor(QPalette.ButtonText, WHITE)
        self.setColor(QPalette.BrightText, RED)
        self.setColor(QPalette.Link, BLUETERTIARY)
        self.setColor(QPalette.Highlight, BLUETERTIARY)
        self.setColor(QPalette.HighlightedText, BLACK)

        self.setColor(QPalette.Disabled, QPalette.WindowText, DISABLED)
        self.setColor(QPalette.Disabled, QPalette.Text, DISABLED)
        self.setColor(QPalette.Disabled, QPalette.ButtonText, DISABLED)

class QSkyBGPalette(QLightPalette):
    def __init__(self, *__args):
        super().__init__(*__args)
        self.highlight_color = SKYHIGHLIGHT

        # Set all the colors based on the constants in globals
        self.setColor(QPalette.Window, SKYSECONDARY)
        self.setColor(QPalette.WindowText, WHITE)
        self.setColor(QPalette.Base, SKYTERTIARY)
        self.setColor(QPalette.AlternateBase, SKYPRIMARY)
        self.setColor(QPalette.ToolTipBase, WHITE)
        self.setColor(QPalette.ToolTipText, WHITE)
        self.setColor(QPalette.Text, WHITE)
        self.setColor(QPalette.Button, SKYSECONDARY)
        self.setColor(QPalette.ButtonText, WHITE)
        self.setColor(QPalette.BrightText, RED)
        self.setColor(QPalette.Link, TERTIARY)
        self.setColor(QPalette.Highlight, SKYHIGHLIGHT)
        self.setColor(QPalette.HighlightedText, WHITE)

        self.setColor(QPalette.Disabled, QPalette.WindowText, DISABLED)
        self.setColor(QPalette.Disabled, QPalette.Text, DISABLED)
        self.setColor(QPalette.Disabled, QPalette.ButtonText, DISABLED)

    def set_app(self, app):
        """Set the Fusion theme and this palette to a `QtWidgets.QApplication`."""
        app.setStyle("Fusion")
        app.setPalette(self)
        self.set_stylesheet(app)

class QPurpleBGPalette(QLightPalette):
    def __init__(self, *__args):
        super().__init__(*__args)
        self.highlight_color = PURPLEHIGHLIGHT

        # Set all the colors based on the constants in globals
        self.setColor(QPalette.Window, PURPLESECONDARY)
        self.setColor(QPalette.WindowText, WHITE)
        self.setColor(QPalette.Base, PURPLETERTIARY)
        self.setColor(QPalette.AlternateBase, PURPLESECONDARY)
        self.setColor(QPalette.ToolTipBase, WHITE)
        self.setColor(QPalette.ToolTipText, WHITE)
        self.setColor(QPalette.Text, WHITE)
        self.setColor(QPalette.Button, PURPLEPRIMARY)
        self.setColor(QPalette.ButtonText, WHITE)
        self.setColor(QPalette.BrightText, RED)
        self.setColor(QPalette.Link, TERTIARY)
        self.setColor(QPalette.Highlight, PURPLEHIGHLIGHT)
        self.setColor(QPalette.HighlightedText, WHITE)

        self.setColor(QPalette.Disabled, QPalette.WindowText, DISABLED)
        self.setColor(QPalette.Disabled, QPalette.Text, DISABLED)
        self.setColor(QPalette.Disabled, QPalette.ButtonText, DISABLED)

    def set_app(self, app):
        """Set the Fusion theme and this palette to a `QtWidgets.QApplication`."""
        app.setStyle("Fusion")
        app.setPalette(self)
        self.set_stylesheet(app)

def set(app, theme_idx):
    """
    Unfortunately for now, icon colors don't change until restart
    """
    if theme_idx == 0:
        d = QLightPalette()
        d.set_app(app)
    elif theme_idx == 1:
        d = QDarkPalette()
        d.set_app(app)
    elif theme_idx == 2:
        d = QDiscordPalette()
        d.set_app(app)
    elif theme_idx == 3:
        d = QDarkBGPalette()
        d.set_app(app)
    elif theme_idx == 4:
        d = QBlueBGPalette()
        d.set_app(app)
    elif theme_idx == 5:
        d = QSkyBGPalette()
        d.set_app(app)
    elif theme_idx == 6:
        d = QPurpleBGPalette()
        d.set_app(app)

    if theme_idx == 3:
        app.custom_style_sheet += "QDialog {background-image: url(icons/bg.png)};"
    elif theme_idx == 4:
        app.custom_style_sheet += "QDialog {background-image: url(icons/bg2.png)};"
    elif theme_idx == 5:
        app.custom_style_sheet += "QDialog {background-image: url(icons/bg3.png)};"
    elif theme_idx == 6:
        app.custom_style_sheet += "QDialog {background-image: url(icons/bg4.png)};"
    else:
        app.custom_style_sheet += "QDialog {background-image: none;"

    app.setStyleSheet(app.custom_style_sheet)
