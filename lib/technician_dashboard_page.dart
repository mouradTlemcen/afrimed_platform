// technician_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'task_management_page.dart';

class TechnicianDashboardPage extends StatelessWidget {
  // Method to display account details in a bottom sheet.
  void _showAccountDetails(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return FutureBuilder<DocumentSnapshot>(
          future:
          FirebaseFirestore.instance.collection('users').doc(uid).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            var userData = snapshot.data!.data() as Map<String, dynamic>;
            String firstName = userData["firstName"] ?? "";
            String lastName = userData["lastName"] ?? "";
            String displayName = (firstName + " " + lastName).trim();
            if (displayName.isEmpty) displayName = "No Name";
            String email = userData["email"] ?? "No Email";
            // Use the role field if available, otherwise fallback to the position.
            String userRole = userData.containsKey('role')
                ? userData['role']
                : (userData['position'] ?? "Technician");
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue.shade700,
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : "?",
                      style: TextStyle(fontSize: 40, color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(displayName,
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(email,
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                  SizedBox(height: 8),
                  Text("Role: $userRole",
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Close"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Technician sees only one module: Task Management.
    final List<Map<String, dynamic>> technicianModules = [
      {"name": "Task Management", "route": "/tasks", "icon": Icons.task},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Afrimed Management System'),
        backgroundColor: const Color(0xFF003366),
        actions: [
          IconButton(
            icon: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: const Color(0xFF003366)),
            ),
            onPressed: () => _showAccountDetails(context),
          ),
          SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF003366), const Color(0xFF0073E6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'AFRIMED APP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Technician Dashboard',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.black87),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.task, color: Colors.black87),
              title: const Text('Task Management'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskManagementPage(isTechnician: true),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context); // Add logout functionality if needed.
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: technicianModules.length,
          itemBuilder: (context, index) {
            final module = technicianModules[index];
            return GestureDetector(
              onTap: () {
                if (module['route'] == '/tasks') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskManagementPage(isTechnician: true),
                    ),
                  );
                }
              },
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade700, Colors.blue.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(module["icon"], size: 50, color: Colors.white),
                      const SizedBox(height: 12),
                      Text(
                        module["name"]!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
