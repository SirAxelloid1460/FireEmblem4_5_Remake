from dataclasses import dataclass, fields
from .state_enums import MainEditorScreenStates

import logging


@dataclass
class EditorState():
    """
    Class containing application state variables.
    """
    # NID of current level in editor
    selected_level: str = '0'
    # NID of current overworld map in editor
    selected_overworld: str = '0'
    # NID of current node selected on overworld
    selected_node: str = None
    
    # Main editor mode, edit enum to add modes
    main_editor_mode: MainEditorScreenStates = MainEditorScreenStates.GLOBAL_EDITOR
    

    """
    # This one is a cheeky dummy signal; broadcast this whenever you want to refresh the whole editor

    # [!!!WARNING!!!]
    # Be EXTREMELY cautious when using any signal, but particularly this one. This could very easily get stuck
    # in a broadcast loop, for example:

    #     def __init__(self):
    #       [...]
    #           ### when the UI signal is refreshed, of course I want to update my own view!
    #       self.state_manager.subscribe(self.__name__, 'ui_refresh_signal', self.update_view)

    #     def update_view(self):
    #       update_self_with_data_that_changed_elsewhere()
    #           ### Since I updated, let's update everyone!
    #       self.state_manager.change_and_broadcast('ui_refresh_signal', None)
    
    # Broadcasting is DANGEROUS, kids.
    """
    ui_refresh_signal: str = None


class EditorStateManager():
    """
    Provides an application state and a broadcast alert system
    for updating subscribed components.
    """

    def __init__(self):
        self.state = EditorState()
        self.subscribed_callbacks = {field.name: {}
                                     for field in fields(EditorState)}

    def subscribe_to_key(self, name, key, callback):
        """Subscribes a callback to a key in state. Upon change in state key, 
        the callback will be called like so: callback(state[key]). The `name` field 
        keys the subscription for cancellation purposes.

        Args:
            name (str): identifier for the subscription
            key (str): valid field in EditorState
            callback (function): function to be called upon change
        """
        if key not in self.subscribed_callbacks:
            logging.error("Key not found in EditorState")
            raise AttributeError
        self.subscribed_callbacks[key][name] = callback

    def change_and_broadcast(self, key, value):
        """Sets key to value, then broadcasts the change to all subscribed callbacks.

        Args:
            key (str): valid field in EditorState
            value (str): value for key to be set
        """
        if key not in self.subscribed_callbacks:
            logging.error("Key not found in EditorState")
            raise AttributeError
        setattr(self.state, key, value)
        for callback in self.subscribed_callbacks[key].values():
            callback(getattr(self.state, key))

    def unsubscribe_from_key(self, name, key):
        """Unsubscribe from state updates.

        Args:
            name (str): subscription identifier
            key (str): field in EditorState that the callback is subscribed to
        """
        self.subscribed_callbacks[key].pop(name, None)
