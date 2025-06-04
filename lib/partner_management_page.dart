import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To get current user ID
import 'add_partner_page.dart';
import 'update_partner_page.dart';
import 'view_partner_page.dart';
import 'activity_logger.dart'; // Import your custom activity logger

class PartnerManagementPage extends StatefulWidget {
  const PartnerManagementPage({Key? key}) : super(key: key);

  @override
  _PartnerManagementPageState createState() => _PartnerManagementPageState();
}

class _PartnerManagementPageState extends State<PartnerManagementPage> {
  String _searchQuery = '';
  String _selectedTypeFilter = 'All';    // "All" means no type filter
  String _selectedCountryFilter = 'All'; // "All" means no country filter

  // The available partner types (plus "All")
  final List<String> _typeOptions = [
    'All',
    'Supplier',
    'Distributor',
    'Client',
    'Ministry of Health',
    'Other',
  ];

  // This list will be built from the "country" fields in partner documents.
  List<String> _countryOptions = ['All'];

  @override
  void initState() {
    super.initState();
    _fetchCountryOptions();
  }

  /// Fetch distinct countries from the 'partners' collection.
  Future<void> _fetchCountryOptions() async {
    try {
      QuerySnapshot snapshot =
      await FirebaseFirestore.instance.collection('partners').get();
      Set<String> countries = {'All'};
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('country')) {
          String country = data['country'].toString().trim();
          if (country.isNotEmpty && country.toLowerCase() != 'select country') {
            countries.add(country);
          }
        }
      }
      setState(() {
        _countryOptions = countries.toList()..sort();
      });
    } catch (e) {
      debugPrint("Error fetching country options: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner Management'),
        centerTitle: true,
        backgroundColor: const Color(0xFF003366), // Navy blue
      ),
      body: Column(
        children: [
          // Header with Search and Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // --- Search Bar ---
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search partners...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    isDense: true,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                // --- Filters: Use a Wrap so they don't overflow horizontally ---
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // Filter by Type
                    Container(
                      width: 250, // set a max width so it doesn't expand too far
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonFormField<String>(
                        value: _selectedTypeFilter,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'Filter by Type',
                        ),
                        items: _typeOptions.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTypeFilter = value ?? 'All';
                          });
                        },
                      ),
                    ),

                    // Filter by Country
                    Container(
                      width: 250, // set a max width so it doesn't expand too far
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCountryFilter,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'Filter by Country',
                        ),
                        items: _countryOptions.map((country) {
                          return DropdownMenuItem<String>(
                            value: country,
                            child: Text(country),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCountryFilter = value ?? 'All';
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // The partner list in an Expanded widget
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('partners').snapshots(),
              builder: (context, snapshot) {
                // Show loading spinner while waiting for data
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // If no data or empty list, show a message
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No partners found.',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  );
                }

                // Filter the partners based on the search query, type filter, and country filter
                final partners = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['contactDetails']?['email'] ?? '')
                      .toString()
                      .toLowerCase();
                  final type =
                  (data['partnershipType'] ?? '').toString().toLowerCase();
                  final country =
                  (data['country'] ?? '').toString().toLowerCase();

                  // Compare countries in a case-insensitive way
                  final selectedCountry = _selectedCountryFilter.toLowerCase();

                  final matchesSearch = name.contains(_searchQuery) ||
                      email.contains(_searchQuery) ||
                      type.contains(_searchQuery);
                  final matchesType = _selectedTypeFilter == 'All'
                      ? true
                      : type == _selectedTypeFilter.toLowerCase();
                  final matchesCountry = _selectedCountryFilter == 'All'
                      ? true
                      : country == selectedCountry;

                  return matchesSearch && matchesType && matchesCountry;
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: partners.length,
                  itemBuilder: (context, index) {
                    final partnerDoc = partners[index];
                    final data = partnerDoc.data() as Map<String, dynamic>;
                    final partnerId = partnerDoc.id;
                    final name = data['name'] ?? 'N/A';
                    final logoUrl = data['logoUrl'] ?? '';

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12.0),
                        onTap: () async {
                          // Log event: view partner details.
                          await logActivity(
                            userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                            action: 'view_partner',
                            details: 'Viewing partner with id: $partnerId',
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ViewPartnerPage(partnerId: partnerId),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              // Leading logo or initial avatar
                              if (logoUrl.isNotEmpty)
                                CircleAvatar(
                                  backgroundImage: NetworkImage(logoUrl),
                                  radius: 20,
                                )
                              else
                                CircleAvatar(
                                  backgroundColor: const Color(0xFF003366),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  radius: 20,
                                ),
                              const SizedBox(width: 12),
                              // Partner info (name, etc.)
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.0,
                                  ),
                                ),
                              ),
                              // Edit & Delete icons
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    tooltip: 'Edit Partner',
                                    onPressed: () async {
                                      // Log event: edit partner.
                                      await logActivity(
                                        userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                                        action: 'edit_partner',
                                        details: 'Editing partner with id: $partnerId',
                                      );
                                      FocusScope.of(context).unfocus();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UpdatePartnerPage(partnerId: partnerId),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Delete Partner',
                                    onPressed: () {
                                      FocusScope.of(context).unfocus();
                                      deletePartner(partnerId);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Log event: add new partner.
          await logActivity(
            userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
            action: 'add_partner',
            details: 'Navigating to add partner page.',
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddPartnerPage()),
          );
        },
        backgroundColor: const Color(0xFF0073E6),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Confirm and delete a partner document by ID
  void deletePartner(String partnerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Partner'),
          content: const Text('Are you sure you want to delete this partner?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('partners')
          .doc(partnerId)
          .delete();
      // Log event: delete partner.
      await logActivity(
        userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        action: 'delete_partner',
        details: 'Deleted partner with id: $partnerId',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partner deleted successfully!')),
      );
    }
  }
}
