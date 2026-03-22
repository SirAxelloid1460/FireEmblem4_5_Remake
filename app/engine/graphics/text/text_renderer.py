from __future__ import annotations

import re
from typing import List, Tuple

from app.engine import engine
from app.engine.fonts import FONT
from app.engine.icons import draw_icon_by_alias
from app.utilities.enums import Alignments
from app.utilities.typing import NID

MATCH_TAG_RE = re.compile('<(.*?)>')
MATCH_CAPTURE_TAG_RE = re.compile('(<[^<]*?>)')

def font_height(font: NID):
    return FONT[font].height

def rendered_text_width(fonts: List[NID], texts: List[str]) -> int:
    """Returns the full rendered width (see render_text) of a text list.

    Args:
        fonts (List[NID]): List of fonts to use to write text.
        texts (List[str]): List of strings to write with corresponding fonts.

    Returns:
        int: Width of string if it were rendered
    """
    if not fonts:
        return
    if not texts:
        return
    if len(fonts) < len(texts):
        fonts += [fonts[-1] for i in range(len(texts) - len(fonts))]
    font_stack = list(reversed(fonts))
    text_stack = list(reversed(texts))

    base_font = fonts[-1]
    font_history_stack = []
    total_width = 0
    while(text_stack):
        curr_text = text_stack.pop()
        curr_font = font_stack.pop()
        # process text for tags and push them onto stack for later processing
        any_tags = MATCH_TAG_RE.search(curr_text)
        if any_tags:
            tag_start, tag_end = any_tags.span()
            tag_font = any_tags.group().strip("<>")
            if '/' in tag_font:
                tag_font = font_history_stack.pop() if font_history_stack else base_font
            else:
                font_history_stack.append(curr_font)
            text_stack.append(curr_text[tag_end:])
            curr_text = curr_text[:tag_start]
            if tag_font in FONT or tag_font == 'icon':
                font_stack.append(tag_font)
            else:
                font_stack.append(curr_font)
        # actually render font
        if curr_font != 'icon':
            total_width += FONT[curr_font].width(curr_text)
        else:
            total_width += 16
    return total_width

def text_width(font: NID, text: str) -> int:
    """Simply determines the width of the text

    Args:
        font (NID): font to use to write text.
        text (str): string to write with corresponding font.

    Returns:
        int: Width of string if it were rendered
    """
    return rendered_text_width([font], [text])

def fix_tags(text_block: List[str]) -> List[str]:
    """Fixes unclosed tags.

    Example: ["You must push the <red>RED", "button</> or else you will die!"]
          -> ["You must push the <red>RED</>", "<red>button</> or else you will die!"]

    Args:
        text_block (List[str]): a chunk block of text that may have faulty tags

    Returns:
        List[str]: that same text block with tags properly closed
    """
    tag_stack = []
    fixed_text = []
    if not text_block:
        text_block = []
    for line in text_block:
        tags_in_line = re.findall(MATCH_TAG_RE, line)
        newline = line
        for tag in reversed(tag_stack):
            newline = "<%s>%s" % (tag, newline)
        for tag in tags_in_line:
            if '/' in tag: # closing, pop off the stack
                if tag_stack:
                    tag_stack.pop()
            else:
                tag_stack.append(tag)

        for tag in tag_stack:
            newline = "%s</>" % newline
        fixed_text.append(newline)
    return fixed_text

def remove_tags(text_block: List[str]) -> List[str]:
    """removes all tags.

    Example: ["You must push the <red>RED", "button</> or else you will die!"]
          -> ["You must push the RED", "button or else you will die!"]

    Args:
        text_block (List[str]): a chunk block of text that may have tags

    Returns:
        List[str]: that same text block with all tags removed
    """
    new_text_block = []
    for line in text_block:
        new_line = re.sub(MATCH_TAG_RE, '', line)
        new_text_block.append(new_line)
    return new_text_block

def render_text(surf: engine.Surface, fonts: List[NID], texts: List[str], colors: List[NID | None], topleft: Tuple[int, int], align: Alignments = Alignments.LEFT) -> engine.Surface:
    """An enhanced text render layer wrapper around BmpFont.
    Supports multiple fonts and multiple text sections, as well as
    embedded icons.

    Args:
        fonts (List[NID]): List of fonts to use to write text.
        texts (List[str]): List of strings to write with corresponding fonts.
        colors (List[str]): List of colors to write with corresponding fonts.

    Returns:
        engine.Surface: a surface that has text printed upon it.
    """
    if not fonts:
        return
    if not texts:
        return
    if not colors:
        colors = [None]
    if len(fonts) < len(texts):
        fonts += [fonts[-1] for i in range(len(texts) - len(fonts))]
    if len(colors) < len(texts):
        colors += [colors[-1] for i in range(len(texts) - len(colors))]
    font_stack = list(reversed(fonts))
    text_stack = list(reversed(texts))
    color_stack = list(reversed(colors))

    # for non-left alignments
    if align == Alignments.CENTER or align == Alignments.RIGHT:
        width = rendered_text_width(fonts, texts)
        tx, ty = topleft
        if align == Alignments.CENTER:
            tx -= width//2
        elif align == Alignments.RIGHT:
            tx -= width
    else:
        tx, ty = topleft

    base_font = fonts[-1]
    font_history_stack = []
    while(text_stack):
        curr_text = text_stack.pop()
        curr_font = font_stack.pop()
        curr_color = color_stack.pop() if color_stack else None
        # process text for tags and push them onto stack for later processing
        any_tags = MATCH_TAG_RE.search(curr_text)
        if any_tags:
            tag_start, tag_end = any_tags.span()
            tag_font = any_tags.group().strip("<>")
            if tag_font == '/':
                tag_font, tag_color = font_history_stack.pop() if font_history_stack else (base_font, None)
            else:
                if tag_font in FONT or tag_font == 'icon':
                    tag_color = curr_color
                else:
                    tag_color = tag_font
                    tag_font = curr_font
                font_history_stack.append((curr_font, curr_color))
            text_stack.append(curr_text[tag_end:])
            curr_text = curr_text[:tag_start]
            font_stack.append(tag_font)
            color_stack.append(tag_color)
        # actually render font
        if curr_font != 'icon':
            FONT[curr_font].blit(curr_text, surf, (tx, ty), curr_color)
            tx += FONT[curr_font].width(curr_text)
        else:
            draw_icon_by_alias(surf, curr_text.strip(), (tx, ty))
            tx += 16
    return surf
