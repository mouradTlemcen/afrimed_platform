import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For current user ID
import 'document_details_page.dart';
import 'add_document_page.dart';
import 'activity_logger.dart'; // Your centralized activity logger
import 'global_obligatory_docs_page.dart'; // Page to manage global obligatory docs

class DocumentManagementPage extends StatefulWidget {
  @override
  _DocumentManagementPageState createState() => _DocumentManagementPageState();
}

class _DocumentManagementPageState extends State<DocumentManagementPage> {
  // Control whether to show the filters
  bool _showFilters = true;

  // Filter state variables
  String _filterProject = "All";
  String _filterPhase = "All";
  String _filterSite = "All";
  String _filterCreatedBy = "All";

  TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> projects = [];
  List<String> filterSites = ["All", "Global"];

  final List<String> phases = [
    "All",
    "Global",
    "Tender Preparation and submission",
    "Order preparation",
    "Factory test",
    "Shipment",
    "Site preparation",
    "Installation and training",
    "Commissioning",
    "Warranty period",
    "After warranty period",
  ];

  List<String> createdByOptions = ["All"];

  @override
  void initState() {
    super.initState();
    _fetchProjects();
    _fetchAllCreators();
  }

  Future<void> _fetchProjects() async {
    var snapshot = await FirebaseFirestore.instance.collection('projects').get();
    setState(() {
      projects = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'projectNumber': data['Afrimed_projectId']?.toString() ?? "Unknown",
        };
      }).toList();
    });
  }

  Future<void> _fetchAllCreators() async {
    var docsSnapshot = await FirebaseFirestore.instance.collection('documents').get();
    Set<String> distinctCreators = {};
    for (var docSnap in docsSnapshot.docs) {
      final data = docSnap.data() as Map<String, dynamic>;
      final val = data['createdBy']?.toString().trim();
      if (val != null && val.isNotEmpty) distinctCreators.add(val);
    }
    setState(() {
      createdByOptions = ["All", ...distinctCreators];
    });
  }

  Future<void> _fetchSitesForProject(String projectId) async {
    var lotSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('lots')
        .get();
    List<String> sitesList = ["All", "Global"];
    for (var lot in lotSnapshot.docs) {
      var siteSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('lots')
          .doc(lot.id)
          .collection('sites')
          .get();
      for (var siteDoc in siteSnapshot.docs) {
        var data = siteDoc.data() as Map<String, dynamic>;
        String name = data['siteName']?.toString() ?? "Unnamed Site";
        if (!sitesList.contains(name)) sitesList.add(name);
      }
    }
    setState(() {
      filterSites = sitesList;
      _filterSite = "All";
    });
  }

  Widget _buildFilters() {
    return Card(
      margin: EdgeInsets.all(12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Row 1: Project and Phase
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: "Project",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.folder_open),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _filterProject,
                    items: [
                      DropdownMenuItem(value: "All", child: Text("All Projects")),
                      DropdownMenuItem(value: "Global", child: Text("Global")),
                      ...projects.map((proj) =>
                          DropdownMenuItem(value: proj['projectNumber'].toString(), child: Text(proj['projectNumber'].toString()))),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterProject = value!;
                        if (value != "All" && value != "Global") {
                          var proj = projects.firstWhere((p) => p['projectNumber'].toString() == value);
                          _fetchSitesForProject(proj['id']);
                        } else {
                          filterSites = ["All", "Global"];
                          _filterSite = "All";
                        }
                      });
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: "Phase",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.event_note),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _filterPhase,
                    items: phases.map((ph) => DropdownMenuItem(value: ph, child: Text(ph))).toList(),
                    onChanged: (value) => setState(() => _filterPhase = value!),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Row 2: Site + Created By
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: "Site",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.location_on),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _filterSite,
                    items: filterSites.map((site) => DropdownMenuItem(value: site, child: Text(site))).toList(),
                    onChanged: (value) => setState(() => _filterSite = value!),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: "Created By",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.person),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _filterCreatedBy,
                    items: createdByOptions.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                    onChanged: (value) => setState(() => _filterCreatedBy = value!),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Row 3: Search field
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: "Search",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  bool _filterDocument(Map<String, dynamic> data) {
    final docProject   = (data['projectNumber'] ?? '').toString().toLowerCase();
    final docPhase     = (data['phase'] ?? '').toString().toLowerCase();
    final docSite      = (data['site'] ?? '').toString().toLowerCase();
    final docTitle     = (data['docTitle'] ?? '').toString().toLowerCase();
    final docCreatedBy = (data['createdBy'] ?? '').toString().toLowerCase();

    final fProj = _filterProject.toLowerCase();
    final fPhase = _filterPhase.toLowerCase();
    final fSite = _filterSite.toLowerCase();
    final fBy = _filterCreatedBy.toLowerCase();

    if (fProj != 'all' && docProject != fProj) return false;
    if (fPhase != 'all' && docPhase != fPhase) return false;
    if (fSite != 'all' && docSite != fSite) return false;
    if (fBy   != 'all' && docCreatedBy != fBy) return false;

    if (searchController.text.isNotEmpty && !docTitle.contains(searchController.text.toLowerCase().trim())) {
      return false;
    }
    return true;
  }

  Future<List<String>> _fetchMissingObligatoryDocs() async {
    if (_filterProject == "All" || _filterPhase == "All" || _filterSite == "All") {
      return [];
    }

    var globalSnap = await FirebaseFirestore.instance
        .collection('global_obligatory_documents')
        .where('phase', isEqualTo: _filterPhase)
        .get();

    var requiredTitles = globalSnap.docs
        .map((d) => (d.data() as Map<String, dynamic>)['docTitle'].toString())
        .toList();

    var uploadedSnap = await FirebaseFirestore.instance
        .collection('documents')
        .where('projectNumber', isEqualTo: _filterProject)
        .where('phase', isEqualTo: _filterPhase)
        .where('site', isEqualTo: _filterSite)
        .where('standardStatus', isEqualTo: "Already Uploaded")
        .get();

    var uploadedTitles = uploadedSnap.docs
        .map((d) => (d.data() as Map<String, dynamic>)['docTitle'].toString())
        .toList();

    return requiredTitles.where((t) => !uploadedTitles.contains(t)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Document Management"),
        backgroundColor: Colors.blue[800],
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list : Icons.filter_list_off),
            tooltip: _showFilters ? 'Hide Filters' : 'Show Filters',
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showFilters) _buildFilters(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            child: ElevatedButton.icon(
              icon: Icon(Icons.settings),
              label: Text("Manage the Obligatory Documents"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                minimumSize: Size(double.infinity, 48),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GlobalObligatoryDocsPage()),
              ),
            ),
          ),

          FutureBuilder<List<String>>(
            future: _fetchMissingObligatoryDocs(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Container();
              var missing = snapshot.data!;
              if (_filterProject == "All" || _filterPhase == "All" || _filterSite == "All") {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Select a specific Project, Phase, and Site to see missing obligatory documents.",
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                );
              }
              if (missing.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "All obligatory documents have been uploaded!",
                    style: TextStyle(color: Colors.green),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Missing Obligatory Documents:",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ...missing.map((t) => Text("- $t")).toList(),
                  ],
                ),
              );
            },
          ),

          // <<< ONLY change is here: we now only listen for Already Uploaded docs >>>
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('documents')
                  .where('standardStatus', isEqualTo: 'Already Uploaded')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                var rawDocs = snapshot.data!.docs;
                var filteredDocs = rawDocs.where((doc) {
                  return _filterDocument(doc.data()! as Map<String, dynamic>);
                }).toList();

                if (filteredDocs.isEmpty) return Center(child: Text("No documents found."));
                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, i) {
                    var doc = filteredDocs[i];
                    var data = doc.data()! as Map<String, dynamic>;
                    var docId = doc.id;
                    var title = data['docTitle'] ?? "Untitled";
                    var proj = data['projectNumber'] ?? "";
                    var phase = data['phase'] ?? "";
                    var site = data['site'] ?? "";
                    var version = data['version'] ?? 0;

                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Icon(Icons.description, color: Colors.blue[800]),
                        contentPadding: EdgeInsets.all(12),
                        title: Text(
                          "$title (v$version)",
                          style: TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          "Project: $proj\nPhase: $phase\nSite: $site",
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          await logActivity(
                            userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                            action: 'view_document',
                            details: 'Viewing document with id: $docId',
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DocumentDetailsPage(documentId: docId)),
                          );
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_forward_ios, color: Colors.blue[800]),
                              onPressed: () async {
                                await logActivity(
                                  userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                                  action: 'view_document',
                                  details: 'Viewing document with id: $docId',
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => DocumentDetailsPage(documentId: docId)),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete Document',
                              onPressed: () async {
                                await logActivity(
                                  userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                                  action: 'delete_document',
                                  details: 'Deleting document with id: $docId',
                                );
                                _confirmDelete(docId);
                              },
                            ),
                          ],
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[800],
        child: Icon(Icons.add),
        onPressed: () async {
          await logActivity(
            userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
            action: 'navigate_to_add_document',
            details: 'Navigating to AddDocumentPage',
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddDocumentPage()),
          );
        },
      ),
    );
  }

  /// Confirmation dialog for document deletion.
  void _confirmDelete(String documentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Document'),
        content: Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('documents').doc(documentId).delete();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Document deleted successfully!')));
    }
  }
}
