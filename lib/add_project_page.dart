// File: add_project_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_lots_and_sites_page.dart';
import 'project_management_page.dart';

class AddProjectPage extends StatefulWidget {
  @override
  _AddProjectPageState createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for project info
  final TextEditingController projectIdController = TextEditingController();

  // Selected client (from partners database)
  String? selectedClient;
  String? selectedMainClientCoordinator;

  // Selected Afrimed Managers (from users collection)
  String? selectedOperationsManager;
  String? selectedPSAProgramManager;
  String? selectedTechnicalManager;
  String? selectedBIDManager;
  String? selectedClientRelationshipManager;

  /// Save project once and then redirect to AddLotsAndSitesPage.
  Future<void> _saveProject() async {
    if (_formKey.currentState!.validate()) {
      // Create project in Firestore with "afrimedProjectId" field
      DocumentReference projectRef =
      await FirebaseFirestore.instance.collection('projects').add({
        'Afrimed_projectId': projectIdController.text,
        'clientId': selectedClient,
        'mainClientCoordinator': selectedMainClientCoordinator,
        'operationsManager': selectedOperationsManager,
        'psaProgramManager': selectedPSAProgramManager,
        'technicalManager': selectedTechnicalManager,
        'bidManager': selectedBIDManager,
        'clientRelationshipManager': selectedClientRelationshipManager,
        'lots': [],
      });

      // Add the auto-generated document ID as "projectDocId"
      await projectRef.update({
        'projectDocId': projectRef.id,
      });

      // Show success message.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Project Saved Successfully!')),
      );

      // Navigate to AddLotsAndSitesPage and wait for the result.
      bool? lotsAdded = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              AddLotsAndSitesPage(projectId: projectRef.id),
        ),
      );

      // Regardless of lotsAdded value (true or false), redirect to ProjectManagementPage.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ProjectManagementPage()),
      );
    }
  }

  /// Helper function to build Afrimed personnel dropdowns from "users".
  Widget buildUserDropdown(
      String label, String? selectedValue, ValueChanged<String?> onChanged) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        var users = snapshot.data!.docs;
        return DropdownButtonFormField<String>(
          value: selectedValue,
          onChanged: onChanged,
          items: users.map<DropdownMenuItem<String>>((user) {
            var data = user.data() as Map<String, dynamic>;
            String firstName =
            data.containsKey('firstName') ? data['firstName'] ?? 'Unknown' : 'Unknown';
            String lastName =
            data.containsKey('lastName') ? data['lastName'] ?? '' : '';
            String position =
            data.containsKey('position') ? data['position'] ?? 'No Position' : 'No Position';
            return DropdownMenuItem<String>(
              value: user.id,
              child: Text('$firstName $lastName - $position'),
            );
          }).toList(),
          decoration: InputDecoration(labelText: label),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Project'),
        backgroundColor: const Color(0xFF003366),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Project ID
              TextFormField(
                controller: projectIdController,
                decoration: const InputDecoration(labelText: 'Project ID'),
                validator: (value) => value!.isEmpty ? 'Enter Project ID' : null,
              ),

              // Client Dropdown (Fetch Only Clients)
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('partners')
                    .where('partnershipType', isEqualTo: 'Client')
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  var clients = snapshot.data!.docs;
                  return DropdownButtonFormField<String>(
                    value: selectedClient,
                    onChanged: (newValue) {
                      setState(() {
                        selectedClient = newValue;
                        selectedMainClientCoordinator = null;
                      });
                    },
                    items: clients.map<DropdownMenuItem<String>>((client) {
                      var data = client.data() as Map<String, dynamic>;
                      return DropdownMenuItem<String>(
                        value: client.id,
                        child: Text(data['name'] ?? 'Unknown'),
                      );
                    }).toList(),
                    decoration: const InputDecoration(labelText: 'Select Client'),
                  );
                },
              ),

              const SizedBox(height: 20),
              const Text("Select Afrimed Managers",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

              // Afrimed Managers Dropdowns
              buildUserDropdown('Afrimed Operations Manager', selectedOperationsManager,
                      (newValue) {
                    setState(() => selectedOperationsManager = newValue);
                  }),
              buildUserDropdown('Afrimed PSA Program Manager', selectedPSAProgramManager,
                      (newValue) {
                    setState(() => selectedPSAProgramManager = newValue);
                  }),
              buildUserDropdown('Afrimed PSA Technical Manager', selectedTechnicalManager,
                      (newValue) {
                    setState(() => selectedTechnicalManager = newValue);
                  }),
              buildUserDropdown('Afrimed BID Manager', selectedBIDManager, (newValue) {
                setState(() => selectedBIDManager = newValue);
              }),
              buildUserDropdown('Afrimed Client Relationship Manager', selectedClientRelationshipManager,
                      (newValue) {
                    setState(() => selectedClientRelationshipManager = newValue);
                  }),

              const SizedBox(height: 20),

              // Save Project Button
              ElevatedButton(
                onPressed: _saveProject,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003366)),
                child: const Text('Save Project', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
