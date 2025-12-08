# Written by me & ChatGPT.
# Known issues:
# - The formatter assumes that tag start/end are always at the beginning/end of a line,
#   but it's possible to start a new tag after ending the previous one within the same line.

import argparse
import re
import sys

parser = argparse.ArgumentParser(description="Simple XML indentation formatter.")
parser.add_argument("--input", required=True, help="File path or '-' for stdin")
parser.add_argument("--output", required=True, help="File path or '-' for stdout")
parser.add_argument("--indent", default=4)
args = parser.parse_args()

indent_unit = " " * int(args.indent)

# Patterns for classification
re_open_tag = re.compile(r"^<([A-Za-z_][^/>]*)>$")
re_close_tag = re.compile(r"^</.+>$")
re_selfclose_tag = re.compile(r"^<.+/>$")
re_comment_single = re.compile(r"^<!--.*?-->$")
re_comment_start = re.compile(r"^<!--")
re_comment_end = re.compile(r".*-->$")


depth = 0
buffer = []  # stores multiline tag lines
inside_comment = False
inside_tag = False

if args.input == "-":
    input_stream = sys.stdin
else:
    input_stream = open(args.input, "r")

if args.output == "-":
    output_stream = sys.stdout
else:
    output_stream = open(args.output, "w")

for rawline in input_stream:
    tag = None
    stripped = rawline.strip()

    if inside_comment:
        buffer.append(stripped)
        if re_comment_end.search(stripped):
            inside_comment = False
            tag = " ".join(filter(lambda t: len(t) > 0, buffer))
            buffer = []
        else:
            continue

    if inside_tag:
        buffer.append(stripped)
        if stripped.endswith(">"):
            inside_tag = False
            tag = " ".join(filter(lambda t: len(t) > 0, buffer))
            buffer = []
        else:
            continue

    # Empty line: preserve as-is
    if not stripped:
        output_stream.write("\n")
        continue

    # Detect start of multiline comment
    if re_comment_start.match(stripped) and not re_comment_end.match(stripped):
        inside_comment = True
        buffer = [stripped]
        continue

    # If this looks like the beginning of a multiline tag
    if stripped.startswith("<") and not stripped.endswith(">"):
        inside_tag = True
        buffer = [stripped]
        continue

    if tag is None:
        tag = stripped

    if re_close_tag.match(tag):
        depth -= 1
    output_stream.write(f"{indent_unit * depth}{tag}\n")
    if re_open_tag.match(tag):
        depth += 1

if input_stream is not sys.stdin:
    input_stream.close()
if output_stream is not sys.stdout:
    output_stream.close()
