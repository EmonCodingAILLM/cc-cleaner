"""Decode Claude Code's project directory names back to filesystem paths.

Claude Code encodes paths by replacing '/' with '-'.
This is lossy for directory names containing hyphens.
We resolve ambiguity by checking the filesystem at each segment boundary.
"""

import os


def decode(encoded_name):
    """Decode an encoded project name back to a real filesystem path.

    Args:
        encoded_name: e.g. "-Users-wenqiu-AIAgent-cc-cleaner"

    Returns:
        (path, exists): e.g. ("/Users/wenqiu/AIAgent/cc-cleaner", True)
    """
    segments = encoded_name.lstrip('-').split('-')
    if not segments:
        return encoded_name, False

    current = '/' + segments[0]
    i = 1

    while i < len(segments):
        found = False
        for j in range(i, len(segments)):
            candidate = '-'.join(segments[i:j + 1])
            test_path = os.path.join(current, candidate)
            if os.path.exists(test_path):
                current = test_path
                i = j + 1
                found = True
                break

        if not found:
            # Best effort: join all remaining segments with '-'
            candidate = '-'.join(segments[i:])
            current = os.path.join(current, candidate)
            return current, False

    return current, os.path.exists(current)
