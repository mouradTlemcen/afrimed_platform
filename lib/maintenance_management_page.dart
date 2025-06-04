// File: lib/maintenance_management_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To get current user ID
import 'preventive_maintenance_page.dart';
import 'curative_maintenance_page.dart';
import 'activity_logger.dart'; // Import your activity logger

class MaintenanceManagementPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Maintenance Management"),
        backgroundColor: const Color(0xFF003366),
      ),
      // Added a background gradient to the body.
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // New heading for the page.
                Text(
                  "Select Maintenance Type",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 30),
                // Preventive Maintenance button with an icon.
                ElevatedButton.icon(
                  onPressed: () async {
                    // Log event: navigate to Preventive Maintenance.
                    await logActivity(
                      userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                      action: 'navigate_to_preventive_maintenance',
                      details: 'Navigating to PreventiveMaintenancePage',
                    );
                    // Navigate to Preventive Maintenance Page
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PreventiveMaintenancePage()),
                    );
                  },
                  icon: const Icon(Icons.timer, color: Colors.white),
                  label: const Text("Preventive Maintenance"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0073E6),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 20),
                // Curative Maintenance button with an icon.
                ElevatedButton.icon(
                  onPressed: () async {
                    // Log event: navigate to Curative Maintenance.
                    await logActivity(
                      userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                      action: 'navigate_to_curative_maintenance',
                      details: 'Navigating to CurativeMaintenancePage',
                    );
                    // Navigate to Curative Maintenance Page
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CurativeMaintenancePage()),
                    );
                  },
                  icon: const Icon(Icons.build, color: Colors.white),
                  label: const Text("Curative Maintenance"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0073E6),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 40),
                // A divider and a new section for recent maintenance activity.
                Divider(
                  thickness: 2,
                  indent: 30,
                  endIndent: 30,
                  color: Colors.blue.shade300,
                ),
                const SizedBox(height: 20),
                Text(
                  "Recent Maintenance Activity",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                // Placeholder for recent activity. Replace with actual activity list if needed.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    "No recent maintenance activity to show.",
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
