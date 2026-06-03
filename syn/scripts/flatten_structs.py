#!/usr/bin/env python3
"""
Convert packed struct declarations and field accesses to flat packed arrays
for Yosys 0.20 compatibility.

Handles:
  typedef struct packed { field1; field2; ... } typename;
  typename array_name[SIZE];

And all field accesses:
  array_name[idx].field -> array_name[idx][FIELD_HI:FIELD_LO]
"""

import re
import sys
import os

def parse_packed_struct_fields(struct_text):
    """Parse a packed struct definition and return list of (name, msb, lsb, width)."""
    fields = []
    # Remove comments
    text = re.sub(r'//[^\n]*', '', struct_text)
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)

    # Find typedef struct packed { ... } name;
    # Extract body between { and }
    m = re.search(r'typedef\s+struct\s+packed\s*\{([^}]*)\}\s*(\w+)\s*;', text, re.DOTALL)
    if not m:
        return None, None, []

    body = m.group(1)
    type_name = m.group(2)

    # Parse each field: optional 'logic' or just type, optional [width], field_name;
    # We need to handle: logic [W-1:0] name;  and  logic name;  and  logic [A:B][C:D] name;
    # For simplicity, handle single-dim fields and single-bit fields
    field_lines = [l.strip() for l in body.split(';') if l.strip()]
    total_width = 0
    field_specs = []

    for line in field_lines:
        # Remove trailing comments
        line = re.sub(r'//[^\n]*', '', line).strip()
        if not line:
            continue

        # Match: [optional type] [WIDTH] field_name [= default]
        # Patterns:
        # logic field_name
        # logic [HI:LO] field_name
        # logic [A:B][C:D] field_name
        pm = re.match(r'(?:logic\s+)?(?:\[([^\]]+)\]\s*)?(?:\[([^\]]+)\]\s*)?(\w+)\s*(?:=\s*[^,;]+)?', line)
        if not pm:
            print(f"    WARNING: cannot parse field: {line}")
            continue

        dim1 = pm.group(1)  # e.g., "WAY_NUM-1:0"
        dim2 = pm.group(2)  # second dimension if present
        fname = pm.group(3)

        if dim1 and dim2:
            # Multi-dimensional: width = (dim1_range) * (dim2_range)
            w = f'({dim_width_expr(dim1)})*({dim_width_expr(dim2)})'
            h = w
            l = '0'
        elif dim1:
            w = dim_width_expr(dim1)
            h = w
            l = '0'
        else:
            h = '1'
            l = '0'
            w = '1'

        field_specs.append((fname, h, l, w))
        total_width += 1  # placeholder; actual width is expression-based

    # Now compute bit offsets (MSB first for packed struct)
    # For expression-based widths, we keep them as expressions
    result = []
    offset_expr = '0'
    for i, (fname, h, l, w) in enumerate(field_specs):
        if i == 0:
            hi_expr = f'({w})-1'
            lo_expr = '0'
        else:
            hi_expr = f'({prev_hi})+({w})'
            lo_expr = f'({prev_hi})+1'
        result.append((fname, hi_expr, lo_expr))
        prev_hi = hi_expr

    return type_name, result, m


def dim_width_expr(dim):
    """Return width expression for a dimension like '3:0' or 'W-1:0'."""
    parts = dim.split(':')
    if len(parts) == 2:
        hi = parts[0].strip()
        lo = parts[1].strip()
        return f'({hi}-({lo})+1)'
    return '1'


def compute_field_offsets_from_file(filepath):
    """Read a file, find struct definitions, and compute field bit offsets."""
    with open(filepath, 'r') as f:
        content = f.read()

    # Find all typedef struct packed blocks
    structs = {}
    pattern = r'typedef\s+struct\s+packed\s*\{([^}]*)\}\s*(\w+)\s*;'
    for m in re.finditer(pattern, content, re.DOTALL):
        body = m.group(1)
        type_name = m.group(2)
        fields = []
        lines = [l.strip() for l in body.split(';') if l.strip()]

        # Compute total width by expanding each field
        field_widths = []
        for line in lines:
            line = re.sub(r'//.*', '', line).strip()
            if not line:
                continue
            pm = re.match(r'(?:logic\s+)?\[([^\]]+)\]\s*(\w+)', line)
            if pm:
                w = dim_width_expr(pm.group(1))
                fname = pm.group(2)
                field_widths.append((fname, w))
            else:
                pm2 = re.match(r'(?:logic\s+)?(\w+)', line)
                if pm2:
                    field_widths.append((pm2.group(1), '1'))

        # Compute cumulative offsets from LSB
        structs[type_name] = {}
        cum_width = '0'
        for fname, w in reversed(field_widths):
            structs[type_name][fname] = (f'({cum_width})+({w})-1', cum_width)
            cum_width = f'({cum_width})+({w})'

        structs[type_name]['_total_width'] = cum_width

    return structs


def flatten_struct_file(input_path, output_path):
    """Flatten all struct field accesses in a file."""
    structs = compute_field_offsets_from_file(input_path)

    if not structs:
        print(f"  No structs found in {input_path}, copying as-is.")
        with open(input_path, 'r') as f_in, open(output_path, 'w') as f_out:
            f_out.write(f_in.read())
        return

    with open(input_path, 'r') as f:
        content = f.read()

    # Find array declarations using struct types
    for type_name, fields in structs.items():
        total_w = fields['_total_width']
        # Replace: expt_ent_t ent[CAM_DEPTH] with: logic [TOTAL_W-1:0] ent [CAM_DEPTH-1:0]
        # Note: unpacked array syntax stays the same
        decl_pattern = re.compile(
            r'\b' + type_name + r'\s+(\w+)\s*\[([^\]]+)\]'
        )
        for dm in decl_pattern.finditer(content):
            arr_name = dm.group(1)
            arr_size = dm.group(2)

        # Replace typedef struct packed { ... } type_name; with comment
        content = re.sub(
            r'typedef\s+struct\s+packed\s*\{[^}]*\}\s*' + type_name + r'\s*;',
            f'// {type_name} struct flattened to logic [{total_w}-1:0] for Yosys compatibility',
            content,
            flags=re.DOTALL
        )

        # Replace type_name with logic width in array declarations
        content = re.sub(
            r'\b' + type_name + r'\s+',
            f'logic [{total_w}-1:0] ',
            content
        )

        # Replace field accesses: arr[idx].field -> arr[idx][HI:LO]
        for fname, (hi, lo) in fields.items():
            if fname.startswith('_'):
                continue
            # arr_name[idx].field -> arr_name[idx][HI:LO]
            content = re.sub(
                r'(\w+)\[([^\]]+)\]\.' + fname + r'\b',
                rf'\1[\2][{hi}:{lo}]',
                content
            )

    # Replace '{default:0} with '0
    content = content.replace("'{default:0}", "'0")

    with open(output_path, 'w') as f:
        f.write(content)

    print(f"  Flattened structs in {input_path}:")
    for type_name, fields in structs.items():
        field_names = [f for f in fields.keys() if not f.startswith('_')]
        print(f"    {type_name}: {field_names}")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: flatten_structs.py <file1.sv> [file2.sv ...]")
        sys.exit(1)

    syn_scripts_dir = os.path.dirname(os.path.abspath(__file__))

    for input_path in sys.argv[1:]:
        basename = os.path.basename(input_path)
        output_path = os.path.join(syn_scripts_dir, 'flattened_' + basename)
        flatten_struct_file(input_path, output_path)
