#!/usr/bin/env python3
"""Extract uncovered code coverage items for L1TLB and L2TLB scopes from URG HTML report.

Reads phase14_urgReport/modNN.html (and cond-split pages modNN_cM.html) and produces
a markdown report grouped by module, mirroring ptw_covp_uncovered_code_report.md format.
"""
import argparse
import html
import re
import sys
from pathlib import Path
from collections import OrderedDict, defaultdict


# Mapping: modfile basename -> module name (for TLB-relevant modules)
# We'll discover module name from <title> in each HTML.

# L1TLB scope modules - we discover by checking which module HTML files have
# source file path under mmu_l1dtlb.sv / mmu_l1itlb.sv / or are clearly sub-modules.
# Instead of hard-coding, we'll list known TLB-relevant module names.
L1TLB_MODULES = [
    "mmu_l1dtlb",
    "mmu_l1dtlb_allocator",
    "mmu_l1dtlb_mb_entry",
    "mmu_l1dtlb_expt_cam",
    "mmu_l1dtlb_hit_rd",
    "mmu_l1dtlb_install",
    "mmu_l1dtlb_scheduler",
    "mmu_l1itlb",
    "ct_mmu_iutlb_entry",
    "ct_mmu_iutlb_fst_entry",
    # SVAs
    "mmu_l1dtlb_sva",
    "mmu_l1dtlb_mb_entry_sva",
    "mmu_l1dtlb_expt_cam_sva",
    "mmu_l1dtlb_install_sva",
    "mmu_l1dtlb_hit_rd_sva",
    "mmu_l1dtlb_allocator_sva",
    "mmu_l1dtlb_scheduler_sva",
]

L2TLB_MODULES = [
    "mmu_l2tlb",
    "mmu_l2tlb_reqq",
    "mmu_l2tlb_reqq_entry",
    "mmu_l2tlb_replacement_policy",
    "mmu_l2tlb_rrpv_wbuf",
    "mmu_l2tlb_mb",
    "mmu_l2tlb_mb_entry",
    "ct_mmu_l2tlb_rrpv_array",
    "ct_mmu_l2tlb_tag_array",
    "ct_mmu_l2tlb_data_array",
    # SVAs
    "mmu_l2tlb_rrpv_sva",
    "mmu_l2tlb_mb_sva",
    "mmu_l2tlb_rrpv_wbuf_sva",
]


def strip_html(raw: str) -> str:
    raw = html.unescape(raw)
    raw = re.sub(r"<[^>]+>", "", raw)
    return raw


def get_module_name(report_dir: Path, modfile: str) -> str:
    """Extract module name from <title> of modNN.html."""
    path = report_dir / (modfile + ".html")
    if not path.is_file():
        return ""
    text = path.read_text(encoding="utf-8", errors="ignore")
    m = re.search(r"<title>Unified Coverage Report :: Module :: ([^<]+)</title>", text)
    if m:
        return m.group(1).strip()
    return ""


def get_source_file(report_dir: Path, modfile: str) -> str:
    """Extract primary source file from module HTML."""
    path = report_dir / (modfile + ".html")
    text = path.read_text(encoding="utf-8", errors="ignore")
    m = re.search(r"openSrcFile\('([^']+)'\)", text)
    if m:
        return m.group(1)
    return ""


def get_score_row(report_dir: Path, modfile: str) -> dict:
    """Extract SCORE/LINE/COND/TOGGLE/FSM/BRANCH/ASSERT for this module from modlist.txt."""
    out = {}
    keys = ["score", "line", "cond", "toggle", "fsm", "branch", "assert"]
    modlist = report_dir / "modlist.txt"
    if not modlist.is_file():
        return out
    text = modlist.read_text(encoding="utf-8", errors="ignore")
    # Look for the module name line. Format columns:
    #   SCORE LINE COND TOGGLE FSM BRANCH ASSERT NAME
    # Values may be "##.##" or "--" (no metric).
    # We find the line whose trailing field is exactly the module name (whitespace-separated).
    module_name = get_module_name(report_dir, modfile)
    if not module_name:
        return out
    # The module name may also be parametrized (e.g. "ct_spsram_wrapper ( parameter ... )");
    # we only match the base name on its own line.
    for line in text.splitlines():
        s = line.strip()
        if not s:
            continue
        # Split on whitespace; last token is the name (for non-param lines)
        parts = s.split()
        if len(parts) < 2:
            continue
        # Match the simple form: "score line cond toggle fsm branch assert NAME"
        if parts[-1] == module_name and len(parts) >= 8:
            try:
                vals = parts[:7]
                # Sanity check: all should be numeric or "--"
                ok = all(re.match(r"^\d+\.\d+$", v) or v == "--" for v in vals)
                if ok:
                    for k, v in zip(keys, vals):
                        out[k] = v
                    break
            except Exception:
                pass
    return out


def find_modfile_for_module(report_dir: Path, module_name: str) -> str:
    """Find modNN basename whose <title> module matches given name."""
    for path in sorted(report_dir.glob("mod*.html")):
        # Skip instance/split pages
        bn = path.stem
        if "_" in bn and not re.match(r"mod\d+$", bn.split("_")[0]):
            continue
        if "_" in bn:
            # skip mod27_0 / mod106_c1 style
            continue
        name = get_module_name(report_dir, bn)
        if name == module_name:
            return bn
    return ""


def find_cond_split_pages(report_dir: Path, modfile: str) -> list:
    """Return list of cond-split basenames (e.g. mod106_c1, mod106_c2) for module."""
    out = []
    for path in sorted(report_dir.glob(modfile + "_c*.html")):
        out.append(path.stem)
    return out


def get_module_section_range(text: str, section_header_re: str) -> tuple:
    """Find the byte range of a coverage section. Returns (start, end).

    Boundary is the next coverage section header (Line/Cond/Toggle/Branch/FSM/Assert
    Coverage for Module) or the per-instance "Coverage for Instance" header.
    Note: we do NOT use <hr> as a boundary because some sections (notably FSM
    details) include <hr> between summary and detail tables.
    """
    m = re.search(section_header_re, text)
    if not m:
        return (-1, -1)
    start = m.start()
    rest = text[start:]
    end_m = re.search(
        r"Line Coverage for Module|Cond Coverage for Module|"
        r"Toggle Coverage for Module|Branch Coverage for Module|"
        r"FSM Coverage for Module|Assert Coverage for Module|"
        r"Coverage for Instance",
        rest[100:],
    )
    if end_m:
        return (start, start + 100 + end_m.start())
    return (start, len(text))


def parse_line_coverage(text: str) -> list:
    """Extract uncovered lines from Line Coverage for Module section.

    Returns list of (line_no, code_text) tuples.
    """
    out = []
    start, end = get_module_section_range(text, r"<a name=\"Line\"></a>\s*Line Coverage for Module")
    if start < 0:
        return out
    section = text[start:end]
    # Find all red font lines with 0/N markers
    # Format: " LINENO <font color = "red">HIT/TOT ==> CODE</font>"
    pattern = re.compile(
        r"(?:^|\n)\s*(\d+)\s*<font color = \"red\">\s*(\d+)/(\d+)\s*==>\s*([^<]+)</font>",
    )
    seen = set()
    for m in pattern.finditer(section):
        line_no, hit, total, code = m.group(1), m.group(2), m.group(3), m.group(4)
        if hit != "0" or total == "0":
            continue
        code_clean = strip_html(code).strip()
        key = (line_no, code_clean)
        if key in seen:
            continue
        seen.add(key)
        out.append((line_no, code_clean))
    return out


def parse_cond_coverage(report_dir: Path, modfile: str) -> list:
    """Extract uncovered cond items from cond split pages or inline.

    Returns list of dicts: {line, kind (EXPRESSION/SUB-EXPRESSION), text, uncovered_combos}
    """
    out = []
    split_pages = find_cond_split_pages(report_dir, modfile)
    if split_pages:
        files = [report_dir / (sp + ".html") for sp in split_pages]
    else:
        # inline in main module file
        path = report_dir / (modfile + ".html")
        if not path.is_file():
            return out
        text = path.read_text(encoding="utf-8", errors="ignore")
        start, end = get_module_section_range(text, r"<a name=\"Cond\"></a>\s*Cond Coverage for Module")
        if start < 0:
            return out
        files = []  # we'll handle inline below
        inline_text = text[start:end]
        files = [None]  # sentinel

    for fpath in files:
        if fpath is None:
            section = inline_text
        else:
            section = fpath.read_text(encoding="utf-8", errors="ignore")
        # Walk through expression blocks
        # Each block: <pre class="code"> LINE N \n (EXPRESSION|SUB-EXPRESSION) (expr) ... </pre>
        # Followed by <table> with rows containing 0/1 term values and status
        blocks = re.split(r"<pre class=\"code\">", section)
        for block in blocks[1:]:
            # Find the closing </pre>
            pre_end = block.find("</pre>")
            if pre_end < 0:
                continue
            pre_content = block[:pre_end]
            # Extract LINE number
            ln_m = re.search(r"LINE\s+(\d+)", pre_content)
            if not ln_m:
                continue
            line_no = ln_m.group(1)
            # Determine EXPRESSION or SUB-EXPRESSION
            kind_m = re.search(r"(EXPRESSION|SUB-EXPRESSION)", pre_content)
            if not kind_m:
                continue
            kind = kind_m.group(1)
            # Build expression text. Two forms:
            # (a) single-line: " EXPRESSION (expr)" -> capture text after EXPRESSION on same line
            # (b) multi-line : " EXPRESSION \n Number  Term \n      1  term1 \n      2  term2 ..."
            single_m = re.search(r"EXPRESSION\s+(\([^<]+?)\s*$", pre_content, re.MULTILINE)
            multi_m = re.search(r"EXPRESSION\s*\n\s*Number\s+Term(.*?)(?:\n\s*</pre>|\Z)", pre_content, re.DOTALL)
            if single_m and not multi_m:
                expr_text = single_m.group(1).strip()
            elif multi_m:
                # Concatenate terms: each line is "      N  term"
                term_lines = re.findall(r"\n\s*\d+\s+(.+?)(?=\n|\Z)", multi_m.group(1))
                expr_text = " ".join(strip_html(t).strip() for t in term_lines if t.strip())
                # Wrap with parens to indicate multi-term expression
                expr_text = "(" + expr_text + ")"
            else:
                # Fallback: take whatever follows EXPRESSION on the same line
                fb = re.search(r"EXPRESSION\s+(.+?)(?:\n|$)", pre_content)
                expr_text = fb.group(1).strip() if fb else ""
            expr_text = strip_html(expr_text).strip()
            # Now find the next <table> after this pre block
            tbl_start = block.find("<table", pre_end)
            tbl_end = block.find("</table>", tbl_start)
            if tbl_start < 0 or tbl_end < 0:
                continue
            tbl = block[tbl_start:tbl_end]
            # Find uRed rows with Not Covered status
            rows = re.findall(r"<tr\s+class=\"uRed\">.*?</tr>", tbl, re.DOTALL)
            for row in rows:
                tds = re.findall(r"<td[^>]*>(.*?)</td>", row, re.DOTALL)
                tds_clean = [strip_html(t).strip() for t in tds]
                if not any("Not Covered" in t.replace("&nbsp;", " ") for t in tds_clean):
                    continue
                vals = [t for t in tds_clean if t and "Covered" not in t.replace("&nbsp;", " ")]
                combo = " ".join(vals) + " Not Covered"
                out.append({
                    "line": line_no,
                    "kind": kind,
                    "text": expr_text,
                    "combo": combo,
                })
    return out


def parse_toggle_coverage(text: str) -> tuple:
    """Extract uncovered toggle items. Returns (ports_list, signals_list).

    Each item: (name, toggle, t10, t01, direction)
    """
    ports = []
    signals = []
    start, end = get_module_section_range(text, r"<a name=\"Toggle\"></a>\s*Toggle Coverage for Module")
    if start < 0:
        return (ports, signals)
    section = text[start:end]
    # Port Details and Signal Details tables
    # Find <caption><b>Port Details</b></caption> and Signal Details
    for caption, sink in [("Port Details", ports), ("Signal Details", signals)]:
        cap_m = re.search(r"<caption><b>" + caption + r"</b></caption>(.*?)</table>", section, re.DOTALL)
        if not cap_m:
            continue
        tbl = cap_m.group(1)
        # Each row: <tr><td>name</td><td class="sN cl">Yes/No</td><td class="sN cl">Yes/No</td>...
        # Some have direction column (Ports)
        rows = re.findall(
            r"<tr>\s*<td[^>]*>([^<]+)</td>\s*"
            r"<td class=\"s\d+ cl\">(Yes|No)</td>\s*"
            r"<td class=\"s\d+ cl\">(Yes|No)</td>\s*"
            r"<td class=\"s\d+ cl\">(Yes|No)</td>\s*"
            r"(?:<td>([^<]*)</td>)?",
            tbl,
        )
        for r in rows:
            name, tog, t10, t01, direction = r
            if tog == "No" or t10 == "No" or t01 == "No":
                sink.append((name.strip(), tog, t10, t01, (direction or "").strip()))
    return (ports, signals)


def parse_branch_coverage(text: str) -> list:
    """Extract uncovered branches. Returns list of (line_no, branch_text, uncovered_combo)."""
    out = []
    start, end = get_module_section_range(text, r"<a name=\"Branch\"></a>\s*Branch Coverage for Module")
    if start < 0:
        return out
    section = text[start:end]
    # Walk through pre blocks (each pre block corresponds to one if/case statement)
    blocks = re.split(r"<pre class=\"code\">", section)
    for block in blocks[1:]:
        pre_end = block.find("</pre>")
        if pre_end < 0:
            continue
        pre_content = block[:pre_end]
        # Get first source line number in pre block (digit token at start of a line)
        ln_m = re.search(r"(?:^|\n)\s*(\d+)\s", pre_content)
        if not ln_m:
            continue
        line_no = ln_m.group(1)
        # Find MISSING_ELSE marker
        has_missing_else = "MISSING_ELSE" in pre_content
        # Find the next table after this pre block
        tbl_start = block.find("<table", pre_end)
        tbl_end = block.find("</table>", tbl_start)
        if tbl_start < 0 or tbl_end < 0:
            continue
        tbl = block[tbl_start:tbl_end]
        # Find each uRed row, then check if any td is "Not Covered"
        rows = re.findall(r"<tr\s+class=\"uRed\">.*?</tr>", tbl, re.DOTALL)
        for row in rows:
            tds = re.findall(r"<td[^>]*>(.*?)</td>", row, re.DOTALL)
            tds_clean = [strip_html(t).strip() for t in tds]
            # Check if last or any td is "Not Covered"
            if not any("Not Covered" in t.replace("&nbsp;", " ") for t in tds_clean):
                continue
            # All but status td are term values
            vals = [t for t in tds_clean if t and "Covered" not in t.replace("&nbsp;", " ")]
            combo = " ".join(vals) + " Not Covered"
            # Use first code line for context
            first_code = strip_html(pre_content).strip().split("\n")[0][:100]
            out.append((line_no, first_code, combo))
        if has_missing_else:
            # Also need to confirm MISSING_ELSE row is marked Not Covered
            me_rows = re.findall(
                r"MISSING_ELSE.*?Not\s*Covered",
                block[pre_end:tbl_end + 200],
                re.DOTALL,
            )
            if me_rows:
                out.append((line_no, "MISSING_ELSE", "implicit else Not Covered"))
    return out


def parse_fsm_coverage(text: str) -> list:
    """Extract uncovered FSM transitions. Returns list of (fsm_name, transition, line_no)."""
    out = []
    start, end = get_module_section_range(text, r"<a name=\"FSM\"></a>\s*FSM Coverage for Module|FSM Coverage for Module")
    if start < 0:
        return out
    section = text[start:end]
    # Find each FSM summary: <caption><b>Summary for FSM :: name</b></caption>
    # Each followed by transitions table
    fsm_blocks = re.split(r"Summary for FSM :: ([^<]+)</b></caption>", section)
    # fsm_blocks[0] is preamble, then alternating (fsm_name, content_until-next-split)
    for i in range(1, len(fsm_blocks), 2):
        fsm_name = fsm_blocks[i].strip()
        content = fsm_blocks[i+1] if i+1 < len(fsm_blocks) else ""
        # Find "transitions" table in content
        # Match each uRed transition row
        rows = re.findall(
            r"<tr\s+class=\"uRed\">\s*<td nowrap>([^<]+)</td>\s*<td class=\"rt\">(\d+)</td>\s*<td>Not(?:&nbsp;|\s+)Covered</td>",
            content,
        )
        for trans, line_no in rows:
            out.append((fsm_name, trans.strip(), line_no))
    return out


def parse_assert_coverage(text: str) -> list:
    """Extract uncovered assertions. Returns list of dicts {name, attempts, successes, kind}."""
    out = []
    start, end = get_module_section_range(text, r"<a name=\"Assert\"></a>\s*Assert Coverage for Module|Assert Coverage for Module")
    if start < 0:
        return out
    section = text[start:end]
    # There are two types: "Real Successes" (assertions) and "Matches" (covers)
    # For assertions: rows with Real Successes=0
    # Table header: <th>Attempts</th><th>Real Successes</th>...
    # Pattern: <a name="N"></a>\nname\n in <td>, then <td class="sN cl rt">N</td> for attempts,
    #   then <td class="sN cl rt">N</td> for real successes / matches
    # Parse all assertion rows
    # Header detection
    has_real_succ = "Real Successes" in section
    has_matches = "Matches" in section and ">Matches<" in section
    # Find each table
    # Pattern: rows in tables - find by section
    # Easier: find <a name="...">anchor + name + values
    # Each row: <tr>\s*<td class="wht cl"><a name="N"></a>\s*NAME</td>\s*<td class="s\d cl rt">ATTEMPTS</td>\s*<td class="s\d cl rt">SUCCESSES</td>\s*<td class="s\d cl rt">FAILURES</td>\s*<td class="wht cl rt">INCOMPLETE</td>
    rows = re.findall(
        r"<tr>\s*<td class=\"wht cl\"><a name=\"\d+\"></a>\s*([^<]+)\s*</td>\s*"
        r"<td class=\"s\d+ cl rt\">(\d+)</td>\s*"
        r"<td class=\"s\d+ cl rt\">(\d+)</td>",
        section,
    )
    # We need to determine if the third column is Real Successes or Matches.
    # Find table boundaries and check header
    # Split by tables
    tables = re.split(r"<table[^>]*>", section)
    for tbl in tables:
        if "Attempts" not in tbl:
            continue
        kind = None
        if "Real Successes" in tbl:
            kind = "assertion"
        elif ">Matches<" in tbl:
            kind = "cover"
        if not kind:
            continue
        body = re.findall(
            r"<tr>\s*<td class=\"wht cl\"><a name=\"\d+\"></a>\s*([^<]+)\s*</td>\s*"
            r"<td class=\"s\d+ cl rt\">(\d+)</td>\s*"
            r"<td class=\"s\d+ cl rt\">(\d+)</td>",
            tbl,
        )
        for name, attempts, succ in body:
            succ_i = int(succ)
            if succ_i == 0:
                out.append({"name": name.strip(), "attempts": attempts, "successes": succ, "kind": kind})
    return out


def relative_source_path(src: str) -> str:
    """Convert absolute source path to repo-relative."""
    # remove leading prefix
    m = re.search(r"/(mmu/rtl/.+)$", src)
    if m:
        return m.group(1)
    m = re.search(r"/(mmu_verification/testbench/.+)$", src)
    if m:
        return m.group(1)
    m = re.search(r"/(mmu/.+)$", src)
    if m:
        return m.group(1)
    return src


def find_source_root(src_rel: str) -> Path:
    """Find repo-relative source path. Try a few common roots."""
    candidates = [
        Path(src_rel),
        Path("mmu_verification") / src_rel,
        Path("/x2025/GPrj1/IC1/mmu_verification") / src_rel,
        Path("/x2025/GPrj1/IC1/mmu_verification/mmu_verification/..") / src_rel,
    ]
    for c in candidates:
        if c.is_file():
            return c
    return None


def read_source_lines(src_rel: str) -> list:
    """Read source file and return list of lines (1-indexed: lines[1] is first line)."""
    p = find_source_root(src_rel)
    if not p:
        return []
    try:
        text = p.read_text(encoding="utf-8", errors="ignore")
        return [""] + text.splitlines()
    except Exception:
        return []


def make_source_context_block(src_rel: str, line_no: int, context: int = 2) -> str:
    """Return a markdown code block showing source around line_no, with >> marker."""
    try:
        ln = int(line_no)
    except (ValueError, TypeError):
        return ""
    lines = read_source_lines(src_rel)
    if not lines or ln < 1 or ln >= len(lines):
        return ""
    start = max(1, ln - context)
    end = min(len(lines) - 1, ln + context)
    out = []
    for i in range(start, end + 1):
        marker = ">>" if i == ln else "  "
        out.append(f"     {i:5d}: {marker}  {lines[i]}")
    return "\n".join(out)


def find_signal_declaration(src_rel: str, signal_name: str) -> tuple:
    """Find the declaration line and text of a signal in source file.

    signal_name may include bit range, e.g. 'cp0_mmu_mpp[0]' or 'entry_flg[2][3:0]'.
    Returns (line_no, declaration_text) or (None, None) if not found.
    """
    base = signal_name.split("[")[0].strip()
    if not base:
        return (None, None)
    lines = read_source_lines(src_rel)
    if not lines:
        return (None, None)
    # Match common declaration patterns:
    #   input/output/inout logic [..] name,
    #   logic [..] name;
    #   wire name;
    pat = re.compile(
        r"\b(input|output|inout|logic|wire|reg|assign)\b[^;]*\b" + re.escape(base) + r"\b",
        re.IGNORECASE,
    )
    for i in range(1, len(lines)):
        line = lines[i]
        if pat.search(line) and base in line:
            return (i, line.strip())
    return (None, None)


def find_identifier_line(src_rel: str, name: str) -> int:
    """Find the first source line where `name` appears as a declaration/label.

    Used for SVA assertion/cover names like 'a_foo_bar' which appear as:
        a_foo_bar: assert property (...)
        c_foo: cover property (...)
    Returns line number or None.
    """
    # Strip array index like gen_l1dtlb_entry_sva[10].a_va8_inv -> search for a_va8_inv
    short = name.split(".")[-1] if "." in name else name
    short = short.split("[")[0].strip()
    if not short:
        return None
    lines = read_source_lines(src_rel)
    if not lines:
        return None
    # Prefer lines where the identifier is followed by ':' (label) or is the first token
    label_pat = re.compile(r"\b" + re.escape(short) + r"\b\s*:", re.IGNORECASE)
    for i in range(1, len(lines)):
        if label_pat.search(lines[i]):
            return i
    # Fallback: any line containing the identifier
    plain_pat = re.compile(r"\b" + re.escape(short) + r"\b", re.IGNORECASE)
    for i in range(1, len(lines)):
        if plain_pat.search(lines[i]):
            return i
    return None


def generalize_pattern(text: str) -> str:
    """Generalize parameterized patterns for grouping.

    E.g. 'gen_mb_entries[3].is_jtlb_refill' -> 'gen_mb_entries[N].is_jtlb_refill'
    """
    t = text
    # Replace numeric indices in brackets
    t = re.sub(r"\[\d+\]", "[N]", t)
    # Replace numeric literals like "0[(EID_WIDTH-1):0]" -> "N[(EID_WIDTH-1):0]"
    t = re.sub(r"\b\d+\[", "N[", t)
    return t


def group_cond_items(items: list) -> list:
    """Group cond items by (line, generalized_text). Returns list of dicts:
    {line, kind, text, combos (combined), count}
    """
    groups = OrderedDict()
    for c in items:
        key = (c["line"], c["kind"], generalize_pattern(c["text"]))
        if key not in groups:
            groups[key] = {
                "line": c["line"],
                "kind": c["kind"],
                "text": c["text"],
                "combos": [],
                "count": 0,
                "sample_text": c["text"],
            }
        groups[key]["combos"].append(c["combo"])
        groups[key]["count"] += 1
    # Dedupe combos within group
    out = []
    for g in groups.values():
        g["combos"] = list(dict.fromkeys(g["combos"]))
        out.append(g)
    return out


def group_toggle_items(items: list) -> list:
    """Group toggle items by generalized name. Returns list of (name, count, sample_tog, sample_t10, sample_t01, direction)."""
    groups = OrderedDict()
    for name, tog, t10, t01, direction in items:
        gname = generalize_pattern(name)
        if gname not in groups:
            groups[gname] = {
                "name": name,
                "count": 0,
                "tog_no": 0,
                "t10_no": 0,
                "t01_no": 0,
                "direction": direction,
                "samples": [],
            }
        groups[gname]["count"] += 1
        if tog == "No":
            groups[gname]["tog_no"] += 1
        if t10 == "No":
            groups[gname]["t10_no"] += 1
        if t01 == "No":
            groups[gname]["t01_no"] += 1
        if len(groups[gname]["samples"]) < 2:
            groups[gname]["samples"].append(name)
    return [(g["name"], g["count"], g["tog_no"], g["t10_no"], g["t01_no"], g["direction"], g["samples"]) for g in groups.values()]


def group_assert_items(items: list) -> list:
    """Group assert items by generalized name."""
    groups = OrderedDict()
    for a in items:
        gname = generalize_pattern(a["name"])
        if gname not in groups:
            groups[gname] = {
                "name": a["name"],
                "count": 0,
                "attempts": a["attempts"],
                "successes": a["successes"],
                "kind": a["kind"],
            }
        groups[gname]["count"] += 1
    return list(groups.values())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--urg-report", required=True, help="phase14_urgReport directory")
    ap.add_argument("--scope", required=True, choices=["L1TLB", "L2TLB"])
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    report_dir = Path(args.urg_report)
    modules = L1TLB_MODULES if args.scope == "L1TLB" else L2TLB_MODULES

    # Build modfile map
    all_modfiles = {}  # module name -> modfile
    for path in sorted(report_dir.glob("mod*.html")):
        bn = path.stem
        if re.match(r"mod\d+(_\d+)?$", bn):
            # skip instance pages like mod27_0
            if "_" in bn:
                continue
        elif "_" in bn:
            # split pages like mod106_c1 - skip for name discovery
            continue
        name = get_module_name(report_dir, bn)
        if name:
            all_modfiles[name] = bn

    # Process each module in scope
    results = OrderedDict()  # module name -> {source, score, line, cond, branch, fsm, toggle_ports, toggle_signals, asserts}
    for modname in modules:
        if modname not in all_modfiles:
            continue
        modfile = all_modfiles[modname]
        path = report_dir / (modfile + ".html")
        text = path.read_text(encoding="utf-8", errors="ignore")
        src = get_source_file(report_dir, modfile)
        score = get_score_row(report_dir, modfile)
        lines = parse_line_coverage(text)
        conds = parse_cond_coverage(report_dir, modfile)
        branches = parse_branch_coverage(text)
        fsms = parse_fsm_coverage(text)
        tog_ports, tog_sigs = parse_toggle_coverage(text)
        asserts = parse_assert_coverage(text)
        results[modname] = {
            "modfile": modfile,
            "source": relative_source_path(src),
            "score": score,
            "lines": lines,
            "conds": conds,
            "branches": branches,
            "fsms": fsms,
            "toggle_ports": tog_ports,
            "toggle_signals": tog_sigs,
            "asserts": asserts,
        }

    # Generate markdown
    lines_out = []
    if args.scope == "L1TLB":
        lines_out.append("# L1TLB covp 未覆盖代码报告")
    else:
        lines_out.append("# L2TLB covp 未覆盖代码报告")
    lines_out.append("")
    lines_out.append(f"本报告基于 `make covp` 生成的 URG 覆盖率报告：`mmu_verification/output/coverage/phase14_urgReport`。")
    lines_out.append("- 原始 URG 数据源：`mmu_verification/output/coverage/phase14_merged.vdb`")
    lines_out.append("- URG 命令：`urg -full64 -dir .../phase14_merged.vdb -elfile .../simu/exclude_v4.tgl -format both -report .../phase14_urgReport`")
    if args.scope == "L1TLB":
        lines_out.append("- 统计范围：`tb_top.u_dut.u_mmu_l1dtlb` 与 `tb_top.u_dut.x_mmu_l1itlb` 子树下的所有实例（含 SVA 与子模块）。")
    else:
        lines_out.append("- 统计范围：`tb_top.u_dut.x_mmu_l2tlb` 子树下的所有实例（含 SVA 与子模块）。")
    lines_out.append("")
    lines_out.append("## 阅读说明")
    lines_out.append("")
    lines_out.append("- 重复实例与参数化条目（如不同 entry index、不同 way、不同位段）按覆盖率类型、模块、源码行号和代码文本合并；`影响条目数` 表示合并前命中的原始条目数（即同一个未覆盖对象在多少个实例/参数化变体上出现）。")
    lines_out.append("- 表格中 `行号` 为源码行号，`未覆盖代码/对象` 为 URG 指出的语句、表达式、信号、端口、状态迁移或 SVA 对象，`URG 细节` 保留原始覆盖率细节。")
    lines_out.append("- 代码块只给出定位上下文，`>>` 标记 URG 对应的源码行；上下相邻行用于辅助判断该代码属于哪个 if/case/always/assert 块。")
    lines_out.append("- 条件覆盖的 0/1 位串按表达式 term 顺序排列。")
    lines_out.append("- Toggle 覆盖率在 URG 中通常没有可执行源码行；这里列出未翻转的端口/信号以及源码中匹配到的声明或赋值位置。")
    lines_out.append("- `implicit_else` 是 VCS/URG 推导出的隐式 else 路径未覆盖，不一定对应 RTL 中显式写出的 `else` 行。")
    lines_out.append("- 断言中 `Real Successes=0` 表示该 SVA 虽被 attempt 但未真正命中；cover 中 `Matches=0` 表示 cover 点未采样到。")
    lines_out.append("")

    # Code column explanation (mirrors PTW report style)
    lines_out.append("## 代码列说明")
    lines_out.append("")
    lines_out.append("- 如果 `未覆盖代码/对象` 是完整 RTL/SVA 语句，表示该语句在本次回归中没有达到 URG 统计要求。")
    lines_out.append("- 如果显示 `EXPRESSION` 或 `SUB-EXPRESSION`，表示条件表达式中的某些取值组合没有被测到；`URG 细节` 中的 0/1 串按表达式 term 顺序排列。")
    lines_out.append("- 如果显示 `signal[range] -> declaration`，左侧是未完整翻转的位段，右侧是源码中匹配到的声明或赋值，用来定位信号定义。")
    lines_out.append("- `MISSING_ELSE after previous statement` 表示前一条条件语句的隐式 else/默认路径没有被覆盖。")
    lines_out.append("- 断言/cover 条目中的 `RealSuccesses=0` 或 `Matches=0` 表示该 SVA 对象虽然可能被 attempt，但没有真正成功或命中。")
    lines_out.append("")

    # Per-scope summary numbers
    # Raw count = sum of parsed items (pre-merge across parameterized variants/instances)
    # Merged count = after grouping by (line, kind, generalized_text) or generalized name
    n_lines_raw = sum(len(r["lines"]) for r in results.values())
    n_conds_raw = sum(len(r["conds"]) for r in results.values())
    n_branches_raw = sum(len(r["branches"]) for r in results.values())
    n_fsms_raw = sum(len(r["fsms"]) for r in results.values())
    n_tog_ports_raw = sum(len(r["toggle_ports"]) for r in results.values())
    n_tog_sigs_raw = sum(len(r["toggle_signals"]) for r in results.values())
    n_asserts_raw = sum(len(r["asserts"]) for r in results.values())

    # Merged counts: dedupe within module then count unique objects
    n_lines_merged = sum(len(set((ln, code) for ln, code in r["lines"])) for r in results.values())
    n_conds_merged = sum(len(group_cond_items(r["conds"])) for r in results.values())
    n_branches_merged = sum(len(set((ln, txt, combo) for ln, txt, combo in r["branches"])) for r in results.values())
    n_fsms_merged = sum(len(set((fsm, trans, ln) for fsm, trans, ln in r["fsms"])) for r in results.values())
    n_tog_ports_merged = sum(len(group_toggle_items(r["toggle_ports"])) for r in results.values())
    n_tog_sigs_merged = sum(len(group_toggle_items(r["toggle_signals"])) for r in results.values())
    n_asserts_merged = sum(len(group_assert_items(r["asserts"])) for r in results.values())

    n_raw_total = n_lines_raw + n_conds_raw + n_branches_raw + n_fsms_raw + n_tog_ports_raw + n_tog_sigs_raw + n_asserts_raw
    n_merged_total = n_lines_merged + n_conds_merged + n_branches_merged + n_fsms_merged + n_tog_ports_merged + n_tog_sigs_merged + n_asserts_merged

    lines_out.append("## 汇总")
    lines_out.append("")
    lines_out.append("| 覆盖类型 | 原始未覆盖记录数 | 合并后唯一代码对象数 |")
    lines_out.append("| --- | ---: | ---: |")
    lines_out.append(f"| 行覆盖 | {n_lines_raw} | {n_lines_merged} |")
    lines_out.append(f"| 条件覆盖 | {n_conds_raw} | {n_conds_merged} |")
    lines_out.append(f"| 分支覆盖（含 MISSING_ELSE）| {n_branches_raw} | {n_branches_merged} |")
    lines_out.append(f"| FSM 状态迁移覆盖 | {n_fsms_raw} | {n_fsms_merged} |")
    lines_out.append(f"| 翻转覆盖 - 端口 | {n_tog_ports_raw} | {n_tog_ports_merged} |")
    lines_out.append(f"| 翻转覆盖 - 内部信号 | {n_tog_sigs_raw} | {n_tog_sigs_merged} |")
    lines_out.append(f"| 断言/cover 命中覆盖 | {n_asserts_raw} | {n_asserts_merged} |")
    lines_out.append(f"| **合计** | **{n_raw_total}** | **{n_merged_total}** |")
    lines_out.append("")

    # Per-module summary
    lines_out.append("| 模块 | SCORE/LINE/COND/TOGGLE/FSM/BRANCH/ASSERT (%) | 未覆盖对象数 | 源码 |")
    lines_out.append("| --- | --- | ---: | --- |")
    for modname, r in results.items():
        score = r["score"]
        s_str = "/".join(score.get(k, "-") for k in ("score", "line", "cond", "toggle", "fsm", "branch", "assert"))
        total = len(r["lines"]) + len(r["conds"]) + len(r["branches"]) + len(r["fsms"]) + len(r["toggle_ports"]) + len(r["toggle_signals"]) + len(r["asserts"])
        lines_out.append(f"| `{modname}` | {s_str} | {total} | `{r['source']}` |")
    lines_out.append("")

    # Executive analysis section
    lines_out.append("## 主要未覆盖模式分析")
    lines_out.append("")
    # Collect top uncovered lines (Line + Cond + Branch)
    top_lines = []
    for modname, r in results.items():
        for ln, code in r["lines"]:
            top_lines.append((modname, r["source"], ln, code))
    lines_out.append("### 行覆盖缺口（语句从未执行）")
    lines_out.append("")
    if top_lines:
        # Add source context for each
        seen_modsrc = set()
        for modname, src, ln, code in top_lines:
            code_md = "`" + code.replace("`", "'") + "`"
            lines_out.append(f"- `{modname}` `{src}:{ln}` {code_md}")
            key = (src, ln)
            if key in seen_modsrc:
                continue
            seen_modsrc.add(key)
            ctx = make_source_context_block(src, ln, context=3)
            if ctx:
                lines_out.append("")
                lines_out.append(f"`{src}:{ln}`")
                lines_out.append("")
                lines_out.append("```systemverilog")
                lines_out.append(ctx)
                lines_out.append("```")
                lines_out.append("")
    else:
        lines_out.append("（无）")
        lines_out.append("")

    # Top cond patterns (grouped)
    lines_out.append("### 条件覆盖缺口（按表达式模式聚合）")
    lines_out.append("")
    cond_grouped_all = []
    for modname, r in results.items():
        for g in group_cond_items(r["conds"]):
            cond_grouped_all.append((modname, r["source"], g))
    # Sort by count desc
    cond_grouped_all.sort(key=lambda x: -x[2]["count"])
    if cond_grouped_all:
        lines_out.append("| 模块 | 行号 | 表达式（已聚合参数化条目） | 未覆盖组合（采样） | 影响条目数 |")
        lines_out.append("| --- | ---: | --- | --- | ---: |")
        for modname, src, g in cond_grouped_all[:60]:
            text_md = (g["text"][:140] + "...") if len(g["text"]) > 140 else g["text"]
            text_md = "`" + g["kind"] + " " + text_md.replace("`", "'") + "`"
            combos = "; ".join(g["combos"][:3])
            if len(g["combos"]) > 3:
                combos += f"; ... 共 {len(g['combos'])} 种组合"
            lines_out.append(f"| `{modname}` | {g['line']} | {text_md} | {combos} | {g['count']} |")
        if len(cond_grouped_all) > 60:
            lines_out.append(f"| ... | ... | （其余 {len(cond_grouped_all)-60} 个聚合模式见下方分模块详情） | ... | ... |")
        lines_out.append("")
    else:
        lines_out.append("（无）")
        lines_out.append("")

    # FSM gaps
    fsm_all = []
    for modname, r in results.items():
        for fsm_name, trans, ln in r["fsms"]:
            fsm_all.append((modname, r["source"], fsm_name, trans, ln))
    if fsm_all:
        lines_out.append("### FSM 状态迁移缺口")
        lines_out.append("")
        lines_out.append("| 模块 | FSM | 未覆盖迁移 | 行号 |")
        lines_out.append("| --- | --- | --- | ---: |")
        for modname, src, fsm_name, trans, ln in fsm_all:
            lines_out.append(f"| `{modname}` | `{fsm_name}` | `{trans}` | {ln} |")
        lines_out.append("")
        # Add context for first FSM transition
        modname, src, fsm_name, trans, ln = fsm_all[0]
        ctx = make_source_context_block(src, ln, context=4)
        if ctx:
            lines_out.append(f"`{src}:{ln}` ({fsm_name} FSM 的 `{trans}` 迁移):")
            lines_out.append("")
            lines_out.append("```systemverilog")
            lines_out.append(ctx)
            lines_out.append("```")
            lines_out.append("")

    # Assert gaps (grouped)
    assert_grouped_all = []
    for modname, r in results.items():
        for g in group_assert_items(r["asserts"]):
            assert_grouped_all.append((modname, r["source"], g))
    if assert_grouped_all:
        lines_out.append("### 断言/cover 命中缺口（按名称模式聚合）")
        lines_out.append("")
        lines_out.append("| 模块 | 名称（已聚合） | 类型 | Attempts | Successes/Matches | 影响条目数 |")
        lines_out.append("| --- | --- | --- | ---: | ---: | ---: |")
        for modname, src, g in assert_grouped_all:
            name_md = "`" + g["name"].replace("`", "'") + "`"
            lines_out.append(f"| `{modname}` | {name_md} | {g['kind']} | {g['attempts']} | {g['successes']} | {g['count']} |")
        lines_out.append("")

    # Toggle gaps grouped
    tog_port_grouped = []
    tog_sig_grouped = []
    for modname, r in results.items():
        for name, count, tog_no, t10_no, t01_no, direction, samples in group_toggle_items(r["toggle_ports"]):
            tog_port_grouped.append((modname, name, count, tog_no, t10_no, t01_no, direction, samples))
        for name, count, tog_no, t10_no, t01_no, direction, samples in group_toggle_items(r["toggle_signals"]):
            tog_sig_grouped.append((modname, name, count, tog_no, t10_no, t01_no, direction, samples))
    tog_port_grouped.sort(key=lambda x: -x[2])
    tog_sig_grouped.sort(key=lambda x: -x[2])

    if tog_port_grouped:
        lines_out.append("### 翻转覆盖 - 端口（按信号模式聚合）")
        lines_out.append("")
        lines_out.append("| 模块 | 端口（已聚合参数化位段） | 影响条目数 | Toggle No | 1->0 No | 0->1 No | 方向 |")
        lines_out.append("| --- | --- | ---: | ---: | ---: | ---: | --- |")
        for modname, name, count, tog_no, t10_no, t01_no, direction, samples in tog_port_grouped[:40]:
            name_md = "`" + name.replace("`", "'") + "`"
            lines_out.append(f"| `{modname}` | {name_md} | {count} | {tog_no} | {t10_no} | {t01_no} | {direction} |")
        if len(tog_port_grouped) > 40:
            lines_out.append(f"| ... | ... （其余 {len(tog_port_grouped)-40} 个模式见下方分模块详情） | ... | ... | ... | ... | ... |")
        lines_out.append("")

    if tog_sig_grouped:
        lines_out.append("### 翻转覆盖 - 内部信号（按信号模式聚合）")
        lines_out.append("")
        lines_out.append("| 模块 | 信号（已聚合参数化位段） | 影响条目数 | Toggle No | 1->0 No | 0->1 No |")
        lines_out.append("| --- | --- | ---: | ---: | ---: | ---: |")
        for modname, name, count, tog_no, t10_no, t01_no, direction, samples in tog_sig_grouped[:40]:
            name_md = "`" + name.replace("`", "'") + "`"
            lines_out.append(f"| `{modname}` | {name_md} | {count} | {tog_no} | {t10_no} | {t01_no} |")
        if len(tog_sig_grouped) > 40:
            lines_out.append(f"| ... | ... （其余 {len(tog_sig_grouped)-40} 个模式见下方分模块详情） | ... | ... | ... | ... |")
        lines_out.append("")

    lines_out.append("---")
    lines_out.append("")
    lines_out.append("## 结论与覆盖建议")
    lines_out.append("")
    # Identify top toggle-offenders (modules with most toggle gaps)
    toggle_by_mod = []
    for modname, r in results.items():
        n = len(r["toggle_ports"]) + len(r["toggle_signals"])
        if n > 0:
            toggle_by_mod.append((modname, n, r["score"].get("toggle", "-")))
    toggle_by_mod.sort(key=lambda x: -x[1])
    if toggle_by_mod:
        lines_out.append("### 翻转覆盖薄弱模块（按未翻转对象数排序）")
        lines_out.append("")
        lines_out.append("| 模块 | 未翻转对象数 | 模块级 TOGGLE 覆盖率 |")
        lines_out.append("| --- | ---: | ---: |")
        for modname, n, t in toggle_by_mod[:10]:
            lines_out.append(f"| `{modname}` | {n} | {t} |")
        lines_out.append("")

    # Identify top cond-offenders
    cond_by_mod = []
    for modname, r in results.items():
        n = len(r["conds"])
        if n > 0:
            cond_by_mod.append((modname, n, r["score"].get("cond", "-")))
    cond_by_mod.sort(key=lambda x: -x[1])
    if cond_by_mod:
        lines_out.append("### 条件覆盖薄弱模块（按未覆盖表达式数排序）")
        lines_out.append("")
        lines_out.append("| 模块 | 未覆盖表达式数 | 模块级 COND 覆盖率 |")
        lines_out.append("| --- | ---: | ---: |")
        for modname, n, c in cond_by_mod[:10]:
            lines_out.append(f"| `{modname}` | {n} | {c} |")
        lines_out.append("")

    # Overall conclusions
    lines_out.append("### 主要结论")
    lines_out.append("")
    if args.scope == "L1TLB":
        lines_out.append("- **L1TLB 整体未覆盖对象集中在 `mmu_l1dtlb`、`mmu_l1itlb`、`mmu_l1dtlb_sva`、`mmu_l1dtlb_hit_rd`/`mmu_l1dtlb_hit_rd_sva` 等模块**，主要表现为：")
        lines_out.append("  - **翻转覆盖（TOGGLE）缺口最多**：参数化 entry/bit 位段（如 `l1dtlb_ent_ppn[N][...]`、`l1dtlb_ent_vpn[N][...]`、`mb_entry_vpn[N][...]`）大多只在 0/1 号 entry 上翻转过，高位 entry（N=8..15）从未被写入或翻转，反映现有定向用例未遍历所有 16 个 entry。")
        lines_out.append("  - **条件覆盖（COND）缺口**主要在 `mmu_l1dtlb` 主模块：例如 line 305/315 的 PTW/JTLB refill 完成 + 页错误/访问错误 + entry valid + WFC 状态 + 非 flush 的多 term 与表达式，部分 term 组合（如 pgflt||acc_err=0 同时 vld=0、state 非 WFC、flush=1）从未同时命中；line 957/958/969 的 `ref_id == N` 等值比较在 entry 2..7/3..7 上从未命中；line 1116/1120/1190 的 invalidation/比较表达式在高位 entry 上从未命中。")
        lines_out.append("  - **行覆盖（LINE）缺口**集中在 `mmu_l1dtlb` 行 987-991（`is_jtlb_refill` 分支内 `entry_ref_*` 赋值），即 JTLB refill 路径从未真正执行；`mmu_l1itlb` 行 1192-1194（iUTLB 异常处理）也从未走到。")
        lines_out.append("  - **FSM 迁移缺口**：`mmu_l1itlb` 中 `ref_cur_st`（iUTLB refill 状态机：IDLE/WFG/WFC/ABT）的 `WFG -> IDLE` 与 `WFG -> ABT` 两条迁移未覆盖，即在 WFG（等待 PTW 授权）状态下收到 `ifu_mmu_abort` 的回 idle / 转 ABT 的两条 abort 路径从未激励。")
        lines_out.append("  - **断言/cover 命中缺口**：`mmu_l1dtlb_sva` 中 19 个 `gen_l1dtlb_entry_sva[N].a_va8_inv_clears_matching_entry` 在 entry 8..15 上从未成功；`mmu_l1dtlb_hit_rd_sva` 中大量 cover 点（`cp_*`）Matches=0，反映特定 hit/read 时序场景未采样到。")
        lines_out.append("")
        lines_out.append("### 建议的定向激励")
        lines_out.append("")
        lines_out.append("1. **遍历所有 16 个 dutlb entry**：构造用例让 entry 0..15 都被 install/refill/hit/invalidate 一次，可一次性闭合大量 entry 参数化的 TOGGLE/COND/cover 缺口（`l1dtlb_ent_*[N]`、`mb_entry_*[N]`、`gen_l1dtlb_entry_sva[N].*`）。")
        lines_out.append("2. **JTLB/UTLB refill 路径**：当前 line 987-991 JTLB refill 分支从未执行，需要构造 utlb refill 触发 dutlb entry 更新的场景。")
        lines_out.append("3. **PTW refill 异常组合**：针对 line 305/315 的多 term 表达式，构造 ptw_l1dtlb_ref_cmplt=1 同时 pgflt/accerr/vld/state/flush 不同取值的定向序列，覆盖 `0 1 1 1 1`、`1 1 0 1 1` 等缺失组合。")
        lines_out.append("4. **iUTLB WFG 状态 abort 路径**：让 iUTLB miss 进入 WFG（等待 PTW 授权）后收到 `ifu_mmu_abort`，且分别配合 `credit_cnt != 0`（转 ABT）与 `credit_cnt == 0`（回 IDLE），覆盖 `ref_cur_st` 的两条缺失迁移。")
        lines_out.append("5. **VA8 invalidation 命中 entry 8..15**：让 `tlboper_utlb_inv_va_req` 命中 dutlb entry 8..15 的 VPN，闭合 line 1116 与 `a_va8_inv_clears_matching_entry[N]` 缺口。")
        lines_out.append("6. **`cpurst_b` 复位时序**：多个 SVA 模块 `cpurst_b` 端口 Toggle=No（1->0=No），说明测试中从未触发真正的复位下沿（功率/复位测试可补充）。")
    else:
        lines_out.append("- **L2TLB 整体未覆盖对象主要集中在 `mmu_l2tlb` 主模块**，其他子模块（reqq/mb/rrpv_wbuf 等）缺口较少。主要表现为：")
        lines_out.append("  - **翻转覆盖（TOGGLE）缺口最多**：`ct_mmu_l2tlb_tag_array` 的 `l2tlb_tag_dout[0]`（25 个位段）、`ct_mmu_l2tlb_data_array` 的 `l2tlb_data_dout[130]`（10 个位段）等 SRAM 输出位从未翻转；`mmu_l2tlb` 内部 `l2tlb_*_ppn[27:20]`、`mmu_lsu_pa2[27:20]`、`mmu_pmp_pa4[27:20]` 等高位 PPN 位段未翻转，反映现有用例使用的高位物理地址不够分散。")
        lines_out.append("  - **条件覆盖（COND）缺口**集中在 `mmu_l2tlb` line 814（`final_way_hit_kid0..4` 多 way 命中表达式，影响 11 个实例）、line 1409（`final_hit_flg`/权限检查组合，影响多种权限/异常组合）、line 553/555/1041（`arb_l2tlb_acc_type == 3'b101/3'b1` 等 arbiter 写/安装类型）、line 769（`raw_way_g[0] || tlboper_l2tlb_cmp_noasid` 全局匹配/asid 比较旁路）、line 1005/1021/1031（`mb_issue_req/final_reqq_miss & cp0_mmu_ptw_en & mb_alloc_valid` PTW miss miss 流水）。")
        lines_out.append("  - **行覆盖（LINE）缺口**：line 1368 `pfu_nxt_st = PFU_DENY` 与 line 1382 FSM default `pfu_nxt_st = PFU_IDLE`，对应 PFU（预取单元）的 deny 与异常返回路径。")
        lines_out.append("  - **FSM 迁移缺口**：`pfu_cur_st` 的 `PFU_CHK -> PFU_DENY` 与 `PFU_CHK -> PFU_IDLE`，对应 prefetch check 后拒绝/直接回 idle 的迁移。")
        lines_out.append("  - **断言/cover 命中缺口**：`mmu_l2tlb_rrpv_wbuf_sva` 的 3 个 assertion/cover（`a_cam_hit_only_push_may_accept_when_full`、`a_true_full_blocks_new_entry_without_pop`、`c_rrpv_wbuf_true_full_block`）从未命中，反映 rrpv_wbuf 真满 + CAM 命中/新 entry 的场景未构造；`mmu_l2tlb_mb_sva` 的 dtlb/itlb full 不可覆盖 assertion 与 mb issue backpressure cover 未命中。")
        lines_out.append("")
        lines_out.append("### 建议的定向激励")
        lines_out.append("")
        lines_out.append("1. **高位 PPN/PA 翻转**：构造用例让 `l2tlb_*_ppn[27:20]`、`mmu_lsu_pa2[27:20]`、`mmu_pmp_pa4[27:20]`、`ptw_l2tlb_ref_ppn[23:21]` 等高位物理地址位段经历 0->1 与 1->0；同时让 `ct_mmu_l2tlb_tag_array`/`data_array` 各数据位都被实际写入并读出。")
        lines_out.append("2. **多 way 命中组合**：针对 line 814 `final_way_hit_kid0..4` 的 5-way 命中表达式，构造不同 way 命中分布的用例，覆盖 `1 1 0 1`、`1 0 1 1`、`0 1 1 1` 等组合。")
        lines_out.append("3. **PFU deny 路径**：激励 `l2tlb_pfu_deny=1`，覆盖 FSM `PFU_CHK -> PFU_DENY` 迁移以及 line 1368 的 `pfu_nxt_st = PFU_DENY`；并构造 FSM 异常状态回到 `PFU_IDLE`（覆盖 line 1382 default）。")
        lines_out.append("4. **权限/异常 flg 组合**：针对 line 1409 `final_hit_flg` 与 `sysmap_mmu_flg4` 的多 term 组合，构造 sum/mxr/supv/user 不同权限与权限错误同时命中的场景。")
        lines_out.append("5. **arbiter 写/安装类型**：激励 `arb_l2tlb_acc_type == 3'b101`（write/install）、`3'b1`（write tag）配合 `arb_l2tlb_write=1` 与 `arb_l2tlb_tag_din[TAG_WIDTH-1]` 的 0/1 组合，闭合 line 553/555/1041。")
        lines_out.append("6. **rrpv_wbuf 满场景**：构造 rrpv_wbuf 真满（`fifo_full`/`count==DEPTH`）时 CAM 命中 push、新 entry push、pop 的组合，闭合 `a_cam_hit_only_push_may_accept_when_full`、`a_true_full_blocks_new_entry_without_pop`、`c_rrpv_wbuf_true_full_block`。")
        lines_out.append("7. **MB dtlb/itlb full**：构造 L2TLB miss buffer dtlb/itlb 满（`mb_dtlb_full`/`mb_itlb_full`）后不再被覆盖的场景，闭合 `a_dtlb_full_no_overwrite`、`a_itlb_full_no_overwrite`、`c_mb_issue_reselect_under_backpressure`。")
    lines_out.append("")
    lines_out.append("---")
    lines_out.append("")
    lines_out.append("## 分模块详情")
    lines_out.append("")

    # Detail sections per module
    for modname, r in results.items():
        lines_out.append(f"## 模块 `{modname}`")
        lines_out.append("")
        lines_out.append(f"源码：`{r['source']}`")
        raw_total = len(r["lines"]) + len(r["conds"]) + len(r["branches"]) + len(r["fsms"]) + len(r["toggle_ports"]) + len(r["toggle_signals"]) + len(r["asserts"])
        merged_total = (
            len(set((ln, code) for ln, code in r["lines"]))
            + len(group_cond_items(r["conds"]))
            + len(set((ln, txt, combo) for ln, txt, combo in r["branches"]))
            + len(set((fsm, trans, ln) for fsm, trans, ln in r["fsms"]))
            + len(group_toggle_items(r["toggle_ports"]))
            + len(group_toggle_items(r["toggle_signals"]))
            + len(group_assert_items(r["asserts"]))
        )
        lines_out.append(f"原始未覆盖记录数：`{raw_total}`；合并后唯一代码对象数：`{merged_total}`。")
        lines_out.append("")

        # Line coverage
        if r["lines"]:
            lines_out.append("### 行覆盖")
            lines_out.append("")
            lines_out.append("说明：这里列出执行次数不足的 RTL/SVA 语句；后面的代码块用 `>>` 标出对应源码行。")
            lines_out.append("")
            lines_out.append("| 行号 | 未覆盖代码/对象 | URG 细节 |")
            lines_out.append("| ---: | --- | --- |")
            for ln, code in r["lines"]:
                code_md = "`" + code.replace("`", "'") + "`"
                lines_out.append(f"| {ln} | {code_md} | 0/N |")
            lines_out.append("")
            # Source context for EVERY line (PTW-style: one code block per item)
            seen_ln = set()
            for ln, _ in r["lines"]:
                if ln in seen_ln:
                    continue
                seen_ln.add(ln)
                ctx = make_source_context_block(r["source"], ln, context=4)
                if ctx:
                    lines_out.append(f"`{r['source']}:{ln}`")
                    lines_out.append("")
                    lines_out.append("```systemverilog")
                    lines_out.append(ctx)
                    lines_out.append("```")
                    lines_out.append("")

        # Cond coverage - grouped
        if r["conds"]:
            lines_out.append("### 条件覆盖")
            lines_out.append("")
            lines_out.append("说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。参数化条目（如不同 entry index）已聚合，`影响条目数` 表示同一表达式模式命中的实例数。")
            lines_out.append("")
            grouped = group_cond_items(r["conds"])
            lines_out.append("| 行号 | 未覆盖代码/对象 | URG 细节（采样） | 影响条目数 |")
            lines_out.append("| ---: | --- | --- | ---: |")
            for g in grouped:
                text_md = (g["text"][:160] + "...") if len(g["text"]) > 160 else g["text"]
                text_md = "`" + g["kind"] + " " + text_md.replace("`", "'") + "`"
                combos = "; ".join(g["combos"][:3])
                if len(g["combos"]) > 3:
                    combos += f"; ... 共 {len(g['combos'])} 种"
                lines_out.append(f"| {g['line']} | {text_md} | {combos} | {g['count']} |")
            lines_out.append("")
            # Source context for EVERY grouped cond item (PTW-style)
            seen_ln = set()
            for g in grouped:
                ln = g["line"]
                if ln in seen_ln:
                    continue
                seen_ln.add(ln)
                ctx = make_source_context_block(r["source"], ln, context=3)
                if ctx:
                    lines_out.append(f"`{r['source']}:{ln}`")
                    lines_out.append("")
                    lines_out.append("```systemverilog")
                    lines_out.append(ctx)
                    lines_out.append("```")
                    lines_out.append("")

        # Branch coverage
        if r["branches"]:
            lines_out.append("### 分支覆盖")
            lines_out.append("")
            lines_out.append("说明：这里列出 if/case/三目表达式分支没有完全走到的位置；`URG 细节` 给出未覆盖组合。")
            lines_out.append("")
            lines_out.append("| 行号 | 未覆盖代码/对象 | URG 细节 |")
            lines_out.append("| ---: | --- | --- |")
            for ln, txt, combo in r["branches"]:
                txt_md = (txt[:120] + "...") if len(txt) > 120 else txt
                lines_out.append(f"| {ln} | `{txt_md}` | {combo} |")
            lines_out.append("")
            # Source context for EVERY branch item (PTW-style)
            seen_ln = set()
            for ln, _, _ in r["branches"]:
                if ln in seen_ln:
                    continue
                seen_ln.add(ln)
                ctx = make_source_context_block(r["source"], ln, context=4)
                if ctx:
                    lines_out.append(f"`{r['source']}:{ln}`")
                    lines_out.append("")
                    lines_out.append("```systemverilog")
                    lines_out.append(ctx)
                    lines_out.append("```")
                    lines_out.append("")

        # FSM coverage
        if r["fsms"]:
            lines_out.append("### FSM 状态迁移覆盖")
            lines_out.append("")
            lines_out.append("| FSM | 未覆盖迁移 | 行号 |")
            lines_out.append("| --- | --- | ---: |")
            for fsm_name, trans, ln in r["fsms"]:
                lines_out.append(f"| `{fsm_name}` | `{trans}` | {ln} |")
            lines_out.append("")
            # Source context for EVERY FSM transition (PTW-style)
            seen = set()
            for fsm_name, trans, ln in r["fsms"]:
                key = (ln, fsm_name, trans)
                if key in seen:
                    continue
                seen.add(key)
                ctx = make_source_context_block(r["source"], ln, context=5)
                if ctx:
                    lines_out.append(f"`{r['source']}:{ln}` (FSM `{fsm_name}` 的 `{trans}` 迁移)")
                    lines_out.append("")
                    lines_out.append("```systemverilog")
                    lines_out.append(ctx)
                    lines_out.append("```")
                    lines_out.append("")

        # Toggle ports - grouped, PTW-style format with line number + declaration
        if r["toggle_ports"]:
            lines_out.append("### 翻转覆盖 - 端口")
            lines_out.append("")
            lines_out.append("说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。")
            lines_out.append("")
            lines_out.append("| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |")
            lines_out.append("| ---: | --- | --- | --- | ---: |")
            grouped = group_toggle_items(r["toggle_ports"])
            for name, count, tog_no, t10_no, t01_no, direction, samples in grouped:
                decl_ln, decl_text = find_signal_declaration(r["source"], name)
                obj_str = name
                if decl_text:
                    obj_str = f"{name} -> {decl_text}"
                obj_md = "`" + obj_str.replace("`", "'") + "`"
                ln_str = str(decl_ln) if decl_ln else "-"
                tog_detail = f"Toggle={'No' if tog_no else 'Yes'}, 1->0={'No' if t10_no else 'Yes'}, 0->1={'No' if t01_no else 'Yes'}"
                dir_str = direction or "-"
                lines_out.append(f"| {ln_str} | {obj_md} | {tog_detail} | {dir_str} | {count} |")
            lines_out.append("")
            # Source context for EVERY unique declaration line (PTW-style)
            seen_ln = set()
            for name, count, tog_no, t10_no, t01_no, direction, samples in grouped:
                decl_ln, _ = find_signal_declaration(r["source"], name)
                if not decl_ln or decl_ln in seen_ln:
                    continue
                seen_ln.add(decl_ln)
                ctx = make_source_context_block(r["source"], decl_ln, context=3)
                if ctx:
                    lines_out.append(f"`{r['source']}:{decl_ln}` (声明 `{name.split('[')[0]}`)")
                    lines_out.append("")
                    lines_out.append("```systemverilog")
                    lines_out.append(ctx)
                    lines_out.append("```")
                    lines_out.append("")

        # Toggle signals - grouped, PTW-style format
        if r["toggle_signals"]:
            lines_out.append("### 翻转覆盖 - 内部信号")
            lines_out.append("")
            lines_out.append("说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。")
            lines_out.append("")
            lines_out.append("| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |")
            lines_out.append("| ---: | --- | --- | ---: |")
            grouped = group_toggle_items(r["toggle_signals"])
            for name, count, tog_no, t10_no, t01_no, direction, samples in grouped:
                decl_ln, decl_text = find_signal_declaration(r["source"], name)
                obj_str = name
                if decl_text:
                    obj_str = f"{name} -> {decl_text}"
                obj_md = "`" + obj_str.replace("`", "'") + "`"
                ln_str = str(decl_ln) if decl_ln else "-"
                tog_detail = f"Toggle={'No' if tog_no else 'Yes'}, 1->0={'No' if t10_no else 'Yes'}, 0->1={'No' if t01_no else 'Yes'}"
                lines_out.append(f"| {ln_str} | {obj_md} | {tog_detail} | {count} |")
            lines_out.append("")
            # Source context for EVERY unique declaration line (PTW-style)
            seen_ln = set()
            for name, count, tog_no, t10_no, t01_no, direction, samples in grouped:
                decl_ln, _ = find_signal_declaration(r["source"], name)
                if not decl_ln or decl_ln in seen_ln:
                    continue
                seen_ln.add(decl_ln)
                ctx = make_source_context_block(r["source"], decl_ln, context=3)
                if ctx:
                    lines_out.append(f"`{r['source']}:{decl_ln}` (声明 `{name.split('[')[0]}`)")
                    lines_out.append("")
                    lines_out.append("```systemverilog")
                    lines_out.append(ctx)
                    lines_out.append("```")
                    lines_out.append("")

        # Assert coverage - grouped
        if r["asserts"]:
            lines_out.append("### 断言/cover 命中覆盖")
            lines_out.append("")
            lines_out.append("说明：`Real Successes=0` 表示 assert 在测试中虽然被尝试但从未真正成立；`Matches=0` 表示 cover 点未采样到。")
            lines_out.append("")
            lines_out.append("| 名称 | 类型 | Attempts | Successes/Matches | 影响条目数 |")
            lines_out.append("| --- | --- | ---: | ---: | ---: |")
            grouped = group_assert_items(r["asserts"])
            for g in grouped:
                name_md = "`" + g["name"].replace("`", "'") + "`"
                lines_out.append(f"| {name_md} | {g['kind']} | {g['attempts']} | {g['successes']} | {g['count']} |")
            lines_out.append("")
            # Source context for EVERY assert/cover item (PTW-style)
            seen = set()
            for g in grouped:
                nm = g["name"]
                if nm in seen:
                    continue
                seen.add(nm)
                ln = find_identifier_line(r["source"], nm)
                if ln:
                    ctx = make_source_context_block(r["source"], ln, context=4)
                    if ctx:
                        short_nm = nm.split(".")[-1] if "." in nm else nm
                        lines_out.append(f"`{r['source']}:{ln}` (`{short_nm}`)")
                        lines_out.append("")
                        lines_out.append("```systemverilog")
                        lines_out.append(ctx)
                        lines_out.append("```")
                        lines_out.append("")

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines_out) + "\n", encoding="utf-8")
    print(f"[extract_tlb_uncovered] scope={args.scope} wrote {out_path}")
    print(f"  modules processed: {len(results)}")
    print(f"  lines={n_lines_raw}->{n_lines_merged} conds={n_conds_raw}->{n_conds_merged} branches={n_branches_raw}->{n_branches_merged} fsms={n_fsms_raw}->{n_fsms_merged} tog_ports={n_tog_ports_raw}->{n_tog_ports_merged} tog_sigs={n_tog_sigs_raw}->{n_tog_sigs_merged} asserts={n_asserts_raw}->{n_asserts_merged}")


if __name__ == "__main__":
    main()
