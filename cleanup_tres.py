import re
import sys

def cleanup(content):
    # Remove top-level devices array
    content = re.sub(r'devices = Array\[Dictionary\]\(\[.*?\]\)\n', '', content, flags=re.DOTALL)
    # Remove top-level junctions array
    content = re.sub(r'junctions = Array\[Dictionary\]\(\[.*?\]\)\n', '', content, flags=re.DOTALL)
    return content

for filepath in sys.argv[1:]:
    with open(filepath, 'r') as f:
        content = f.read()
    new_content = cleanup(content)
    with open(filepath, 'w') as f:
        f.write(new_content)
