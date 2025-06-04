import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'equipmentdetailpage.dart';
import 'equipmentupdatepage.dart';
import 'brand_model_creation_page.dart';

class EquipmentListPage extends StatefulWidget {
  const EquipmentListPage({Key? key}) : super(key: key);

  @override
  State<EquipmentListPage> createState() => _EquipmentListPageState();
}

class _EquipmentListPageState extends State<EquipmentListPage> {
  // --------------------------
  // Search TextField
  // --------------------------
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(); // <-- FocusNode helps keep focus
  String _searchQuery = '';

  // --------------------------
  // Dropdown filters
  // --------------------------
  String _selectedBrand = 'All';
  String _selectedType = 'All';
  String _selectedModel = 'All';

  // Just to indicate if we are deleting
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();

    // Listen for changes to the search controller
    // Update _searchQuery each time the user types
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose(); // dispose focus node
    super.dispose();
  }

  // --------------------------
  // Confirm & Delete
  // --------------------------
  Future<void> _confirmDeleteOne(String docId, String brand, String model) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Text("Are you sure you want to delete '$brand - $model'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteOneDocument(docId);
    }
  }

  Future<void> _deleteOneDocument(String docId) async {
    setState(() => _isDeleting = true);
    try {
      await FirebaseFirestore.instance
          .collection('equipment_definitions')
          .doc(docId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Deleted doc ID: $docId")),
      );
    } catch (e) {
      debugPrint("Error deleting doc $docId: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting: $e")),
      );
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  // --------------------------
  // Build
  // --------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // -------------------------------------
      // AppBar
      // -------------------------------------
      appBar: AppBar(
        title: const Text("Equipment Definitions"),
        backgroundColor: const Color(0xFF003366),
      ),

      // -------------------------------------
      // Body
      // -------------------------------------
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF005599), Color(0xFF003366)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isDeleting
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            // -------------------------------------
            // 1) Search Bar (OUTSIDE StreamBuilder)
            // -------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode, // keep focus
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search brand, model, or type...',
                  hintStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search, color: Colors.white),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ),

            // -------------------------------------
            // 2) StreamBuilder for real-time data
            //    (Dropdowns + List)
            // -------------------------------------
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('equipment_definitions')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  // handle states
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Error: ${snapshot.error}",
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: Text(
                        "No data from Firestore yet...",
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final allDocs = snapshot.data!.docs;
                  if (allDocs.isEmpty) {
                    return const Center(
                      child: Text(
                        "No equipment definitions found.",
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  // ---------------------------------------------------
                  // A) Build brand/type/model sets to fill dropdowns
                  // ---------------------------------------------------
                  final Set<String> allBrands = {'All'};
                  final Set<String> allTypes = {'All'};
                  final Set<String> allModels = {'All'};

                  for (var doc in allDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final brand = (data['brand'] ?? '').toString();
                    final type = (data['equipmentType'] ?? '').toString();
                    final model = (data['model'] ?? '').toString();

                    if (brand.isNotEmpty) allBrands.add(brand);
                    if (type.isNotEmpty) allTypes.add(type);
                    if (model.isNotEmpty) allModels.add(model);
                  }

                  // ---------------------------------------------------
                  // B) Build sets of valid type/model for chaining
                  // ---------------------------------------------------
                  final Set<String> validTypesForBrand = {'All'};
                  final Set<String> validModelsForBrandType = {'All'};

                  // Loop docs again
                  for (var doc in allDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final docBrand = (data['brand'] ?? '').toString();
                    final docType = (data['equipmentType'] ?? '').toString();
                    final docModel = (data['model'] ?? '').toString();

                    // If brand matches (or 'All'), add that type
                    final brandMatches = (_selectedBrand == 'All')
                        ? true
                        : docBrand.toLowerCase() ==
                        _selectedBrand.toLowerCase();
                    if (brandMatches && docType.isNotEmpty) {
                      validTypesForBrand.add(docType);
                    }

                    // If brand & type match, add that model
                    final typeMatches = (_selectedType == 'All')
                        ? true
                        : docType.toLowerCase() == _selectedType.toLowerCase();
                    if (brandMatches && typeMatches && docModel.isNotEmpty) {
                      validModelsForBrandType.add(docModel);
                    }
                  }

                  // ---------------------------------------------------
                  // C) Single-pass filter for final list
                  // ---------------------------------------------------
                  final filteredDocs = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final brand = (data['brand'] ?? '').toString().toLowerCase();
                    final type = (data['equipmentType'] ?? '').toString().toLowerCase();
                    final model = (data['model'] ?? '').toString().toLowerCase();

                    final brandOk = (_selectedBrand == 'All')
                        ? true
                        : brand == _selectedBrand.toLowerCase();
                    final typeOk = (_selectedType == 'All')
                        ? true
                        : type == _selectedType.toLowerCase();
                    final modelOk = (_selectedModel == 'All')
                        ? true
                        : model == _selectedModel.toLowerCase();

                    // Search text (partial match)
                    final searchOk = brand.contains(_searchQuery) ||
                        type.contains(_searchQuery) ||
                        model.contains(_searchQuery);

                    return brandOk && typeOk && modelOk && searchOk;
                  }).toList();

                  // ---------------------------------------------------
                  // D) Build UI: Filter Dropdowns + List
                  // ---------------------------------------------------
                  return Column(
                    children: [
                      // -----------------------------------------
                      // Dropdowns for Brand / Type / Model
                      // -----------------------------------------
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            // BRAND
                            _buildDropdownFilter(
                              label: 'Brand',
                              value: _selectedBrand,
                              items: (allBrands.toList()..sort()),
                              validItems: allBrands, // brand can always show all
                              onChanged: (String? newValue) {
                                if (newValue == null) return;
                                setState(() {
                                  _selectedBrand = newValue;
                                  // Reset type/model
                                  _selectedType = 'All';
                                  _selectedModel = 'All';
                                });
                              },
                            ),

                            // TYPE
                            _buildDropdownFilter(
                              label: 'Type',
                              value: _selectedType,
                              items: (validTypesForBrand.toList()..sort()),
                              validItems: validTypesForBrand,
                              onChanged: (String? newValue) {
                                if (newValue == null) return;
                                setState(() {
                                  _selectedType = newValue;
                                  // Reset model
                                  _selectedModel = 'All';
                                });
                              },
                            ),

                            // MODEL
                            _buildDropdownFilter(
                              label: 'Model',
                              value: _selectedModel,
                              items:
                              (validModelsForBrandType.toList()..sort()),
                              validItems: validModelsForBrandType,
                              onChanged: (String? newValue) {
                                if (newValue == null) return;
                                setState(() {
                                  _selectedModel = newValue;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // -----------------------------------------
                      // The List of Filtered Docs
                      // -----------------------------------------
                      Expanded(
                        child: filteredDocs.isEmpty
                            ? const Center(
                          child: Text(
                            "No matching equipment found.",
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                            : ListView.builder(
                          itemCount: filteredDocs.length,
                          padding:
                          const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final data =
                            doc.data() as Map<String, dynamic>;
                            final docId = doc.id;

                            final brand = data['brand'] ?? 'N/A';
                            final model = data['model'] ?? 'N/A';
                            final type =
                                data['equipmentType'] ?? 'N/A';

                            final Timestamp? ts =
                            data['createdAt'] as Timestamp?;
                            final dateStr = (ts != null)
                                ? ts
                                .toDate()
                                .toString()
                                .split('.')
                                .first
                                : "No date";

                            return Card(
                              color: Colors.white.withOpacity(0.9),
                              margin: const EdgeInsets.symmetric(
                                  vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                              elevation: 3,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                  const Color(0xFF003366),
                                  child: Text(
                                    brand.isNotEmpty
                                        ? brand[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  "$brand - $model",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                    "Type: $type\nCreated: $dateStr"),
                                isThreeLine: true,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          EquipmentDetailPage(
                                            equipmentData: data,
                                            equipmentId: docId,
                                          ),
                                    ),
                                  );
                                },
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.grey,
                                      ),
                                      tooltip: "Edit",
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EquipmentUpdatePage(
                                                  equipmentData: data,
                                                  equipmentId: docId,
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      tooltip: "Delete",
                                      onPressed: () {
                                        _confirmDeleteOne(
                                          docId,
                                          brand,
                                          model,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // -------------------------------------
      // FloatingActionButton
      // -------------------------------------
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF003366),
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BrandModelCreationPage(),
            ),
          );
        },
      ),
    );
  }

  /// Helper: Builds a styled dropdown with label
  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<String> items,
    required Set<String> validItems,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 120, // Adjust as you see fit
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white),
          filled: true,
          fillColor: Colors.white.withOpacity(0.2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF003366),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          underline: const SizedBox(),
          style: const TextStyle(color: Colors.white),
          onChanged: onChanged,
          items: items.map((String item) {
            final isDisabled = !validItems.contains(item);
            return DropdownMenuItem<String>(
              value: item,
              enabled: !isDisabled,
              child: Text(
                item,
                style: TextStyle(
                  color: isDisabled ? Colors.white38 : Colors.white,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
