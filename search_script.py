import json

log_path = r'C:\Users\Por Woodden\.gemini\antigravity\brain\441cd301-8f6d-4505-868d-d78b6a0b13a9\.system_generated\logs\transcript_full.jsonl'
found_contents = []

with open(log_path, 'r', encoding='utf-8') as f:
    for line in f:
        data = json.loads(line)
        if data.get('type') == 'TOOL_RESPONSE' and data.get('source') == 'SYSTEM':
            content = data.get('content', '')
            if 'VisitPlannerScreenState' in content:
                found_contents.append((data['step_index'], content))

print(f'Found {len(found_contents)} instances of the file being printed.')
for idx, content in found_contents:
    print(f'Step {idx}: Length {len(content)}')
