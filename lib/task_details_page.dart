// task_details_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TaskDetailsPage extends StatefulWidget {
  final String taskId;

  TaskDetailsPage({required this.taskId});

  @override
  _TaskDetailsPageState createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  // Controllers for text fields.
  TextEditingController taskTitleController = TextEditingController();
  TextEditingController taskDescriptionController = TextEditingController();

  // Variables for dropdowns and dates.
  String? selectedProjectId,
      selectedSite,
      selectedPhase,
      assignedTo,
      createdBy,
      selectedPriority;
  DateTime? startDate, endDate;

  // Lists for dropdown items.
  List<Map<String, dynamic>> projects = [];
  List<Map<String, dynamic>> sites = [];
  List<Map<String, dynamic>> users = [];
  final List<String> projectPhases = [
    "Tender Preparation",
    "Planning & Design",
    "Procurement",
    "Construction",
    "Commissioning",
    "Operations & Maintenance"
  ];
  final List<String> priorityLevels = ["Low", "Medium", "High", "Urgent"];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTask();
    _fetchProjects();
    _fetchUsers();
  }

  void _loadTask() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.taskId)
        .get();
    if (doc.exists) {
      var data = doc.data() as Map<String, dynamic>;
      setState(() {
        taskTitleController.text = data["title"] ?? "";
        taskDescriptionController.text = data["description"] ?? "";
        selectedProjectId = data["projectId"];
        selectedSite = data["site"];
        selectedPhase = data["phase"];
        assignedTo = data["assignedTo"];
        createdBy = data["createdBy"];
        selectedPriority = data["priority"];
        startDate = (data["startingDate"] as Timestamp?)?.toDate();
        endDate = (data["endingDate"] as Timestamp?)?.toDate();
        _isLoading = false;
      });
      // Fetch sites after setting project.
      _fetchSites();
    }
  }

  void _fetchProjects() async {
    QuerySnapshot querySnapshot =
    await FirebaseFirestore.instance.collection('projects').get();
    setState(() {
      projects = querySnapshot.docs
          .map((doc) => {"id": doc.id, "name": doc["projectId"] ?? "Unknown"})
          .toList();
    });
  }

  void _fetchUsers() async {
    QuerySnapshot querySnapshot =
    await FirebaseFirestore.instance.collection('users').get();
    setState(() {
      users = querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          "id": doc.id,
          "name": "${data["firstName"] ?? ""} ${data["lastName"] ?? ""}".trim()
        };
      }).toList();
    });
  }

  // Fetch sites for the selected project.
  void _fetchSites() async {
    if (selectedProjectId == null) return;
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
  }

  // Date picker helper.
  Future<void> _pickDate({required bool isStart}) async {
    DateTime initialDate = isStart ? (startDate ?? DateTime.now()) : (endDate ?? DateTime.now());
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  void _saveTask() async {
    if (taskTitleController.text.isEmpty ||
        selectedPhase == null ||
        createdBy == null ||
        selectedPriority == null ||
        startDate == null ||
        endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all required fields")));
      return;
    }
    await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
      "projectId": selectedProjectId ?? "General",
      "site": selectedSite ?? "General",
      "phase": selectedPhase,
      "title": taskTitleController.text.trim(),
      "description": taskDescriptionController.text.trim(),
      "assignedTo": assignedTo ?? "Unassigned",
      "createdBy": createdBy,
      "priority": selectedPriority,
      "startingDate": Timestamp.fromDate(startDate!),
      "endingDate": Timestamp.fromDate(endDate!),
      "status": "Pending",
      "updatedAt": Timestamp.now(),
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Task updated successfully")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Task"),
        backgroundColor: Colors.blue[800],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text("Task Title", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: taskTitleController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter task title",
              ),
            ),
            const SizedBox(height: 16),
            const Text("Description", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: taskDescriptionController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter task description",
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // Project Dropdown
            const Text("Project", style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: selectedProjectId,
              onChanged: (newValue) {
                setState(() {
                  selectedProjectId = newValue;
                  _fetchSites();
                });
              },
              items: projects
                  .map((project) => DropdownMenuItem<String>(
                value: project["id"],
                child: Text(project["name"]),
              ))
                  .toList(),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            // Site Dropdown
            const Text("Site", style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: selectedSite,
              onChanged: (newValue) {
                setState(() {
                  selectedSite = newValue;
                });
              },
              items: [
                const DropdownMenuItem(value: "General", child: Text("General")),
                ...sites.map((site) => DropdownMenuItem<String>(
                  value: site["id"],
                  child: Text(site["name"]),
                ))
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            // Project Phase Dropdown
            const Text("Project Phase", style: TextStyle(fontWeight: FontWeight.bold)),
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
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            // Priority Dropdown
            const Text("Priority", style: TextStyle(fontWeight: FontWeight.bold)),
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
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            // Starting Date Field
            const Text("Starting Date", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              readOnly: true,
              onTap: () => _pickDate(isStart: true),
              controller: TextEditingController(
                text: startDate != null ? DateFormat('yyyy-MM-dd').format(startDate!) : "",
              ),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Select starting date",
              ),
            ),
            const SizedBox(height: 16),
            // Ending Date Field
            const Text("Ending Date", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              readOnly: true,
              onTap: () => _pickDate(isStart: false),
              controller: TextEditingController(
                text: endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : "",
              ),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Select ending date",
              ),
            ),
            const SizedBox(height: 16),
            // (Optional) You can add additional fields such as Assigned To and Created By here,
            // possibly using an Autocomplete widget similar to your AddTaskPage.
            ElevatedButton(
              onPressed: _saveTask,
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}
