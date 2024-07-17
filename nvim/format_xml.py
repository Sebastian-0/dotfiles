import argparse
import re

parser = argparse.ArgumentParser(
    description="Offloads tasks to the mesh",
)
parser.add_argument("--input", required=True)
parser.add_argument("--output", required=True)
args = parser.parse_args()

p_single = re.compile("<.*\\/>")
p_open = re.compile("<.*>")
p_close = re.compile("<\\/.*>")
p_comment = re.compile("<!--.*-->")

output = []
indent = " " * 4
depth = 0
with open(args.input, "r") as f:
    for line in f:
        line = line.strip()
        if p_comment.match(line):
            output.append(f"{indent * depth}{line}\n")
        elif p_single.match(line):
            output.append(f"{indent * depth}{line}\n")
        elif p_close.match(line):
            depth -= 1
            output.append(f"{indent * depth}{line}\n")
        elif p_open.match(line):
            output.append(f"{indent * depth}{line}\n")
            depth += 1
        elif not line:
            output.append("\n")
        else:
            output.append(f"{indent * depth}{line}\n")

with open(args.output, "w") as f:
    f.writelines(output)
