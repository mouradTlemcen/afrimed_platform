import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To get current user ID
import 'project_details_page.dart';
import 'add_project_page.dart';
import 'activity_logger.dart'; // Import your activity logger

class ProjectManagementPage extends StatefulWidget {
  @override
  _ProjectManagementPageState createState() => _ProjectManagementPageState();
}

class _ProjectManagementPageState extends State<ProjectManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Management'),
        backgroundColor: const Color(0xFF003366),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: _buildFilterSection(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Dynamically choose the number of columns based on screen width.
            final double width = constraints.maxWidth;
            int crossAxisCount;
            if (width >= 1200) {
              crossAxisCount = 4; // Very large screen
            } else if (width >= 900) {
              crossAxisCount = 3; // Large tablet / desktop
            } else if (width >= 600) {
              crossAxisCount = 2; // Small tablet
            } else {
              crossAxisCount = 1; // Phones or very small width
            }

            // Adjust icon size for bigger screens
            final double iconSize = width >= 1200
                ? 70
                : width >= 900
                ? 60
                : width >= 600
                ? 50
                : 40;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('projects')
              // IMPORTANT: Must match the field name exactly as in Firestore
                  .orderBy('Afrimed_projectId', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                // 1) If the stream has an error, show the error text
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                // 2) While waiting for data, show a loading indicator
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 3) If the stream is active but has no docs
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No projects found.'));
                }

                // We do have documents: filter them based on _searchQuery
                var allProjects = snapshot.data!.docs;
                var filteredProjects = allProjects.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  // Make sure we read the same key: "Afrimed_projectId"
                  final afrimedProjectId =
                  (data['Afrimed_projectId'] ?? '').toString().toLowerCase();
                  final country =
                  (data['country'] ?? '').toString().toLowerCase();

                  // If either field contains the query, include it
                  return afrimedProjectId.contains(_searchQuery) ||
                      country.contains(_searchQuery);
                }).toList();

                if (filteredProjects.isEmpty) {
                  return const Center(
                    child: Text('No projects match your filter.'),
                  );
                }

                // Build the grid of projects
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: filteredProjects.length,
                  itemBuilder: (context, index) {
                    var projectDoc = filteredProjects[index];
                    var projectData =
                    projectDoc.data() as Map<String, dynamic>;

                    // Firestore doc ID
                    String firestoreId = projectDoc.id;

                    // Make sure to read the same field:
                    String afrimedProjectId =
                        projectData['Afrimed_projectId'] ?? 'Unknown';

                    // Use a fallback name or the ID
                    String projectName =
                        projectData['name'] ?? afrimedProjectId;
                    String projectCountry =
                        projectData['country'] ?? 'Unknown';

                    return Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          // Log event: view project details.
                          await logActivity(
                            userId:
                            FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                            action: 'view_project',
                            details:
                            'Viewing project with Firestore ID: $firestoreId',
                          );
                          // Navigate to Project Details Page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProjectDetailsPage(
                                firestoreId: firestoreId,
                                projectId: afrimedProjectId,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0073E6), // Blue
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              // Main content
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.folder,
                                      size: iconSize, color: Colors.white),
                                  const SizedBox(height: 12),
                                  Text(
                                    projectName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Afrimed Project ID: $afrimedProjectId',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    'Country: $projectCountry',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                              // Delete button (top-right)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    // Log event: delete project.
                                    await logActivity(
                                      userId: FirebaseAuth
                                          .instance.currentUser
                                          ?.uid ??
                                          'unknown',
                                      action: 'delete_project',
                                      details:
                                      'Deleting project with Firestore ID: $firestoreId',
                                    );
                                    _deleteProject(firestoreId);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Log event: navigating to add project.
          await logActivity(
            userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
            action: 'navigate_to_add_project',
            details: 'Navigating to AddProjectPage',
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddProjectPage()),
          );
        },
        backgroundColor: const Color(0xFF003366),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // A small filter/search bar
  Widget _buildFilterSection() {
    return Container(
      height: 60,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by Afrimed Project ID or Country...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim().toLowerCase();
          });
        },
      ),
    );
  }

  // Delete project after user confirmation
  void _deleteProject(String projectDocId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Project"),
        content: const Text("Are you sure you want to delete this project?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectDocId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project deleted successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting project: $e')),
        );
      }
    }
  }
}
