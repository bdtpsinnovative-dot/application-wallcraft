# -*- coding: utf-8 -*-
import sys
file_path = r'C:\app_test\hello_app\lib\screens\visit_planner\components\add_visit_modal.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_logic = '''      // Only consider it a pipeline company if the current user has visited it
      bool hasMine = false;
      int myProjectCount = 0;
      if (p['projects'] != null) {
        for (var proj in p['projects']) {
          if (proj['is_mine'] == true) {
            hasMine = true;
            myProjectCount++;
          }
        }
      }'''

new_logic = '''      // Only consider it a pipeline company if the current user has visited it
      bool hasMine = false;
      int myProjectCount = 0;
      
      if (widget.isAdmin && _selectedAssignToUserId != null) {
        final List<dynamic> userIds = p['user_ids'] ?? [];
        if (userIds.contains(_selectedAssignToUserId)) {
          hasMine = true;
          myProjectCount = (p['projects'] as List).length;
        }
      } else {
        if (p['projects'] != null) {
          for (var proj in p['projects']) {
            if (proj['is_mine'] == true) {
              hasMine = true;
              myProjectCount++;
            }
          }
        }
      }'''

content = content.replace(old_logic, new_logic)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Updated getCompanyOptions')
