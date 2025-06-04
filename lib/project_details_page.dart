import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectDetailsPage extends StatefulWidget {
  final String firestoreId;
  final String projectId;

  ProjectDetailsPage({required this.firestoreId, required this.projectId});

  @override
  _ProjectDetailsPageState createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  /// Fetch the first name of a manager from the 'users' collection.
  Future<String> _getManagerName(String managerId) async {
    if (managerId.isEmpty) return "Not Assigned";
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(managerId)
        .get();
    if (userDoc.exists) {
      var data = userDoc.data() as Map<String, dynamic>;
      return data['firstName'] ?? "Not Assigned";
    }
    return "Not Assigned";
  }

  /// Returns a widget that displays the manager's first name with a label.
  Widget _buildManagerName(String label, String managerId) {
    return FutureBuilder<String>(
      future: _getManagerName(managerId),
      builder: (context, snapshot) {
        String displayName = "Not Assigned";
        if (snapshot.connectionState == ConnectionState.waiting) {
          displayName = "Loading...";
        } else if (snapshot.hasError) {
          displayName = "Error";
        } else if (snapshot.hasData) {
          displayName = snapshot.data!;
        }
        return Text(
          "$label: $displayName",
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        );
      },
    );
  }

  /// Fetch partner's name from the 'partners' collection.
  Future<String> _getPartnerName(String clientId) async {
    if (clientId.isEmpty || clientId == 'Unknown Client') {
      return "Unknown Client";
    }
    DocumentSnapshot partnerDoc = await FirebaseFirestore.instance
        .collection('partners')
        .doc(clientId)
        .get();
    if (partnerDoc.exists) {
      var data = partnerDoc.data() as Map<String, dynamic>;
      return data['name'] ?? "No Name Field";
    }
    return "Partner Not Found";
  }

  /// Builds a widget that displays "Client: Partner Name".
  Widget _buildPartnerName(String clientId) {
    return FutureBuilder<String>(
      future: _getPartnerName(clientId),
      builder: (context, snapshot) {
        String displayName = "Loading...";
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            displayName = "Error fetching client";
          } else if (snapshot.hasData) {
            displayName = snapshot.data!;
          }
        }
        return Text(
          "Client: $displayName",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Project Details"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.firestoreId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Project not found"));
          }

          var projectData = snapshot.data!.data() as Map<String, dynamic>;
          String clientId = projectData['clientId'] ?? 'Unknown Client';
          String operationsManager = projectData['operationsManager'] ?? '';
          String psaProgramManager = projectData['psaProgramManager'] ?? '';
          String technicalManager = projectData['technicalManager'] ?? '';
          String bidManager = projectData['bidManager'] ?? '';
          String clientRelationshipManager =
              projectData['clientRelationshipManager'] ?? '';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Text(
                  "Project ID: ${widget.projectId}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildPartnerName(clientId),
                const SizedBox(height: 20),
                const Text(
                  "Afrimed Managers",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                _buildManagerName("Operations Manager", operationsManager),
                _buildManagerName("PSA Program Manager", psaProgramManager),
                _buildManagerName("Technical Manager", technicalManager),
                _buildManagerName("BID Manager", bidManager),
                _buildManagerName(
                  "Client Relationship Manager",
                  clientRelationshipManager,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Lots & PSA Sites",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('projects')
                      .doc(widget.firestoreId)
                      .collection('lots')
                      .get(),
                  builder: (context, lotSnapshot) {
                    if (!lotSnapshot.hasData ||
                        lotSnapshot.data!.docs.isEmpty) {
                      return const Text("No lots available.");
                    }
                    var lots = lotSnapshot.data!.docs;
                    return Column(
                      children: lots.map((lot) {
                        var lotData = lot.data() as Map<String, dynamic>;
                        String lotId = lot.id;
                        String lotName = lotData['lotName'] ?? 'Unknown Lot';
                        return Card(
                          // A Card just to visually separate each lot
                          child: Column(
                            children: [
                              // ExpansionTile with initiallyExpanded set to true
                              ExpansionTile(
                                initiallyExpanded: true,
                                title: Text("Lot: $lotName"),
                                children: [
                                  FutureBuilder<QuerySnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('projects')
                                        .doc(widget.firestoreId)
                                        .collection('lots')
                                        .doc(lotId)
                                        .collection('sites')
                                        .get(),
                                    builder: (context, siteSnapshot) {
                                      if (!siteSnapshot.hasData ||
                                          siteSnapshot.data!.docs.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text("No sites available."),
                                        );
                                      }
                                      var sites = siteSnapshot.data!.docs;
                                      return Column(
                                        children: sites.map((site) {
                                          var siteData = site.data()
                                          as Map<String, dynamic>;
                                          String siteName =
                                              siteData['siteName'] ??
                                                  'Unknown Site';
                                          String psaConfig =
                                              siteData['psaConfiguration'] ??
                                                  'Unknown Config';
                                          String linkedToPSA =
                                              siteData['Linked to PSA'] ??
                                                  'Not Linked';
                                          return ListTile(
                                            title: Text("Site: $siteName"),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                              children: [
                                                Text("PSA Type: $psaConfig"),
                                                Text(
                                                    "Linked to PSA: $linkedToPSA"),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
