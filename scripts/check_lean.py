#!/usr/bin/env python3
"""Reject proof holes and new axiom declarations outside Lean comments/strings."""
import pathlib
import re
import sys


def code_only(source):
    result = []
    i = depth = 0
    while i < len(source):
        if source.startswith("/-", i):
            depth += 1
            result.append("  ")
            i += 2
        elif depth and source.startswith("-/", i):
            depth -= 1
            result.append("  ")
            i += 2
        elif depth:
            result.append("\n" if source[i] == "\n" else " ")
            i += 1
        elif source.startswith("--", i):
            end = source.find("\n", i)
            end = len(source) if end < 0 else end
            result.append(" " * (end - i))
            i = end
        elif source[i] == '"':
            result.append(" ")
            i += 1
            while i < len(source):
                char = source[i]
                result.append("\n" if char == "\n" else " ")
                i += 1
                if char == "\\" and i < len(source):
                    result.append(" ")
                    i += 1
                elif char == '"':
                    break
        else:
            result.append(source[i])
            i += 1
    return "".join(result)


def forbidden(source):
    code = code_only(source)
    return [(code.count("\n", 0, match.start()) + 1, match.group())
            for match in re.finditer(r"\b(?:sorry|admit|axiom)\b", code)]


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "lean")
    failures = []
    for path in sorted(root.rglob("*.lean")):
        if ".lake" not in path.parts:
            failures.extend(f"{path}:{line}: forbidden {token}" for line, token in forbidden(path.read_text()))
    for failure in failures:
        print(failure, file=sys.stderr)
    return bool(failures)


if __name__ == "__main__":
    sys.exit(main())
