from __future__ import annotations

import logging
from enum import Enum
from typing import Callable, List, Dict, Set, Tuple

from app.utilities.data import Prefab


class Tags(Enum):
    FLOW_CONTROL = 'Flow Control'
    MUSIC_SOUND = 'Music/Sound'
    PORTRAIT = 'Portrait'
    BG_FG = 'Background/Foreground'
    DIALOGUE_TEXT = 'Dialogue/Text'
    CURSOR_CAMERA = 'Cursor/Camera'
    LEVEL_VARS = 'Level-wide Unlocks and Variables'
    GAME_VARS = 'Game-wide Unlocks and Variables'
    TILEMAP = 'Tilemap'
    REGION = 'Region'
    ADD_REMOVE_INTERACT_WITH_UNITS = 'Add/Remove/Interact with Units'
    MODIFY_UNIT_PROPERTIES = 'Modify Unit Properties'
    MODIFY_ITEM_PROPERTIES = 'Modify Item Properties'
    UNIT_GROUPS = 'Unit Groups'
    MISCELLANEOUS = 'Miscellaneous'
    OVERWORLD = 'Overworld'
    ACHIEVEMENT = 'Achievement'
    PERSISTENT_RECORDS = 'Persistent Records'
    HIDDEN = 'Hidden'

UNIVERSAL_FLAGS = ['no_warn']

class EventCommand(Prefab):
    nid: str = None
    nickname: str = None
    tag: Tags = Tags.HIDDEN
    special_handling: bool = False
    desc: str = ''

    # static, shared among all instances of an EventCommand
    keywords: list = []
    optional_keywords: list = []
    keyword_types: list = []  # always same size as keywords + optional keywords
    _flags: list = []

    # volatile, can be different between the same class
    parameters: dict = {}
    chosen_flags: set = set()
    display_values: list = []

    def __init__(self, parameters: Dict[str, str] = None, flags: Set[str] = None, display_values: List[str] = None):
        self.parameters: Dict[str, str] = parameters or {}
        self.chosen_flags: Set[str] = flags or set()
        self.display_values: List[str] = display_values or []

    def save(self):
        return self.nid, self.display_values

    def to_plain_text(self) -> str:
        return ';'.join([self.nid] + self.display_values)

    def __repr__(self):
        return self.to_plain_text()

    def get_keyword_types(self) -> list:
        if len(self.keyword_types) == len(self.keywords + self.optional_keywords):
            return self.keyword_types
        else:
            return self.keywords + self.optional_keywords

    def get_validator_from_keyword(self, keyword: str) -> str:
        if keyword in self.keywords:
            i = self.keywords.index(keyword)
            return self.get_keyword_types()[i]
        elif keyword in self.optional_keywords:
            i = self.optional_keywords.index(keyword)
            return self.get_keyword_types()[len(self.keywords) + i]

    def get_index_from_keyword(self, keyword: str) -> int:
        for idx, value in enumerate(self.display_values):
            if (keyword + '=') in value:
                return idx

        if keyword in self.keywords:
            return self.keywords.index(keyword)
        elif keyword in self.optional_keywords:
            return self.optional_keywords.index(keyword) + len(self.keywords)
        return 0

    @classmethod
    def copy(cls, command: EventCommand) -> EventCommand:
        new_command = cls()
        new_command.parameters = command.parameters.copy()
        new_command.chosen_flags = command.chosen_flags.copy()
        new_command.display_values = command.display_values.copy()
        return new_command

    @property
    def flags(self) -> List[str]:
        return self._flags + UNIVERSAL_FLAGS

class Comment(EventCommand):
    nid = "comment"
    nickname = '#'
    tag = Tags.FLOW_CONTROL
    desc = \
        """
**Lines** starting with '#' will be ignored.
        """

    def to_plain_text(self) -> str:
        if self.display_values and not self.display_values[0].startswith('#'):
            self.display_values[0] = '#' + self.display_values[0]
        if self.display_values:
            return self.display_values[0]
        return ''

class If(EventCommand):
    nid = "if"
    tag = Tags.FLOW_CONTROL
    special_handling = True
    desc = \
        """
If the *Expression* returns true, the block under this command will be executed.
If it returns false, the script will search for the next **elif**, **else**,
or **end** command before proceeding. If it is not a valid Python expression, the result will be treated as false.

Remember to end your **if** blocks with **end**.

The indentation is not required, but is recommended for organization of the conditional blocks.

Example:

```
if;game.check_dead('Eirika')
    lose_game
elif;game.check_dead('Lyon')
    win_game
else
    u;Eirika
    s;Eirika;Nice!
    r;Eirika
end
```
        """

    keywords = ['Expression']

class Elif(EventCommand):
    nid = "elif"
    tag = Tags.FLOW_CONTROL
    special_handling = True
    desc = \
        """
Works exactly like the **if** statement, but is called only if the previous **if** or **elif** returned false.

In the following example, the **elif** will only be processed if `if;game.check_dead('Eirika')` return false.

Example:

```
if;game.check_dead('Eirika')
    lose_game
elif;game.check_dead('Lyon')
    win_game
else
    u;Eirika
    s;Eirika;Nice!
    r;Eirika
end
```
        """

    keywords = ['Expression']

class Else(EventCommand):
    nid = "else"
    tag = Tags.FLOW_CONTROL
    special_handling = True
    desc = \
        """
Defines a block to be executed only if the previous **if** or **elif** returned false.

Example:

```
if;game.check_dead('Eirika')
    lose_game
elif;game.check_dead('Lyon')
    win_game
else
    u;Eirika
    s;Eirika;Nice!
    r;Eirika
end
```
        """

class End(EventCommand):
    nid = "end"
    tag = Tags.FLOW_CONTROL
    special_handling = True
    desc = \
        """
Ends a conditional block. Refer to the **if** command for more information.
        """

class For(EventCommand):
    nid = "for"
    tag = Tags.FLOW_CONTROL
    special_handling = True
    desc = \
    """The Expression will be evaluated, and it should return a list of strings.
For every string in this list, the events below will be ran once, with the contents of the string accessible via the bracketed `{$(nid)}` tag.

Remember to end your **for** blocks with **endf**.

Flags:
The *no_warn* flag will suppress warnings, but not errors. Use this flag only if you know why you're using it.

Example: this will give every unit in the party the Inspiration skill silently

```
for;PARTY_UNIT;[unit.nid for unit in game.get_units_in_party()]
    give_skill;{PARTY_UNIT};Inspiration;no_banner
endf
```
    """
    keywords = ['Nid', 'Expression']

class Endf(EventCommand):
    nid = "endf"
    tag = Tags.FLOW_CONTROL
    special_handling = True
    desc = \
        """
Ends a for block. Refer to the **for** command for more information.
        """

class Finish(EventCommand):
    nid = "finish"
    nickname = "break"
    tag = Tags.FLOW_CONTROL
    desc = \
        """
Immediately ends the current event.
        """


class Wait(EventCommand):
    nid = "wait"
    tag = Tags.FLOW_CONTROL
    desc = \
        """
Pauses the execution of the script for *Time* milliseconds.

Often used after a scene transition, cursor movement, or reinforcements to give the player a chance to take in the scene.
        """

    keywords = ['Time']

class EndSkip(EventCommand):
    nid = "end_skip"
    tag = Tags.FLOW_CONTROL
    desc = \
        """
If the player was skipping through the event script, stop the skip here.
Used to prevent a single skip from skipping through an entire event.
        """

class Music(EventCommand):
    nid = "music"
    nickname = "m"
    tag = Tags.MUSIC_SOUND
    desc = \
        """
Fades in *Music* over the course of *FadeIn* milliseconds. Fade in defaults to 400 milliseconds.
        """

    keywords = ['Music']
    optional_keywords = ['FadeIn']  # How long to fade in (default 400)
    keyword_types = ['Music', 'Time']

class MusicClear(EventCommand):
    nid = "music_clear"
    tag = Tags.MUSIC_SOUND

    desc = \
        """
Fades out the currently playing song over the course of *FadeOut* milliseconds.
Also clears the entire song stack. Fade out defaults to 400 milliseconds.
        """

    optional_keywords = ['FadeOut']  # How long to fade out
    keyword_types = ['Time']

class Sound(EventCommand):
    nid = "sound"
    tag = Tags.MUSIC_SOUND

    desc = \
        """
Plays the *Sound* once.
        """

    keywords = ['Sound']
    optional_keywords = ['Volume']

class ChangeMusic(EventCommand):
    nid = 'change_music'
    tag = Tags.MUSIC_SOUND

    desc = \
        """
Changes the phase theme music. For instance, you could use this command to change the player phase theme halfway through the chapter.
        """

    keywords = ['Phase', 'Music']
    keyword_types = ['PhaseMusic', 'Music']

class AddPortrait(EventCommand):
    nid = "add_portrait"
    nickname = "u"
    tag = Tags.PORTRAIT

    desc = \
        """
Adds a portrait to the screen.

Extra flags:

1. *mirror*: Portrait will face opposite expected direction.
2. *low_priority*: Portrait will appear behind all other portraits on the screen.
3. *immediate*: Portrait will not fade in.
4. *no_block*: Portrait will fade in, but will not pause execution of event script while doing so.
        """

    keywords = ['Portrait', 'ScreenPosition']
    optional_keywords = ['Slide', 'ExpressionList', 'SpeedMult']
    keyword_types = ['Portrait', 'ScreenPosition', 'Slide', 'ExpressionList', 'Float']
    _flags = ["mirror", "low_priority", "immediate", "no_block"]

class MultiAddPortrait(EventCommand):
    nid = "multi_add_portrait"
    nickname = "uu"
    tag = Tags.PORTRAIT

    desc = \
        """
Adds more than one portrait to the screen at the same time. Accepts 2-4 portraits and their associated *ScreenPosition* as input.
        """

    keywords = ['Portrait1', 'ScreenPosition1', 'Portrait2', 'ScreenPosition2']
    optional_keywords = ['Portrait3', 'ScreenPosition3', 'Portrait4', 'ScreenPosition4']
    keyword_types = ['Portrait', 'ScreenPosition', 'Portrait', 'ScreenPosition', 'Portrait', 'ScreenPosition', 'Portrait', 'ScreenPosition']

class RemovePortrait(EventCommand):
    nid = "remove_portrait"
    nickname = "r"
    tag = Tags.PORTRAIT

    desc = \
        """
Removes a portrait from the screen.

Extra flags:

1. *immediate*: Portrait will disappear instantly and will not fade out.
2. *no_block*: Portrait will fade out, but will not pause execution of event script while doing so.
        """

    keywords = ['Portrait']
    optional_keywords = ['SpeedMult']
    keyword_types = ['Portrait', 'Float']
    _flags = ["immediate", "no_block"]

class MultiRemovePortrait(EventCommand):
    nid = "multi_remove_portrait"
    nickname = "rr"
    tag = Tags.PORTRAIT

    desc = \
        """
Removes multiple portraits from the screen simultaneously.
        """

    keywords = ['Portrait1', 'Portrait2']
    optional_keywords = ['Portrait3', 'Portrait4']
    keyword_types = ['Portrait', 'Portrait', 'Portrait', 'Portrait']

class MovePortrait(EventCommand):
    nid = "move_portrait"
    tag = Tags.PORTRAIT

    desc = \
        """
Causes a portrait to "walk" from one screen position to another. Default *SpeedMult* is 1. Higher speeds are faster.

Extra flags:

1. *immediate*: Portrait will teleport instantly to the new position.
2. *no_block*: Portrait will walk as normal, but will not pause execution of event script while doing so.
        """

    keywords = ['Portrait', 'ScreenPosition']
    optional_keywords = ['SpeedMult']
    keyword_types = ['Portrait', 'ScreenPosition', 'Float']
    _flags = ["immediate", "no_block"]

class BopPortrait(EventCommand):
    nid = "bop_portrait"
    nickname = "bop"
    tag = Tags.PORTRAIT

    desc = \
        """
Causes a portrait to briefly bob up and down. Often used to illustrate a surprised or shocked reaction.
If the *no_block* flag is set, portrait bopping will not pause execution of event script.
        """

    keywords = ['Portrait']
    _flags = ["no_block"]

class MirrorPortrait(EventCommand):
    nid = "mirror_portrait"
    nickname = "mirror"
    tag = Tags.PORTRAIT

    desc = \
        """
The direction of the portrait is flipped across the Y axis.
        """

    keywords = ['Portrait']
    _flags = ["no_block"]

class Expression(EventCommand):
    nid = "expression"
    nickname = "e"
    tag = Tags.PORTRAIT

    desc = \
        """
Changes a portrait's facial expression.
        """

    keywords = ['Portrait', 'ExpressionList']

class SpeakStyle(EventCommand):
    nid = "speak_style"
    tag = Tags.DIALOGUE_TEXT

    desc = \
"""
Automatically formats all `speak` commands with NID equal to the style's NID with the style.

A style consists of all parameters that one can apply to individual speak commands, including flags.

NOTE: Speak styles persist through events. If you load your speak styles in the `on_title_screen` trigger, you will be able to use them
throughout the entire game.

NOTE: You can set the `__default` speak style, which will automatically apply to all speak commands thereafter.
"""

    keywords = ['Style']
    optional_keywords = ['Speaker', 'Position', 'Width', 'Speed', 'FontColor', 'FontType', 'Background', 'NumLines', 'DrawCursor', 'MessageTail', 'Transparency', 'NameTagBg']
    keyword_types = ['Nid', 'Speaker', 'AlignOrPosition', 'Width', 'Float', 'FontColor', 'Font', 'MaybeSprite', 'PositiveInteger', 'Bool', 'MaybeSprite', 'Float', 'MaybeSprite']
    _flags = ['low_priority', 'hold', 'no_popup', 'fit', 'no_talk', 'no_sound']

class Speak(EventCommand):
    nid = "speak"
    nickname = "s"
    tag = Tags.DIALOGUE_TEXT

    desc = \
        """
Causes the *Speaker* to speak some *Text*. If *Speaker* is a portrait nid that is currently displayed on screen,
*Text* will appear in a speech bubble from that portrait. If *Speaker* is left blank,
*Text* will appear in a box with no name label. For all other values of *Speaker*,
*Text* will appear in a box with the *Speaker* as the name label.

*TextSpeed* indicates the speed of the text - higher numbers are slower.

The pipe | symbol can be used within the *Text* body to insert a line break.

The *Nid* optional keyword changes how the text is displayed graphically, by accessing built-in speak styles.

1. *thought_bubble*: causes the text to be in a cloud-like thought bubble instead of a speech bubble.
2. *noir*: causes the speech bubble to be dark grey with white text.
3. *hint*: causes the text to be displayed in a hint box similar to tutorial information.
4. *narration*: causes the text to be displayed in a blue narration box at the bottom of the screen. No name label will be displayed.
5. *narration_top*: same as *narration* but causes the text box to be displayed at the top of the screen.

Extra flags:

1. *low_priority*: The speaker's portrait will not be moved in front of other overlapping portraits.
2. *hold*: The dialog box will remain even after the player has pressed A (useful for narration).
3. *no_popup*: The dialog box will not transition in, but rather will appear immediately.
4. *fit*: The dialog box will shrink to fit the text. (not needed if there is an associated portrait).
5. *no_block*: the speak command will not block event execution.
6. *no_talk*: The speaker's portrait will not "talk".
7. *no_sound*: The normal boop sound of dialog will be turned off
        """

    keywords = ['Speaker', 'Text']
    optional_keywords = ['TextPosition', 'Width', 'StyleNid', 'TextSpeed', 'FontColor', 'FontType', 'DialogBox', 'NumLines', 'DrawCursor', 'MessageTail', 'Transparency', 'NameTagBg']
    keyword_types = ['Speaker', 'Text', 'AlignOrPosition', 'Width', 'DialogVariant', 'Float', 'FontColor', 'Font', 'MaybeSprite', 'PositiveInteger', 'Bool', 'MaybeSprite', 'Float', 'MaybeSprite']
    _flags = ['low_priority', 'hold', 'no_popup', 'fit', 'no_block', 'no_talk', 'no_sound']

class Unhold(EventCommand):
    nid = "unhold"
    tag = Tags.DIALOGUE_TEXT

    desc = """
Remove a speak command from the screen. This is useful if you used the `hold` flag on a speak command earlier.

This will 'unhold' the speak command with the specified NID.
    """

    keywords = ['Nid']

class Unpause(EventCommand):
    nid = "unpause"
    tag = Tags.DIALOGUE_TEXT

    desc = """
Unpauses a previously paused text box. Has no effect if text box was not paused using `{p}` before.

This will 'unpause' the text box with the specified speaker NID.
    """

    keywords = ['Nid']

class Narrate(EventCommand):
    nid = "narrate"
    tag = Tags.DIALOGUE_TEXT

    desc = \
        """
Causes text to be displayed in the whole-screen narration frame.
Before using this command, the narration frame must be phased in using **toggle_narration_mode**.

Extra flags:

1. *no_block*: The event script will continue to execute while the narration text is being displayed.
        """

    keywords = ['Speaker', 'String']
    _flags = ['no_block']

class Transition(EventCommand):
    nid = "transition"
    nickname = "t"
    tag = Tags.BG_FG

    desc = \
        """
If a scene is currently displayed, it is faded out to a black screen.
The next use of this function will fade the scene back into view.
The optional *Speed* and *Color3* keywords control the speed and color of the transition.

Extra flags:

1. *no_block*: The event script will continue to execute while the screen is fading in or out
        """

    optional_keywords = ['Direction', 'Speed', 'Color3']
    _flags = ['no_block']

class ChangeBackground(EventCommand):
    # Also does remove background
    nid = "change_background"
    nickname = "b"
    tag = Tags.BG_FG

    desc = \
        """
Changes the dialogue scene's background image to *Panorama*. If no *Panorama* is specified,
the current background is removed without being replaced.
Displayed portraits are also removed unless the *keep_portraits* flag is set.
        """

    optional_keywords = ['Panorama']
    _flags = ["keep_portraits"]

class PauseBackground(EventCommand):
    nid = "pause_background"
    tag = Tags.BG_FG

    desc = \
        """
Pauses the current background if it has multiple frames. Optional *PauseAt* parameter lets you control exactly which frame to pause on.
        """

    optional_keywords = ['PauseAt']
    keyword_types = ['WholeNumber']

class UnpauseBackground(EventCommand):
    nid = "unpause_background"
    tag = Tags.BG_FG

    desc = \
        """
Unpauses the current background.
        """

class DispCursor(EventCommand):
    nid = "disp_cursor"
    tag = Tags.CURSOR_CAMERA

    desc = \
        """
Toggles whether the game's cursor is displayed.
        """

    keywords = ["ShowCursor"]
    keyword_types = ["Bool"]

class MoveCursor(EventCommand):
    nid = "move_cursor"
    nickname = "set_cursor"
    tag = Tags.CURSOR_CAMERA

    desc = \
        """
Moves the cursor to the map coordinate given by *Position*. The optional *Speed* keyword changes how fast the cursor moves.

Extra flags:

1. *immediate*: Causes the cursor to immediately jump to the target coordinates.
2. *no_block*: Event script will continue while cursor moves in background.
        """

    keywords = ["Position"]
    optional_keywords = ['Speed']
    _flags = ["immediate", "no_block"]


class CenterCursor(EventCommand):
    nid = "center_cursor"
    tag = Tags.CURSOR_CAMERA

    desc = \
        """
Similar to **move_cursor** except that it attempts to center the screen on the new cursor position to the greatest extent possible.

Extra flags:

1. *immediate*: Causes the cursor to immediately jump to the target coordinates.
2. *no_block*: Event script will continue while cursor moves in background.
        """

    keywords = ["Position"]
    optional_keywords = ['Speed']
    _flags = ["immediate", "no_block"]

class FlickerCursor(EventCommand):
    nid = 'flicker_cursor'
    nickname = 'highlight'
    tag = Tags.CURSOR_CAMERA

    desc = \
        """
Causes the cursor to briefly blink on and off at the indicated *Position*.
        """

    keywords = ["Position"]
    _flags = ["immediate"]

class ScreenShake(EventCommand):
    nid = 'screen_shake'
    tag = Tags.CURSOR_CAMERA

    desc = \
        """
Causes the map to shake rapidly, imitating an earthquake, powerful strike, or other effect.
Several different screen shake variations are available.
Set *Duration* to 0 to make screen shake effect last indefinitely.
        """

    keywords = ["Duration"]
    optional_keywords = ["ShakeType"]
    keyword_types = ["Time", "ShakeType"]
    _flags = ["no_block"]

class ScreenShakeEnd(EventCommand):
    nid = 'screen_shake_end'
    tag = Tags.CURSOR_CAMERA

    desc = \
        """
Ends any extant screen shake command if there is one present
        """

class GameVar(EventCommand):
    nid = 'game_var'
    nickname = 'gvar'
    tag = Tags.GAME_VARS

    desc = \
        """
Creates a game variable or changes its value. Game variables are preserved between chapters.
The *Nid* is the variable's identifier, and the *Condition* is the value that is given to the variable.
*Condition* can be a number or a Python expression.
        """
    keywords = ['Nid', 'Expression']
    keyword_types = ["GeneralVar", "Expression"]

class IncGameVar(EventCommand):
    nid = 'inc_game_var'
    nickname = 'ginc'
    tag = Tags.GAME_VARS

    desc = \
        """
Increments a game variable by one, or by a Python expression provided using the *Expression* optional keyword.
        """

    keywords = ["Nid"]
    optional_keywords = ["Expression"]
    keyword_types = ["GeneralVar", "Expression"]

class LevelVar(EventCommand):
    nid = 'level_var'
    nickname = 'lvar'
    tag = Tags.LEVEL_VARS

    desc = \
        """
Creates a level-specific variable or changes its value.
Level variables are deleted upon completion of a chapter.
The *Nid* is the variable's identifier, and the *Expression* is the
value that is given to the variable. *Expression* can be a number or a Python expression.
        """

    keywords = ["Nid", "Expression"]
    keyword_types = ["GeneralVar", "Expression"]

class IncLevelVar(EventCommand):
    nid = 'inc_level_var'
    nickname = 'linc'
    tag = Tags.LEVEL_VARS

    desc = \
        """
Increments a level variable by one, or by a Python expression provided using the *Expression* optional keyword.
        """

    keywords = ["Nid"]
    optional_keywords = ["Expression"]
    keyword_types = ["GeneralVar", "Expression"]

class SetNextChapter(EventCommand):
    nid = 'set_next_chapter'
    tag = Tags.GAME_VARS

    desc = \
        """
Sets the next chapter the player will go to
        """

    keywords = ["Chapter"]

class SetFogOfWar(EventCommand):
    nid = 'set_fog_of_war'
    tag = Tags.LEVEL_VARS

    desc = \
        """
Sets the fog of war state for the current level.
        """

    keywords = ["FogOfWarType", "Radius"]
    optional_keywords = ["AIRadius", "OtherRadius"]
    keyword_types = ["FogOfWarType", "PositiveInteger", "PositiveInteger", "PositiveInteger"]

class EnableFogOfWar(EventCommand):
    nid = 'enable_fog_of_war'
    tag = Tags.LEVEL_VARS

    desc = \
        """
Activates or deactivates base level of fog of war. Does not affect presence of fog or vision regions
        """

    keywords = ["Activated"]
    keyword_types = ['Bool']

class EnableSupports(EventCommand):
    nid = 'enable_supports'
    tag = Tags.GAME_VARS

    desc = \
        """
Activates or deactivates supports.
        """

    keywords = ["Activated"]
    keyword_types = ['Bool']

class EnableTurnwheel(EventCommand):
    nid = 'enable_turnwheel'
    tag = Tags.GAME_VARS

    desc = \
        """
Activates or deactivates turnwheel. You will also need the Constant
checked to see the turnwheel option in your menu.
        """

    keywords = ["Activated"]
    keyword_types = ['Bool']

class WinGame(EventCommand):
    nid = 'win_game'
    tag = Tags.LEVEL_VARS

    desc = \
        """
Ends the current chapter in victory.
        """

class LoseGame(EventCommand):
    nid = 'lose_game'
    tag = Tags.LEVEL_VARS

    desc = \
        """
Ends the current chapter in defeat. The game over screen will be displayed.
        """

class MainMenu(EventCommand):
    nid = 'main_menu'
    tag = Tags.LEVEL_VARS

    desc = \
        """
Returns the player to the main menu
        """

class ForceChapterCleanUp(EventCommand):
    nid = 'force_chapter_clean_up'
    tag = Tags.LEVEL_VARS

    desc = \
        """
Cleans up the chapter as if the chapter were about to end
What does it do?:
    - Increments End Chapter Supports
    - Resets all units, items, and skills
    - Resurrects units if you are in casual mode
    - Moves dead unit items to the convoy
    - Resets the turnwheel
    - Sets turncount to 1
Unlike a true chapter clean up, it doesn't:
    - Remove any units from the field
    - Remove all generic units from memory
    - Remove all now unused items and skills from memory
    - Remove any regions or terrain statuses
    - Reset level vars
    - Reset talk options or base convos
    - Actually remove the level
        """

class SkipSave(EventCommand):
    nid = 'skip_save'
    tag = Tags.LEVEL_VARS

    desc = \
    """
Sets whether or not to bring up the save screen after the level ends.
    """

    keywords = ["TrueOrFalse"]
    keyword_types = ["Bool"]

class ActivateTurnwheel(EventCommand):
    nid = 'activate_turnwheel'
    tag = Tags.MISCELLANEOUS

    desc = \
        """
Brings up the turnwheel interface to allow the player to roll back turns.
The optional *bool* keyword controls whether the player is forced to turn back time,
or whether it's optional (default = true = forced to).
        """

    # Whether to force the player to move the turnwheel back
    # defaults to true
    optional_keywords = ['Force']
    keyword_types = ['Bool']

class BattleSave(EventCommand):
    nid = 'battle_save'
    tag = Tags.MISCELLANEOUS

    desc = \
        """
The player is given the option of saving the game mid-battle.
This can be useful if the player chose Classic Mode,
as he or she would otherwise only be able to suspend and not save mid-battle.
        """

class ClearTurnwheel(EventCommand):
    nid = 'clear_turnwheel'
    tag = Tags.MISCELLANEOUS

    desc = \
        """
The turnwheel's history will be cleared. The player will not be able to
return to any action that occurs before this event.
        """

class ChangeTilemap(EventCommand):
    nid = 'change_tilemap'
    tag = Tags.TILEMAP

    desc = \
        """
Changes the current map to a different layout (*Tilemap*).
If the *reload* flag is set, the currently deployed units
and currently extant regions will be placed at their same positions
on the new tilemap.
If a *PositionOffset* is given, the units and regions will be reloaded but shifted by +x,+y.

Instead of reloading the units/regions from their current positions,
a second *Tilemap* optional keyword can be specified.
In this case, unit deployment will be loaded from that tilemap's previous data instead of from the current map.

Note that this command cannot be turnwheel'ed.
Players attempting to use the turnwheel will find that
they cannot turn time back past the point when this command was executed.
        """

    # Which tilemap to load the unit positions from
    keywords = ["Tilemap"]
    # How much to offset placed units by
    optional_keywords = ["PositionOffset", "LoadTilemap"]
    keyword_types = ["Tilemap", "PositionOffset", "Tilemap"]
    _flags = ["reload"]  # Should place units in previously recorded positions

class ChangeBgTilemap(EventCommand):
    nid = 'change_bg_tilemap'
    tags = Tags.TILEMAP

    desc = "Changes the bg tilemap for this level. Call without arguments to remove the bg tilemap. Can be turnwheeled, unlike `change_tilemap`."

    optional_keywords = ['Tilemap']
    keyword_types = ['Tilemap']

class SetGameBoardBounds(EventCommand):
    nid = 'set_game_board_bounds'
    tag = Tags.TILEMAP

    desc = \
        """
Instead of using the natural boundaries of the tilemap as the board boundaries,
specific bounds within the tilemap can be specified
Bounds must form a rectangle
        """

    keywords = ["MinX", "MinY", "MaxX", "MaxY"]
    keyword_types = ["WholeNumber", "WholeNumber", "WholeNumber", "WholeNumber"]

class RemoveGameBoardBounds(EventCommand):
    nid = 'remove_game_board_bounds'
    tag = Tags.TILEMAP

    desc = \
        """
Return to using the natural boundaries of the tilemap as the board boundaries
        """

class LoadUnit(EventCommand):
    nid = 'load_unit'
    tag = Tags.ADD_REMOVE_INTERACT_WITH_UNITS

    desc = \
        """
Loads a unique (non-generic) unit from memory.
This does not place the unit on the map. If the unit already exists in the game's memory, this command will do nothing.

Optionally, the loaded unit can be assigned to a *Team* and given an *AI* preset. If not specified, defaults of Player team and no AI script are applied.
        """

    keywords = ["UniqueUnit"]
    optional_keywords = ["Team", "AI"]

class MakeGeneric(EventCommand):
    nid = 'make_generic'
    tag = Tags.ADD_REMOVE_INTERACT_WITH_UNITS

    desc = \
        """
Fabricates a new generic unit from scratch. This does not place instances of the new unit on the map.

**If the NID field is left empty, then the event's `{created_unit}` will be overwritten to refer to the result of CreateUnit.**

Several optional keywords can also be provided to further modify the new unit:
*AI* defines an AI preset to be given to the unit, *Faction* assignes the unit
to one of the factions for the chapter, the unit can be given an animation variant
(*AnimationVariant*), and finally the unit can be given an inventory of items (*ItemList*).


        """

    # Nid, class, level, team, ai, faction, anim variant
    keywords = ["Nid", "Klass", "Level", "Team"]
    optional_keywords = ["AI", "Faction", "AnimationVariant", "ItemList"]
    keyword_types = ["Nid", "Klass", "PositiveInteger", "Team", "AI", "Faction", "Nid", "ItemList"]

class CreateUnit(EventCommand):
    nid = 'create_unit'
    tag = Tags.ADD_REMOVE_INTERACT_WITH_UNITS

    desc = \
        """
Creates a new instance of a unit and, optionally, places it on the map.
*Unit* points to the unit template to be used. A new nid can be assigned using *String* (can be empty: '').

**If the NID field is left empty, then the event's `{created_unit}` will be overwritten to refer to the result of CreateUnit.**

Several optional keywords can be provided to modify the unit and/or place it on the map.

Optional keywords can be specified to place the unit on the map.
The *Nid* value sets the unit's nid, if a specific nid is desired.
The *Level* value, if provided, sets the unit's level.
The *Position* value indicates the map coordinates that the unit will be placed at.
*EntryType* defines which placement animation is used.
Finally, *Placement* defines the behavior that occurs if the chosen map position is already occupied.

The optional flag *copy_stats* will cause the new unit to have exactly the same stats as the original *Unit*, rather than being calculated anew.
        """

    # Unit template
    keywords = ["Unit"]
    optional_keywords = ["Nid", "Level", "Position", "EntryType", "Placement"]
    keyword_types = ["Unit", "Nid", "PositiveInteger", "Position", "EntryType", "Placement"]
    _flags = ["copy_stats"]

class AddUnit(EventCommand):
    nid = 'add_unit'
    nickname = 'add'
    tag = Tags.ADD_REMOVE_INTERACT_WITH_UNITS

    desc = \
        """
Places *Unit* on the map. The unit must be in the chapter's data or otherwise have been loaded into memory (see **load_unit** or **make_generic**).

The optional keywords define how the unit is placed. *Position* indicates the map coordinates that the unit will be placed at.
*EntryType* defines which placement animation is used. *Placement* defines the behavior that occurs if the chosen map position is already occupied.
If no placement information is provided, the unit will attempt to be placed at its starting location from the chapter data (if any).
*AnimationType* defines from which direction the unit enters, if using the *fade* entrytype.
        """

    keywords = ["Unit"]
    optional_keywords = ["Position", "EntryType", "Placement", "AnimationType"]

class MoveUnit(EventCommand):
    nid = 'move_unit'
    nickname = 'move'
    tag = Tags.ADD_REMOVE_INTERACT_WITH_UNITS

    desc = \
        """
Causes *Unit* to move to a new position on the map.

The optional keywords define how the movement occurs.
*Position* indicates the target map coordinates. *MovementType* selects the method of movement.
*Placement* defines the behavior that occurs if the chosen map position is already occupied.
*Speed* defines the speed of the moving unit. 120 is the default. Lower numbers are faster and higher slower.

The *no_block* optional flag causes the event script to continue to execute while the unit is moving.
The *no_follow* flag prevents the camera from tracking the unit as it moves.
        """

    keywords = ["Unit"]
    optional_keywords = ["Position", "MovementType", "Placement", "Speed"]
    _flags = ['no_block', 'no_follow']

class RemoveUnit(EventCommand):
    nid = 'remove_unit'
    nickname = 'remove'
    tag = Tags.ADD_REMOVE_INTERACT_WITH_UNITS

    desc = \
        """
Removes *Unit* from the map. The optional *RemoveType* keyword specifies the method of removal.
If the `fade` RemoveType is chosen, the unit will use `AnimationType` to determine which direction
(if any) to fade into.
        """

    keywords = ["Unit"]
    optional_keywords = ["RemoveType", 'AnimationType']

class KillUnit(EventCommand):
    nid = 'kill_unit'
    nickname = 'kill'
    tag = Tags.ADD_REMOVE_INTERACT_WITH_UNITS

    desc = \
        """
Causes *Unit* to be removed from the map and marked as dead.
The *immediate* flag causes this to occur instantly without the normal map death animation.
        """

    keywords = ["Unit"]
    _flags = ['immediate']

class RemoveAllUnits(EventCommand):
    nid = 'remove_all_units'
    tag = Tags.ADD_REMOVE_INTERACT_WITH_UNITS

    desc = \
        """
Removes all units from the map.
        """

class RemoveAllEnemies(EventCommand):
    nid = 'remove_all_enemies'
    tag = Tags.ADD_REMOVE_INTERACT_WITH_UNITS

    desc = \
        """
Removes all units in the enemy team from the map.
        """

class InteractUnit(EventCommand):
    nid = 'interact_unit'
    nickname = 'interact'
    tag = Tags.ADD_REMOVE_INTERACT_WITH_UNITS

    desc = \
        """
Initiates a battle. The *Unit* will target the *Position* to start the combat.
A *CombatScript* can optionally be provided to ensure a pre-set outcome to the battle.
*Ability* can be used to specify which item or ability the attacker will use.
*PositiveInteger* can be set to determine the number of rounds the combat will go on for. Defaults to 1. Useful for arena combats (set to 20+).
The *arena* flag should be set when you want to allow the player to be able to press B and leave the combat between rounds. It also sets the combat background to the arena.
The *force_animation* flag tells the engine to ignore the player's settings and forcibly display a combat animation. Useful for arena combats.
        """

    keywords = ["Unit", "Position"]
    optional_keywords = ["CombatScript", "Ability", "Rounds"]
    keyword_types = ["Unit", "Position", "CombatScript", "Ability", "PositiveInteger"]
    _flags = ["arena", "force_animation"]

class SetName(EventCommand):
    nid = 'set_name'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Sets *Unit*'s name to *String*. This is permanent.
        """

    keywords = ["Unit", "String"]

class SetCurrentHP(EventCommand):
    nid = 'set_current_hp'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Sets *Unit*'s hit points to *HP*.
        """

    keywords = ["Unit", "HP"]
    keyword_types = ["Unit", "PositiveInteger"]

class SetCurrentMana(EventCommand):
    nid = 'set_current_mana'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Sets *Unit*'s mana to *Mana*.
        """

    keywords = ["Unit", "Mana"]
    keyword_types = ["Unit", "WholeNumber"]

class AddFatigue(EventCommand):
    nid = 'add_fatigue'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Modify *Unit*'s current fatigue level by *Integer*.
        """
    keywords = ["Unit", "Fatigue"]
    keyword_types = ["Unit", "Integer"]

class SetUnitField(EventCommand):
    nid = 'set_unit_field'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
    """
Set arbitrary property on _Unit_. **Note**: This cannot be used to set unit stats; if you try, you will simply set
a property called, for example, "STR", that has nothing to do with the unit's stats. This is for enabling unit-level
vars that are persisted across events.

If the flag `increment_mode` is supplied, this will add the value to the existing value instead instead of setting it.
Please try to avoid using `increment_mode` with non-numerical fields. That would erase your field and then nobody will be happy.
    """
    keywords = ["Unit", "Key", "Value"]
    keyword_types = ['Unit', 'UnitField', 'String']
    _flags = ['increment_mode']

class Resurrect(EventCommand):
    nid = 'resurrect'
    nickname = 'resurrect_unit'
    tag = Tags.ADD_REMOVE_INTERACT_WITH_UNITS

    desc = \
        """
Brings a dead unit back to life. This does not place the unit on the map.
        """

    keywords = ["GlobalUnit"]

class Reset(EventCommand):
    nid = 'reset'
    nickname = 'reset_unit'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Refreshes the unit so that it can act again this turn.
        """

    keywords = ["Unit"]

class HasAttacked(EventCommand):
    nid = 'has_attacked'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Sets the unit's state as having already attacked this turn.
        """

    keywords = ["Unit"]

class HasTraded(EventCommand):
    nid = 'has_traded'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Sets the unit's state as having already traded this turn. The unit can still attack, but can no longer move.
        """

    keywords = ['Unit']

class HasFinished(EventCommand):
    nid = 'has_finished'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Sets the unit's state as already having completed all of its actions this turn. The unit will be grayed out.
        """

    keywords = ['Unit']

class RecruitGeneric(EventCommand):
    nid = 'recruit_generic'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
"""
Convert a generic into a permanent party member.

You will have to rename this generic with a unique NID and a name.

Be extremely careful with this function. The new NID *must* be unique across every level.

Otherwise extremely undefined behavior can occur.
"""

    keywords = ['Unit', 'Nid', 'Name']
    keyword_types = ['Unit', 'Nid', 'String']

class AddGroup(EventCommand):
    nid = 'add_group'
    tag = Tags.UNIT_GROUPS

    desc = \
        """
Adds a unit group to the map. This will use the group's starting position data in the chapter by default.
Alternatively, a separate unit group nid can be provided as *StartingGroup* to cause the units to be placed at this other group's starting position.
*EntryType* selects the method of placement, and *Placement* defines the behavior that occurs if any of the chosen map positions are already occupied.

If the *create* flag is set, a copy of each unit will be created and deployed instead of using the unit itself.
        """

    keywords = ["Group"]
    optional_keywords = ["StartingGroup", "EntryType", "Placement"]
    _flags = ["create"]

class SpawnGroup(EventCommand):
    nid = 'spawn_group'
    tag = Tags.UNIT_GROUPS

    desc = \
        """
Causes a unit *Group* to arrive on the map from one of the *CardinalDirection*s.
*MovementType* selects the method of placement, and *Placement* defines the behavior that occurs if any of the chosen map positions are already occupied.

If the *create* flag is set, a copy of each unit will be created and deployed instead of using the unit itself.
*no_block* causes the script to continue executing while the units appear on the map. *no_follow* prevents the camera from focusing on the point where the units enter the map.
        """

    keywords = ["Group", "CardinalDirection", "StartingGroup"]
    optional_keywords = ["MovementType", "Placement"]
    _flags = ["create", "no_block", 'no_follow']

class MoveGroup(EventCommand):
    nid = 'move_group'
    nickname = 'morph_group'
    tag = Tags.UNIT_GROUPS

    desc = \
        """
Causes a unit *Group* to move to a new set of map positions specified using a different group's nid (*StartingGroup*).
*MovementType* selects the method of movement, and *Placement* defines the behavior that occurs if any of the chosen map positions are already occupied.

If the *no_block* flag is set, the script will continue to execute while the units move.
*no_follow* prevents the camera from following the movement of the units.
        """

    keywords = ["Group", "StartingGroup"]
    optional_keywords = ["MovementType", "Placement"]
    _flags = ['no_block', 'no_follow']

class RemoveGroup(EventCommand):
    nid = 'remove_group'
    tag = Tags.UNIT_GROUPS

    desc = \
        """
Removes a unit *Group* from the map. *RemoveType* selects the method of removal.
        """

    keywords = ["Group"]
    optional_keywords = ["RemoveType"]

class GiveItem(EventCommand):
    nid = 'give_item'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Gives a new copy of *Item* to *GlobalUnitOrConvoy*. If the *no_banner* flag is set, there will not be a banner announcing that "X unit got a Y item!".

If the unit's inventory is full, the player will be given the option of which item to send to the convoy.
If the *no_choice* flag is set, the new item will be automatically sent to the convoy in this case without prompting the player.
The *droppable* flag determines whether the item is set as a "droppable" item (generally only given to enemy units).
        """

    keywords = ["GlobalUnitOrConvoy", "Item"]
    _flags = ['no_banner', 'no_choice', 'droppable']

class EquipItem(EventCommand):
    nid = 'equip_item'
    tag = Tags.MODIFY_UNIT_PROPERTIES
    desc = \
        """
Forces *GlobalUnit* to equip *Item*.

The event will produce no effect if the item does not exist in the unit's inventory yet.
It will also produce no effect if the item cannot be equipped by that unit.
If the item chosen is a multi-item, the top-most valid option will be equipped.
If the *recursive* flag is set, the event will first attempt to equip items directly
in the unit's inventory, and then if no matching item is found, check the sub-items of multi-items.
        """

    keywords = ["GlobalUnit", "Item"]
    _flags = ['recursive']

class RemoveItem(EventCommand):
    nid = 'remove_item'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Removes *Item* from the inventory of *GlobalUnitOrConvoy*.
If the *no_banner* flag is set, there will not be a banner announcing that "X unit lost a Y item!".
Also, if the item is removed from the convoy, there will not be a banner.
        """

    keywords = ["GlobalUnitOrConvoy", "Item"]
    _flags = ['no_banner']

class MoveItem(EventCommand):
    nid = 'move_item'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Removes *Item* from the inventory of *Giver* and adds it to the inventory of *Receiver*.
If *Item* is not supplied, just moves the last item from the inventory of *Giver*.
If the inventory of *Receiver* is full, this command will not succeed.
        """

    keywords = ["Giver", "Receiver"]
    optional_keywords = ["Item"]
    keyword_types = ["GlobalUnitOrConvoy", "GlobalUnitOrConvoy", "Item"]

class MoveItemBetweenConvoys(EventCommand):
    nid = 'move_item_between_convoys'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Moves *Item* from the convoy of *Party1* and adds it to the convoy of *Party2*.
        """

    keywords = ["Item", "Party1", "Party2"]
    keyword_types = ["Item", "Party", "Party"]

class SetItemUses(EventCommand):
    nid = 'set_item_uses'
    tag = Tags.MODIFY_ITEM_PROPERTIES

    desc = \
        """
Sets the uses of an *Item* to *Uses* in the inventory of *GlobalUnitOrConvoy*.
If the *recursive* flag is set, the event will first attempt to equip items directly
in the unit's inventory, and then if no matching item is found, check the sub-items of multi-items.

*  the *additive* flag adds the given uses instead
        """

    keywords = ["GlobalUnitOrConvoy", "Item", "Uses"]
    keyword_types = ["GlobalUnitOrConvoy", "Item", "Integer"]

    _flags = ["additive", "recursive"]

class BreakItem(EventCommand):
    nid = 'break_item'
    tag = Tags.MODIFY_ITEM_PROPERTIES

    desc = \
        """
Breaks *Item* in inventory of *GlobalUnitOrConvoy*, setting uses to 0.
Will behave as if the item had been broken in combat,
including notifying the player.
If the *no_banner* flag is set, there will not be a banner announcing that the item has been broken.
        """

    keywords = ["GlobalUnitOrConvoy", "Item"]
    _flags = ['no_banner']


class SetItemData(EventCommand):
    nid = 'set_item_data'
    tag = Tags.MODIFY_ITEM_PROPERTIES

    desc = \
        """
Finds the *Item* in the inventory of *GlobalUnitOrConvoy*.
Then, it sets the data field *Nid* of the *Item* to *Expression*.
        """

    keywords = ["GlobalUnitOrConvoy", "Item", "Nid", "Expression"]

class ChangeItemName(EventCommand):
    nid = 'change_item_name'
    tag = Tags.MODIFY_ITEM_PROPERTIES

    desc = \
        """
Changes the name of *Item* in the inventory of *GlobalUnitOrConvoy* to *String*.
        """

    keywords = ["GlobalUnitOrConvoy", "Item", "String"]

class ChangeItemDesc(EventCommand):
    nid = 'change_item_desc'
    tag = Tags.MODIFY_ITEM_PROPERTIES

    desc = \
        """
Changes the description of *Item* in the inventory of *GlobalUnitOrConvoy* to *String*.
        """

    keywords = ["GlobalUnitOrConvoy", "Item", "String"]

class AddItemToMultiitem(EventCommand):
    nid = 'add_item_to_multiitem'
    tag = Tags.MODIFY_ITEM_PROPERTIES

    desc = \
        """
Adds a new item to an existing multi-item in the inventory of *GlobalUnitOrConvoy*.

Flags:
-`no_duplicate` will not add if the item already exists on the multi-item.
If the *equip* flag is set, the unit will automatically equip the added item.
        """

    keywords = ["GlobalUnitOrConvoy", "MultiItem", "ChildItem"]
    keyword_types = ["GlobalUnitOrConvoy", "Item", "Item"]
    _flags = ['no_duplicate', 'equip']

class RemoveItemFromMultiitem(EventCommand):
    nid = 'remove_item_from_multiitem'
    tag = Tags.MODIFY_ITEM_PROPERTIES

    desc = \
        """
Removes an item from an existing multi-item in the inventory of *GlobalUnitOrConvoy*.
If *ChildItem* is not specified, all items will be removed form the existing multi-item in the inventory of *GlobalUnitOrConvoy*.
        """

    keywords = ["GlobalUnitOrConvoy", "MultiItem"]
    optional_keywords = ['ChildItem']
    keyword_types = ["GlobalUnitOrConvoy", "Item", "Item"]

class AddItemComponent(EventCommand):
    nid = 'add_item_component'
    tag = Tags.MODIFY_ITEM_PROPERTIES

    desc = \
        """
Adds an *ItemComponent* with optional value of *Expression* to *Item* in the inventory of *GlobalUnitOrConvoy*.
Can be used to modify a specific item within your game, such as for forging.
        """

    keywords = ["GlobalUnitOrConvoy", "Item", "ItemComponent"]
    optional_keywords = ["Expression"]

class ModifyItemComponent(EventCommand):
    nid = 'modify_item_component'
    tag = Tags.MODIFY_ITEM_PROPERTIES

    desc = \
        """
Sets the value of an *ItemComponent* to *Expression* for an *Item* in the inventory of *GlobalUnitOrConvoy*.
Can be used to modify a specific item within your game, such as for forging.

Use **ComponentProperty* to change a specific value if the ItemComponent has more than one option available.

Use the *additive* flag to add rather than set the value.
        """

    keywords = ["UnitOrConvoy", "Item", "ItemComponent", "Expression"]
    optional_keywords = ["ComponentProperty"]
    keyword_types = ["GlobalUnitOrConvoy", "Item", "ItemComponent", "Expression", "String"]
    _flags = ['additive']

class RemoveItemComponent(EventCommand):
    nid = 'remove_item_component'
    tag = Tags.MODIFY_ITEM_PROPERTIES

    desc = \
        """
Removes *ItemComponent* from *Item* in the inventory of *GlobalUnitOrConvoy*.
        """

    keywords = ["GlobalUnitOrConvoy", "Item", "ItemComponent"]

class GiveMoney(EventCommand):
    nid = 'give_money'
    tag = Tags.GAME_VARS

    desc = \
        """
Gives *Money* to the indicated *Party*.
If *Party* is not specified, the player's current party will be used.
If the *no_banner* flag is set, there will not be a banner announcing that the player "received X gold!".
        """

    keywords = ["Money"]
    optional_keywords = ["Party"]
    keyword_types = ["Integer", "Party"]
    _flags = ['no_banner']

class GiveBexp(EventCommand):
    nid = 'give_bexp'
    tag = Tags.GAME_VARS

    desc = \
        """
Gives bonus experience of the amount defined by *Integer* to the indicated *Party*.
If *Party* is not specified, the player's current party will be used.
The optional *String* keyword specifies what text is shown to the player in the banner.
If *String* is not specified, the banner will state "Got X BEXP".
If the *no_banner* flag is set, the player will not be informed that the bonus experience was awarded.
        """

    keywords = ["Bexp"]
    optional_keywords = ["Party", "String"]
    keyword_types = ["Integer", "Party", "String"]
    _flags = ['no_banner']

class GiveExp(EventCommand):
    nid = 'give_exp'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Gives *Experience* to *GlobalUnit*.
        """

    keywords = ["GlobalUnit", "Experience"]
    keyword_types = ["GlobalUnit", "Integer"]

    _flags = ['silent']

class SetExp(EventCommand):
    nid = 'set_exp'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Sets *GlobalUnit*'s current experience to *Experience*.
        """

    keywords = ["GlobalUnit", "Experience"]
    keyword_types = ["GlobalUnit", "WholeNumber"]

class GiveWexp(EventCommand):
    nid = 'give_wexp'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Gives a *PositiveInteger* amount of weapon experience in *WeaponType* to *GlobalUnit*. If the *no_banner* flag is set, the player will not be informed that weapon experience was awarded.
        """

    keywords = ["GlobalUnit", "WeaponType", "PositiveInteger"]
    _flags = ['no_banner']

class GiveSkill(EventCommand):
    nid = 'give_skill'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
*GlobalUnit* gains *Skill*. If the *no_banner* flag is set, the player will not be informed of this.
Optional *Initiator* global unit can be given to give the skill an initiator.
         """

    keywords = ["GlobalUnit", "Skill"]
    optional_keywords = ["Initiator"]
    keyword_types = ["GlobalUnit", "Skill", "GlobalUnit"]
    _flags = ['no_banner']

class RemoveSkill(EventCommand):
    nid = 'remove_skill'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
*GlobalUnit* loses *Skill* up to *Count* times. If *Count* is not set, all instances of skill are removed. If the *no_banner* flag is set, the player will not be informed of this.
        """

    keywords = ["GlobalUnit", "Skill"]
    optional_keywords = ['Count']
    keyword_types = ['GlobalUnit', 'Skill', 'Integer']
    _flags = ['no_banner']

class SetSkillData(EventCommand):
    nid = 'set_skill_data'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Finds the first matching *Skill* of *GlobalUnit*.
Then, it sets the data field *Nid* of the *Skill* to *Expression*.


As an example, you could change the number of charges a skill has using this.

`set_skill_data;Eirika;Luna;charge;5`

In general, you need to know how the innards of a given skill component
interacts with the data of the skill to use this command.
        """

    keywords = ["GlobalUnit", "Skill", "Nid", "Expression"]

class ChangeAI(EventCommand):
    nid = 'change_ai'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Sets the *AI* used by *GlobalUnit*.
        """

    keywords = ["GlobalUnit", "AI"]

class ChangeParty(EventCommand):
    nid = 'change_party'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Changes the *Party* of *GlobalUnit*. Used for games in which the player's units are divided into multiple parties.
        """

    keywords = ["GlobalUnit", "Party"]

class ChangeFaction(EventCommand):
    nid = 'change_faction'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Changes the *Faction* of *GlobalUnit*.
        """

    keywords = ["GlobalUnit", "Faction"]


class ChangeTeam(EventCommand):
    nid = 'change_team'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Changes *GlobalUnit*'s *Team*. For example, this can recruit an enemy unit to the player's team in a Talk event script.
        """

    keywords = ["GlobalUnit", "Team"]

class ChangePortrait(EventCommand):
    nid = 'change_portrait'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Changes *GlobalUnit*'s portrait to the one specified by *PortraitNid*.
        """

    keywords = ["GlobalUnit", "PortraitNid"]

class ChangeUnitDesc(EventCommand):
    nid = 'change_unit_desc'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Changes *GlobalUnit*'s description to *String*.
        """
    keywords = ["GlobalUnit", "String"]

class ChangeStats(EventCommand):
    nid = 'change_stats'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Changes the stats (STR, SKL, etc.) of *GlobalUnit*. The *StatList* defines the changes to be applied. This will display the unit's stat changes similarly to a level-up unless the *immediate* flag is set.
        """

    keywords = ["GlobalUnit", "StatList"]
    _flags = ['immediate']

class SetStats(EventCommand):
    nid = 'set_stats'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Sets the stats (STR, SKL, etc.) of *GlobalUnit* to specific values defined in *StatList*. This will display the unit's stat changes similarly to a level-up unless the *immediate* flag is set.
        """

    keywords = ["GlobalUnit", "StatList"]
    _flags = ['immediate']

class ChangeGrowths(EventCommand):
    nid = 'change_growths'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Changes the growths (STR, SKL, etc.) of *GlobalUnit*. The *StatList* defines the changes to be applied. Always silent.
        """

    keywords = ["GlobalUnit", "StatList"]

class SetGrowths(EventCommand):
    nid = 'set_growths'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Sets the growths (STR, SKL, etc.) of *GlobalUnit* to specific values defined in *StatList*. Always silent.
        """

    keywords = ["GlobalUnit", "StatList"]

class SetUnitLevel(EventCommand):
    nid = 'set_unit_level'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Sets *GlobalUnit*'s level to the specified value. Does not change stats like a levelup.
        """

    keywords = ["GlobalUnit", "Level"]
    keyword_types = ["GlobalUnit", "Integer"]

class AutolevelTo(EventCommand):
    nid = 'autolevel_to'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Levels *GlobalUnit* up to *Level*.
If *GrowthMethod* is not specified, the unit will use whatever they would normally use for the player's selected difficulty setting.
If the *hidden* flag is set, the unit still gains the effects of the indicated level-ups, but its actual level is not incremented. In other words, the unit gets more powerful but remains at the same level.
        """

    keywords = ["GlobalUnit", "Level"]
    optional_keywords = ["GrowthMethod"]
    keyword_types = ["GlobalUnit", "Integer", "GrowthMethod"]
    # Whether to actually change the unit's level
    _flags = ["hidden"]

class SetModeAutolevels(EventCommand):
    nid = 'set_mode_autolevels'
    tag = Tags.GAME_VARS

    desc = \
        """
Changes the number of additional levels that enemy units gain from the difficulty mode setting. This can be used to grant a higher number of bonus levels to enemies later in the game to maintain a resonable difficulty curve. *Level* specifies the number of levels to be granted. If the *hidden* flag is set, enemy units will still gain the effects of the indicated level-ups, but their actual level is not incremented. In other words, the units get more powerful but remains at the same level. If the *boss* flag is included, this will only affect units with the "Boss" tag.
        """

    keywords = ["Level"]
    keyword_types = ["Integer"]
    # Whether to actually change the unit's level
    _flags = ["hidden", "boss"]

class Promote(EventCommand):
    nid = 'promote'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Promotes *GlobalUnit* into a specified class (*Klass*) or, if no *Klass* is given, the unit promotes as normal using its promotion data. If more than one *Klass* is given (comma-delimited), the player will receive a promotion choice menu.
If the *silent* flag is given, the unit will promote immediately into the specified class (*Klass*).
        """

    keywords = ["GlobalUnit"]
    optional_keywords = ["KlassList"]
    _flags = ["silent"]

class ChangeClass(EventCommand):
    nid = 'change_class'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Changes *GlobalUnit* into a specified class (*Klass*) or, if no *Klass* is given, the unit class changes as normal using its alternative class data.
If the *silent* flag is given, the unit will change class immediately into the specified class (*Klass*).
        """

    keywords = ["GlobalUnit"]
    optional_keywords = ["KlassList"]
    _flags = ["silent"]

class AddTag(EventCommand):
    nid = 'add_tag'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Adds a *Tag* to *GlobalUnit*. Examples would include "Lord", "Armor", "Boss", etc.
        """

    keywords = ["GlobalUnit", "Tag"]

class RemoveTag(EventCommand):
    nid = 'remove_tag'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Removes a *Tag* from *GlobalUnit*.
        """

    keywords = ["GlobalUnit", "Tag"]

class AddTalk(EventCommand):
    nid = 'add_talk'
    tag = Tags.LEVEL_VARS

    desc = \
        """
Adds the ability for the two indicated units to "Talk" in the current chapter. The first *Unit* will be able to initiate conversation with the second *Unit*.
        """

    keywords = ["Unit1", "Unit2"]
    keyword_types = ["Unit", "Unit"]

class RemoveTalk(EventCommand):
    nid = 'remove_talk'
    tag = Tags.LEVEL_VARS

    desc = \
        """
Removes the ability for the two indicated units to "Talk" in the current chapter. You probably want to use this after the dialogue scene between the two units.
        """

    keywords = ["Unit1", "Unit2"]
    keyword_types = ["Unit", "Unit"]

class AddLore(EventCommand):
    nid = 'add_lore'
    nickname = 'unlock_lore'

    desc = \
        """
Unlocks the player's ability to read the specified game *Lore* entry.
        """

    tag = Tags.GAME_VARS

    keywords = ["Lore"]

class RemoveLore(EventCommand):
    nid = 'remove_lore'
    tag = Tags.GAME_VARS

    desc = \
        """
Removes the player's ability to read the specified game *Lore* entry.
        """

    keywords = ["Lore"]

class AddBaseConvo(EventCommand):
    nid = 'add_base_convo'
    tag = Tags.LEVEL_VARS

    desc = \
        """
Unlocks a base conversation specified by *Nid* for later viewing by the player.
        """

    keywords = ["Nid"]

class IgnoreBaseConvo(EventCommand):
    nid = 'ignore_base_convo'
    tag = Tags.LEVEL_VARS

    desc = \
        """
Sets the base conversation specified by *Nid* to unselectable and greyed-out, but still visible. You usually want to use this at the end of a base convo to prevent the player from viewing it again.
        """

    keywords = ["Nid"]
    optional_keywords = ["Ignore"]
    keyword_types = ["Nid", "Bool"]

class RemoveBaseConvo(EventCommand):
    nid = 'remove_base_convo'
    tag = Tags.LEVEL_VARS

    desc = \
        """
Removes the base conversation specified by *Nid* from the list entirely unless it is later re-added using **add_base_convo**.
        """

    keywords = ["Nid"]

class IncrementSupportPoints(EventCommand):
    nid = 'increment_support_points'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Adds support points between the two specified units.
        """

    keywords = ['Unit1', 'Unit2', 'SupportPoints']
    keyword_types = ['GlobalUnit', 'GlobalUnit', 'PositiveInteger']

class UnlockSupportRank(EventCommand):
    nid = 'unlock_support_rank'
    tag = Tags.MODIFY_UNIT_PROPERTIES

    desc = \
        """
Unlocks the specific *SupportRank* between the two specified units.
        """

    keywords = ['Unit1', 'Unit2', 'SupportRank']
    keyword_types = ['GlobalUnit', 'GlobalUnit', 'SupportRank']

class AddMarketItem(EventCommand):
    nid = 'add_market_item'
    tag = Tags.GAME_VARS

    desc = \
        """
Adds *Item* to the list of purchaseable goods in the base's market. If the optional *Stock* is supplied, adds that amount of stock of the item to the base's market.
        """

    keywords = ["Item"]
    optional_keywords = ["Stock"]
    keywords_types = ["Item", "WholeNumber"]

class RemoveMarketItem(EventCommand):
    nid = 'remove_market_item'
    tag = Tags.GAME_VARS

    desc = \
        """
Removes *Item* from the list of purchaseable goods in the base's market. If the optional *Stock* is supplied, removes that amount of stock of the item from the base's market.
        """

    keywords = ["Item"]
    optional_keywords = ["Stock"]
    keywords_types = ["Item", "WholeNumber"]

class ClearMarketItems(EventCommand):
    nid = 'clear_market_items'
    tag = Tags.GAME_VARS

    desc = \
        """
Removes all items from the list of purchaseable goods in the base's market.
        """

class AddRegion(EventCommand):
    nid = 'add_region'
    tag = Tags.REGION

    desc = \
        """
Adds a new region to the map that can be referenced by events. *Nid* will be the new regions identifier. *Position* is the map coordinate desired for the upper-left corner of the new region. *Size* is the dimensions of the new region. *RegionType* defines the type of region that is created (status region, etc.).

The optional *String* keyword can be used to specify the sub-region type.

When set, the *only_once* flag applies only to event region, preventing them from being used more than once. The *interrupt_move* flag halts a unit's movement once they move into the region.
        """

    keywords = ["Region", "Position", "Size", "RegionType"]
    optional_keywords = ["String", "TimeLeft"]
    keyword_types = ["Region", "Position", "Size", "RegionType", "String", "PositiveInteger"]
    _flags = ["only_once", "interrupt_move"]

class RegionCondition(EventCommand):
    nid = 'region_condition'
    tag = Tags.REGION

    desc = \
        """
Modifies the trigger *Expression* for the event-type region specified by *Region*.
        """

    keywords = ["Region", "Expression"]

class RemoveRegion(EventCommand):
    nid = 'remove_region'
    tag = Tags.REGION

    desc = \
        """
Removes the region specified by *Region*.
        """

    keywords = ["Region"]

class RemoveGenericsFromRegion(EventCommand):
    nid = 'remove_generics_from_region'
    tag = Tags.REGION

    desc = \
        """
Removes all generics in the given region.
        """

    keywords = ["Nid"]

class ShowLayer(EventCommand):
    nid = 'show_layer'
    tag = Tags.TILEMAP

    desc = \
        """
Causes the specified map *Layer* to be displayed. The optional *LayerTransition* keyword controls whether the layer fades in (default) or is immediately displayed.
        """

    keywords = ["Layer"]
    optional_keywords = ["LayerTransition"]

class HideLayer(EventCommand):
    nid = 'hide_layer'
    tag = Tags.TILEMAP

    desc = \
        """
Causes the specified map *Layer* to be hidden. The optional *LayerTransition* keyword controls whether the layer fades out (default) or is immediately hidden.
        """

    keywords = ["Layer"]
    optional_keywords = ["LayerTransition"]

class AddWeather(EventCommand):
    nid = 'add_weather'
    tag = Tags.TILEMAP

    desc = \
        """
Adds the specified *Weather* to the current map.
        """

    keywords = ["Weather"]
    optional_keywords = ["Position"]

class RemoveWeather(EventCommand):
    nid = 'remove_weather'
    tag = Tags.TILEMAP

    desc = \
        """
Removes the specified *Weather* from the current map.
        """

    keywords = ["Weather"]
    optional_keywords = ["Position"]

class ChangeObjectiveSimple(EventCommand):
    nid = 'change_objective_simple'
    tag = Tags.LEVEL_VARS

    desc = \
        """
Changes the simple version of the chapter's objective text to *String*.
        """

    keywords = ["String"]

class ChangeObjectiveWin(EventCommand):
    nid = 'change_objective_win'
    tag = Tags.LEVEL_VARS

    desc = \
        """
Changes the victory condition of the chapter's objective text to *String*.
        """

    keywords = ["String"]

class ChangeObjectiveLoss(EventCommand):
    nid = 'change_objective_loss'
    tag = Tags.LEVEL_VARS

    desc = \
        """
Changes the defeat condition of the chapter's objective text to *String*.
        """

    keywords = ["String"]

class SetPosition(EventCommand):
    nid = 'set_position'
    tag = Tags.MISCELLANEOUS

    desc = \
        """
Stores a given position as the event's home position. It can later be referenced in this event script using {position}.
        """

    keywords = ["Position"]

class MapAnim(EventCommand):
    nid = 'map_anim'
    tag = Tags.TILEMAP
    desc = \
'''Plays a map animation denoted by the nid *MapAnim* at *Position*. Optional args: a speed multiplier
which increases the length of time it takes to play the animation (larger is slower).

Flags:
* *no_block* - whether to wait until the animation finishes to continue
* *permanent* - whether the effect persists
* *blend* - additive blending
* *multiply* - multiplicative blending
* *overlay* - whether the animation will be played above units or below units
'''

    keywords = ["MapAnim", "FloatPosition"]
    optional_keywords = ["Speed"]
    keyword_types = ["MapAnim", "FloatPosition", "Float"]
    _flags = ["no_block", "permanent", "blend", "multiply", "overlay"]

class RemoveMapAnim(EventCommand):
    nid = 'remove_map_anim'
    tag = Tags.TILEMAP
    desc = ('Removes a map animation denoted by the nid *MapAnim* at *Position*. Only removes MapAnims that were created using'
            ' the "permanent" flag')
    keywords = ["MapAnim", "Position"]
    _flags = ['overlay']

class AddUnitMapAnim(EventCommand):
    nid = 'add_unit_map_anim'
    tag = Tags.MODIFY_UNIT_PROPERTIES
    desc = ('Plays a map animation denoted by the nid *MapAnim* on *Unit*. Optional args: a speed multiplier'
            ' which increases the length of time it takes to play the animation (larger is slower)')
    keywords = ["MapAnim", "Unit"]
    optional_keywords = ["Speed"]
    keyword_types = ["MapAnim", "Unit", "Float"]
    _flags = ["no_block", "permanent", "blend"]

class RemoveUnitMapAnim(EventCommand):
    nid = 'remove_unit_map_anim'
    tag = Tags.MODIFY_UNIT_PROPERTIES
    desc = ('Removes a map animation denoted by the nid *MapAnim* from *Unit*. Only removes MapAnims that were created using'
            ' the "permanent" flag')
    keywords = ["MapAnim", "Unit"]

class MergeParties(EventCommand):
    nid = 'merge_parties'
    tag = Tags.MISCELLANEOUS
    # Merges the second party onto the first party
    # The second will still exist, but will have no money, bexp,
    # items in convoy, or units associated with it
    # The first will gain all of those properties

    desc = \
        """
Merges two parties together. The second specified party's units, money, and bonus experience will be added to the first specified party. Note that the second party will still exist but will now be empty.
        """

    keywords = ["Party1", "Party2"]
    keyword_types = ["Party", "Party"]

class ArrangeFormation(EventCommand):
    nid = 'arrange_formation'
    tag = Tags.MISCELLANEOUS
    # Puts units on formation tiles automatically

    desc = \
        """
Places units on the map's formation tiles automatically.
        """

class Prep(EventCommand):
    nid = 'prep'
    tag = Tags.MISCELLANEOUS

    desc = \
        """
Display the prep screen.

Optional args:
* *PickUnitsEnabled* sets whether the "Pick Units" menu will be available in the prep screen.
* The optional *Music* keyword specifies the music track that will be played during the preparations menu.
* *OtherOptions* is a list of strings (Option1, Option2, Option3) that specify additional option names to display in the base.
* *OtherOptionsEnabled* is a list of string bools (e.g. true, false, false) that specify which of the OtherOptions are enabled. If blank, all OtherOptions will be enabled by default.
* *OtherOptionsOnSelect* is a list of Event NIDs or Event Names. These events will be triggered when the corresponding OtherOptions are selected.

        """

    optional_keywords = ['PickUnitsEnabled', 'Music', 'OtherOptions', 'OtherOptionsEnabled', 'OtherOptionsOnSelect']
    keyword_types = ["Bool", "Music", "StringList", "StringList", "StringList"]


class Base(EventCommand):
    nid = 'base'
    tag = Tags.MISCELLANEOUS

    desc = \
"""
When called, the player is sent to the Base menu. The *Background* and *Music* keywords specify the background image and the music track that will be played for the base.

Optional args:
* *Music* specify which music track will play for the base.
* *OtherOptions* is a list of strings (Option1, Option2, Option3) that specify additional option names to display in the base.
* *OtherOptionsEnabled* is a list of string bools (e.g. true, false, false) that specify which of the OtherOptions are enabled. If blank, all OtherOptions will be enabled by default.
* *OtherOptionsOnSelect* is a list of Event NIDs or Event Names. These events will be triggered when the corresponding OtherOptions are selected.

Flags:
* *show_map* determines whether or not the background will simply be the map of the mission.
"""

    keywords = ["Background"]
    optional_keywords = ["Music", 'OtherOptions', 'OtherOptionsEnabled', 'OtherOptionsOnSelect']
    keyword_types = ['Panorama', 'Music', "StringList", "StringList", "StringList"]
    _flags = ["show_map"]

class Shop(EventCommand):
    nid = 'shop'
    tag = Tags.MISCELLANEOUS

    desc = \
        """
Causes *Unit* to enter a shop that sells *ItemList* items. The optional *ShopFlavor* keyword determines whether the shop appears as a vendor or an armory. The optional *StockList* keyword determines if an item should have a limited stock. The order will be the same as ItemList. Use -1 for unlimited stock.
        """

    keywords = ["Unit", "ItemList"]
    optional_keywords = ["ShopFlavor", "StockList"]
    keyword_types = ["Unit", "ItemList", "ShopFlavor", "IntegerList"]

class Choice(EventCommand):
    nid = 'choice'
    tag = Tags.MISCELLANEOUS

    desc = \
        """
Presents the player with a menu in which he/she can choose from several options. An example would be the choice to go with Eirika or Ephraim in The Sacred Stones.

The result of the selection is stored in the game_var `$(nid)` - e.g. `routesplit` for a choice with NID `routesplit`.

The current selection is stored in the game_var `$(nid)_choice_hover` - e.g. `routesplit_choice_hover` for a choice with NID `routesplit`.

The outcome of the previous choice dialog can be accessed in `_last_choice`.

* *Nid* is the name of this choice, which can be checked later to recall the player's decision.
* *Title* is the text describing the choice, such as "which will you choose?"
* *Choices* is one of two things. It can be a *StringList*, i.e. a list of string choices, or it can be a Python Expression, which refers to a list of string choices.
For example, `Eirika, Ephraim, Seth` would be a list of string choices. `[unit.nid for unit in game.get_units_in_party()]` is an expression that would evaluate to `Eirika, Ephraim, Seth`.
What is the difference? The Python Expression will be constantly updated, which means that if the party changes, the choices will automatically change as well.

**NOTE: Use the flags to determine the correct type.**

**NOTE:** You can use the `|` delimiter to mark a distinction between the nid of a choice, and the text of a choice, if the nid is not meant to be read.
For example, suppose you give the player a choice between two klasses, and these klasses are called ArmorKnight\_Sun and ArmorKnight\_Moon. Obviously, you don't
want the player to be forced to read the weird nid. You can instead populate the choices like so:

`choice;ClassSelection;Choose Class; ArmorKnight_Sun|Solar Knight,ArmorKnight_Moon|Lunar Knight;...`

And the choice will use `Solar Knight` and `Lunar Knight` as its text.

Optional args:

* *RowWidth* allows you to specify the specific width of each row.
* The *Orientation* keyword specifies whether the options are displayed as a vertical list or side-by-side.
* The *Alignment* keyword specifies where on the screen the choice box will be displayed.
* *BG* specifies what base image to use as background. menu_bg images will be tiled, while other sprites will not.
* The *Event* keyword gives you the option to call an event on selection, if you should so choose. The new event will have the same args {unit}, {unit2} etc. as the current event.
* The *Type* keyword specifies the specific type of the options, and will change the way the entries are displayed.
* The *Dimensions* keyword allows you to specify the size of the list in `(rows, columns)`.
* The *TextAlign* keyword specifies the alignment of the choice text

* *type_skill* will interpret all options as skill NIDs
* *type_base_item* will interpret all options as item NIDs
* *type_game_item* will interpret all options as item UIDs (i.e. actual items in game - important if you want to distiguish between a 1/40 vs 40/40 Iron Sword, for example)
* *type_unit* will interpret all options as unit NIDs
* *type_class* will interpret all options as class NIDs.
* *type_icon* will use the following syntax: `iconsheetnid-iconx-icony-choicetext`, and will display the specific icon16 alongside the choice.
* *type_portrait* will interpret the options as portrait NIDs.
* *type_chibi* will interpret the options as unit nids, and draw the chibi corresponding.

* The *persist* flag indicates whether or not the choice ends after you make a selection. If *persist* is true, then the choice can only be exited
via hitting the back button, and the event will go on as normal.

* The *expression* flag indicates that the provided table data should be be continually parsed as a python expression and updated.
* The *no_bg* flag removes the bg.
* *no_cursor* removes the cursor.
* *arrows* adds pulsing left/right arrows.
* *scroll_bar* adds a vertical scroll bar
* *backable* allows you to exit out of the menu without making a choice - similarly to *persist*. If backed out in this way, will set `BACK` as the chosen option.
 """

    keywords = ['Nid', 'Title', 'Choices']
    optional_keywords = ['RowWidth', 'Orientation', 'Alignment', 'BG', 'EventNid', 'EntryType', 'Dimensions', 'TextAlign']
    keyword_types = ['GeneralVar', 'String', 'String', 'Width', 'Orientation', 'Align', 'Sprite', 'Event', 'TableEntryType', 'Size', 'HAlign']
    _flags = ['persist', 'expression', 'no_bg', 'no_cursor', 'arrows', 'scroll_bar', 'backable']

class Unchoice(EventCommand):
    nid = 'unchoice'
    tag = Tags.MISCELLANEOUS

    desc = \
    """
If this event was called from a Choice, then prevents that Choice from ending once this event ends. Otherwise, does nothing.
    """

class Textbox(EventCommand):
    nid = 'textbox'
    tag = Tags.MISCELLANEOUS

    desc = """
Displays a box on screen containing some text. This is distinct from dialogue and choice in that it is non-interactable. It shares many of its arguments with `speak`,
and predictably, those args will function the same way as in `speak`.

* *NID* is the name of this box.
* *Text* is either string to be displayed, or a Python expression to be constantly evaluated, e.g. `game.get_money()`, which would keep the textbox updated with the current amount of money. (Requires the `expression` flag)

* *BoxPosition* allows you to specify the location on screen of the textbox.
* *Width* allows you to specify the width of the box. This defaults to full screen width.
* *NumLines* allows you to specify the number of lines taken up by the textbox. This defaults to 1.
* The *StyleNid* allows you to outsource all configuration to an existing speak style.
* The *TextSpeed* keyword specifies how quickly the text is displayed. Lower is faster.
* The *FontColor* keyword specifies the font color
* The *FontType* keyword specifies the font type
* The *BG* keyword specifies what base image to use as background. menu_bg images will be tiled, while other sprites will not.

* The *expression* flag indicates that the provided table data should be be continually parsed as a python expression and updated.
    """

    keywords = ['NID', 'Text']
    optional_keywords = ['BoxPosition', 'Width', 'NumLines', 'StyleNid', 'TextSpeed', 'FontColor', 'FontType', 'BG']
    keyword_types = ['Nid', 'String', 'AlignOrPosition', 'Width', 'PositiveInteger', 'Nid', 'Float', 'FontColor', 'Font', 'Sprite']
    _flags = ['expression']

class Table(EventCommand):
    nid = 'table'
    tag = Tags.MISCELLANEOUS

    desc = \
    """Displays a box on screen containing some text or tabulated information. This is distinct from dialogue and choice in that it is non-interactable,
existing only to be looked at.

* *Nid* is the name of this box.
* *TableData* is one of many things. It can be a String, some simple text to display. It can be a *StringList*, i.e., a list of strings that can be parsed.
This can be combined with the flags to display specific types of strings - skills, items, even units. Or it can be an Expression, a Python statement that resolves to
a string or list of strings. For example, `game.get_money()` would resolve to the current amount of gold in the party. The difference between Expressions
and String/StringLists is that Expressions will constantly update with current information. For example, if the party's gold is reduced, then the previous
expression would automatically update the gold.

* *Title* allows you to optionally add a title to the box.
* *Dimensions* allows you to specify the size of the box in terms of (rows, columns).
* *RowWidth* allows you to specify the specific width of each row.
* The *Alignment* keyword specifies where on the screen the choice box will be displayed.
* The *BG* keyword specifies what base image to use as background. menu_bg images will be tiled, while other sprites will not.
* The *Type* keyword specifies the specific type of the options, and will change the way the entries are displayed.
* The *TextAlign* keyword specifies the alignment of the choice text

* *type_skill* will interpret all options as skill NIDs
* *type_base_item* will interpret all options as item NIDs
* *type_game_item* will interpret all options as item UIDs (i.e. actual items in game - important if you want to distiguish between a 1/40 vs 40/40 Iron Sword, for example)
* *type_unit* will interpret all options as unit NIDs
* *type_class* will interpret all options as class NIDs.
* *type_icon* will use the following syntax: `iconsheetnid-iconx-icony-choicetext`, and will display the specific icon16 alongside the choice.
* *type_portrait* will interpret the options as portrait NIDs.
* *type_chibi* will interpret the options as unit nids, and draw the chibi corresponding.

* The *expression* flag indicates that the provided table data should be be continually parsed as a python expression and updated.
* The *no_bg* flag removes the bg.
    """

    keywords = ['Nid', 'TableData']
    optional_keywords = ['Title', 'Dimensions', 'RowWidth', 'Alignment', 'BG', 'EntryType', 'TextAlign']
    keyword_types = ['Nid', 'String', 'String', 'Size', 'Width', 'Align', 'Sprite', 'TableEntryType', 'HAlign']
    _flags = ['expression', 'no_bg']

class RemoveTable(EventCommand):
    nid = 'remove_table'
    nickname = 'rmtable'
    tag = Tags.MISCELLANEOUS

    desc = \
    """
    Removes a GUI object created by the `Table` or `Textbox` command.

    * *Nid* is the name of the object to be removed.
    """

    keywords = ['Nid']

class TextEntry(EventCommand):
    nid = 'text_entry'
    tag = Tags.MISCELLANEOUS

    desc = \
        """
Presents the player with a menu in which they can enter text. An example use-case would be to create a tactician name.

*Nid* is the name of this entry, which can be checked later to recall the player's input.
For instance, if nid was "tactician", use `{var:tactician}` anywhere in events to replace it with the user's entry.
*String* is the text describing the choice, such as "Please enter a name."
*PositiveInteger* is the character limit. If not set, defaults to 16.
*StringList* specifies which characters to ban. Only accepts 'uppercase', 'lowercase', 'uppercase_UTF8', 'lowercase_UTF8', 'numbers_and_punctuation'

If the force_entry flag is set, the player will not be able to exit text entry before assigning a value to the game variables. (i.e., they must hit 'Yes' in the entry confirmation to end text entry)
        """

    keywords = ['Nid', 'String']
    optional_keywords = ['PositiveInteger', 'IllegalCharacterList']
    _flags = ['force_entry']

class ChapterTitle(EventCommand):
    nid = 'chapter_title'
    tag = Tags.MISCELLANEOUS

    desc = \
        """
Brings up the chapter title screen, optionally with the specified *Music* and chapter name (*String*).
        """

    optional_keywords = ["Music", "String"]

class DrawOverlaySprite(EventCommand):
    nid = 'draw_overlay_sprite'
    nickname = 'draw_overlay'
    tag = Tags.MISCELLANEOUS

    desc = \
"""
Draws a sprite on the screen at the specified position. Position defaults to 0, 0.
Will always draw immediately behind the dialog.
You can control the order that multiple siimultaneous overlays are drawn by choosing a custom z-level.
Higher z-level sprites will cover lower z-level sprites occupying the same positions.

Can choose to animate the sprite in and out.
"""

    keywords = ["Nid", "SpriteID"]
    optional_keywords = ["Position", "ZLevel", "Animation"]
    keyword_types = ["Nid", "Sprite", "PositionOffset", "Integer", "AnimationType"]

class RemoveOverlaySprite(EventCommand):
    nid = 'remove_overlay_sprite'
    nickname = 'delete_overlay'
    tag = Tags.MISCELLANEOUS

    desc = \
"""
Removes an overlay sprite with the given name from the screen.
"""

    keywords = ['Nid']

class Alert(EventCommand):
    nid = 'alert'
    tag = Tags.DIALOGUE_TEXT

    desc = \
        """
Displays the text given in *String* in an alert box. This is used for events such as "The switch was pulled!".

Optionally, takes in an item icon from *Item* to display, a skill icon from *Skill* to display, or a named icon *Icon*.
        """

    keywords = ["String"]
    optional_keywords = ["Item", "Skill", "Icon"]

class VictoryScreen(EventCommand):
    nid = 'victory_screen'
    tag = Tags.MISCELLANEOUS

    desc = \
        """
Displays the chapter's victory screen. Congratulations!
        """

class RecordsScreen(EventCommand):
    nid = 'records_screen'
    tag = Tags.MISCELLANEOUS

    desc = \
        """
Displays the game's records screen.
        """

class LocationCard(EventCommand):
    nid = 'location_card'
    tag = Tags.DIALOGUE_TEXT

    desc = \
        """
Used to display text (*String*) in the upper-left corner of the screen. This is often used to indicate the current location shown, such as "Castle Ostia".
        """

    keywords = ["String"]

class Credits(EventCommand):
    nid = 'credits'
    tag = Tags.DIALOGUE_TEXT

    desc = \
        """
Display a line of credits. The *Role* specifies the credit type ("Director"). The *Credits* is a comma-delimited list of credits ("Nolan,Spielberg,Tarantino"). If the *no_split* flag is set, the list will not be split based on the commas in *Credits*. The *wait* and *center* flags modify how the credit line is displayed.
        """

    keywords = ["Role", "Credits"]
    keyword_types = ["String", "String"]
    _flags = ['wait', 'center', 'no_split']

class Ending(EventCommand):
    nid = 'ending'
    tag = Tags.DIALOGUE_TEXT

    desc = \
        """
Displays the epilogue text for a character. *Portrait* is the portrait to be displayed, *Title* is the name displayed (ex: "Marcus, Badass Paladin"), the *Text* is the block of text describing what happened to the character.
        """

    keywords = ["Portrait", "Title", "Text"]
    keyword_types = ["Portrait", "String", "String"]

class PopDialog(EventCommand):
    nid = 'pop_dialog'
    tag = Tags.DIALOGUE_TEXT
    desc = \
        """
Removes the most recent dialog text box from the screen. Generally only used in conjunction with the `ending` command to remove the Ending box during a transition.

Example:

```
ending;Coyote;Coyote, Man of Mystery;Too mysterious for words.
transition;Close
pop_dialog
transition;Open
```
        """

class Unlock(EventCommand):
    nid = 'unlock'
    tag = Tags.REGION

    desc = \
        """
A convenient wrapper function that combines **find_unlock** and **spend_unlock**. This is ususally used in a region's event script to cause *Unit* to spend a key to unlock the current region.
        """

    keywords = ["Unit"]

class FindUnlock(EventCommand):
    nid = 'find_unlock'
    tag = Tags.HIDDEN

    desc = \
        """
Use **unlock** instead.
        """

    keywords = ["Unit"]

class SpendUnlock(EventCommand):
    nid = 'spend_unlock'
    tag = Tags.HIDDEN

    desc = \
        """
Use **unlock** instead.
        """

    keywords = ["Unit"]

class TriggerScript(EventCommand):
    nid = 'trigger_script'
    tag = Tags.MISCELLANEOUS

    desc = \
        """
Executes the event script specified by *Event*. Can optionally feed two *Units* into the script as {unit} and {unit2}.
        """

    keywords = ["Event"]
    optional_keywords = ["Unit1", "Unit2"]
    keyword_types = ["Event", "GlobalUnit", "GlobalUnit"]

class TriggerScriptWithArgs(EventCommand):
    nid = 'trigger_script_with_args'
    tag = Tags.MISCELLANEOUS

    desc = \
        """
Executes the event script specified by *Event*. Can feed any number of arguments of your choice to the new event, as long as they are strings. You will give each of these arguments a name that you can access in the called event using `{eval:name}`, syntax.

For example, if you called `trigger_script_with_args;MyEvent;Color,Purple,Animal,Dog`, when MyEvent runs you could access the color in that event using `{eval:Color}` which would return 'Purple'. Similarly, you could access the animal using `{eval:Animal}`.
        """

    keywords = ["Event"]
    optional_keywords = ["ArgList"]
    keyword_types = ["Event", "ArgList"]

class LoopUnits(EventCommand):
    nid = 'loop_units'
    tag = Tags.MISCELLANEOUS

    desc = \
        """
The first argument to this command should be a Python expression that evaluates to a list of unit nids.

This command will run the designated event script for each unit in the list.

Example:
```
# This gives all player units 1 fatigue using the Gain Fatigue Event script
loop_units;[unit.nid for unit in game.get_player_units()];Gain Fatigue Event
```
        """

    keywords = ["Expression", "Event"]

class ChangeRoaming(EventCommand):
    nid = 'change_roaming'
    tag = Tags.MISCELLANEOUS
    desc = "Turn free roam mode on or off"

    keywords = ["FreeRoamEnabled"]
    keyword_types = ["Bool"]

class ChangeRoamingUnit(EventCommand):
    nid = 'change_roaming_unit'
    tag = Tags.MISCELLANEOUS
    desc = "Changes the level's current roaming unit."

    keywords = ["Unit"]

class CleanUpRoaming(EventCommand):
    nid = 'clean_up_roaming'
    tag = Tags.MISCELLANEOUS
    desc = "Removes all units other than the roaming unit"

class AddToInitiative(EventCommand):
    nid = 'add_to_initiative'
    tag = Tags.MISCELLANEOUS
    desc = "Adds the specified unit to the specified point in the initiative order. 0 is the current initiative position."

    keywords = ["Unit", "Integer"]

class MoveInInitiative(EventCommand):
    nid = 'move_in_initiative'
    tag = Tags.MISCELLANEOUS
    desc = "Moves the initiative of the specified unit."

    keywords = ["Unit", "Integer"]

class PairUp(EventCommand):
    nid = 'pair_up'
    tag = Tags.MISCELLANEOUS
    desc = "Pairs the first unit into the second"

    keywords = ["Unit1", "Unit2"]
    keyword_types = ["Unit", "Unit"]

class Separate(EventCommand):
    nid = 'separate'
    tag = Tags.MISCELLANEOUS
    desc = "Sets the unit's traveler to none. Does not place that partner on the map."

    keywords = ["Unit"]

# === OVERWORLD COMMANDS START HERE ===
class OverworldCinematic(EventCommand):
    nid = 'overworld_cinematic'
    tag = Tags.OVERWORLD
    desc = 'Sets the background to the overworld, allowing us to create cutscenes set in the overworld'

    optional_keywords = ['OverworldNID']
    keyword_types = ['OverworldNID']

class SetOverworldPosition(EventCommand):
    nid = 'set_overworld_position'
    tag = Tags.OVERWORLD
    desc = "Sets the position of a specific party in the overworld to a specific coordinate or node in the overworld"

    keywords = ['OverworldEntity', 'OverworldLocation']
    _flags = ['no_animate']

class OverworldMoveUnit(EventCommand):
    nid = 'overworld_move_unit'
    nickname = 'omove'
    tag = Tags.OVERWORLD
    desc = ('Issues a move command to *OverworldEntity* to move from its current position to given *OverworldLocation*. '
            'Alternately, moves *OverworldEntity* along a path denoted by the *PointList* in the format "(x, y)-(x1,y1)-(x2,y2)-...". '
            'You can adjust the travel time via the *Speed* parameter - higher is slower (2 is twice as slow, 3 is thrice...)'
            '\n the `disable_after` flag determines whether or not to remove the unit after the move concludes. Useful for cinematics.')

    keywords = ["OverworldEntity"]
    optional_keywords = ['OverworldLocation', 'Speed', 'PointList']
    keyword_types = ["OverworldEntity", 'OverworldLocation', 'Float', 'PointList']
    _flags = ['no_block', 'no_follow', 'disable_after', 'no_sound']

class RevealOverworldNode(EventCommand):
    nid = 'reveal_overworld_node'
    tag = Tags.OVERWORLD
    desc = ('Reveals an overworld node on the map: moves the camera to the new location, plays the animation, and fades in the nodes.'
            'By default, fades in via animation; use the *immediate* flag to skip this anim.')

    keywords = ['OverworldNodeNid']
    keyword_types = ["OverworldLocation"]
    _flags = ["immediate"]

class RevealOverworldRoad(EventCommand):
    nid = 'reveal_overworld_road'
    tag = Tags.OVERWORLD
    desc = ('Enables a road between two overworld nodes. *OverworldNodeNID* denotes the NID of a valid node. '
            'By default, fades in via animation; use the *immediate* flag to skip this anim.')

    keywords = ['Node1', 'Node2']
    keyword_types = ['OverworldNodeNid', 'OverworldNodeNid']
    _flags = ["immediate"]

class CreateOverworldEntity(EventCommand):
    nid = 'create_overworld_entity'
    tag = Tags.OVERWORLD
    desc = ('Create an overworld entity in memory with nid *Nid*. This can be used for purely cinematic purposes,'
            ' or alternatively, used to spawn enemy reinforcements on the map.'
            'If the `delete` flag is passed, this command will instead delete the entity with said NID')

    keywords = ['Nid']
    optional_keywords = ['Unit', 'Team']
    _flags = ['delete']

class DisableOverworldEntity(EventCommand):
    nid = 'disable_overworld_entity'
    tag = Tags.OVERWORLD
    desc = ('remove an overworld entity from the map, with or without animation')

    keywords = ['Nid']
    _flags = ['no_animate']

class ToggleNarrationMode(EventCommand):
    nid = 'toggle_narration_mode'
    tag = Tags.DIALOGUE_TEXT
    desc = ('Enter or exit a full-screen narration mode.')

    keywords = ['Direction']
    optional_keywords = ['Speed']

class SetOverworldMenuOptionEnabled(EventCommand):
    nid = 'set_overworld_menu_option_enabled'
    tag = Tags.OVERWORLD
    desc = ('Toggle whether the specified node menu option can be accessed by the player. Note that even if enabled, it must also be visible for the player to access it.')

    keywords = ['OverworldNodeNid', 'OverworldNodeMenuOption', 'Setting']
    keyword_types = ['OverworldNodeNid', 'OverworldNodeMenuOption', 'Bool']

class SetOverworldMenuOptionVisible(EventCommand):
    nid = 'set_overworld_menu_option_visible'
    tag = Tags.OVERWORLD
    desc = ('Toggle whether the specified node menu option can be seen by the player. Note that even if visible, it must also be enabled for the player to access it.')

    keywords = ['OverworldNodeNID', 'OverworldNodeMenuOption', 'Setting']
    keyword_types = ['OverworldNodeNID', 'OverworldNodeMenuOption', 'Bool']

class CreateAchievement(EventCommand):
    nid = 'create_achievement'
    tag = Tags.ACHIEVEMENT
    desc = ('Creates a new achievement. Set `completed` flag to automatically complete the achievement when it is first unlocked. Set `hidden` flag to prevent the player from seeing it until it is completed. Does nothing if nid already present.')

    keywords = ['Nid', 'Name', 'Description']
    _flags = ['completed', 'hidden']
    keyword_types = ['Nid', 'String', 'String']

class UpdateAchievement(EventCommand):
    nid = 'update_achievement'
    tag = Tags.ACHIEVEMENT
    desc = ('Updates the name and description of achievement with the given nid. Does nothing if there is no achievement with that nid.')

    keywords = ['Achievement', 'Name', 'Description']
    _flags = ['hidden']
    keyword_types = ['Achievement', 'String', 'String']

class CompleteAchievement(EventCommand):
    nid = 'complete_achievement'
    tag = Tags.ACHIEVEMENT
    desc = ('True marks the achievement as complete. False marks it as incomplete. No effect if achievement doesn\'t exist.\n\nYou can check an achievement\'s completion status with `check_achievement("nid")`\n\nbanner flag determines whether a pop-up box will appear notifying the player.')

    keywords = ['Achievement', 'Completed']
    keyword_types = ['Achievement', 'Bool']

    _flags = ['banner']

class ClearAchievements(EventCommand):
    nid = 'clear_achievements'
    tag = Tags.ACHIEVEMENT
    desc = ('Clear all achievements from the player\'s computer')

class CreateRecord(EventCommand):
    nid = 'create_record'
    tag = Tags.PERSISTENT_RECORDS
    desc = ('Creates a new persistent record. Does nothing if nid is already present')

    keywords = ['Nid', 'Expression']

class UpdateRecord(EventCommand):
    nid = 'update_record'
    tag = Tags.PERSISTENT_RECORDS
    desc = ('Updates a persistent record with a new value. Does nothing if nid is not present')

    keywords = ['Nid', 'Expression']

class ReplaceRecord(EventCommand):
    nid = 'replace_record'
    tag = Tags.PERSISTENT_RECORDS
    desc = ("Updates a persistent record with a new value. Creates it first if it doesn't already exist")

    keywords = ['Nid', 'Expression']

class DeleteRecord(EventCommand):
    nid = 'delete_record'
    tag = Tags.PERSISTENT_RECORDS
    desc = ('Remove a persistent record. Does nothing if nid is not present')

    keywords = ['Nid']

class UnlockDifficulty(EventCommand):
    nid = 'unlock_difficulty'
    tag = Tags.PERSISTENT_RECORDS
    desc = ("Unlocks the specified difficulty. Locked difficulties cannot be selected by the player when creating a new game.")

    keywords = ['DifficultyMode']
    keyword_types = ['DifficultyMode']

class Python(EventCommand):
    nid = 'python'
    tag = Tags.HIDDEN
    special_handling = True

    desc = "Executes the following lines in python. End with `end_python`"

class EndPython(EventCommand):
    nid = 'end_python'
    tag = Tags.HIDDEN
    special_handling = True

    desc = "Ends a block of python code."

def get_commands():
    return EventCommand.__subclasses__()

def restore_command(dat) -> EventCommand:
    if len(dat) == 2:
        nid, display_values = dat
    elif len(dat) == 3:  # Old method
        nid, values, display_values = dat
    else:
        logging.error("Couldn't restore event command: Data: %s", dat)
        return None

    text = ';'.join([nid] + display_values)
    command, _ = parse_text_to_command(text, strict=True)
    if command:
        return command
    else:
        return Comment(display_values=[nid + ';' + str.join(';', display_values)])

evaluables = ('Expression', 'String', 'StringList', 'PointList', 'DashList', 'Nid')

def get_command_arguments(text: str) -> List[str]:
    # Replacement for text.split(';')
    # that ignores any semicolons
    # found within '{}' brackets
    arguments = []
    curr = ""
    level = 0
    for t in text:
        if t == ';' and level == 0:
            arguments.append(curr)
            curr = ""
        elif t == '{':
            level += 1
            curr += t
        elif t == '}':
            level -= 1
            curr += t
        else:
            curr += t
    arguments.append(curr)
    return arguments

def determine_command_type(text: str) -> EventCommand:
    text = text.lstrip()
    if text.startswith('#'):
        return Comment(display_values=[text])
    if text.startswith('comment;'):
        return Comment(display_values=[text[8:]])
    arguments = get_command_arguments(text)
    command_nid = arguments[0]
    subclasses = EventCommand.__subclasses__()
    for command_type in subclasses:
        if command_type.nid == command_nid or command_type.nickname == command_nid:
            return command_type()
    return Comment()

def parse_text_to_command(text: str, strict: bool = False) -> Tuple[EventCommand, int]:
    """parses a line into a command

    Args:
        text (str): text to be parsed
        strict (bool, optional): whether invalid command should be parsed as comments, or None.
        This defaults to false; usually, invalid commands are caused by engine version mismatch,
        and parsing them as None will erase the user's hard work. Parsing them as comments allows them to be
        preserved harmlessly. However, in certain cases - such as event validation - strict will be useful.

    Returns:
        EventCommand: parsed command
        int: Index of the character the command failed to parse at (only if strict)
    """
    def _process_arg(cmd_keyword: str, arg: str) -> str:
        # if parentheses exists, then they contain the "true" arg, with everything outside parens essentially as comments
        # we do NOT want to use this with evals, hence the '{' and '}' stoppage
        if '(' in arg and ')' in arg and '{' not in arg and '}' not in arg and \
                ('FLAG' in arg or (cmd_keyword and cmd_keyword not in evaluables and 'list' not in cmd_keyword.lower())):
            return arg[arg.find("(") + 1 : arg.rfind(")")]
        return arg

    def _parse_command(command: EventCommand, arguments: List[str]) -> Tuple:
        # Start parsing
        keyword_argument_mode: bool = False
        cmd_args = arguments[1:]
        parameters, flags = {}, set()
        command_info = command()

        for idx, arg in enumerate(cmd_args):
            # remove line break chars. speak has its own handling, so keep them
            if command_info.nid not in ('speak', 'textbox'):
                arg = arg.replace('\u2028', '')

            all_keywords = command_info.keywords + command_info.optional_keywords

            # Check for flag first
            if _process_arg(None, arg) in command_info.flags:
                flags.add(_process_arg(None, arg))

            # Handle Python style keyword arguments
            # For example `s;Speaker=Eirika;Text=Hi!;Nid=normal`
            elif '=' in arg and arg.split('=', 1)[0] in all_keywords:
                keyword_argument_mode = True
                cmd_keyword, arg = arg.split('=', 1)
                cmd_validator = command_info.get_validator_from_keyword(cmd_keyword)
                if cmd_validator:
                    parameters[cmd_keyword] = _process_arg(cmd_validator, arg)
                else:
                    logging.debug("Keyword argument %s not found", cmd_keyword)
                    return None, idx

            elif keyword_argument_mode:
                # Positional arguments cannot follow keyword arguments
                return None, idx

            else:  # Positional mode
                if idx < len(command_info.keywords):
                    cmd_keyword = command_info.keywords[idx]
                    cmd_validator = command_info.get_keyword_types()[idx]
                    parameters[cmd_keyword] = _process_arg(cmd_validator, arg)
                elif idx - len(command_info.keywords) < len(command_info.optional_keywords):
                    cmd_keyword = command_info.optional_keywords[idx - len(command_info.keywords)]
                    cmd_validator = command_info.get_keyword_types()[idx]
                    parameters[cmd_keyword] = _process_arg(cmd_validator, arg)
                else:
                    logging.debug("too many arguments: %s, %s", arg, arguments)
                    return None, idx

        # Check that we have all the required keywords
        for keyword in command_info.keywords:
            if keyword not in parameters:
                logging.debug("Missing required parameter: %s in %s", keyword, parameters)
                return None, len(cmd_args) - 1

        copy = command(parameters, flags, cmd_args)
        return copy, None

    # Main function starts here
    if not text:
        return None, None
    text = text.lstrip()
    if text.startswith('#'):
        return Comment(display_values=[text]), None
    if text.startswith('comment;'):
        return Comment(display_values=[text[8:]]), None
    # Remove trailing semicolons
    # Since they screw up the parser
    if text.endswith(';'):
        text = text[:-1]

    arguments = get_command_arguments(text)

    command_nid = arguments[0]
    subclasses = EventCommand.__subclasses__()
    bad_idx = None
    for command_type in subclasses:
        if command_type.nid == command_nid or command_type.nickname == command_nid:
            output, bad_idx = _parse_command(command_type, arguments)
            if output:
                return output, None
    # Only gets here if it couldn't find a good match
    if strict:
        return None, bad_idx
    elif not text:
        return None, None
    else:
        return Comment(display_values=[text]), None

def parse(command: EventCommand, _eval_evals: Callable[[str], str] = None):
    parameters = command.parameters
    if _eval_evals:
        parameters = {k: _eval_evals(v) for k, v in parameters.items()}
    return parameters, command.chosen_flags

def convert_parse(command: EventCommand, _eval_evals: Callable[[str], str] = None):
    from app.events.event_validators import convert

    parameters = command.parameters
    if _eval_evals:
        parameters = {k: _eval_evals(v) if isinstance(v, str) else v for k, v in parameters.items()}

    for keyword, value in parameters.items():
        if keyword in command.keywords:
            idx = command.keywords.index(keyword)
        elif keyword in command.optional_keywords:
            idx = command.optional_keywords.index(keyword) + len(command.keywords)
        else:
            logging.error("Could not find %s in %s or %s", keyword, command.keywords, command.optional_keywords)
            continue
        keyword_type = command.get_keyword_types()[idx]
        parameters[keyword] = convert(keyword_type, value)

    return parameters, command.chosen_flags
