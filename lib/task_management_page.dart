import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'task_progress_page.dart';
import 'add_task_page.dart';
import 'activity_logger.dart'; // Import your centralized activity logger

class TaskManagementPage extends StatefulWidget {
  final bool isTechnician;
  TaskManagementPage({this.isTechnician = false});

  @override
  _TaskManagementPageState createState() => _TaskManagementPageState();
}

class _TaskManagementPageState extends State<TaskManagementPage> {
  final CollectionReference _tasksCollection =
  FirebaseFirestore.instance.collection('tasks');

  // FILTER STATE VARIABLES
  String filterProject = "All";
  String filterAssignedTo = "All";
  String filterSite = "All";
  bool filterOverdue = false;
  bool filterEmergency = false;

  // New taskType filter state variable.
  String filterTaskType = "All";
  List<String> taskTypeOptions = ["All"];

  // NEW: Phase filter state variable.
  String filterPhase = "All";
  List<String> phaseOptions = ["All"];

  // Variables for an open progress period filter.
  DateTime? progressFrom;
  DateTime? progressTo;
  TextEditingController searchController = TextEditingController();

  // New status filter variables.
  List<String> filterStatuses = [];
  final List<String> statusOptions = [
    "Pending",
    "In Progress",
    "Done In Time",
    "Done After Deadline",
    "Deadline Passed and Not Done"
  ];

  // Lists for filter dropdown items.
  List<Map<String, dynamic>> allProjects = [];
  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> filterSites = [];

  @override
  void initState() {
    super.initState();
    _fetchProjectsForFilters();
    _fetchUsersForFilters();
    _fetchTaskTypes();
    _fetchPhases(); // <-- Fetch distinct phases
  }

  /// Fetch projects for filter dropdown.
  void _fetchProjectsForFilters() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('projects').get();
    setState(() {
      allProjects = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          "id": doc.id,
          "name": data["Afrimed_projectId"] ?? "Unknown",
        };
      }).toList();
    });
  }

  /// Fetch users for filter dropdown.
  void _fetchUsersForFilters() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('users').get();
    setState(() {
      allUsers = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          "id": doc.id,
          "name": "${data["firstName"] ?? ""} ${data["lastName"] ?? ""}".trim()
        };
      }).toList();
    });
  }

  /// Fetch distinct taskType values from tasks
  void _fetchTaskTypes() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('tasks').get();
    Set<String> types = {};
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data.containsKey("taskType") && data["taskType"] != null) {
        types.add(data["taskType"].toString());
      }
    }
    setState(() {
      taskTypeOptions = ["All"] + types.toList();
    });
  }

  /// NEW: Fetch distinct phase values from tasks
  void _fetchPhases() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('tasks').get();
    Set<String> phases = {};
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data.containsKey("phase") && data["phase"] != null) {
        phases.add(data["phase"].toString());
      }
    }
    setState(() {
      phaseOptions = ["All"] + phases.toList();
    });
  }

  /// Fetch sites for a specific project
  void _fetchSitesForFilter(String projectId) async {
    QuerySnapshot lotSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('lots')
        .get();

    List<Map<String, dynamic>> sites = [];
    for (var lot in lotSnapshot.docs) {
      QuerySnapshot siteSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('lots')
          .doc(lot.id)
          .collection('sites')
          .get();
      for (var site in siteSnapshot.docs) {
        var data = site.data() as Map<String, dynamic>;
        sites.add({
          "id": site.id,
          "name": data["siteName"] ?? "Unnamed Site",
        });
      }
    }
    setState(() {
      filterSites = sites;
      // Reset site filter to "All" whenever the project filter changes.
      filterSite = "All";
    });
  }

  Future<void> _navigateToAddTask() async {
    // Log event: navigating to add task.
    await logActivity(
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      action: 'navigate_to_add_task',
      details: 'Navigating to AddTaskPage',
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddTaskPage()),
    );
  }

  void _deleteTask(String taskId) async {
    // Log event: delete task.
    await logActivity(
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      action: 'delete_task',
      details: 'Deleting task with id: $taskId',
    );
    await _tasksCollection.doc(taskId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Task deleted successfully!")),
    );
  }

  // Removed _openEditTask and the TaskDetailsPage import

  void _openTaskProgress(String taskId) async {
    // Log event: open task progress.
    await logActivity(
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      action: 'open_task_progress',
      details: 'Opening task progress for task with id: $taskId',
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaskProgressPage(taskId: taskId)),
    );
  }

  /// Returns the display name of a project based on its document id.
  String getProjectDisplayName(String projectId) {
    if (!allProjects.any((p) => p["id"] == projectId)) {
      return projectId;
    }
    final match = allProjects.firstWhere(
          (p) => p["id"] == projectId,
      orElse: () => <String, String>{"id": projectId, "name": projectId},
    );
    return match["name"] ?? projectId;
  }

  /// Returns the display name of a user based on their document id.
  String getUserDisplayName(String userId) {
    if (!allUsers.any((u) => u["id"] == userId)) {
      return userId;
    }
    final match = allUsers.firstWhere(
          (u) => u["id"] == userId,
      orElse: () => <String, String>{"id": userId, "name": userId},
    );
    return match["name"] ?? userId;
  }

  /// Helper method to build a dropdown with a label.
  Widget _buildDropdown({
    required String label,
    required String currentValue,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            value: currentValue,
            underline: SizedBox(),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// Builds a nicely designed filter section inside an ExpansionTile.
  Widget _buildFilterSection() {
    return Card(
      margin: EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        title: Text(
          "Filter Tasks",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Icon(Icons.filter_list),
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                // Row for Project, Assigned To, and Site dropdowns.
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        label: "Project",
                        currentValue: filterProject,
                        items: [
                          DropdownMenuItem(
                            value: "All",
                            child: Text("All Projects"),
                          ),
                          ...allProjects.map((p) => DropdownMenuItem(
                            value: p["id"], // store doc ID
                            child: Text(p["name"]),
                          ))
                        ],
                        onChanged: (value) {
                          setState(() {
                            filterProject = value!;
                            if (filterProject != "All") {
                              _fetchSitesForFilter(filterProject);
                            } else {
                              filterSites = [];
                              filterSite = "All";
                            }
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        label: "Assigned To",
                        currentValue: filterAssignedTo,
                        items: [
                          DropdownMenuItem(
                            value: "All",
                            child: Text("All Assigned"),
                          ),
                          ...allUsers.map((u) => DropdownMenuItem(
                            value: u["id"],
                            child: Text(u["name"]),
                          ))
                        ],
                        onChanged: (value) {
                          setState(() {
                            filterAssignedTo = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        label: "Site",
                        currentValue: filterSite,
                        items: (filterProject == "All")
                            ? [
                          DropdownMenuItem(
                              value: "All", child: Text("All Sites"))
                        ]
                            : [
                          DropdownMenuItem(
                              value: "All", child: Text("All Sites")),
                          ...filterSites.map((s) => DropdownMenuItem(
                            value: s["id"],
                            child: Text(s["name"]),
                          ))
                        ],
                        onChanged: (value) {
                          setState(() {
                            filterSite = value!;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          labelText: "Search Title",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Row for Task Type filter
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        label: "Task Type",
                        currentValue: filterTaskType,
                        items: taskTypeOptions.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            filterTaskType = value!;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    // NEW: Phase filter
                    Expanded(
                      child: _buildDropdown(
                        label: "Phase",
                        currentValue: filterPhase,
                        items: phaseOptions.map((phase) {
                          return DropdownMenuItem(
                            value: phase,
                            child: Text(phase),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            filterPhase = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Row for checkboxes Overdue & Emergency
                Row(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: filterOverdue,
                          onChanged: (val) {
                            setState(() {
                              filterOverdue = val ?? false;
                            });
                          },
                        ),
                        Text("Overdue"),
                      ],
                    ),
                    SizedBox(width: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: filterEmergency,
                          onChanged: (val) {
                            setState(() {
                              filterEmergency = val ?? false;
                            });
                          },
                        ),
                        Text("Emergency"),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Status Filter
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Status Filter:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: statusOptions.map((status) {
                    bool selected = filterStatuses.contains(status);
                    return FilterChip(
                      label: Text(status),
                      selected: selected,
                      onSelected: (bool value) {
                        setState(() {
                          if (value)
                            filterStatuses.add(status);
                          else
                            filterStatuses.remove(status);
                        });
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: 12),
                // Last Progress Period Filter
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Last Progress Period:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("From"),
                              SizedBox(height: 4),
                              InkWell(
                                onTap: () async {
                                  DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: progressFrom ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      progressFrom = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    progressFrom == null
                                        ? "Any"
                                        : DateFormat('yyyy-MM-dd')
                                        .format(progressFrom!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("To"),
                              SizedBox(height: 4),
                              InkWell(
                                onTap: () async {
                                  DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: progressTo ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      progressTo = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    progressTo == null
                                        ? "Any"
                                        : DateFormat('yyyy-MM-dd')
                                        .format(progressTo!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              progressFrom = null;
                              progressTo = null;
                            });
                          },
                          child: Text("Reset Period"),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Filtering logic: Applies all filters to the list of tasks.
  List<DocumentSnapshot> _applyFilters(List<DocumentSnapshot> tasks) {
    return tasks.where((task) {
      Map<String, dynamic> data = task.data() as Map<String, dynamic>;

      // projectId check
      String projectId = data["projectId"] ?? "General";
      if (filterProject != "All" && projectId != filterProject) return false;

      // assignedTo check
      if (filterAssignedTo != "All" && data["assignedTo"] != filterAssignedTo) {
        return false;
      }

      // site check
      if (filterSite != "All" && data["site"] != filterSite) return false;

      // Title search
      if (searchController.text.isNotEmpty) {
        final titleString = data["title"]?.toString().toLowerCase() ?? "";
        if (!titleString.contains(searchController.text.toLowerCase())) {
          return false;
        }
      }

      // Overdue check
      if (filterOverdue) {
        if (data["endingDate"] == null) return false;
        Timestamp ts = data["endingDate"];
        if (ts.toDate().isAfter(DateTime.now())) return false;
      }

      // Emergency check
      if (filterEmergency && data["priority"] != "Urgent") return false;

      // Status check
      if (filterStatuses.isNotEmpty && !filterStatuses.contains(data["status"])) {
        return false;
      }

      // TaskType check
      if (filterTaskType != "All") {
        if (!data.containsKey("taskType") ||
            data["taskType"] != filterTaskType) {
          return false;
        }
      }

      // Phase check
      if (filterPhase != "All") {
        if (!data.containsKey("phase") || data["phase"] != filterPhase) {
          return false;
        }
      }

      // Last progress date check
      if (progressFrom != null || progressTo != null) {
        if (data["lastProgressAt"] == null) return false;
        Timestamp progressTs = data["lastProgressAt"];
        DateTime lastProgress = progressTs.toDate();
        if (progressFrom != null && lastProgress.isBefore(progressFrom!)) {
          return false;
        }
        if (progressTo != null) {
          DateTime endOfDay = DateTime(
            progressTo!.year,
            progressTo!.month,
            progressTo!.day,
            23,
            59,
            59,
            999,
          );
          if (lastProgress.isAfter(endOfDay)) return false;
        }
      }

      // If technician mode, only include tasks assigned to OR created by current user
      if (widget.isTechnician) {
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          bool assignedMatch = (data["assignedTo"] == currentUser.uid);
          bool createdMatch = (data["createdBy"] == currentUser.uid);
          if (!assignedMatch && !createdMatch) {
            return false;
          }
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Task Management"),
        backgroundColor: Colors.blue[800],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _tasksCollection.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          var tasks = snapshot.data!.docs;
          List<DocumentSnapshot> filteredTasks = _applyFilters(tasks);

          return Column(
            children: [
              _buildFilterSection(),
              Expanded(
                child: filteredTasks.isEmpty
                    ? Center(
                  child: Text("No tasks match these filters."),
                )
                    : ListView.builder(
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    var task = filteredTasks[index];
                    var taskData = task.data() as Map<String, dynamic>;

                    String title = taskData["title"] ?? "Untitled Task";
                    String status = taskData["status"] ?? "Pending";
                    String priority = taskData["priority"] ?? "Low";
                    String phase = taskData["phase"] ?? "";

                    // Safe access for projectId
                    String projectId = taskData["projectId"] ?? "General";
                    String projectDisplay =
                    getProjectDisplayName(projectId);

                    // Created At
                    String createdAt = "";
                    if (taskData["createdAt"] != null) {
                      createdAt = (taskData["createdAt"] as Timestamp)
                          .toDate()
                          .toString()
                          .split(" ")[0];
                    }

                    // Assigned To (Display Name)
                    String assignedToDisplay = "Unassigned";
                    if (taskData["assignedTo"] != null) {
                      assignedToDisplay =
                          getUserDisplayName(taskData["assignedTo"]);
                    }

                    return Card(
                      margin: EdgeInsets.all(12),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  label: Text(priority),
                                  backgroundColor: Colors.orangeAccent,
                                ),
                                Chip(
                                  label: Text(phase),
                                  backgroundColor: Colors.lightBlueAccent,
                                ),
                                Chip(
                                  label: Text(status),
                                  backgroundColor: Colors.greenAccent,
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Project: $projectDisplay",
                              style: TextStyle(fontSize: 14),
                            ),
                            Text(
                              "Assigned To: $assignedToDisplay",
                              style: TextStyle(fontSize: 14),
                            ),
                            Text(
                              "Created on: $createdAt",
                              style: TextStyle(fontSize: 14),
                            ),
                            ButtonBar(
                              alignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  child: Text("Progress"),
                                  onPressed: () async {
                                    // Log event: open task progress.
                                    await logActivity(
                                      userId: FirebaseAuth
                                          .instance.currentUser?.uid ??
                                          'unknown',
                                      action: 'open_task_progress',
                                      details:
                                      'Opening progress for task id: ${task.id}',
                                    );
                                    _openTaskProgress(task.id);
                                  },
                                ),
                                // Removed the Edit button
                                TextButton(
                                  child: Text("Delete"),
                                  onPressed: () async {
                                    // Log event: delete task.
                                    await logActivity(
                                      userId: FirebaseAuth
                                          .instance.currentUser?.uid ??
                                          'unknown',
                                      action: 'delete_task',
                                      details:
                                      'Deleting task with id: ${task.id}',
                                    );
                                    _deleteTask(task.id);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddTask,
        backgroundColor: Colors.blue[800],
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
