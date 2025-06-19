import re
from uuid import uuid4

rules_text = """
[[rules]]
description = "AWS Access Key"
regex = '''(A3T[A-Z0-9]|AKIA|AGPA|AIDA|AROA|AIPA|ANPA|ANVA|ASIA)[A-Z0-9]{16}'''
tags = ["key", "AWS"]

[[rules]]
description = "AWS Secret Key"
regex = '''(?i)aws(.{0,20})?(?-i)['\"][0-9a-zA-Z\/+]{40}['\"]'''
tags = ["key", "AWS"]

[[rules]]
description = "Hardcoded Credential"
regex = '''((?i)(set)?password\\s*(.?=.?|\\()\\s*['|\\\"]\\w+[[:print:]]*['|\\\"])|((?i)(set)?pass\\s*(.?=.?|\\()\\s*['|\\\"]\\w+[[:print:]]*['|\\\"])|((?i)(set)?pwd\\s*(.?=.?|\\()\\s*['|\\\"]\\w+[[:print:]]*['|\\\"])|((?i)(set)?passwd\\s*(.?=.?|\\()\\s*['|\\\"]\\w+[[:print:]]*['|\\\"])|((?i)(set)?senha\\s*(.?=.?|\\()\\s*['|\\\"]\\w+[[:print:]]*['|\\\"])|([a-zA-Z]{3,10}://[^/\\s:@]{3,20}:[^/\\s:@]{3,20}@.{1,100}/?.?)'''
tags = ["key", "Hardcoded", "generic"]
"""

def add_ids_to_rules(toml_text):
    rules = re.split(r'(?=\[\[rules\]\])', toml_text)
    updated_rules = []
    for rule in rules:
        if rule.strip():
            if "id =" not in rule:
                desc_match = re.search(r'description\s*=\s*"([^"]+)"', rule)
                if desc_match:
                    rule_id = desc_match.group(1).lower().replace(" ", "-").replace("(", "").replace(")", "")
                else:
                    rule_id = f"rule-{uuid4().hex[:8]}"
                rule = rule.replace("[[rules]]", f'[[rules]]\nid = "{rule_id}"', 1)
            updated_rules.append(rule.strip())
    return "\n\n".join(updated_rules)

allowlist_block = """
[allowlist]
description = "Allowlisted files"
files = ['''^\\.?gitleaks\\.toml$''',
         '''(.*?)(png|jpg|gif|doc|docx|pdf|bin|xls|pyc|zip)$''',
         '''(go\\.mod|go\\.sum)$''']
"""

final_toml = add_ids_to_rules(rules_text) + "\n\n" + allowlist_block
print(final_toml)

