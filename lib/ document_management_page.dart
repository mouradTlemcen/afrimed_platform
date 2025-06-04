// File: document_management_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'document_details_page.dart';
import 'add_document_page.dart';

class DocumentManagementPage extends StatefulWidget {
  @override
  _DocumentManagementPageState createState() => _DocumentManagementPageState();
}

class _DocumentManagementPageState extends State<DocumentManagementPage> {
  // Filter state variables
  String _filterProject = "All";
  String _filterPhase = "All";
  String _filterSite = "All";
  TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> projects = [];
  List<String> filterSites = ["All"]; // Sites for the selected project

  // Predefined phases
  final List<String> phases = [
    "Tender Preparation and submission",
    "Order preparation",
    "Factory test",
    "Shipment",
    "Site preparation",
    "Installation and training",
    "Commissioning",
    "Warranty period",
    "After warranty period"
  ];

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  // Fetch projects from Firestore.
  Future<void> _fetchProjects() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('projects').get();
    setState(() {
      projects = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'projectNumber': data['projectId']?.toString() ?? "Unknown",
        };
      }).toList();
    });
  }

  // Fetch sites for a given project id.
  Future<void> _fetchSitesForProject(String projectId) async {
    QuerySnapshot lotSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('lots')
        .get();
    List<String> sitesList = ["All"];
    for (var lot in lotSnapshot.docs) {
      QuerySnapshot siteSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('lots')
          .doc(lot.id)
          .collection('sites')
          .get();
      for (var siteDoc in siteSnapshot.docs) {
        var data = siteDoc.data() as Map<String, dynamic>;
        String siteName = data['siteName']?.toString() ?? "Unnamed Site";
        if (!sitesList.contains(siteName)) {
          sitesList.add(siteName);
        }
      }
    }
    setState(() {
      filterSites = sitesList;
      _filterSite = "All";
    });
  }

  /// Build a professional filter section.
  Widget _buildFilters() {
    return Card(
      margin: EdgeInsets.all(12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // First row: Project & Phase
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Project",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: Icon(Icons.folder_open),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _filterProject,
                    items: [
                      DropdownMenuItem<String>(
                          value: "All", child: Text("All Projects")),
                      ...projects.map((proj) {
                        String projectNumber = proj['projectNumber'].toString();
                        return DropdownMenuItem<String>(
                          value: projectNumber,
                          child: Text(projectNumber),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterProject = value!;
                        if (_filterProject != "All") {
                          var proj = projects.firstWhere((p) =>
                          p['projectNumber'].toString() == _filterProject);
                          _fetchSitesForProject(proj['id']);
                        } else {
                          filterSites = ["All"];
                          _filterSite = "All";
                        }
                      });
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Phase",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: Icon(Icons.event_note),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _filterPhase,
                    items: [
                      DropdownMenuItem<String>(
                          value: "All", child: Text("All Phases")),
                      ...phases.map((ph) {
                        return DropdownMenuItem<String>(
                          value: ph,
                          child: Text(ph),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterPhase = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Second row: Site & Search
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Site",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: Icon(Icons.location_on),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _filterSite,
                    items: filterSites.map((siteName) {
                      return DropdownMenuItem<String>(
                        value: siteName,
                        child: Text(siteName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _filterSite = value!;
                      });
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: "Search",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) {
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Returns true if the document data matches all filters.
  bool _filterDocument(Map<String, dynamic> data) {
    if (_filterProject != "All" && data['projectNumber'] != _filterProject)
      return false;
    if (_filterPhase != "All" && data['phase'] != _filterPhase) return false;
    if (_filterSite != "All" && data['site'] != _filterSite) return false;
    if (searchController.text.isNotEmpty &&
        !(data['docTitle']?.toString().toLowerCase().contains(searchController.text.toLowerCase()) ?? false))
      return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Document Management"),
        backgroundColor: Colors.blue[800],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('documents').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                List<DocumentSnapshot> docs = snapshot.data!.docs;
                List<DocumentSnapshot> filteredDocs = docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return _filterDocument(data);
                }).toList();
                if (filteredDocs.isEmpty) {
                  return Center(child: Text("No documents found."));
                }
                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var doc = filteredDocs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String docTitle = data['docTitle'] ?? "Untitled";
                    String projectNumber = data['projectNumber'] ?? "";
                    String phase = data['phase'] ?? "";
                    String site = data['site'] ?? "";
                    int version = data['version'] ?? 0;
                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.description, color: Colors.blue[800]),
                        contentPadding: EdgeInsets.all(12),
                        title: Text(
                          "$docTitle (v$version)",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("Project: $projectNumber\nPhase: $phase\nSite: $site"),
                        trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue[800]),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DocumentDetailsPage(documentId: doc.id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[800],
        child: Icon(Icons.add),
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => AddDocumentPage()));
        },
      ),
    );
  }
}
