import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../constants.dart';

const Color kDarkBg = Color(0xFF0F0F11); 
const Color kCardDark = Color(0xFF1C1C1E); 
const Color kLimeGreen = Color(0xFFD2E862); 

class SampleProductionPage extends StatefulWidget {
  const SampleProductionPage({Key? key}) : super(key: key);

  @override
  State<SampleProductionPage> createState() => _SampleProductionPageState();
}

class _SampleProductionPageState extends State<SampleProductionPage> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedCompany;
  String? _selectedProject;
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  String? _selectedSeries; // เปลี่ยนเป็น String? สำหรับ Dropdown
  String? _selectedFilm;
  int _qty = 1;
  final TextEditingController _noteController = TextEditingController();

  bool _isLoading = false;
  bool _isFetchingData = true;

  List<dynamic> _companies = [];
  List<dynamic> _projects = [];
  List<dynamic> _customerTypes = [];

  // Mockup Data สำหรับ Series และ Film
  final List<String> _seriesOptions = [
    'Series A (Standard)',
    'Series B (Premium)',
    'Series C (Eco)'
  ];

  final Map<String, List<String>> _seriesToFilms = {
    'Series A (Standard)': ['Matte Finish', 'Glossy Clear'],
    'Series B (Premium)': ['Texture Wood', 'Metallic Brushed', 'Anti-scratch Film', 'Matte Finish'],
    'Series C (Eco)': ['Matte Finish'],
  };

  List<String> get _availableFilms {
    if (_selectedSeries == null) return [];
    return _seriesToFilms[_selectedSeries!] ?? [];
  }

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
  }

  Future<void> _fetchDropdownData() async {
    try {
      final companiesResponse = await http.get(Uri.parse('${AppConfig.baseUrl}/companies'));
      final projectsResponse = await http.get(Uri.parse('${AppConfig.baseUrl}/projects'));
      final customerTypesResponse = await http.get(Uri.parse('${AppConfig.baseUrl}/customer-types'));

      if (mounted) {
        setState(() {
          if (companiesResponse.statusCode == 200) {
            _companies = json.decode(companiesResponse.body);
            // ตรวจสอบว่า _selectedCompany ยังมีอยู่ใน list หรือไม่ ถ้าไม่มีให้เป็น null
            if (_selectedCompany != null && !_companies.any((c) => c['id'].toString() == _selectedCompany)) {
              _selectedCompany = null;
            }
          }
          if (projectsResponse.statusCode == 200) {
            _projects = json.decode(projectsResponse.body);
            // ตรวจสอบว่า _selectedProject ยังมีอยู่ใน list หรือไม่ ถ้าไม่มีให้เป็น null
            if (_selectedProject != null && !_projects.any((p) => p['id'].toString() == _selectedProject)) {
              _selectedProject = null;
            }
          }
          if (customerTypesResponse.statusCode == 200) {
            _customerTypes = json.decode(customerTypesResponse.body);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching dropdown data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingData = false;
        });
      }
    }
  }

  List<DropdownMenuItem<String>> _getUniqueItems(List<dynamic> list, String nameKey) {
    final Map<String, DropdownMenuItem<String>> uniqueMap = {};
    for (var item in list) {
      if (item['id'] != null) {
        final idStr = item['id'].toString();
        uniqueMap[idStr] = DropdownMenuItem<String>(
          value: idStr,
          child: Text(
            item[nameKey] ?? 'Unknown',
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }
    }
    return uniqueMap.values.toList();
  }

  Future<void> _addNewCompany() async {
    final controller = TextEditingController();
    String? localSelectedCustomerType;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: kCardDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Add Company', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter company name',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: localSelectedCustomerType,
                    dropdownColor: kCardDark,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Select Customer Type',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    items: _getUniqueItems(_customerTypes, 'name'),
                    onChanged: (val) {
                      setStateDialog(() {
                        localSelectedCustomerType = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kLimeGreen, 
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    if (controller.text.trim().isEmpty) return;
                    Navigator.pop(context, {
                      'name': controller.text.trim(),
                      'customer_type_id': localSelectedCustomerType,
                    });
                  },
                  child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            );
          }
        );
      },
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final res = await http.post(
          Uri.parse('${AppConfig.baseUrl}/companies'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(result),
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          final newCompany = json.decode(res.body);
          await _fetchDropdownData(); // reload
          if (mounted) {
            setState(() {
              _selectedCompany = newCompany['id'].toString();
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company added', style: TextStyle(color: Colors.black, fontSize: 13)), backgroundColor: kLimeGreen, behavior: SnackBarBehavior.floating));
          }
        } else {
          final err = json.decode(res.body);
          throw Exception(err['error'] ?? 'Failed to add company');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e', style: const TextStyle(color: Colors.white, fontSize: 13)), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addNewProject() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add Project', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter project name',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kLimeGreen, 
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final res = await http.post(
          Uri.parse('${AppConfig.baseUrl}/projects'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'project_name': result}),
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          final newProject = json.decode(res.body);
          await _fetchDropdownData(); // reload
          if (mounted) {
            setState(() {
              _selectedProject = newProject['id'].toString();
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project added', style: TextStyle(color: Colors.black, fontSize: 13)), backgroundColor: kLimeGreen, behavior: SnackBarBehavior.floating));
          }
        } else {
          final err = json.decode(res.body);
          throw Exception(err['error'] ?? 'Failed to add project');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e', style: const TextStyle(color: Colors.white, fontSize: 13)), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedCompany == null || _selectedProject == null || _selectedSeries == null || _selectedFilm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Company, Project, Series, and Film')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final Uri url = Uri.parse('${AppConfig.baseUrl}/sample-orders');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'company_id': _selectedCompany,
          'project_id': _selectedProject,
          'product_name': _productNameController.text.trim(),
          'color': _colorController.text.trim(),
          'series': _selectedSeries, // ส่งค่า Dropdown กลับไปเป็น String
          'film': _selectedFilm,
          'qty': _qty,
          'note': _noteController.text.trim(),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สั่งสินค้าตัวอย่างสำเร็จ!', style: TextStyle(color: Colors.black, fontSize: 13)),
            backgroundColor: kLimeGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _formKey.currentState!.reset();
        setState(() {
          _selectedCompany = null;
          _selectedProject = null;
          _selectedSeries = null;
          _selectedFilm = null;
          _qty = 1;
          _productNameController.clear();
          _colorController.clear();
          _noteController.clear();
        });
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'เกิดข้อผิดพลาดในการส่งข้อมูล');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: const TextStyle(color: Colors.white, fontSize: 13)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white54, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: kCardDark,
      ),
      validator: validator ?? (value) {
        if (value == null || value.trim().isEmpty) {
          return 'กรุณากรอก $label';
        }
        return null;
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    void Function(String?)? onChanged,
    required IconData icon,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true, // แก้ปัญหา Overflow ด้านขวา
      value: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: kCardDark,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white54, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: kCardDark,
      ),
      validator: (val) => val == null ? 'กรุณาเลือก $label' : null,
    );
  }

  Widget _buildDropdownWithAdd({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    void Function(String?)? onChanged,
    required VoidCallback onAddPressed,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildDropdown(
            label: label,
            value: value,
            items: items,
            onChanged: onChanged,
            icon: icon,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 44, // Match dropdown height approx
          width: 44,
          decoration: BoxDecoration(
            color: kCardDark,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: const Icon(Icons.add, color: kLimeGreen, size: 20),
            onPressed: onAddPressed,
            tooltip: 'Add new',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchingData) {
      return Scaffold(
        backgroundColor: kDarkBg,
        appBar: AppBar(
          title: const Text('Sample Request', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white, size: 20),
        ),
        body: const Center(child: CircularProgressIndicator(color: kLimeGreen, strokeWidth: 2)),
      );
    }

    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        title: const Text('Sample Request', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'PROJECT INFO',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2),
                ),
                const SizedBox(height: 10),
                _buildDropdownWithAdd(
                  label: 'Company',
                  icon: Icons.business,
                  value: _selectedCompany,
                  items: _getUniqueItems(_companies, 'name'),
                  onChanged: (val) => setState(() => _selectedCompany = val),
                  onAddPressed: _addNewCompany,
                ),
                const SizedBox(height: 10),
                _buildDropdownWithAdd(
                  label: 'Project',
                  icon: Icons.apartment,
                  value: _selectedProject,
                  items: _getUniqueItems(_projects, 'project_name'),
                  onChanged: (val) => setState(() => _selectedProject = val),
                  onAddPressed: _addNewProject,
                ),
                const SizedBox(height: 24),

                const Text(
                  'PRODUCT DETAILS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2),
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _productNameController,
                  label: 'Product Name',
                  icon: Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _colorController,
                        label: 'Color',
                        icon: Icons.color_lens_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDropdown(
                        label: 'Series',
                        icon: Icons.category_outlined,
                        value: _selectedSeries,
                        items: _seriesOptions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedSeries = val;
                            // รีเซ็ต Film ถ้า Series ใหม่ไม่มี Film เดิมที่เลือกไว้
                            if (_selectedFilm != null && !_availableFilms.contains(_selectedFilm)) {
                              _selectedFilm = null;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildDropdown(
                  label: _selectedSeries == null ? 'Select Series First' : 'Film Pattern',
                  icon: Icons.texture_outlined,
                  value: _selectedFilm,
                  items: _availableFilms.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: _availableFilms.isEmpty ? null : (val) => setState(() => _selectedFilm = val),
                ),
                const SizedBox(height: 10),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: kCardDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.format_list_numbered, color: Colors.white54, size: 18),
                          SizedBox(width: 10),
                          Text('Quantity', style: TextStyle(fontSize: 13, color: Colors.white70)),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.remove_circle_outline),
                            color: Colors.redAccent,
                            onPressed: () {
                              if (_qty > 1) setState(() => _qty--);
                            },
                          ),
                          const SizedBox(width: 12),
                          Text('$_qty', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(width: 12),
                          IconButton(
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.add_circle_outline),
                            color: kLimeGreen,
                            onPressed: () {
                              setState(() => _qty++);
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                _buildTextField(
                  controller: _noteController,
                  label: 'Note (Optional)',
                  icon: Icons.note_alt_outlined,
                  maxLines: 2,
                  validator: (val) => null, 
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: kLimeGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Text(
                          'Submit Request',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}