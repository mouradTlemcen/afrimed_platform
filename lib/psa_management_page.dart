import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For current user ID
import 'activity_logger.dart'; // Your activity logger
import 'add_psa_page.dart';
import 'edit_psa_page.dart'; // Defines EditPSAPage
import 'psa_equipment_page.dart'; // Defines PSAEquipmentPage
import 'psa_details_page.dart';   // Defines PSADetailsPage

class PSAManagementPage extends StatefulWidget {
  const PSAManagementPage({Key? key}) : super(key: key);

  @override
  _PSAManagementPageState createState() => _PSAManagementPageState();
}

class _PSAManagementPageState extends State<PSAManagementPage> {
  // Filter state variables.
  String _filterProject = "All";
  String _filterSite = "All";
  String _filterInstallationStatus = "All"; // "All", "Installed", "Not Installed"
  String _filterComment = "All"; // "All", "Has Comment"
  bool _isFilterExpanded = false;

  // Mapping: project document ID -> Afrimed_projectId
  Map<String, String> _projectMapping = {};
  // Mapping: siteId -> siteName
  Map<String, String> _siteMapping = {};

  @override
  void initState() {
    super.initState();
    _loadProjectMapping();
  }

  /// Loads project mapping from the 'projects' collection.
  /// Here we map Firestore document ID to Afrimed_projectId (the business value).
  Future<void> _loadProjectMapping() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('projects').get();
      final Map<String, String> mapping = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Trim the value in case extra spaces are present.
        mapping[doc.id] = (data['Afrimed_projectId']?.toString() ?? "Unknown").trim();
      }
      setState(() {
        _projectMapping = mapping;
      });
      debugPrint(">> _loadProjectMapping: Loaded ${_projectMapping.length} projects.");
    } catch (e) {
      debugPrint(">> _loadProjectMapping ERROR: $e");
    }
  }

  /// Loads site mapping from PSA documents.
  /// Each PSA is assumed to store a 'projectDocId', 'lotId', and 'siteId' field.
  Future<Map<String, String>> _loadSiteMapping(List<QueryDocumentSnapshot> docs) async {
    final mapping = <String, String>{};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      // Trim the IDs to remove any extra spaces.
      final projectDocId = (data['projectDocId']?.toString() ?? "").trim();
      final lotId = (data['lotId']?.toString() ?? "").trim();
      final siteId = (data['siteId']?.toString() ?? "").trim();
      if (projectDocId.isNotEmpty && lotId.isNotEmpty && siteId.isNotEmpty) {
        final siteName = await _getSiteName(projectDocId, lotId, siteId);
        mapping[siteId] = siteName;
      }
    }
    return mapping;
  }

  /// Helper: Get the site name from Firestore using the actual project doc ID.
  Future<String> _getSiteName(String projectDocId, String lotId, String siteId) async {
    // Ensure the IDs are trimmed.
    projectDocId = projectDocId.trim();
    lotId = lotId.trim();
    siteId = siteId.trim();

    // Check if any are empty to prevent building an invalid path.
    if (projectDocId.isEmpty || lotId.isEmpty || siteId.isEmpty) {
      debugPrint(">> _getSiteName: Missing ID(s): projectDocId='$projectDocId', lotId='$lotId', siteId='$siteId'");
      return "Incomplete site reference";
    }

    debugPrint(">> _getSiteName called with projectDocId=$projectDocId, lotId=$lotId, siteId=$siteId");
    try {
      final siteRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(projectDocId)
          .collection('lots')
          .doc(lotId)
          .collection('sites')
          .doc(siteId);
      debugPrint(">> Checking site doc path: ${siteRef.path}");
      final siteDoc = await siteRef.get();
      if (!siteDoc.exists) {
        debugPrint(">> _getSiteName: Site doc does NOT exist at path: ${siteRef.path}");
        return "No site doc found";
      }
      final data = siteDoc.data() as Map<String, dynamic>;
      final siteName = (data['siteName']?.toString() ?? "Unnamed Site").trim();
      debugPrint(">> _getSiteName: Found siteName='$siteName' at path: ${siteRef.path}");
      return siteName;
    } catch (e, stack) {
      debugPrint(">> _getSiteName ERROR: $e\n$stack");
      return "Error: $e";
    }
  }

  Future<void> _deletePSA(String psaId) async {
    try {
      await FirebaseFirestore.instance.collection('psa_units').doc(psaId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PSA deleted successfully!")),
      );
    } catch (e) {
      debugPrint("Error deleting PSA: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting PSA: $e"), backgroundColor: Colors.red),
      );
    }
  }

  /// Filters the PSA documents based on selected filters.
  List<QueryDocumentSnapshot> _applyFilters(
      List<QueryDocumentSnapshot> docs, Map<String, String> siteMapping) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      // Filter by project using Afrimed_projectId.
      if (_filterProject != "All") {
        final projField = (data['Afrimed_projectId']?.toString() ?? "").trim();
        if (projField != _filterProject) return false;
      }
      // Filter by site.
      if (_filterSite != "All") {
        final sid = (data['siteId']?.toString() ?? "").trim();
        final siteName = siteMapping[sid] ?? "";
        if (siteName != _filterSite) return false;
      }
      // Filter by installation status.
      final installed = data.containsKey('installationDate') && data['installationDate'] != null;
      if (_filterInstallationStatus == "Installed" && !installed) return false;
      if (_filterInstallationStatus == "Not Installed" && installed) return false;
      // Filter by comment.
      if (_filterComment == "Has Comment") {
        if (!data.containsKey('lastCommentTimestamp') || data['lastCommentTimestamp'] == null) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _buildFilterSection(List<String> projectFilterList, List<String> siteFilterList) {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        title: const Text("Filter PSA Units", style: TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.filter_list),
        initiallyExpanded: _isFilterExpanded,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: "Project",
                          border: OutlineInputBorder(),
                        ),
                        value: _filterProject,
                        items: projectFilterList.map((proj) {
                          return DropdownMenuItem(
                            value: proj,
                            child: Text(proj),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() { _filterProject = val!; }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: "Site",
                          border: OutlineInputBorder(),
                        ),
                        value: _filterSite,
                        items: siteFilterList.map((site) {
                          return DropdownMenuItem(
                            value: site,
                            child: Text(site),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() { _filterSite = val!; }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: "Installation Status",
                          border: OutlineInputBorder(),
                        ),
                        value: _filterInstallationStatus,
                        items: ["All", "Installed", "Not Installed"].map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() { _filterInstallationStatus = val!; }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: "Comment",
                          border: OutlineInputBorder(),
                        ),
                        value: _filterComment,
                        items: ["All", "Has Comment"].map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() { _filterComment = val!; }),
                      ),
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

  // ============================== BUILD UI ==============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PSA Management"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('psa_units').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return const Center(child: Text("No PSA units found."));

          // Load site mapping if not yet loaded.
          if (_siteMapping.isEmpty) {
            _loadSiteMapping(docs).then((map) {
              if (mounted) setState(() { _siteMapping = map; });
            });
          }

          // Build distinct lists for filtering.
          final projectFilterSet = <String>{};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final projField = (data['Afrimed_projectId']?.toString() ?? "").trim();
            projectFilterSet.add(projField);
          }
          projectFilterSet.add("All");
          final sortedProjects = projectFilterSet.toList()..sort();

          // Build site filter list.
          final siteFilterSet = <String>{};
          if (_filterProject == "All") {
            if (_siteMapping.isNotEmpty) {
              siteFilterSet.addAll(_siteMapping.values.toSet()..removeWhere((s) => s.isEmpty));
            }
          } else {
            final filteredSiteNames = <String>{};
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final projField = (data['Afrimed_projectId']?.toString() ?? "").trim();
              if (projField == _filterProject) {
                final sid = (data['siteId']?.toString() ?? "").trim();
                if (_siteMapping.containsKey(sid)) {
                  filteredSiteNames.add(_siteMapping[sid]!);
                }
              }
            }
            siteFilterSet.addAll(filteredSiteNames);
          }
          siteFilterSet.add("All");
          final sortedSites = siteFilterSet.toList()..sort();

          // Apply filters.
          final filteredDocs = _applyFilters(docs, _siteMapping);
          filteredDocs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>?;
            final bData = b.data() as Map<String, dynamic>?;
            final aTs = aData?['lastCommentTimestamp'] as Timestamp?;
            final bTs = bData?['lastCommentTimestamp'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.toDate().compareTo(aTs.toDate());
          });

          return Column(
            children: [
              _buildFilterSection(sortedProjects, sortedSites),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final docId = doc.id;
                    // Use Afrimed_projectId from the PSA doc.
                    final rawProjectField = (data['Afrimed_projectId']?.toString() ?? "Unknown").trim();
                    // Retrieve projectDocId, lotId, siteId and trim them.
                    final projectDocId = (data['projectDocId']?.toString() ?? "").trim();
                    final lotId = (data['lotId']?.toString() ?? "").trim();
                    final siteId = (data['siteId']?.toString() ?? "").trim();
                    final psaReference = data['reference']?.toString() ?? "Unknown PSA";

                    String installationDate = "Not Installed";
                    if (data.containsKey('installationDate') && data['installationDate'] != null) {
                      final ts = data['installationDate'] as Timestamp;
                      installationDate = DateFormat('yyyy-MM-dd').format(ts.toDate());
                    }

                    final status = data['status']?.toString() ??
                        (data.containsKey('installationDate') && data['installationDate'] != null
                            ? "Functional"
                            : "Under Maintenance");

                    return GestureDetector(
                      onTap: () async {
                        await logActivity(
                          userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                          action: 'view_psa',
                          details: 'Viewing PSA with id: $docId',
                        );
                        // Optionally navigate to PSA details.
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "PSA: $psaReference",
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Project: $rawProjectField",
                                style: const TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                              FutureBuilder<String>(
                                future: _getSiteName(projectDocId, lotId, siteId),
                                builder: (context, snap) {
                                  if (snap.connectionState == ConnectionState.waiting) {
                                    return const Text(
                                      "Site: Loading site...",
                                      style: TextStyle(fontSize: 16, color: Colors.black87),
                                    );
                                  } else if (snap.hasError) {
                                    return Text(
                                      "Site: Error: ${snap.error}",
                                      style: const TextStyle(fontSize: 16, color: Colors.red),
                                    );
                                  } else if (!snap.hasData) {
                                    return const Text(
                                      "Site: Unknown",
                                      style: TextStyle(fontSize: 16, color: Colors.black87),
                                    );
                                  } else {
                                    final siteLabel = snap.data!;
                                    return Text(
                                      "Site: $siteLabel",
                                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Installation Date: $installationDate",
                                style: const TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                              Text(
                                "Status: $status",
                                style: const TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Link Equipment button.
                                  IconButton(
                                    icon: const Icon(Icons.link, color: Colors.blueGrey),
                                    tooltip: "Link Equipment",
                                    onPressed: () async {
                                      await logActivity(
                                        userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                                        action: 'link_psa_equipment',
                                        details: 'Linking PSA equipment with id: $docId',
                                      );
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PSAEquipmentPage(
                                            psaReference: psaReference,
                                            psaId: docId,
                                            afrimedProjectId: '',
                                            projectDocId: '',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.timeline, color: Colors.black87),
                                    tooltip: "Progress Support",
                                    onPressed: () async {
                                      await logActivity(
                                        userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                                        action: 'edit_psa',
                                        details: 'Editing PSA with id: $docId',
                                      );
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditPSAPage(
                                            psaId: docId,
                                            psaData: data,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                    tooltip: "Delete PSA",
                                    onPressed: () async {
                                      await logActivity(
                                        userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                                        action: 'delete_psa',
                                        details: 'Deleting PSA with id: $docId',
                                      );
                                      _deletePSA(docId);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
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
        onPressed: () async {
          await logActivity(
            userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
            action: 'add_psa',
            details: 'Navigating to AddPSAPage',
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddPSAPage()),
          );
        },
        backgroundColor: const Color(0xFF003366),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
