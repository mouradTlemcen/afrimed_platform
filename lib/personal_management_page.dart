// File: lib/personal_management_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // For launching external URLs
import 'package:firebase_auth/firebase_auth.dart'; // Needed to get current user ID
import 'user_profile_page.dart';
import 'add_user_page.dart';
import 'update_user_page.dart';
import 'activity_logger.dart'; // Import your custom activity logger

class PersonalManagementPage extends StatefulWidget {
  @override
  _PersonalManagementPageState createState() => _PersonalManagementPageState();
}

class _PersonalManagementPageState extends State<PersonalManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Filter state variables
  String _selectedPositionFilter = "All";
  String _selectedSkillFilter = "All";
  String _selectedOnlineMissionFilter = "All";
  String _selectedFieldMissionFilter = "All";
  String _selectedHasTasksFilter = "All";

  // Whether the filters are visible - set to false so filters are closed initially.
  bool _showFilters = false;

  // Fixed lists for the dropdowns
  final List<String> _positionOptions = [
    "All",
    "Technician",
    "Engineer",
    "Project Manager",
    "Site Manager",
    "Program Manager",
    "Top Manager",
    "Suppliers relationships Manager",
    "Clients relationships Manager",
    "Tender departement Manager",
    "Operations Manager",
    "Admin"
  ];

  final List<String> _skillOptions = [
    "All",
    "Electrical engineering skills",
    "Mechanical engineering skills",
    "Full PSA skills",
    "Construction design and architecture skills",
    "IT skills",
    "Management skills",
    "Administration skills",
    "Tender preparation skills"
  ];

  final List<String> _missionOptions = ["All", "No mission", "In mission"];
  final List<String> _hasTasksOptions = ["All", "YES", "NO"];

  /// Opens a Google Maps URL for a single coordinate.
  Future<void> _launchGoogleMaps(double latitude, double longitude) async {
    final url = 'https://www.google.com/maps?q=$latitude,$longitude';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personnel Management'),
        backgroundColor: const Color(0xFF003366),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search personnel...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
          ),

          // Filter Toggle Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    setState(() {
                      _showFilters = !_showFilters;
                    });
                    // Log filter toggle event
                    await logActivity(
                      userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                      action: 'toggle_filters',
                      details: 'Filters toggled to ${_showFilters ? "shown" : "hidden"}',
                    );
                  },
                  icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
                  label: Text(_showFilters ? "Hide Filters" : "Show Filters"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0073E6),
                  ),
                ),
              ],
            ),
          ),

          // Filter Section (if visible)
          Visibility(
            visible: _showFilters,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    children: [
                      // Position Filter
                      DropdownButtonFormField<String>(
                        isDense: true,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: "Position",
                          border: OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        value: _selectedPositionFilter,
                        items: _positionOptions.map((position) {
                          return DropdownMenuItem(
                            value: position,
                            child: Text(position, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPositionFilter = value!;
                          });
                        },
                      ),

                      // Skill Filter
                      DropdownButtonFormField<String>(
                        isDense: true,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: "Skill",
                          border: OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        value: _selectedSkillFilter,
                        items: _skillOptions.map((skill) {
                          return DropdownMenuItem(
                            value: skill,
                            child: Text(skill, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSkillFilter = value!;
                          });
                        },
                      ),

                      // Online Mission Filter
                      DropdownButtonFormField<String>(
                        isDense: true,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: "Online Mission",
                          border: OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        value: _selectedOnlineMissionFilter,
                        items: _missionOptions.map((mission) {
                          return DropdownMenuItem(
                            value: mission,
                            child: Text(mission, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedOnlineMissionFilter = value!;
                          });
                        },
                      ),

                      // Field Mission Filter
                      DropdownButtonFormField<String>(
                        isDense: true,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: "Field Mission",
                          border: OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        value: _selectedFieldMissionFilter,
                        items: _missionOptions.map((mission) {
                          return DropdownMenuItem(
                            value: mission,
                            child: Text(mission, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFieldMissionFilter = value!;
                          });
                        },
                      ),

                      // Has Tasks Filter
                      DropdownButtonFormField<String>(
                        isDense: true,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: "Has Tasks",
                          border: OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        value: _selectedHasTasksFilter,
                        items: _hasTasksOptions.map((option) {
                          return DropdownMenuItem(
                            value: option,
                            child: Text(option, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedHasTasksFilter = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Personnel List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No personnel found.',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                final users = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  // Search filter on full name.
                  final fullName =
                  "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".toLowerCase();
                  if (!fullName.contains(_searchQuery)) return false;

                  // Position filter.
                  if (_selectedPositionFilter != "All" &&
                      (data['position'] == null ||
                          data['position'] != _selectedPositionFilter)) {
                    return false;
                  }

                  // Skill filter (domainsOfExpertise is expected to be a List).
                  if (_selectedSkillFilter != "All") {
                    final List<dynamic>? expertise = data['domainsOfExpertise'];
                    if (expertise == null || !expertise.contains(_selectedSkillFilter)) {
                      return false;
                    }
                  }

                  // Online Mission Status filter.
                  if (_selectedOnlineMissionFilter != "All" &&
                      (data['onlineMissionStatus'] == null ||
                          data['onlineMissionStatus'] != _selectedOnlineMissionFilter)) {
                    return false;
                  }

                  // Field Mission Status filter.
                  if (_selectedFieldMissionFilter != "All" &&
                      (data['fieldMissionStatus'] == null ||
                          data['fieldMissionStatus'] != _selectedFieldMissionFilter)) {
                    return false;
                  }

                  // Has Tasks filter.
                  if (_selectedHasTasksFilter != "All" &&
                      (data['has_tasks'] == null ||
                          data['has_tasks'] != _selectedHasTasksFilter)) {
                    return false;
                  }

                  return true;
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final data = user.data() as Map<String, dynamic>;
                    final firstName = data['firstName'] ?? 'N/A';
                    final lastName = data['lastName'] ?? 'N/A';
                    final email = data['email'] ?? 'N/A';
                    final phone = data['phone'] ?? 'N/A';
                    final profileImageUrl = data['profileImageUrl'] ?? '';

                    // Check for gpsLocation field.
                    final gpsLocation = data['gpsLocation'] as Map<String, dynamic>?;

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: profileImageUrl.toString().isNotEmpty
                            ? CircleAvatar(
                          backgroundImage: NetworkImage(profileImageUrl),
                          radius: 24,
                        )
                            : CircleAvatar(
                          backgroundColor: const Color(0xFF003366),
                          child: Text(
                            firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                          radius: 24,
                        ),
                        title: Text(
                          '$firstName $lastName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Email: $email'),
                              Text('Phone: $phone'),
                              if (gpsLocation != null)
                                ElevatedButton.icon(
                                  onPressed: () {
                                    final lat = gpsLocation['latitude'];
                                    final lng = gpsLocation['longitude'];
                                    if (lat != null && lng != null) {
                                      _launchGoogleMaps(
                                        lat.toDouble(),
                                        lng.toDouble(),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0073E6),
                                  ),
                                  icon: const Icon(Icons.map, size: 16),
                                  label: const Text('View GPS'),
                                ),
                            ],
                          ),
                        ),
                        onTap: () async {
                          // Log view profile event.
                          await logActivity(
                            userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                            action: 'view_personnel_profile',
                            details: 'Viewing profile for personnel with id: ${user.id}',
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfilePage(userId: user.id),
                            ),
                          );
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Edit Personnel',
                              onPressed: () async {
                                // Log edit personnel event.
                                await logActivity(
                                  userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                                  action: 'edit_personnel',
                                  details: 'Editing personnel with id: ${user.id}',
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UpdateUserPage(userId: user.id),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete Personnel',
                              onPressed: () => _deleteUser(user.id),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0073E6),
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddUserPage()),
          );
        },
      ),
    );
  }

  void _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Personnel'),
        content: const Text('Are you sure you want to delete this personnel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      // Log deletion event.
      await logActivity(
        userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        action: 'delete_personnel',
        details: 'Deleted personnel with id: $userId',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personnel deleted successfully!')),
      );
    }
  }
}
