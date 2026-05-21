#!/usr/bin/env python3
"""Generate EasyBar Lua reference docs from LuaLS annotations.

Generated docs are reference-only. Keep concept guides, examples, and patterns
as hand-written Markdown pages under docs/lua/guides.
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
    r"^---@class\s+([A-Za-z0-9_.:]+)(?::\s*([A-Za-z0-9_.:]+))?\s*(.*)$")
FIELD_RE = re.compile(
    r"^---@field\s+([A-Za-z0-9_.:\[\]-]+)(\?)?\s+(.+?)(?:\s+#\s*(.*))?$")
PARAM_RE = re.compile(
    r"^---@param\s+([A-Za-z0-9_.:\[\]-]+)(\?)?\s+(.+?)(?:\s+#\s*(.*))?$")
RETURN_RE = re.compile(r"^---@return\s+(.+)$")
ALIAS_RE = re.compile(r"^---@alias\s+([A-Za-z0-9_.:]+)\s*(.*)$")
FUNCTION_RE = re.compile(
    r"^(?:function\s+([A-Za-z0-9_.:]+)\s*\(|([A-Za-z0-9_.:]+)\s*=\s*function\s*\()")
CONST_RE = re.compile(
    r"^(easybar\.(?:events|kind)[A-Za-z0-9_.]*)\s*=\s*['\"]([^'\"]+)['\"]")


def doc_text(line: str) -> str | None:
    if line.startswith("---@"):
        return None
    if line.startswith("---"):
        return line[3:].strip()
    return None


def md_escape(text: str) -> str:
    return text.replace("|", "\\|").strip()


def alias_values(text: str) -> list[str]:
    return [part.strip() for part in text.split("|") if part.strip()]


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
                name, parent, trailing = match.groups()
                description = "\n".join(pending_description).strip()
                if trailing:
                    description = f"{description}\n{trailing.strip()}".strip()
                current_class = ClassDoc(
                    name=name, parent=parent, description=description)
                parsed.classes[name] = current_class
                current_alias = None
                pending_description = []
                continue

            if match := FIELD_RE.match(stripped):
                if current_class:
                    name, optional, type_name, description = match.groups()
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

            if current_alias and stripped.startswith('---|"'):
                current_alias.values.append(
                    stripped.removeprefix("---|").strip())
                continue

            if match := PARAM_RE.match(stripped):
                name, optional, type_name, description = match.groups()
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
This file is generated by tools/generate_lua_reference_docs.py.
Do not edit this file by hand. Update the LuaLS stub instead.
-->
"""


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n", encoding="utf-8")


def render_index(_: ParsedDocs) -> str:
    return f"""{generated_header()}
# Lua Reference

This section is generated from the EasyBar LuaLS stub.

Use these pages as the API reference. For usage patterns and explanations, use the hand-written Lua guides.

## Generated pages

- [Functions](functions.md)
- [Node kinds](node-kinds.md)
- [Events](events.md)
- [Properties](properties.md)

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


def render_constants(title: str, constants: list[ConstantDoc], aliases: list[AliasDoc]) -> str:
    lines = [generated_header(), f"# {title}", ""]
    if constants:
        lines += ["| Constant | Value | Description |",
                  "| -------- | ----- | ----------- |"]
        for constant in constants:
            lines.append(
                f"| `{constant.name}` | `{constant.value}` | {md_escape(constant.description)} |")
        lines.append("")
    for alias in aliases:
        lines += [f"## `{alias.name}`", ""]
        if alias.description:
            lines += [alias.description, ""]
        for value in alias.values:
            lines.append(f"- `{value}`")
        lines.append("")
    if not constants and not aliases:
        lines.append("_Nothing found._")
    return "\n".join(lines)


def is_property_class(class_doc: ClassDoc) -> bool:
    lowered = class_doc.name.lower()
    return any(word in lowered for word in (
        "props", "properties", "icon", "label", "background", "popup",
        "font", "slider", "progress", "sparkline", "spaces", "padding",
        "margin", "node",
    ))


def render_properties(parsed: ParsedDocs) -> str:
    classes = [class_doc for class_doc in parsed.classes.values()
               if is_property_class(class_doc)]
    lines = [generated_header(), "# Properties", "",
             "Generated from LuaLS class and field annotations.", ""]
    if not classes:
        lines.append("_No property classes found._")
        return "\n".join(lines)

    for class_doc in sorted(classes, key=lambda item: item.name):
        lines += [f"## `{class_doc.name}`", ""]
        if class_doc.parent:
            lines += [f"Extends `{class_doc.parent}`.", ""]
        if class_doc.description:
            lines += [class_doc.description, ""]
        if class_doc.fields:
            lines += ["| Property | Type | Description |",
                      "| -------- | ---- | ----------- |"]
            for field in class_doc.fields:
                name = f"`{field.name}`"
                if field.optional:
                    name += " _(optional)_"
                lines.append(
                    f"| {name} | `{md_escape(field.type_name)}` | {md_escape(field.description)} |")
            lines.append("")
        else:
            lines += ["_No fields documented._", ""]
    return "\n".join(lines)


def generate_docs(input_paths: list[Path], output_dir: Path) -> None:
    parsed = parse_lua_stub(input_paths)

    if output_dir.exists():
        shutil.rmtree(output_dir)

    output_dir.mkdir(parents=True, exist_ok=True)
    write_file(output_dir / "index.md", render_index(parsed))
    write_file(output_dir / "functions.md", render_functions(parsed))
    write_file(output_dir / "node-kinds.md", render_constants(
        "Node Kinds",
        parsed.kind_constants,
        [alias for alias in parsed.aliases.values() if "kind" in alias.name.lower()],
    ))
    write_file(output_dir / "events.md", render_constants(
        "Events",
        parsed.event_constants,
        [alias for alias in parsed.aliases.values() if "event" in alias.name.lower()],
    ))
    write_file(output_dir / "properties.md", render_properties(parsed))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", action="append", type=Path, dest="inputs")
    parser.add_argument("--output", type=Path,
                        default=Path("docs/lua/reference"))
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
