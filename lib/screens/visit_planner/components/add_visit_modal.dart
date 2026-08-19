import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../../services/api_service.dart';
import '../../../constants.dart';
import 'package:intl/intl.dart';
import 'custom_calendar_dialog.dart';

const Color kCardDark = Color(0xFF1C1C1E);
const Color kPrimaryColor = Color(0xFFFFFFFF);
const Color kLimeGreen = Color(0xFFD2E862);
const Color kDarkBg = Color(0xFF0F0F11);

class AddVisitModal extends StatefulWidget {
  final DateTime weekStart;
  final Function(Map<String, dynamic> visitData) onSave;
  final Map<String, dynamic>? initialData;
  final List<dynamic> allPlans;
  final bool isAdmin;
  final List<dynamic> adminUsersList;

  const AddVisitModal({
    super.key,
    required this.weekStart,
    required this.onSave,
    this.initialData,
    this.allPlans = const [],
    this.isAdmin = false,
    this.adminUsersList = const [],
  });

  @override
  State<AddVisitModal> createState() => _AddVisitModalState();
}

class _AddVisitModalState extends State<AddVisitModal> {
  bool _isLoading = true;
  bool _isLoadingPipeline = false;
  bool _isReadOnly = false;
  
  List<dynamic> _pipelineData = [];
  List<dynamic> _allCompanies = [];
  List<dynamic> _allProjects = [];
  List<dynamic> _projectTypes = [];
  List<dynamic> _productCategories = [];
  
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _selectedCompany;
  Map<String, dynamic>? _selectedProject;
  String? _selectedProjectType;
  String? _selectedCategory;
  final _conceptCtrl = TextEditingController();
  
  String? _selectedAssignToUserId;

  @override
  void initState() {
    super.initState();
    if (widget.isAdmin && widget.initialData != null) {
      _selectedAssignToUserId = widget.initialData!['user_id'];
    }
    if (widget.initialData != null) {
      if (widget.initialData!['status'] == 'completed') {
        _isReadOnly = true;
      }
      // โหมดแก้ไข
      if (widget.initialData!['planned_date'] != null) {
        _selectedDate = DateTime.parse(widget.initialData!['planned_date']);
      }
      if (widget.initialData!['project_concept'] != null) {
        _conceptCtrl.text = widget.initialData!['project_concept'];
      }
      if (widget.initialData!['project_type_id'] != null) {
        _selectedProjectType = widget.initialData!['project_type_id'].toString();
      }
      if (widget.initialData!['product_category_id'] != null) {
        _selectedCategory = widget.initialData!['product_category_id'].toString();
      }
      // Note: _selectedCompany and _selectedProject will be matched after fetching data
    } else {
      // โหมดสร้างใหม่
      _selectedDate = widget.weekStart;
      if (_selectedDate.isBefore(DateTime.now()) && widget.weekStart.add(const Duration(days: 6)).isAfter(DateTime.now())) {
         _selectedDate = DateTime.now(); // If it's current week, default to today
      }
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final targetUserId = widget.isAdmin ? _selectedAssignToUserId : null;
      final responses = await Future.wait([
        ApiService.getPipeline(userId: targetUserId),
        ApiService.get(Uri.parse('${AppConfig.baseUrl}/orders')), // 🟢 ดึง project_types, product_categories และ initial projects รวดเดียว
      ]);

      if (responses[0].statusCode == 200) {
        var decoded = jsonDecode(responses[0].body);
        _pipelineData = decoded is List ? decoded : (decoded['pipeline'] ?? []);
      }
      if (responses[1].statusCode == 200) {
        var decoded = jsonDecode(responses[1].body);
        _projectTypes = decoded['project_types'] ?? [];
        _productCategories = decoded['product_categories'] ?? [];
        _allProjects = decoded['projects'] ?? [];
      }
        
      // Match selected company and project for edit mode
      if (widget.initialData != null) {
        if (widget.initialData!['companies'] != null) {
          final comp = widget.initialData!['companies'];
          _selectedCompany = {
            'id': comp['id'].toString(),
            'name': comp['name']?.toString() ?? 'Unknown',
            'isPipeline': false,
          };
        }

        if (widget.initialData!['projects'] != null) {
          final proj = widget.initialData!['projects'];
          _selectedProject = {
            'id': proj['id'].toString(),
            'project_name': proj['project_name']?.toString() ?? 'Unknown',
          };
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching modal data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => CustomCalendarDialog(
        initialDate: _selectedDate,
        allPlans: widget.allPlans,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _fetchPipelineForUser(String? userId) async {
    setState(() => _isLoadingPipeline = true);
    try {
      final res = await ApiService.getPipeline(userId: userId);
      if (res.statusCode == 200) {
        var decoded = jsonDecode(res.body);
        _pipelineData = decoded is List ? decoded : (decoded['pipeline'] ?? []);
      }
    } catch (e) {
      debugPrint("Error fetching pipeline for user: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingPipeline = false);
      }
    }
  }

  // Helper to merge pipeline and search companies for DropdownSearch
  Future<List<dynamic>> _getCompanyOptions(String filter) async {
    // 🌟 ถ้าระบบกำลังโหลด Pipeline ของเซลส์คนใหม่อยู่ ให้รอก่อนเปิดรายการ
    while (_isLoadingPipeline) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final lowerFilter = filter.toLowerCase();
    
    // Convert Pipeline to uniform company object with an indicator flag
    final pipelineIds = <String>{};
    final List<dynamic> options = [];
    
    for (var p in _pipelineData) {
      if (p['company'] == null) continue;
      
      final isMine = p['is_mine'] == true;
      final isTeam = p['is_team'] == true;
      final isGlobal = p['is_global'] == true;
      int projectCount = 0;
      
      if (p['projects'] != null) {
        for (var proj in p['projects']) {
          final pName = (proj['project_name'] ?? '').toString().trim();
          if (pName.isEmpty || pName == '-' || 
              pName.contains('ไม่ระบุโครงการ') || 
              pName.contains('ไม่มีการระบุโครงการ')) {
            continue;
          }
          projectCount++;
        }
      }

      final cId = p['company']['id'].toString();
      pipelineIds.add(cId);
      final name = p['company']['name']?.toString() ?? '';
      if (name.toLowerCase().contains(lowerFilter)) {
        // API จัดลำดับตามประวัติไว้แล้ว: ของตนเอง -> ทีม -> ทั่วระบบ
        // ห้ามกรองรายการทีม/ทั่วระบบออก เพราะพนักงานใหม่จะไม่มีรายการแนะนำ
        // เหลืออยู่เลย
        final source = isMine
            ? 'mine'
            : (isTeam ? 'team' : (isGlobal ? 'global' : 'system'));
        options.add({
          'id': cId,
          'name': name,
          'isPipeline': true,
          'pipelineSource': source,
          'projectCount': projectCount,
          'projects': p['projects'] ?? [], // Pipeline projects
        });
      }
    }
    
    // Add companies from API search
    try {
      final response = await ApiService.getCompanies(query: filter);
      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        var apiCompanies = decoded is List ? decoded : (decoded['data'] ?? decoded['companies'] ?? []);
        
        for (var c in apiCompanies) {
          final cId = c['id'].toString();
          if (!pipelineIds.contains(cId)) {
            options.add({
              'id': cId,
              'name': c['name']?.toString() ?? '',
              'isPipeline': false,
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching companies search: $e");
    }

    // Include the initial company if not present
    if (_selectedCompany != null) {
      final scId = _selectedCompany!['id'].toString();
      if (!options.any((o) => o['id'].toString() == scId)) {
        options.add(_selectedCompany!);
      }
    }
    
    return options;
  }

  // Helper to merge pipeline projects and API search projects
  Future<List<dynamic>> _getProjectOptions(String filter) async {
    final lowerFilter = filter.toLowerCase();
    
    final List<dynamic> options = [];
    final List<dynamic> mineOptions = [];
    final List<dynamic> othersOptions = [];
    final List<dynamic> unusedOptions = [];
    final pipelineProjIds = <String>{};
    
    // If a pipeline company is selected, categorize its projects
    if (_selectedCompany != null && _selectedCompany!['isPipeline'] == true) {
       for (var p in _selectedCompany!['projects']) {
         final pId = p['id'].toString();
         pipelineProjIds.add(pId);
         final name = p['project_name']?.toString() ?? '';
         if (name.toLowerCase().contains(lowerFilter)) {
           final projData = {
             'id': pId,
             'project_name': name,
             'isPipeline': true,
             'isMine': p['is_mine'] == true,
             'isTeam': p['is_team'] == true,
             'isGlobal': p['is_global'] == true,
             'usageCount': (p['count'] as num?)?.toInt() ?? 0,
             'project_type_id': p['project_type_id'],
             'product_category_id': p['product_category_id'],
           };
           if (p['is_mine'] == true) {
             mineOptions.add(projData);
           } else {
             othersOptions.add(projData);
           }
         }
       }
    }
    
    // Add projects from API search
    try {
      final response = await ApiService.getProjects(query: filter);
      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        var apiProjects = decoded is List ? decoded : (decoded['data'] ?? decoded['projects'] ?? []);
        
        for (var p in apiProjects) {
          final pId = p['id'].toString();
          if (!pipelineProjIds.contains(pId)) {
             options.add({
               'id': pId,
               'project_name': p['project_name']?.toString() ?? '',
               'isPipeline': false,
               'project_type_id': p['project_type_id'],
               'product_category_id': p['product_category_id'],
             });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching projects search: $e");
    }
    
    options.addAll(mineOptions);
    options.addAll(othersOptions);
    options.addAll(unusedOptions);
    
    // Include the initial project if not present
    if (_selectedProject != null) {
      final spId = _selectedProject!['id'].toString();
      if (!options.any((o) => o['id'].toString() == spId)) {
        options.insert(0, _selectedProject!);
      }
    }

    return options;
  }

  void _onProjectSelected(dynamic val) {
    setState(() {
      _selectedProject = val;
      if (val != null) {
        if (val['project_type_id'] != null) _selectedProjectType = val['project_type_id'].toString();
        if (val['product_category_id'] != null) _selectedCategory = val['product_category_id'].toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24, left: 24, right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: kDarkBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.initialData != null ? "แก้ไขแผนงาน" : "สร้างแผนการเข้าพบลูกค้า",
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.of(context).pop(),
              )
            ],
          ),
          const SizedBox(height: 16),
          
          if (_isReadOnly)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text("แผนนี้เสร็จสิ้นแล้ว ไม่สามารถแก้ไขได้", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13))),
                ],
              ),
            ),
          
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: kLimeGreen),
            ))
          else 
            Flexible(
              child: Opacity(
                opacity: _isReadOnly ? 0.6 : 1.0,
                child: IgnorePointer(
                  ignoring: _isReadOnly,
                  child: SingleChildScrollView(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Date ---
                    const Text("วันที่เข้าพบ", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(color: kCardDark, border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            const Icon(Icons.calendar_month, color: Colors.white54, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                          if (widget.isAdmin && widget.adminUsersList.isNotEmpty) ...[
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedAssignToUserId,
                              decoration: InputDecoration(
                                labelText: 'มอบหมายให้',
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
                                      Text("ตัวเอง", overflow: TextOverflow.ellipsis)
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
                                // 🚀 ดึง Pipeline บริษัทและโครงการของเซลส์คนนั้นมาเตรียมไว้ทันที
                                _fetchPipelineForUser(v);
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                    // --- Company ---
                    const Text("บริษัท *", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownSearch<dynamic>(
                      items: (filter, loadProps) async => _getCompanyOptions(filter),
                      itemAsString: (item) => item['name'] ?? '',
                      selectedItem: _selectedCompany,
                      onChanged: (val) {
                        setState(() {
                          _selectedCompany = val;
                          _selectedProject = null;
                        });
                      },
                      compareFn: (i1, i2) => i1?['id'] == i2?['id'],
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: kCardDark,
                          hintText: "พิมพ์ค้นหา หรือเลือกจากบริษัท...",
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        menuProps: MenuProps(backgroundColor: kCardDark, borderRadius: BorderRadius.circular(8)),
                        searchFieldProps: TextFieldProps(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true, fillColor: kDarkBg,
                            hintText: "ค้นหาบริษัท...",
                            hintStyle: const TextStyle(color: Colors.white38),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                        itemBuilder: (context, item, isSelected, isFocused) {
                          final isPipe = item['isPipeline'] == true;
                          final projCount = (item['projectCount'] as int?) ?? 0;
                          final source = item['pipelineSource']?.toString();
                          final sourceColor = source == 'mine'
                              ? kLimeGreen
                              : source == 'team'
                              ? Colors.lightBlueAccent
                              : Colors.amber;
                          final sourceIcon = source == 'mine'
                              ? Icons.person_outline
                              : source == 'team'
                              ? Icons.groups_outlined
                              : Icons.auto_awesome_outlined;
                          final sourceDescription = source == 'mine'
                              ? 'ประวัติของคุณ'
                              : source == 'team'
                              ? 'ประวัติทีม'
                              : 'รายการแนะนำ';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                              color: isSelected ? kLimeGreen.withOpacity(0.1) : Colors.transparent,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item['name'] ?? '', 
                                    style: TextStyle(
                                      color: isSelected ? kLimeGreen : (isPipe ? Colors.amber[100] : Colors.white), 
                                      fontWeight: isPipe ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (isPipe) ...[
                                  Semantics(
                                    label: sourceDescription,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: sourceColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(sourceIcon, color: sourceColor, size: 15),
                                    ),
                                  ),
                                  if (projCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.folder_outlined, color: Colors.white70, size: 13),
                                          const SizedBox(width: 3),
                                          Text(
                                            '$projCount',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // --- Project ---
                    const Text("โครงการ", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownSearch<dynamic>(
                      items: (filter, loadProps) async => _getProjectOptions(filter),
                      itemAsString: (item) => item['project_name'] ?? '',
                      selectedItem: _selectedProject,
                      onChanged: _onProjectSelected,
                      compareFn: (i1, i2) => i1?['id'] == i2?['id'],
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: kCardDark,
                          hintText: "พิมพ์ค้นหา หรือเลือกจากโครงการ...",
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        menuProps: MenuProps(backgroundColor: kCardDark, borderRadius: BorderRadius.circular(8)),
                        searchFieldProps: TextFieldProps(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true, fillColor: kDarkBg,
                            hintText: "ค้นหาโครงการ...",
                            hintStyle: const TextStyle(color: Colors.white38),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                        itemBuilder: (context, item, isSelected, isFocused) {
                          final isMine = item['isMine'] == true;
                          final isTeam = item['isTeam'] == true;
                          final isPipe = item['isPipeline'] == true;
                          final usageCount = (item['usageCount'] as int?) ?? 0;
                          final sourceColor = isMine
                              ? kLimeGreen
                              : isTeam
                              ? Colors.lightBlueAccent
                              : Colors.amber;
                          final sourceIcon = isMine
                              ? Icons.person_outline
                              : isTeam
                              ? Icons.groups_outlined
                              : Icons.auto_awesome_outlined;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                              color: isSelected ? kLimeGreen.withOpacity(0.1) : Colors.transparent,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item['project_name'] ?? '', 
                                    style: TextStyle(color: isSelected ? kLimeGreen : Colors.white),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isPipe) ...[
                                  const SizedBox(width: 8),
                                  Icon(sourceIcon, color: sourceColor, size: 16),
                                  if (usageCount > 0) ...[
                                    const SizedBox(width: 5),
                                    const Icon(Icons.history_rounded, color: Colors.white54, size: 14),
                                    const SizedBox(width: 2),
                                    Text(
                                      '$usageCount',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Type & Category ---
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("ประเภทโครงการ", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _projectTypes.any((t) => t['id'] == _selectedProjectType) ? _selectedProjectType : null,
                                dropdownColor: kCardDark,
                                decoration: InputDecoration(
                                  filled: true, fillColor: kCardDark,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                hint: const Text("ไม่ระบุ", style: TextStyle(color: Colors.white38)),
                                items: [
                                  const DropdownMenuItem<String>(value: null, child: Text("ไม่ระบุ", overflow: TextOverflow.ellipsis, maxLines: 1)),
                                  ..._projectTypes.map<DropdownMenuItem<String>>((pt) => DropdownMenuItem<String>(
                                    value: pt['id'].toString(),
                                    child: Text(pt['name'].toString(), overflow: TextOverflow.ellipsis, maxLines: 1),
                                  )),
                                ],
                                onChanged: (val) => setState(() => _selectedProjectType = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("หมวดหมู่สินค้า", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _productCategories.any((c) => c['id'] == _selectedCategory) ? _selectedCategory : null,
                                dropdownColor: kCardDark,
                                decoration: InputDecoration(
                                  filled: true, fillColor: kCardDark,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                hint: const Text("ไม่ระบุ", style: TextStyle(color: Colors.white38)),
                                items: [
                                  const DropdownMenuItem<String>(value: null, child: Text("ไม่ระบุ", overflow: TextOverflow.ellipsis, maxLines: 1)),
                                  ..._productCategories.map<DropdownMenuItem<String>>((pc) => DropdownMenuItem<String>(
                                    value: pc['id'].toString(),
                                    child: Text(pc['name'].toString(), overflow: TextOverflow.ellipsis, maxLines: 1),
                                  )),
                                ],
                                onChanged: (val) => setState(() => _selectedCategory = val),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
        
                    // --- Concept ---
                    const Text("แนวโครงการ / รายละเอียด", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _conceptCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 3,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: kCardDark,
                        hintText: "รายละเอียดเพิ่มเติม เช่น โปรเจ็กต์โรงแรม 5 ดาว...",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          ),

          if (_isReadOnly)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [Icon(Icons.lock, color: Colors.amber, size: 16), SizedBox(width: 8), Text("รายการนี้เสร็จสิ้นแล้ว ไม่สามารถแก้ไขได้", style: TextStyle(color: Colors.amber, fontSize: 12))]),
              ),
            ),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isReadOnly ? () => Navigator.of(context).pop() : (_selectedCompany == null ? null : () {
                final data = {
                  'planned_date': _selectedDate.toIso8601String(),
                  'company_id': _selectedCompany!['id'],
                  'project_id': _selectedProject?['id'],
                  'project_concept': _conceptCtrl.text.trim(),
                  'project_type_id': _selectedProjectType,
                  'product_category_id': _selectedCategory,
                  if (widget.isAdmin && _selectedAssignToUserId != null) 'user_id': _selectedAssignToUserId,
                };
                if (widget.initialData != null) {
                  data['id'] = widget.initialData!['id'];
                }
                widget.onSave(data);
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isReadOnly ? Colors.grey.shade800 : kLimeGreen,
                foregroundColor: _isReadOnly ? Colors.white : Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                disabledBackgroundColor: Colors.grey.shade800,
              ),
              child: Text(_isReadOnly ? "ปิดหน้าต่าง" : (widget.initialData != null ? "บันทึกการแก้ไข" : "บันทึกแผนงาน"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
