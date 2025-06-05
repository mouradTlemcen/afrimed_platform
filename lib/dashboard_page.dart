import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Existing pages
import 'personal_management_page.dart';
import 'partner_management_page.dart';
import 'project_management_page.dart';
import 'psa_management_page.dart';
import 'task_management_page.dart';
import 'task_statistics_page.dart';
import 'maintenance_management_page.dart';
import 'document_management_page.dart';
import 'communication_module.dart';
import 'displacement_management.dart';
import 'migrate_data_screen.dart';
import 'equipment_management_page.dart';

// NEW OR CHANGED
import 'activity_logs_page.dart';  // <-- Import your new ActivityLogsPage
import 'mgps_management_page.dart'; // <--- ensure this file exists.

class DashboardPage extends StatefulWidget {
  final String role;

  const DashboardPage({Key? key, required this.role}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool hasAssignedTasks = false;

  final String _hardCodedVersion = "v1.1.3";
  String? _versionYouSee;
  final TextEditingController _editController = TextEditingController();
  bool _hasShownOutdatedDialog = false;

  @override
  void initState() {
    super.initState();
    _checkAssignedTasks();
    _fetchVersionYouSee();
  }

  Future<void> _checkAssignedTasks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('assignedTo', isEqualTo: uid)
          .where('status', whereNotIn: ['Done In Time', 'Done After Deadline'])
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        setState(() {
          hasAssignedTasks = true;
        });
      }
    } catch (e) {
      debugPrint('Error checking tasks: $e');
    }
  }

  Future<void> _fetchVersionYouSee() async {
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('config')
          .doc('appVersion')
          .get();

      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null && data["versionYouSee"] != null) {
          setState(() {
            _versionYouSee = data["versionYouSee"] as String;
          });
        } else {
          debugPrint("versionYouSee field not found in appVersion doc.");
        }
      } else {
        debugPrint("appVersion doc not found in 'config' collection.");
      }
    } catch (e) {
      debugPrint("Error fetching versionYouSee: $e");
    }
  }

  Future<void> _updateVersionYouSee(String newVal) async {
    try {
      await FirebaseFirestore.instance
          .collection('config')
          .doc('appVersion')
          .set({"versionYouSee": newVal}, SetOptions(merge: true));

      setState(() {
        _versionYouSee = newVal;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("versionYouSee updated to $newVal")),
      );
    } catch (e) {
      debugPrint("Error updating versionYouSee: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating version: $e")),
      );
    }
  }

  void _showOutdatedDialog() {
    if (_hasShownOutdatedDialog) return;
    _hasShownOutdatedDialog = true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Outdated Version"),
        content: Text("You don't have the last version. Please refresh the page."),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionRow() {
    final user = FirebaseAuth.instance.currentUser;
    bool isMourad = false;
    if (user != null && user.email != null) {
      isMourad = user.email!.toLowerCase() == "mourad.benosman@servymed.com";
    }

    final String dbVersion = _versionYouSee ?? "(loading...)";

    bool isOutdated = false;
    if (_versionYouSee != null && _versionYouSee != _hardCodedVersion) {
      isOutdated = true;
      if (!_hasShownOutdatedDialog) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showOutdatedDialog();
        });
      }
    }

    return Row(
      children: [
        Text(
          "Code: $_hardCodedVersion",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        SizedBox(width: 16),
        Text(
          "Seen: $dbVersion",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isOutdated ? Colors.red : Colors.black,
          ),
        ),
        if (isOutdated)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text("(outdated)",
                style: TextStyle(fontSize: 12, color: Colors.red)),
          ),
        if (isMourad) ...[
          SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              _editController.text = _versionYouSee ?? "";
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text("Edit versionYouSee"),
                  content: TextField(
                    controller: _editController,
                    decoration: InputDecoration(labelText: "New version"),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        String newVer = _editController.text.trim();
                        if (newVer.isNotEmpty) {
                          _updateVersionYouSee(newVer);
                          Navigator.pop(ctx);
                        }
                      },
                      child: Text("Save"),
                    ),
                  ],
                ),
              );
            },
            child: Text("Edit", style: TextStyle(fontSize: 12)),
          ),
        ]
      ],
    );
  }

  void _showAccountDetails(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    String email = user?.email ?? "No Email";
    String displayName = user?.displayName ?? "No Name";

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          color: const Color(0xFF002244),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue.shade900,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : "?",
                    style: const TextStyle(fontSize: 36, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade300),
                ),
                const SizedBox(height: 8),
                Text(
                  "Role: ${widget.role}",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade300),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: const Text("Close"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Image.asset(
            'assets/images/afrimed_logo.png',
            height: 50,
          ),
          const Spacer(),
          _buildVersionRow(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    bool isMourad = false;
    if (user != null && user.email != null) {
      isMourad = user.email!.toLowerCase() == "mourad.benosman@servymed.com";
    }

    final List<Map<String, dynamic>> adminModules = [
      {
        "name": "1-Personal Management",
        "route": "/personal",
        "icon": Icons.people
      },
      {
        "name": "2-Partner Management",
        "route": "/partner",
        "icon": Icons.business
      },
      {
        "name": "3-Equipment Management",
        "route": "/equipmentManagement",
        "icon": Icons.build
      },
      {
        "name": "4-Project Management",
        "route": "/project",
        "icon": Icons.folder
      },
      {
        "name": "5-PSA Management",
        "route": "/psa",
        "icon": Icons.local_hospital
      },
      {
        "name": "6-Task Management",
        "route": "/tasks",
        "icon": Icons.task
      },
      {
        "name": "7-Task Statistics (under deve)",
        "route": "/statistics",
        "icon": Icons.bar_chart
      },
      {
        "name": "8-Maintenance Management",
        "route": "/maintenance",
        "icon": Icons.settings_suggest
      },
      {
        "name": "9-Document Management",
        "route": "/documentation",
        "icon": Icons.description
      },
      {
        "name": "10-Communication (under deve)",
        "route": "/communication",
        "icon": Icons.chat
      },
      {
        "name": "11-Displacement Management (under deve)",
        "route": "/displacement",
        "icon": Icons.location_on
      },
      {
        "name": "12-Data Migration (under deve)",
        "route": "/migrateData",
        "icon": Icons.cloud_upload_outlined
      },
      {
        "name": "MGPS Management",
        "route": "/mgps",
        "icon": Icons.local_gas_station_rounded,
      },
    ];

    if (isMourad) {
      adminModules.add({
        "name": "Activity Logs",
        "route": "/activityLogs",
        "icon": Icons.history,
      });
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF002244),
        actions: [
          IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFF002244), size: 14),
            ),
            onPressed: () => _showAccountDetails(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF002244), Color(0xFF004466)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.transparent),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AFRIMED APP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Admin Dashboard',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white54),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.2,
                ),
                itemCount: adminModules.length,
                itemBuilder: (context, index) {
                  final module = adminModules[index];

                  // -------- Split the name for number & displayName --------
                  final moduleName = module["name"] as String;
                  final parts = moduleName.split('-');
                  final moduleNumber = parts.length > 1 ? parts[0].trim() : "";
                  final displayName = parts.length > 1 ? parts.sublist(1).join('-').trim() : moduleName;

                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 160), // REQUIRED!
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.indigo.shade800, Colors.blue.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            final route = module['route'] as String;
                            if (route == "/personal") {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => PersonalManagementPage()));
                            } else if (route == "/partner") {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => PartnerManagementPage()));
                            } else if (route == "/equipmentManagement") {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => EquipmentManagementPage()));
                            } else if (route == "/project") {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ProjectManagementPage()));
                            } else if (route == "/psa") {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => PSAManagementPage()));
                            } else if (route == "/tasks") {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => TaskManagementPage()));
                            } else if (route == "/statistics") {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => TaskStatisticsPage()));
                            } else if (route == "/maintenance") {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => MaintenanceManagementPage()));
                            } else if (route == "/documentation") {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => DocumentManagementPage()));
                            } else if (route == "/communication") {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => CommunicationModule()));
                            } else if (route == "/displacement") {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => DisplacementManagementPage()));
                            } else if (route == "/migrateData") {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => MigrateDataScreen()));
                            } else if (route == "/mgps") {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => MGPSManagementPage()));
                            } else if (route == "/activityLogs") {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ActivityLogsPage()));
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    Icon(
                                      module["icon"] as IconData,
                                      size: 38,
                                      color: Colors.white,
                                    ),
                                    if (module["route"] == "/tasks" && hasAssignedTasks)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // ==== Here is the number above name! ====
                                Column(
                                  children: [
                                    if (moduleNumber.isNotEmpty)
                                      Text(
                                        moduleNumber,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white.withOpacity(0.85),
                                        ),
                                      ),
                                    SizedBox(height: 2),
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
