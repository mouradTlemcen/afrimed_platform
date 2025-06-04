import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'AcquiredEquipmentDetailPage.dart';
import 'AddAcquiredEquipmentPage.dart';
import 'EditAcquiredEquipmentPage.dart';

class AcquiredEquipmentListPage extends StatefulWidget {
  const AcquiredEquipmentListPage({Key? key}) : super(key: key);

  @override
  _AcquiredEquipmentListPageState createState() =>
      _AcquiredEquipmentListPageState();
}

class _AcquiredEquipmentListPageState extends State<AcquiredEquipmentListPage> {
  // Filter state
  String _selectedType = 'All';
  String _selectedBrand = 'All';
  String _searchText = '';

  // Optional: Track if a delete is in progress (to show a loading indicator)
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acquired Equipment'),
        backgroundColor: const Color(0xFF002244),
      ),
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF004466), Color(0xFF002244)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Main content
          Column(
            children: [
              // ------------------------------------------------
              // FILTER BAR
              // ------------------------------------------------
              Card(
                color: Colors.white.withOpacity(0.9),
                margin: const EdgeInsets.all(12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First row: Type & Brand dropdown
                      Row(
                        children: [
                          Expanded(child: _buildTypeDropdown()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildBrandDropdown()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Second row: search text field
                      _buildSearchTextField(),
                    ],
                  ),
                ),
              ),

              // ------------------------------------------------
              // MAIN LIST
              // ------------------------------------------------
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('acquired_equipments')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No acquired equipment found.',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    // 1) Gather distinct types & brands for the top filter
                    final allTypes = <String>{'All'};
                    final allBrands = <String>{'All'};

                    for (var doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final type = (data['equipmentType'] ?? '') as String;
                      final brand = (data['brand'] ?? '') as String;
                      if (type.isNotEmpty) allTypes.add(type);
                      if (brand.isNotEmpty) allBrands.add(brand);
                    }

                    final sortedTypes = allTypes.toList()..sort();
                    final sortedBrands = allBrands.toList()..sort();

                    // Ensure selected values are valid
                    if (!sortedTypes.contains(_selectedType)) {
                      _selectedType = 'All';
                    }
                    if (!sortedBrands.contains(_selectedBrand)) {
                      _selectedBrand = 'All';
                    }

                    // 2) Filter the docs
                    final filteredDocs = docs.where((docSnap) {
                      final data = docSnap.data() as Map<String, dynamic>;
                      final type = (data['equipmentType'] ?? '') as String;
                      final brand = (data['brand'] ?? '') as String;
                      final model = (data['model'] ?? '') as String;
                      final serial = (data['serialNumber'] ?? '') as String;

                      // Check type filter
                      if (_selectedType != 'All' && type != _selectedType) {
                        return false;
                      }
                      // Check brand filter
                      if (_selectedBrand != 'All' && brand != _selectedBrand) {
                        return false;
                      }
                      // Check search
                      if (_searchText.isNotEmpty) {
                        final combined =
                        (type + brand + model + serial).toLowerCase();
                        if (!combined.contains(_searchText.toLowerCase())) {
                          return false;
                        }
                      }
                      return true;
                    }).toList();

                    // 3) Build the list
                    return ListView.builder(
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final docId = doc.id;

                        final type = data['equipmentType'] ?? 'N/A';
                        final brand = data['brand'] ?? 'N/A';
                        final model = data['model'] ?? 'N/A';
                        final serialNumber = data['serialNumber'] ?? 'N/A';

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text('$type - $brand - $model'),
                            subtitle: Text('Serial: $serialNumber'),
                            // Tapping the list tile goes to detail
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AcquiredEquipmentDetailPage(
                                    documentId: docId,
                                    data: data,
                                  ),
                                ),
                              );
                            },
                            // Row with both Edit and Delete buttons
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit button
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditAcquiredEquipmentPage(
                                          docId: docId,
                                          docData: data,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Delete button
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    _confirmDeleteOne(docId, brand, model);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // Optional progress indicator if _isDeleting is true
          if (_isDeleting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF002244),
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddAcquiredEquipmentPage(),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------
  // DELETE LOGIC
  // ------------------------------------------------
  Future<void> _confirmDeleteOne(String docId, String brand, String model) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Text(
          "Are you sure you want to delete '$brand - $model'?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteDocument(docId);
    }
  }

  Future<void> _deleteDocument(String docId) async {
    setState(() => _isDeleting = true);
    try {
      await FirebaseFirestore.instance
          .collection('acquired_equipments')
          .doc(docId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Deleted doc: $docId")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting: $e")),
      );
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  // ------------------------------------------------
  // HELPER WIDGETS
  // ------------------------------------------------

  Widget _buildTypeDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('acquired_equipments')
          .snapshots(),
      builder: (context, snapshot) {
        final typesSet = <String>{'All'};
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final type = (data['equipmentType'] ?? '') as String;
            if (type.isNotEmpty) typesSet.add(type);
          }
        }
        final sortedTypes = typesSet.toList()..sort();
        if (!sortedTypes.contains(_selectedType)) {
          _selectedType = 'All';
        }

        return DropdownButtonFormField<String>(
          value: _selectedType,
          decoration: const InputDecoration(
            labelText: 'Equipment Type',
            border: OutlineInputBorder(),
          ),
          items: sortedTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedType = value ?? 'All';
              // Reset brand when type changes
              _selectedBrand = 'All';
            });
          },
        );
      },
    );
  }

  Widget _buildBrandDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('acquired_equipments')
          .snapshots(),
      builder: (context, snapshot) {
        final brandSet = <String>{'All'};
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final type = (data['equipmentType'] ?? '') as String;
            final brand = (data['brand'] ?? '') as String;

            // Only add brand if it matches the selected type or type=All
            if (_selectedType == 'All' || type == _selectedType) {
              if (brand.isNotEmpty) brandSet.add(brand);
            }
          }
        }
        final sortedBrands = brandSet.toList()..sort();
        if (!sortedBrands.contains(_selectedBrand)) {
          _selectedBrand = 'All';
        }

        return DropdownButtonFormField<String>(
          value: _selectedBrand,
          decoration: const InputDecoration(
            labelText: 'Brand',
            border: OutlineInputBorder(),
          ),
          items: sortedBrands.map((brand) {
            return DropdownMenuItem(
              value: brand,
              child: Text(brand),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedBrand = value ?? 'All';
            });
          },
        );
      },
    );
  }

  Widget _buildSearchTextField() {
    return TextFormField(
      decoration: const InputDecoration(
        labelText: 'Search by model, serial, etc.',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (value) {
        setState(() {
          _searchText = value;
        });
      },
    );
  }
}
