// Filename: project_update_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectUpdatePage extends StatefulWidget {
  final String projectId;

  ProjectUpdatePage({required this.projectId});

  @override
  _ProjectUpdatePageState createState() => _ProjectUpdatePageState();
}

class _ProjectUpdatePageState extends State<ProjectUpdatePage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  TextEditingController projectIdController = TextEditingController();
  String? selectedClient;
  String? selectedOperationsManager;
  String? selectedPSAProgramManager;
  String? selectedTechnicalManager;
  String? selectedBIDManager;
  String? selectedClientRelationshipManager;

  @override
  void initState() {
    super.initState();
    _loadProjectDetails();
  }

  void _loadProjectDetails() async {
    DocumentSnapshot projectSnapshot = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
    if (projectSnapshot.exists) {
      var data = projectSnapshot.data() as Map<String, dynamic>;
      setState(() {
        projectIdController.text = data['projectId'] ?? '';
        selectedClient = data['clientId'];
        selectedOperationsManager = data['operationsManager'];
        selectedPSAProgramManager = data['psaProgramManager'];
        selectedTechnicalManager = data['technicalManager'];
        selectedBIDManager = data['bidManager'];
        selectedClientRelationshipManager = data['clientRelationshipManager'];
      });
    }
  }

  void _updateProject() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).update({
        'clientId': selectedClient,
        'operationsManager': selectedOperationsManager,
        'psaProgramManager': selectedPSAProgramManager,
        'technicalManager': selectedTechnicalManager,
        'bidManager': selectedBIDManager,
        'clientRelationshipManager': selectedClientRelationshipManager,
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Project Updated Successfully!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Project"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Project ID (Non-editable)
              TextFormField(
                controller: projectIdController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Project ID'),
              ),

              // Select Client
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('partners').where('partnershipType', isEqualTo: 'Client').get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  var clients = snapshot.data!.docs;
                  return DropdownButtonFormField<String>(
                    value: selectedClient,
                    onChanged: (newValue) => setState(() => selectedClient = newValue),
                    items: clients.map((client) {
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
              const Text("Afrimed Managers", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

              _buildUserDropdown('Afrimed Operations Manager', selectedOperationsManager, (value) {
                setState(() => selectedOperationsManager = value);
              }),

              _buildUserDropdown('Afrimed PSA Program Manager', selectedPSAProgramManager, (value) {
                setState(() => selectedPSAProgramManager = value);
              }),

              _buildUserDropdown('Afrimed PSA Technical Manager', selectedTechnicalManager, (value) {
                setState(() => selectedTechnicalManager = value);
              }),

              _buildUserDropdown('Afrimed BID Manager', selectedBIDManager, (value) {
                setState(() => selectedBIDManager = value);
              }),

              _buildUserDropdown('Afrimed Client Relationship Manager', selectedClientRelationshipManager, (value) {
                setState(() => selectedClientRelationshipManager = value);
              }),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _updateProject,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003366)),
                child: const Text('Update Project', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper function to build user dropdowns
  Widget _buildUserDropdown(String label, String? selectedValue, ValueChanged<String?> onChanged) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        var users = snapshot.data!.docs;
        return DropdownButtonFormField<String>(
          value: selectedValue,
          onChanged: onChanged,
          items: users.map((user) {
            var data = user.data() as Map<String, dynamic>;
            return DropdownMenuItem<String>(
              value: user.id,
              child: Text("${data['firstName']} ${data['lastName']} - ${data['position']}"),
            );
          }).toList(),
          decoration: InputDecoration(labelText: label),
        );
      },
    );
  }
}
