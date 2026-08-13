# -*- coding: utf-8 -*-
import sys
file_path = r'C:\app_test\hello_app\lib\screens\visit_planner\components\add_visit_modal.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

assign_to_block = '''                          if (widget.isAdmin && widget.adminUsersList.isNotEmpty) ...[
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedAssignToUserId,
                              decoration: InputDecoration(
                                labelText: 'มอบหมายให้ (Assign To)',
                                labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                                filled: true,
                                fillColor: Colors.black26,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              dropdownColor: kCardDark,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              items: [
                                DropdownMenuItem(
                                  value: null, 
                                  child: Row(
                                    children: const [
                                      CircleAvatar(radius: 12, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 16, color: Colors.white)),
                                      SizedBox(width: 8),
                                      Text("ตัวเอง (Me)", overflow: TextOverflow.ellipsis)
                                    ]
                                  )
                                ),
                                ...widget.adminUsersList.map((u) {
                                  final name = u['full_name']?.toString() ?? 'Unknown User';
                                  final shortName = name.split(' ')[0];
                                  final avatar = u['avatar_url']?.toString();
                                  return DropdownMenuItem(
                                    value: u['id'].toString(), 
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.white24,
                                          backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                                          child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(shortName, overflow: TextOverflow.ellipsis)
                                      ]
                                    )
                                  );
                                })
                              ],
                              onChanged: _isReadOnly ? null : (v) {
                                setState(() {
                                  _selectedAssignToUserId = v;
                                  _selectedCompany = null;
                                  _selectedProject = null;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                          ],'''

lines = content.split('\n')
start_idx = -1
end_idx = -1
for i, line in enumerate(lines):
    if 'if (widget.isAdmin && widget.adminUsersList.isNotEmpty) ...[' in line:
        start_idx = i
    if start_idx != -1 and i > start_idx and 'const SizedBox(height: 16),' in line and '],' in lines[i+1]:
        end_idx = i + 1
        break

if start_idx != -1 and end_idx != -1:
    del lines[start_idx:end_idx+2]
    
insert_idx = -1
for i, line in enumerate(lines):
    if '// --- Company ---' in line:
        insert_idx = i
        break

if insert_idx != -1:
    lines.insert(insert_idx, assign_to_block)
    
new_content = '\n'.join(lines)
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)
print('Moved assign to block')
