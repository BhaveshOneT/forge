#!/usr/bin/env bash

set -euo pipefail

SCHEMA_FILE="${1:?Usage: validate-json.sh <schema-file> <json-file>}"
JSON_FILE="${2:?Usage: validate-json.sh <schema-file> <json-file>}"

python3 - "$SCHEMA_FILE" "$JSON_FILE" <<'PY'
import json
import re
import sys
from pathlib import Path


def load_json(path_str):
    path = Path(path_str)
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


schema = load_json(sys.argv[1])
payload = load_json(sys.argv[2])
errors = []


def add_error(path, message):
    location = path or "$"
    errors.append(f"{location}: {message}")


def validate_type(value, expected):
    if isinstance(expected, list):
        return any(validate_type(value, candidate) for candidate in expected)

    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        return (isinstance(value, int) or isinstance(value, float)) and not isinstance(value, bool)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "null":
        return value is None
    return True


def validate(value, spec, path="$"):
    expected_type = spec.get("type")
    if expected_type is not None and not validate_type(value, expected_type):
        add_error(path, f"expected type {expected_type!r}, got {type(value).__name__}")
        return

    if "enum" in spec and value not in spec["enum"]:
        add_error(path, f"value {value!r} is not in enum {spec['enum']!r}")

    if isinstance(value, str):
        pattern = spec.get("pattern")
        if pattern and not re.fullmatch(pattern, value):
            add_error(path, f"value {value!r} does not match pattern {pattern!r}")

        min_length = spec.get("minLength")
        if min_length is not None and len(value) < min_length:
            add_error(path, f"string length {len(value)} < minimum {min_length}")

    if isinstance(value, (int, float)) and not isinstance(value, bool):
        minimum = spec.get("minimum")
        maximum = spec.get("maximum")
        if minimum is not None and value < minimum:
            add_error(path, f"value {value} < minimum {minimum}")
        if maximum is not None and value > maximum:
            add_error(path, f"value {value} > maximum {maximum}")

    if isinstance(value, list):
        min_items = spec.get("minItems")
        if min_items is not None and len(value) < min_items:
            add_error(path, f"array length {len(value)} < minimum {min_items}")

        item_spec = spec.get("items")
        if item_spec:
            for index, item in enumerate(value):
                validate(item, item_spec, f"{path}[{index}]")

    if isinstance(value, dict):
        required = spec.get("required", [])
        for key in required:
            if key not in value:
                add_error(path, f"missing required property {key!r}")

        properties = spec.get("properties", {})
        additional_allowed = spec.get("additionalProperties", True)
        if additional_allowed is False:
            for key in value:
                if key not in properties:
                    add_error(path, f"unexpected property {key!r}")

        for key, prop_spec in properties.items():
            if key in value:
                validate(value[key], prop_spec, f"{path}.{key}")


validate(payload, schema)

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)
PY
