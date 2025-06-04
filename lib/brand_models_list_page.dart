import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'brand_model_creation_page.dart';

class BrandModelsListPage extends StatefulWidget {
  const BrandModelsListPage({Key? key}) : super(key: key);

  @override
  _BrandModelsListPageState createState() => _BrandModelsListPageState();
}

class _BrandModelsListPageState extends State<BrandModelsListPage> {
  bool _isDeleting = false;

  // Text editing controller for the "semi search" text field
  final TextEditingController _searchController = TextEditingController();

  // The search query text we use for filtering
  String _searchQuery = '';

  // Brand filter value; 'All' means "no brand filter"
  String _selectedBrand = 'All';

  @override
  void initState() {
    super.initState();

    // Whenever the user types in the search field, update _searchQuery and rebuild
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    // Dispose controller to avoid memory leaks
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --------------------
      // APP BAR
      // --------------------
      appBar: AppBar(
        title: const Text('Marques & Modèles'),
        backgroundColor: const Color(0xFF781F3B),
        actions: [
          // Icon button to "Empty" the equipment_definitions collection
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Vider equipment_definitions',
            onPressed: _confirmDeleteAllEquipmentDefinitions,
          ),
        ],
      ),

      // --------------------
      // BODY
      // --------------------
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF9D2E49), Color(0xFF781F3B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isDeleting
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('brand_models')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Erreur : ${snapshot.error}'),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'Aucune marque/modèle disponible.',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            // All documents in brand_models
            final allDocs = snapshot.data!.docs;

            // --------------------------------
            // Build a set of brand names for the filter dropdown
            // --------------------------------
            final Set<String> brandNames = {'All'};
            for (var doc in allDocs) {
              final brand = (doc['brand'] ?? '').toString();
              if (brand.isNotEmpty) {
                brandNames.add(brand);
              }
            }

            // --------------------------------
            // Filter logic
            //  - If _selectedBrand != 'All', filter by brand
            //  - If _searchQuery is not empty, filter by brand or model
            // --------------------------------
            final filteredDocs = allDocs.where((doc) {
              final brand =
              (doc['brand'] ?? '').toString().toLowerCase();
              final model =
              (doc['model'] ?? '').toString().toLowerCase();
              final matchesSearch = brand.contains(_searchQuery) ||
                  model.contains(_searchQuery);

              // Check brand filter
              final matchesBrandFilter = _selectedBrand == 'All'
                  ? true
                  : brand == _selectedBrand.toLowerCase();

              return matchesSearch && matchesBrandFilter;
            }).toList();

            return Column(
              children: [
                // --------------------------------
                // Search TextField
                // --------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une marque ou un modèle...',
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

                // --------------------------------
                // Brand Filter Dropdown
                // --------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Text(
                        'Marque:',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            isExpanded: true,
                            dropdownColor: Colors.black87,
                            value: _selectedBrand,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Colors.white),
                            underline: const SizedBox(),
                            style: const TextStyle(color: Colors.white),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedBrand = newValue;
                                });
                              }
                            },
                            items: brandNames.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: const TextStyle(
                                      color: Colors.white),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // --------------------------------
                // List of filtered brand/model docs
                // --------------------------------
                Expanded(
                  child: filteredDocs.isEmpty
                      ? const Center(
                    child: Text(
                      'Aucun résultat pour cette recherche/filtre.',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                      : ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final brandName = doc['brand'] ??
                          'Marque non renseignée';
                      final modelName = doc['model'] ??
                          'Modèle non renseigné';
                      final dimensions =
                          doc['dimensions'] ?? '';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(
                            '$brandName - $modelName',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: dimensions.isNotEmpty
                              ? Text('Dimensions: $dimensions')
                              : null,
                          onTap: () {
                            // TODO: Navigation to detail/edit if desired
                          },
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

      // --------------------
      // FAB: add new brand/model
      // --------------------
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF781F3B),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const BrandModelCreationPage(),
            ),
          );
        },
        tooltip: 'Ajouter une nouvelle marque/modèle',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Shows a confirmation dialog, then deletes all docs from "equipment_definitions".
  Future<void> _confirmDeleteAllEquipmentDefinitions() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vider equipment_definitions ?'),
        content: const Text(
            'Voulez-vous vraiment supprimer tous les documents de "equipment_definitions" ?'),
        actions: [
          TextButton(
            child: const Text('Annuler'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteAllEquipmentDefinitions();
    }
  }

  /// Deletes all docs in "equipment_definitions".
  Future<void> _deleteAllEquipmentDefinitions() async {
    setState(() => _isDeleting = true);

    try {
      final collectionRef =
      FirebaseFirestore.instance.collection('equipment_definitions');
      final snapshot = await collectionRef.get();
      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Tous les documents "equipment_definitions" ont été supprimés.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression: $e'),
        ),
      );
    } finally {
      setState(() => _isDeleting = false);
    }
  }
}
