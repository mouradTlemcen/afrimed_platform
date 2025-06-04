// File: add_task_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddTaskPage extends StatefulWidget {
  @override
  _AddTaskPageState createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();

  // Selected values.
  String? selectedProjectId;
  String? selectedSite;
  String? selectedPhase;
  String? assignedTo;
  String? createdBy;      // We'll store the current user's UID here
  String? createdByName;  // We'll store the current user's "full name" here
  String? selectedPriority;
  String? selectedTaskType;

  DateTime? startDate;
  DateTime? endDate;

  // Text controllers.
  TextEditingController startDateController = TextEditingController();
  TextEditingController endDateController = TextEditingController();
  TextEditingController taskTitleController = TextEditingController();
  TextEditingController taskDescriptionController = TextEditingController();

  // Controller for custom task type when user chooses "Other".
  TextEditingController otherTaskTypeController = TextEditingController();

  // Data lists.
  List<Map<String, dynamic>> projects = [];
  List<Map<String, dynamic>> sites = [];
  List<Map<String, dynamic>> users = [];

  // Loading flags for showing progress indicators.
  bool isLoadingProjects = false;
  bool isLoadingSites = false;
  bool isLoadingUsers = false;

  // Dropdown options.
  final List<String> projectPhases = [
    "Tender Preparation and submission",
    "order preparation",
    "factory test",
    "shipment",
    "site preparation",
    "installation and training",
    "commissioning",
    "waranty periode",
    "after waranty periode"
  ];
  final List<String> priorityLevels = ["Low", "Medium", "High", "Urgent"];

  // Task type options (including "Other").
  final List<String> taskTypeOptions = [
    "Document preparation",
    "check and validate documentations",
    "PSA installation",
    "Other"
  ];

  @override
  void initState() {
    super.initState();

    // Get current user's UID; we will also fetch their name from Firestore.
    final currentUser = FirebaseAuth.instance.currentUser;
    createdBy = currentUser?.uid; // store UID
    _fetchCreatedByName();

    _fetchProjects();
    _fetchUsers();
  }

  /// Fetch the "created by" user's name (firstName + lastName) from Firestore.
  Future<void> _fetchCreatedByName() async {
    try {
      if (createdBy != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(createdBy)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          final firstName = data["firstName"] ?? "";
          final lastName = data["lastName"] ?? "";
          setState(() {
            createdByName = "${firstName.trim()} ${lastName.trim()}".trim();
          });
        } else {
          setState(() {
            createdByName = "Unknown";
          });
        }
      } else {
        setState(() {
          createdByName = "Unknown";
        });
      }
    } catch (e) {
      print("Error fetching current user's name: $e");
      setState(() {
        createdByName = "Unknown";
      });
    }
  }

  /// Fetch all projects.
  Future<void> _fetchProjects() async {
    setState(() => isLoadingProjects = true);
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance
              .collection('projects')
              .orderBy('Afrimed_projectId', descending: false)
              .get();

      setState(() {
        projects = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['Afrimed_projectId']?.toString() ?? 'Unknown'
          };
        }).toList();
      });
    } catch (e) {
      print('Error fetching projects: $e');
    } finally {
      setState(() => isLoadingProjects = false);
    }
  }

  /// Fetch all sites for the selected project.
  void _fetchSites() async {
    if (selectedProjectId == null) return;
    setState(() => isLoadingSites = true);
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(selectedProjectId)
          .collection('lots')
          .get();

      List<Map<String, dynamic>> allSites = [];
      for (var lot in querySnapshot.docs) {
        QuerySnapshot siteSnapshot = await FirebaseFirestore.instance
            .collection('projects')
            .doc(selectedProjectId)
            .collection('lots')
            .doc(lot.id)
            .collection('sites')
            .get();
        for (var site in siteSnapshot.docs) {
          var data = site.data() as Map<String, dynamic>;
          allSites.add({
            "id": site.id,
            "name": data["siteName"] ?? "Unnamed Site"
          });
        }
      }
      setState(() {
        sites = allSites;
      });
    } catch (e) {
      print("Error fetching sites: $e");
    } finally {
      setState(() => isLoadingSites = false);
    }
  }

  /// Fetch all users.
  void _fetchUsers() async {
    setState(() => isLoadingUsers = true);
    try {
      QuerySnapshot querySnapshot =
      await FirebaseFirestore.instance.collection('users').get();
      setState(() {
        users = querySnapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return {
            "id": doc.id,
            "name":
            "${data["firstName"] ?? "Unknown"} ${data["lastName"] ?? ""}".trim(),
            "email": data["email"] ?? "No email",
          };
        }).toList();
      });
    } catch (e) {
      print("Error fetching users: $e");
    } finally {
      setState(() => isLoadingUsers = false);
    }
  }

  /// Save the task document to Firestore.
  void _saveTask() async {
    // Validate the form, ensuring required fields are not empty.
    if (!_formKey.currentState!.validate() ||
        selectedPhase == null ||
        createdBy == null ||
        selectedPriority == null ||
        selectedTaskType == null ||
        startDate == null ||
        endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    // If user selected "Other," get the custom value from the text field.
    // Otherwise use the dropdown selection.
    final String finalTaskType = (selectedTaskType == "Other")
        ? otherTaskTypeController.text.trim()
        : selectedTaskType!;

    try {
      await FirebaseFirestore.instance.collection('tasks').add({
        "projectId": selectedProjectId ?? "General",
        "site": selectedSite ?? "General",
        "phase": selectedPhase,
        "title": taskTitleController.text.trim(),
        "description": taskDescriptionController.text.trim(),
        "assignedTo": assignedTo ?? "Unassigned",
        "createdBy": createdBy,
        "createdByName": createdByName ?? "Unknown",
        "priority": selectedPriority,
        "taskType": finalTaskType,
        "startingDate": Timestamp.fromDate(startDate!),
        "endingDate": Timestamp.fromDate(endDate!),
        "status": "Pending",
        "createdAt": Timestamp.now(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Task added successfully!")),
      );
      Navigator.pop(context);
    } catch (e) {
      print("Error saving task: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving task")));
    }
  }

  // A helper widget to build date fields with consistent style.
  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Select $label",
            suffixIcon: Icon(Icons.calendar_today),
          ),
        ),
      ],
    );
  }

  /// Builds the Project dropdown or a progress indicator if still loading.
  Widget _buildProjectDropdown() {
    if (isLoadingProjects) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Project", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Center(child: CircularProgressIndicator()),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Project", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedProjectId,
            onChanged: (newValue) {
              setState(() {
                selectedProjectId = newValue;
                _fetchSites();
              });
            },
            items: projects.map<DropdownMenuItem<String>>((project) {
              return DropdownMenuItem<String>(
                value: project["id"],
                child: Text(project["name"]),
              );
            }).toList(),
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              filled: true,
            ),
            validator: (value) =>
            value == null || value.isEmpty ? "Select a project" : null,
          ),
        ],
      );
    }
  }

  /// Builds the Site dropdown or a progress indicator if still loading.
  Widget _buildSiteDropdown() {
    if (isLoadingSites) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Site", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Center(child: CircularProgressIndicator()),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Site", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedSite,
            onChanged: (newValue) {
              setState(() {
                selectedSite = newValue;
              });
            },
            items: [
              DropdownMenuItem(value: "General", child: Text("General")),
              ...sites.map((site) => DropdownMenuItem<String>(
                value: site["id"],
                child: Text(site["name"]),
              ))
            ],
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              filled: true,
            ),
            validator: (value) =>
            value == null || value.isEmpty ? "Select a site" : null,
          ),
        ],
      );
    }
  }

  /// Builds the "Assigned To" dropdown or a progress indicator if still loading.
  Widget _buildAssignedToDropdown() {
    if (isLoadingUsers) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Assigned To", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Center(child: CircularProgressIndicator()),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Assigned To", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: assignedTo,
            onChanged: (newValue) {
              setState(() {
                assignedTo = newValue;
              });
            },
            items: users.map<DropdownMenuItem<String>>((user) {
              return DropdownMenuItem<String>(
                value: user["id"],
                child: Text(user["name"]),
              );
            }).toList(),
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              filled: true,
            ),
            validator: (value) =>
            value == null || value.isEmpty ? "Select a user" : null,
          ),
        ],
      );
    }
  }

  /// Builds the Task Type dropdown (with "Other" option).
  Widget _buildTaskTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Task Type", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedTaskType,
          onChanged: (newValue) {
            setState(() {
              selectedTaskType = newValue;
            });
          },
          items: taskTypeOptions.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            );
          }).toList(),
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            filled: true,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Select a task type";
            }
            // If "Other" is selected, ensure the user provided custom text
            if (value == "Other" && otherTaskTypeController.text.trim().isEmpty) {
              return "Please specify the task type";
            }
            return null;
          },
        ),
        // If the user chooses "Other", show a text field for custom task type
        if (selectedTaskType == "Other") ...[
          SizedBox(height: 8),
          TextFormField(
            controller: otherTaskTypeController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: "Specify your custom task type",
            ),
            validator: (value) {
              if (selectedTaskType == "Other" &&
                  (value == null || value.isEmpty)) {
                return "Please specify the task type";
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add New Task"),
        backgroundColor: Colors.blue[800],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Project Section
                  _buildProjectDropdown(),
                  SizedBox(height: 16),

                  // Site Section
                  _buildSiteDropdown(),
                  SizedBox(height: 16),

                  // Phase Section
                  Text("Actual Project Phase",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedPhase,
                    onChanged: (newValue) {
                      setState(() {
                        selectedPhase = newValue;
                      });
                    },
                    items: projectPhases
                        .map((phase) => DropdownMenuItem(
                      value: phase,
                      child: Text(phase),
                    ))
                        .toList(),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? "Select a project phase"
                        : null,
                  ),
                  SizedBox(height: 16),

                  // Priority Section
                  Text("Priority", style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedPriority,
                    onChanged: (newValue) {
                      setState(() {
                        selectedPriority = newValue;
                      });
                    },
                    items: priorityLevels
                        .map((priority) => DropdownMenuItem(
                      value: priority,
                      child: Text(priority),
                    ))
                        .toList(),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? "Select a priority level"
                        : null,
                  ),
                  SizedBox(height: 16),

                  // Task Type Dropdown Section (with "Other")
                  _buildTaskTypeDropdown(),
                  SizedBox(height: 16),

                  // Date Fields Section
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateField(
                          label: "Starting Date",
                          controller: startDateController,
                          onTap: () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                startDate = pickedDate;
                                startDateController.text =
                                    DateFormat('yyyy-MM-dd')
                                        .format(pickedDate);
                              });
                            }
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildDateField(
                          label: "Estimated Ending Date",
                          controller: endDateController,
                          onTap: () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                endDate = pickedDate;
                                endDateController.text =
                                    DateFormat('yyyy-MM-dd')
                                        .format(pickedDate);
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Task Title Field
                  Text("Task Title", style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: taskTitleController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Enter task title",
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? "Enter a task title"
                        : null,
                  ),
                  SizedBox(height: 16),

                  // Description Field
                  Text("Description", style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: taskDescriptionController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Enter task description",
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 16),

                  // Created By Field (read-only)
                  Text("Created By", style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    createdByName ?? "Unknown",
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),

                  // Assigned To Field
                  _buildAssignedToDropdown(),
                  SizedBox(height: 16),

                  // Save Task Button
                  Center(
                    child: ElevatedButton(
                      onPressed: _saveTask,
                      child: Text("Save Task"),
                      style: ElevatedButton.styleFrom(
                        padding:
                        EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                        textStyle: TextStyle(fontSize: 16),
                        backgroundColor: Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
