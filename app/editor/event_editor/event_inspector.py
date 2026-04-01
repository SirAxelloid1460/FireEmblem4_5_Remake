from app.events.event_commands import EventCommand, GameVar, LevelVar
from app.utilities.typing import NID
import re
from typing import Dict, Optional, Set, Tuple
from app.events.event_prefab import EventCatalog

class EventInspectorEngine():
    def __init__(self, event_db: EventCatalog):
        self.event_db = event_db

    def find_all_variables_in_level(self, level_nid: Optional[NID]) -> Set[NID]:
        """returns all known user-defined symbols in level."""
        all_vars = set()
        for event in self.event_db.get_by_level(level_nid):
            if event.level_nid == level_nid:
                for command in event.commands:
                    if command.nid in [GameVar.nid, LevelVar.nid]:
                        all_vars.add(command.parameters['Nid'])
        return all_vars

    def find_all_occurrences_of_symbol(self, symbol: str) -> Set[NID]:
        occurrence_dict: Set[NID] = set()
        # regex explanation: match every occurrence of symbol within brackets, but not surrounded by
        # possible interfering chars that alter the symbol
        # e.g. {v:symbol} is probably an occurrence of the symbol.
        # {eval:game.get_var("symbol")} is also an occurence of the symbol. Both match
        # but {v:symbol_version_2} will not match, and neither will {eval:game.get_var("symbol2")}
        rstr = '.*{{.*(?![^0-9A-Za-z_]){symbol}(?![0-9A-Za-z_]).*}}.*'.format(symbol=symbol)
        for event in self.event_db:
            for command in event.commands:
                for parameter in command.parameters.values():
                    if parameter == symbol or re.match(rstr, parameter):
                        occurrence_dict.add(event.nid)
                        break
                if event.nid in occurrence_dict:
                    break
        return occurrence_dict

    def find_all_calls_of_command(self, qcommand: EventCommand, level_nid='all') -> Dict[Tuple[str, int], EventCommand]:
        all_commands = {}
        for event in self.event_db:
            if level_nid == 'all' or event.level_nid == level_nid:
                for idx, command in enumerate(event.commands):
                    if command.nid == qcommand.nid:
                        all_commands[(event.nid, idx)] = command
        return all_commands
