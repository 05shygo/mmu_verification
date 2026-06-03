#!/usr/bin/env python3
"""
Preprocess SystemVerilog to flatten multi-dimensional packed arrays for Yosys 0.20.

Transforms:
  logic [A:B][C:D] sig_name;   ->  logic [(A-B+1)*(C-D+1)-1:0] sig_name;
  sig_name[idx][C:D]           ->  sig_name[idx*(C-D+1)+D +: (C-D+1)]

Handles parameterized dimensions by keeping them as expressions.
"""

import re
import sys
import os

def dim_width(dim_str):
    """Return the width expression for a dimension like '3:0' or 'W-1:0'.
    Returns (width_expr, lo_expr) e.g., ('4', '0') or ('W', '0').
    For parameterized dims like 'PTE_LEVEL-1:0', returns ('PTE_LEVEL', '0').
    """
    dim_str = dim_str.strip()
    parts = dim_str.split(':')
    if len(parts) != 2:
        return None, None
    hi = parts[0].strip()
    lo = parts[1].strip()
    # width = hi - lo + 1
    width = f'({hi}-({lo})+1)'
    return width, lo


def find_mdim_decls(content):
    """Find all multi-dimensional packed array declarations.
    Returns dict mapping signal_name -> (first_dim, second_dim, width_expr, lo_expr)
    """
    signals = {}
    # Pattern: logic [DIM1] [DIM2] sig_name  (allow optional whitespace between brackets)
    pattern = r'logic\s+\[([^\]]+)\]\s*\[([^\]]+)\]\s*(\w+)'
    for m in re.finditer(pattern, content):
        dim1 = m.group(1)
        dim2 = m.group(2)
        sig = m.group(3)
        w, lo = dim_width(dim2)
        if w:
            signals[sig] = (dim1, dim2, w, lo)
    return signals


def process_file(input_path, output_path):
    with open(input_path, 'r') as f:
        content = f.read()

    signals = find_mdim_decls(content)

    if not signals:
        print(f"  No multi-dim arrays in {input_path}, copying as-is.")
        with open(output_path, 'w') as f:
            f.write(content)
        return

    # Step 1: Flatten declarations
    # Replace: [...] [...] sig (with any whitespace) with flattened dimension
    for sig, (dim1, dim2, width, lo) in signals.items():
        dim1_w, _ = dim_width(dim1)
        # Match: [DIM1][DIM2] <whitespace> sig_name
        # Use regex to handle variable whitespace between ] and sig_name
        pattern = re.compile(
            r'\[' + re.escape(dim1) + r'\]\s*\[' + re.escape(dim2) + r'\]\s*' + re.escape(sig)
        )
        replacement = f'[{dim1_w}*{width}-1:0] {sig}'
        content = pattern.sub(replacement, content)

    # Step 2a: Flatten two-bracket part-selects
    # Pattern: sig[IDX][HI:LO] -> sig[IDX*WIDTH+LO +: WIDTH]
    for sig, (dim1, dim2, width, lo) in signals.items():
        pattern = re.compile(
            r'\b' + re.escape(sig) + r'\[([^\]]+)\]\[([^\]]+)\]'
        )
        def make_repl(w, l):
            def repl(m):
                idx = m.group(1)
                inner = m.group(2)
                if '+:' in inner:
                    return m.group(0)  # Already processed
                return f'{sig}[({idx})*{w}+{l} +: {w}]'
            return repl
        content = pattern.sub(make_repl(width, lo), content)

    # Step 2b: Flatten single-index accesses of former 2D arrays
    # Pattern: sig[IDX] -> sig[(IDX)*INNER_WIDTH+LO +: INNER_WIDTH]
    # Skip range accesses (contain ':') and already-flattened patterns
    for sig, (dim1, dim2, width, lo) in signals.items():
        pattern = re.compile(
            r'\b' + re.escape(sig) + r'\[([^\]:]+)\](?!\s*\[)'
        )
        def make_single_repl(w, l):
            def repl(m):
                idx = m.group(1)
                if '+:' in idx:
                    return m.group(0)  # Already processed, skip
                return f'{sig}[({idx})*{w}+{l} +: {w}]'
            return repl
        content = pattern.sub(make_single_repl(width, lo), content)

    # Step 3: Replace '{default:0} with '0 (Yosys 0.20 doesn't support assignment patterns)
    content = content.replace("'{default:0}", "'0")

    with open(output_path, 'w') as f:
        f.write(content)

    print(f"  Preprocessed {input_path}: flattened {len(signals)} signals:")
    for sig in sorted(signals.keys()):
        print(f"    {sig}")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: preprocess_sv.py <file1.sv> [file2.sv ...]")
        sys.exit(1)

    syn_scripts_dir = os.path.dirname(os.path.abspath(__file__))

    for input_path in sys.argv[1:]:
        basename = os.path.basename(input_path)
        output_path = os.path.join(syn_scripts_dir, 'syn_' + basename)
        process_file(input_path, output_path)
