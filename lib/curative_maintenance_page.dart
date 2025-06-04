// File: curative_maintenance_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'curative_maintenance_details_page.dart';
import 'curative_ticket_progress_page.dart';
import 'create_curative_ticket_page.dart';

class CurativeMaintenancePage extends StatefulWidget {
  @override
  _CurativeMaintenancePageState createState() =>
      _CurativeMaintenancePageState();
}

class _CurativeMaintenancePageState extends State<CurativeMaintenancePage> {
  // Basic filters.
  String _filterTicketStatus = "All";
  TextEditingController _searchController = TextEditingController();

  // Dependent filters.
  String _filterProject = "All";
  String _filterSite = "All";
  String _filterPSA = "All";
  String _filterLine = "All";
  String _filterEquipment = "All";

  // Dropdown options. (Replaced "Closed" with "Completed")
  final List<String> _statusOptions =
  ["All", "Open", "In Progress", "Completed"];
  List<String> _projectOptions = ["All"];
  List<String> _siteOptions = ["All"];
  List<String> _psaOptions = ["All"];
  List<String> _lineOptions = ["All"];
  List<String> _equipmentOptions = ["All"];

  @override
  void initState() {
    super.initState();
    _fetchProjects(); // fetch projects from 'projects' collection
  }

  /// Fetch all projects from the 'projects' collection.
  Future<void> _fetchProjects() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('projects').get();
    Set<String> projectSet = {"All"};
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('projectId') && data['projectId'] != null) {
        String proj = data['projectId'].toString();
        if (proj.isNotEmpty) {
          projectSet.add(proj);
        }
      }
    }
    setState(() {
      _projectOptions = projectSet.toList()..sort();
    });
  }

  /// Fetch distinct site names from tickets for the selected project.
  Future<void> _fetchSitesForProject(String project) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('curative_maintenance_tickets')
        .where('projectNumber', isEqualTo: project)
        .get();
    Set<String> siteSet = {"All"};
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['siteName'] != null && data['siteName'].toString().isNotEmpty) {
        siteSet.add(data['siteName'].toString());
      }
    }
    setState(() {
      _siteOptions = siteSet.toList()..sort();
      _filterSite = "All";
      _psaOptions = ["All"];
      _filterPSA = "All";
      _lineOptions = ["All"];
      _filterLine = "All";
      _equipmentOptions = ["All"];
      _filterEquipment = "All";
    });
  }

  /// Fetch distinct PSA references from tickets for the selected project and site.
  Future<void> _fetchPSAForProjectSite(String project, String site) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('curative_maintenance_tickets')
        .where('projectNumber', isEqualTo: project)
        .where('siteName', isEqualTo: site)
        .get();
    Set<String> psaSet = {"All"};
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['psaReference'] != null && data['psaReference'].toString().isNotEmpty) {
        psaSet.add(data['psaReference'].toString());
      }
    }
    setState(() {
      _psaOptions = psaSet.toList()..sort();
      _filterPSA = "All";
      _lineOptions = ["All"];
      _filterLine = "All";
      _equipmentOptions = ["All"];
      _filterEquipment = "All";
    });
  }

  /// Fetch distinct line values from tickets for the selected project, site, and PSA.
  Future<void> _fetchLinesForProjectSitePSA(
      String project, String site, String psa) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('curative_maintenance_tickets')
        .where('projectNumber', isEqualTo: project)
        .where('siteName', isEqualTo: site)
        .where('psaReference', isEqualTo: psa)
        .get();
    Set<String> lineSet = {"All"};
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['line'] != null && data['line'].toString().isNotEmpty) {
        lineSet.add(data['line'].toString());
      }
    }
    setState(() {
      _lineOptions = lineSet.toList()..sort();
      _filterLine = "All";
      _equipmentOptions = ["All"];
      _filterEquipment = "All";
    });
  }

  /// Fetch distinct equipment values (full reference) from tickets for the selected project, site, PSA, and line.
  /// The full reference is composed of equipmentBrand, equipmentModel, and serialNumber.
  Future<void> _fetchEquipmentForProjectSitePSALine(
      String project, String site, String psa, String line) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('curative_maintenance_tickets')
        .where('projectNumber', isEqualTo: project)
        .where('siteName', isEqualTo: site)
        .where('psaReference', isEqualTo: psa)
        .where('line', isEqualTo: line)
        .get();
    Set<String> equipSet = {"All"};
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String brand = data['equipmentBrand']?.toString() ?? "";
      String model = data['equipmentModel']?.toString() ?? "";
      String serial = data['serialNumber']?.toString() ?? "";
      // Build the full reference.
      String combined = "";
      if (brand.isNotEmpty || model.isNotEmpty || serial.isNotEmpty) {
        combined = "$brand $model (Serial: $serial)".trim();
      }
      // Fallback on equipmentName if necessary.
      if (combined.replaceAll(RegExp(r'\s+'), "").isEmpty &&
          data['equipmentName'] != null &&
          data['equipmentName'].toString().isNotEmpty) {
        combined = data['equipmentName'].toString();
      }
      if (combined.isNotEmpty) {
        equipSet.add(combined);
      }
    }
    setState(() {
      _equipmentOptions = equipSet.toList()..sort();
      _filterEquipment = "All";
    });
  }

  /// Prompt the user, then delete the ticket from Firestore if confirmed.
  Future<void> _deleteTicket(String ticketId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Ticket"),
        content: Text("Are you sure you want to delete this ticket?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('curative_maintenance_tickets')
          .doc(ticketId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ticket deleted.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Curative Maintenance Tickets"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Filter Section
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                elevation: 4,
                shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Status and Search
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: "Status",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              value: _filterTicketStatus,
                              items: _statusOptions.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _filterTicketStatus = value!;
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                labelText: "Search Title",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Icon(Icons.search),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              onChanged: (val) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Row 2: Project
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: "Project",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              value: _filterProject,
                              items: _projectOptions.map((proj) {
                                return DropdownMenuItem<String>(
                                  value: proj,
                                  child: Text(proj),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _filterProject = value!;
                                  // Reset dependent filters
                                  _filterSite = "All";
                                  _siteOptions = ["All"];
                                  _filterPSA = "All";
                                  _psaOptions = ["All"];
                                  _filterLine = "All";
                                  _lineOptions = ["All"];
                                  _filterEquipment = "All";
                                  _equipmentOptions = ["All"];
                                });
                                if (_filterProject != "All") {
                                  _fetchSitesForProject(_filterProject);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Row 3: Site + PSA
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: "Site",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              value: _filterSite,
                              items: _siteOptions.map((site) {
                                return DropdownMenuItem<String>(
                                  value: site,
                                  child: Text(site),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _filterSite = value!;
                                  _filterPSA = "All";
                                  _psaOptions = ["All"];
                                  _filterLine = "All";
                                  _lineOptions = ["All"];
                                  _filterEquipment = "All";
                                  _equipmentOptions = ["All"];
                                });
                                if (_filterSite != "All" && _filterProject != "All") {
                                  _fetchPSAForProjectSite(_filterProject, _filterSite);
                                }
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: "PSA Ref",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              value: _filterPSA,
                              items: _psaOptions.map((psa) {
                                return DropdownMenuItem<String>(
                                  value: psa,
                                  child: Text(psa),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _filterPSA = value!;
                                  _filterLine = "All";
                                  _lineOptions = ["All"];
                                  _filterEquipment = "All";
                                  _equipmentOptions = ["All"];
                                });
                                if (_filterPSA != "All" &&
                                    _filterSite != "All" &&
                                    _filterProject != "All") {
                                  _fetchLinesForProjectSitePSA(
                                      _filterProject, _filterSite, _filterPSA);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Row 4: Line + Equipment
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: "Line",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              value: _filterLine,
                              items: _lineOptions.map((line) {
                                return DropdownMenuItem<String>(
                                  value: line,
                                  child: Text(line),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _filterLine = value!;
                                  _filterEquipment = "All";
                                  _equipmentOptions = ["All"];
                                });
                                if (_filterLine != "All" &&
                                    _filterPSA != "All" &&
                                    _filterSite != "All" &&
                                    _filterProject != "All") {
                                  _fetchEquipmentForProjectSitePSALine(
                                    _filterProject,
                                    _filterSite,
                                    _filterPSA,
                                    _filterLine,
                                  );
                                }
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: "Equipment (Full Ref)",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              value: _filterEquipment,
                              items: _equipmentOptions.map((equip) {
                                return DropdownMenuItem<String>(
                                  value: equip,
                                  child: Text(equip),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _filterEquipment = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Note Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                "To add progress to a maintenance ticket, please go to the Tasks Management Page.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.redAccent,
                ),
              ),
            ),
            // List of Tickets
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('curative_maintenance_tickets')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text("No curative maintenance tickets found."),
                    );
                  }

                  // Filter the tickets.
                  List<DocumentSnapshot> tickets = snapshot.data!.docs.where((doc) {
                    var ticketData = doc.data() as Map<String, dynamic>;

                    // Filter by status
                    bool matchesStatus = _filterTicketStatus == "All" ||
                        (ticketData['status']?.toString() == _filterTicketStatus);

                    // Search filter on ticketTitle
                    bool matchesSearch = _searchController.text.isEmpty ||
                        (ticketData['ticketTitle']?.toString().toLowerCase().contains(
                            _searchController.text.toLowerCase()) ??
                            false);

                    // Project
                    String docProject = ticketData['projectNumber']?.toString() ?? "";
                    bool matchesProject =
                        _filterProject == "All" || docProject == _filterProject;

                    // Site
                    String docSite = ticketData['siteName']?.toString() ?? "";
                    bool matchesSite =
                        _filterSite == "All" || docSite == _filterSite;

                    // PSA
                    String docPSA = ticketData['psaReference']?.toString() ?? "";
                    bool matchesPSA =
                        _filterPSA == "All" || docPSA == _filterPSA;

                    // Line
                    String docLine = ticketData['line']?.toString() ?? "";
                    bool matchesLine =
                        _filterLine == "All" || docLine == _filterLine;

                    // Equipment: Combine brand, model and serial to use as full reference.
                    String brand = ticketData['equipmentBrand']?.toString() ?? "";
                    String model = ticketData['equipmentModel']?.toString() ?? "";
                    String serial = ticketData['serialNumber']?.toString() ?? "";
                    String equipmentFullReference = "";
                    if (brand.isNotEmpty ||
                        model.isNotEmpty ||
                        serial.isNotEmpty) {
                      equipmentFullReference =
                          "$brand $model (Serial: $serial)".trim();
                    }
                    // If no full reference is available, fallback.
                    if (equipmentFullReference
                        .replaceAll(RegExp(r'\s+'), "")
                        .isEmpty &&
                        ticketData['equipmentName'] != null) {
                      equipmentFullReference =
                          ticketData['equipmentName'].toString();
                    }
                    bool matchesEquip = _filterEquipment == "All" ||
                        equipmentFullReference == _filterEquipment;

                    return matchesStatus &&
                        matchesSearch &&
                        matchesProject &&
                        matchesSite &&
                        matchesPSA &&
                        matchesLine &&
                        matchesEquip;
                  }).toList();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: tickets.length,
                    itemBuilder: (context, index) {
                      var ticketData = tickets[index].data() as Map<String, dynamic>;
                      String ticketId = tickets[index].id;
                      String ticketTitle = ticketData['ticketTitle'] ?? "No Title";
                      String status = ticketData['status'] ?? "Unknown";

                      // Build the full equipment reference.
                      String brand = ticketData['equipmentBrand']?.toString() ?? "";
                      String model = ticketData['equipmentModel']?.toString() ?? "";
                      String serial = ticketData['serialNumber']?.toString() ?? "";
                      String equipmentFullReference = "";
                      if (brand.isNotEmpty ||
                          model.isNotEmpty ||
                          serial.isNotEmpty) {
                        equipmentFullReference =
                            "$brand $model (Serial: $serial)".trim();
                      }
                      if (equipmentFullReference
                          .replaceAll(RegExp(r'\s+'), "")
                          .isEmpty &&
                          ticketData['equipmentName'] != null) {
                        equipmentFullReference =
                            ticketData['equipmentName'].toString();
                      }

                      String line = ticketData['line'] ?? "";
                      String projectNumber = ticketData['projectNumber'] ?? "";
                      String siteName = ticketData['siteName'] ?? "";
                      Timestamp createdAtTimestamp =
                      ticketData['createdAt'] as Timestamp;
                      String createdAt = DateFormat('yyyy-MM-dd')
                          .format(createdAtTimestamp.toDate());

                      return Card(
                        elevation: 4,
                        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.build, color: Colors.blue[800]),
                          ),
                          title: Text(
                            ticketTitle,
                            style: TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            "Status: $status\n"
                                "Equipment: $equipmentFullReference (Line: $line)\n"
                                "Project: $projectNumber | Site: $siteName\n"
                                "Created: $createdAt",
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Tap the ListTile itself to view details
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CurativeMaintenanceDetailsPage(ticketId: ticketId),
                              ),
                            );
                          },

                          // Only the delete button remains in trailing
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTicket(ticketId),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => CreateCurativeTicketPage()),
          );
        },
        child: const Icon(Icons.add),
        backgroundColor: const Color(0xFF003366),
      ),
    );
  }
}
