#!/usr/bin/env python3
"""Generate EasyBar Lua reference docs from LuaLS annotations.

Generated docs are reference-only. Keep concept guides, examples, and patterns
as hand-written Markdown pages under docs/content/lua/guides.
"""

from __future__ import annotations

import argparse
import dataclasses
import re
import shutil
from pathlib import Path


@dataclasses.dataclass
class FieldDoc:
    name: str
    type_name: str
    description: str
    optional: bool = False


@dataclasses.dataclass
class ClassDoc:
    name: str
    description: str = ""
    parent: str | None = None
    modifiers: list[str] = dataclasses.field(default_factory=list)
    fields: list[FieldDoc] = dataclasses.field(default_factory=list)


@dataclasses.dataclass
class ParamDoc:
    name: str
    type_name: str
    description: str
    optional: bool = False


@dataclasses.dataclass
class FunctionDoc:
    name: str
    description: str = ""
    params: list[ParamDoc] = dataclasses.field(default_factory=list)
    returns: list[str] = dataclasses.field(default_factory=list)


@dataclasses.dataclass
class AliasDoc:
    name: str
    description: str = ""
    values: list[str] = dataclasses.field(default_factory=list)


@dataclasses.dataclass
class ConstantDoc:
    name: str
    value: str
    description: str = ""


@dataclasses.dataclass
class ParsedDocs:
    classes: dict[str, ClassDoc] = dataclasses.field(default_factory=dict)
    functions: dict[str, FunctionDoc] = dataclasses.field(default_factory=dict)
    aliases: dict[str, AliasDoc] = dataclasses.field(default_factory=dict)
    event_constants: list[ConstantDoc] = dataclasses.field(
        default_factory=list)
    kind_constants: list[ConstantDoc] = dataclasses.field(default_factory=list)


CLASS_RE = re.compile(
    r"^---@class\s+(?:\(([^)]+)\)\s+)?([A-Za-z0-9_.:]+)(?::\s*([A-Za-z0-9_.:]+))?\s*(.*)$")
FIELD_RE = re.compile(r"^---@field\s+([A-Za-z0-9_.:\[\]-]+)(\?)?\s+(.+)$")
PARAM_RE = re.compile(r"^---@param\s+([A-Za-z0-9_.:\[\]-]+)(\?)?\s+(.+)$")
RETURN_RE = re.compile(r"^---@return\s+(.+)$")
ALIAS_RE = re.compile(r"^---@alias\s+([A-Za-z0-9_.:]+)\s*(.*)$")
FUNCTION_RE = re.compile(
    r"^(?:function\s+([A-Za-z0-9_.:]+)\s*\(|([A-Za-z0-9_.:]+)\s*=\s*function\s*\()")
CONST_RE = re.compile(
    r"^(easybar\.(?:events|kind)[A-Za-z0-9_.]*)\s*=\s*['\"]([^'\"]+)['\"]")
UNION_VALUE_RE = re.compile(r"^---\|\s*(.+?)\s*$")


def doc_text(line: str) -> str | None:
    if line.startswith("---@"):
        return None
    if line.startswith("---|"):
        return None
    if line.startswith("---"):
        return line[3:].strip()
    return None


def md_escape(text: str) -> str:
    return text.replace("|", "\\|").strip()


def normalize_alias_value(text: str) -> str:
    value = text.strip()
    if len(value) >= 2 and value[0] == "'" and value[-1] == "'":
        value = value[1:-1].strip()
    return value


def alias_values(text: str) -> list[str]:
    return [normalize_alias_value(part) for part in text.split("|") if part.strip()]


def split_type_and_description(text: str) -> tuple[str, str]:
    if " # " in text:
        type_name, description = text.split(" # ", 1)
        return type_name.strip(), description.strip()

    depth_paren = 0
    depth_bracket = 0
    depth_brace = 0
    quote: str | None = None
    previous_nonspace = ""

    for index, char in enumerate(text):
        if quote:
            if char == quote and text[index - 1:index] != "\\":
                quote = None
            continue

        if char in {'"', "'", "`"}:
            quote = char
            continue
        if char == "(":
            depth_paren += 1
            continue
        if char == ")":
            depth_paren = max(0, depth_paren - 1)
            continue
        if char == "[":
            depth_bracket += 1
            continue
        if char == "]":
            depth_bracket = max(0, depth_bracket - 1)
            continue
        if char == "{":
            depth_brace += 1
            continue
        if char == "}":
            depth_brace = max(0, depth_brace - 1)
            continue
        if char.isspace() and depth_paren == 0 and depth_bracket == 0 and depth_brace == 0:
            if previous_nonspace == ":":
                continue
            return text[:index].strip(), text[index + 1:].strip()
        previous_nonspace = char

    return text.strip(), ""


def parse_lua_stub(paths: list[Path]) -> ParsedDocs:
    parsed = ParsedDocs()
    current_class: ClassDoc | None = None
    current_alias: AliasDoc | None = None
    pending_description: list[str] = []
    pending_function: FunctionDoc | None = None

    def flush_function() -> None:
        nonlocal pending_function
        if pending_function and pending_function.name:
            parsed.functions[pending_function.name] = pending_function
        pending_function = None

    for path in paths:
        if not path.exists():
            continue

        for line in path.read_text(encoding="utf-8").splitlines():
            stripped = line.strip()
            comment = doc_text(stripped)

            if comment:
                pending_description.append(comment)
                continue

            if match := CLASS_RE.match(stripped):
                flush_function()
                modifier_text, name, parent, trailing = match.groups()
                description = "\n".join(pending_description).strip()
                if trailing:
                    description = f"{description}\n{trailing.strip()}".strip()
                current_class = ClassDoc(
                    name=name,
                    parent=parent,
                    description=description,
                    modifiers=[item.strip() for item in (modifier_text or "").split(",") if item.strip()],
                )
                parsed.classes[name] = current_class
                current_alias = None
                pending_description = []
                continue

            if match := FIELD_RE.match(stripped):
                if current_class:
                    name, optional, remainder = match.groups()
                    type_name, description = split_type_and_description(remainder)
                    current_class.fields.append(FieldDoc(
                        name=name,
                        optional=optional == "?",
                        type_name=type_name.strip(),
                        description=(description or "").strip(),
                    ))
                pending_description = []
                continue

            if match := ALIAS_RE.match(stripped):
                flush_function()
                name, trailing = match.groups()
                current_alias = AliasDoc(
                    name=name, description="\n".join(pending_description).strip())
                if trailing:
                    current_alias.values.extend(alias_values(trailing))
                parsed.aliases[name] = current_alias
                current_class = None
                pending_description = []
                continue

            if current_alias and (match := UNION_VALUE_RE.match(stripped)):
                current_alias.values.append(
                    normalize_alias_value(match.group(1)))
                continue

            if match := PARAM_RE.match(stripped):
                name, optional, remainder = match.groups()
                type_name, description = split_type_and_description(remainder)
                if pending_function is None:
                    pending_function = FunctionDoc(
                        name="", description="\n".join(pending_description).strip())
                    pending_description = []
                pending_function.params.append(ParamDoc(
                    name=name,
                    optional=optional == "?",
                    type_name=type_name.strip(),
                    description=(description or "").strip(),
                ))
                continue

            if match := RETURN_RE.match(stripped):
                if pending_function is None:
                    pending_function = FunctionDoc(
                        name="", description="\n".join(pending_description).strip())
                    pending_description = []
                pending_function.returns.append(match.group(1).strip())
                continue

            if match := FUNCTION_RE.match(stripped):
                name = match.group(1) or match.group(2)
                if pending_function is None:
                    pending_function = FunctionDoc(
                        name=name, description="\n".join(pending_description).strip())
                else:
                    pending_function.name = name
                flush_function()
                pending_description = []
                continue

            if match := CONST_RE.match(stripped):
                name, value = match.groups()
                constant = ConstantDoc(
                    name=name, value=value, description="\n".join(pending_description).strip())
                if name.startswith("easybar.events"):
                    parsed.event_constants.append(constant)
                else:
                    parsed.kind_constants.append(constant)
                pending_description = []
                continue

            if stripped and not stripped.startswith("---"):
                pending_description = []
                current_alias = None

    flush_function()
    parsed.event_constants.sort(key=lambda item: item.name)
    parsed.kind_constants.sort(key=lambda item: item.name)
    return parsed


def generated_header() -> str:
    return """<!--
This file is generated by scripts/generate_lua_reference_docs.py.
Do not edit this file by hand. Update the LuaLS stub instead.
-->
"""


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n", encoding="utf-8")


def render_index(_: ParsedDocs) -> str:
    return f"""{generated_header()}
# Lua Reference

This section is generated from the EasyBar LuaLS stub and is meant to answer
"what is the exact API surface?" quickly.

Use these pages for exact types, event names, and property tables. For usage
patterns and architecture, use the hand-written guides.

## Generated pages

- [Functions](functions.md)
  Top-level `easybar.*` calls and node handle methods.
- [Node kinds](node-kinds.md)
  Literal kind values plus the `easybar.kind.*` namespace.
- [Events](events.md)
  Runtime event names, payloads, and the `easybar.events.*` namespace.
- [Properties](properties.md)
  Property tables used by nodes, labels, icons, popups, and layout styling.

## Recommended reading order

1. Start with [Lua Overview](../overview.md) for the node-based mental model.
2. Read [Functions](functions.md) to learn how widgets are created and updated.
3. Keep [Events](events.md) and [Properties](properties.md) open while building widgets.

## Source of truth

The source of truth is the public LuaLS stub:

```text
Sources/EasyBarApp/Lua/easybar_api.lua
```

If this reference is wrong, update the stub and regenerate the docs.
"""


def render_functions(parsed: ParsedDocs) -> str:
    lines = [generated_header(), "# Functions", "",
             "Generated from LuaLS function annotations.", ""]
    if not parsed.functions:
        lines.append("_No functions found._")
        return "\n".join(lines)

    for function in sorted(parsed.functions.values(), key=lambda item: item.name):
        lines += [f"## `{function.name}`", ""]
        if function.description:
            lines += [function.description, ""]
        if function.params:
            lines += ["### Parameters", "", "| Name | Type | Description |",
                      "| ---- | ---- | ----------- |"]
            for param in function.params:
                name = f"`{param.name}`"
                if param.optional:
                    name += " _(optional)_"
                lines.append(
                    f"| {name} | `{md_escape(param.type_name)}` | {md_escape(param.description)} |")
            lines.append("")
        if function.returns:
            lines += ["### Returns", ""]
            lines += [f"- `{return_type}`" for return_type in function.returns]
            lines.append("")
    return "\n".join(lines)


def render_alias(alias: AliasDoc, level: str = "##") -> list[str]:
    lines = [f"{level} `{alias.name}`", ""]
    if alias.description:
        lines += [alias.description, ""]
    if alias.values:
        lines += ["| Value |", "| ----- |"]
        for value in alias.values:
            lines.append(f"| `{md_escape(value)}` |")
        lines.append("")
    else:
        lines += ["_No literal values documented._", ""]
    return lines


def render_class(class_doc: ClassDoc, level: str = "##") -> list[str]:
    lines = [f"{level} `{class_doc.name}`", ""]
    if class_doc.parent:
        lines += [f"Extends `{class_doc.parent}`.", ""]
    if class_doc.modifiers:
        joined = ", ".join(f"`{modifier}`" for modifier in class_doc.modifiers)
        lines += [f"Modifiers: {joined}.", ""]
    if class_doc.description:
        lines += [class_doc.description, ""]
    if class_doc.fields:
        lines += ["| Property | Type | Description |", "| -------- | ---- | ----------- |"]
        for field in class_doc.fields:
            name = f"`{field.name}`"
            if field.optional:
                name += " _(optional)_"
            lines.append(
                f"| {name} | `{md_escape(field.type_name)}` | {md_escape(field.description)} |")
        lines.append("")
    else:
        lines += ["_No fields documented._", ""]
    return lines


def is_property_class(class_doc: ClassDoc) -> bool:
    return class_doc.name.endswith("Props") or class_doc.name == "EasyBarNodeProps"


def render_properties(parsed: ParsedDocs) -> str:
    classes = [class_doc for class_doc in parsed.classes.values()
               if is_property_class(class_doc)]
    lines = [generated_header(), "# Properties", "",
             "Generated from LuaLS class and field annotations.", ""]

    property_alias_names = [
        "EasyBarBoolLike",
        "EasyBarIconLike",
        "EasyBarLabelLike",
        "EasyBarPosition",
        "EasyBarRootPosition",
    ]
    aliases = [
        parsed.aliases[name]
        for name in property_alias_names
        if name in parsed.aliases
    ]

    if aliases:
        lines += ["## Common Value Types", ""]
        for alias in aliases:
            lines += render_alias(alias, level="###")

    if not classes:
        lines.append("_No property classes found._")
        return "\n".join(lines)

    for class_doc in sorted(classes, key=lambda item: item.name):
        lines += render_class(class_doc)
    return "\n".join(lines)


def render_node_kinds(parsed: ParsedDocs) -> str:
    lines = [generated_header(), "# Node Kinds", "",
             "Generated from LuaLS aliases and namespace fields.", ""]

    alias = parsed.aliases.get("EasyBarKind")
    if alias:
        lines += render_alias(alias)

    class_doc = parsed.classes.get("EasyBarKinds")
    if class_doc:
        lines += render_class(class_doc)

    if len(lines) <= 4:
        lines.append("_Nothing found._")

    return "\n".join(lines)


def render_events(parsed: ParsedDocs) -> str:
    lines = [generated_header(), "# Events", "",
             "Generated from LuaLS aliases and event namespace classes.", ""]

    event_name_alias = parsed.aliases.get("EasyBarEventName")
    if event_name_alias:
        lines += render_alias(event_name_alias)

    alias_names = [
        "EasyBarEventHandler",
        "EasyBarMouseButton",
        "EasyBarScrollDirection",
    ]
    aliases = [parsed.aliases[name] for name in alias_names if name in parsed.aliases]
    if aliases:
        lines += ["## Supporting Aliases", ""]
        for alias in aliases:
            lines += render_alias(alias, level="###")

    class_names = [
        "EasyBarEvent",
        "EasyBarEventToken",
        "EasyBarEvents",
        "EasyBarMouseEvents",
        "EasyBarSliderEvents",
        "EasyBarMouseButtons",
        "EasyBarScrollDirections",
        "EasyBarNetworkEventData",
        "EasyBarPowerEventData",
        "EasyBarAudioEventData",
    ]
    classes = [parsed.classes[name] for name in class_names if name in parsed.classes]
    for class_doc in classes:
        lines += render_class(class_doc)

    if parsed.event_constants:
        lines += ["## Legacy Constants", ""]
        lines += ["| Constant | Value | Description |", "| -------- | ----- | ----------- |"]
        for constant in parsed.event_constants:
            lines.append(
                f"| `{constant.name}` | `{constant.value}` | {md_escape(constant.description)} |")
        lines.append("")

    if len(lines) <= 4:
        lines.append("_Nothing found._")

    return "\n".join(lines)


def generate_docs(input_paths: list[Path], output_dir: Path) -> None:
    parsed = parse_lua_stub(input_paths)

    if output_dir.exists():
        shutil.rmtree(output_dir)

    output_dir.mkdir(parents=True, exist_ok=True)
    write_file(output_dir / "index.md", render_index(parsed))
    write_file(output_dir / "functions.md", render_functions(parsed))
    write_file(output_dir / "node-kinds.md", render_node_kinds(parsed))
    write_file(output_dir / "events.md", render_events(parsed))
    write_file(output_dir / "properties.md", render_properties(parsed))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", action="append", type=Path, dest="inputs")
    parser.add_argument("--output", type=Path,
                        default=Path("docs/content/lua/reference"))
    args = parser.parse_args()

    inputs = args.inputs or [
        Path("Sources/EasyBarApp/Lua/easybar_api.lua"),
        Path("Sources/EasyBarApp/Lua/easybar_api.base.lua"),
        Path("Sources/EasyBarApp/Lua/easybar_api.events.lua"),
    ]

    existing_inputs = [path for path in inputs if path.exists()]
    if not existing_inputs:
        joined = "\n".join(str(path) for path in inputs)
        raise SystemExit(f"No LuaLS stub files found. Checked:\n{joined}")

    generate_docs(existing_inputs, args.output)


if __name__ == "__main__":
    main()
