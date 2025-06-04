import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'add_displacement_page.dart'; // reuse your existing add displacement page code

// This page manages all displacement records across users.
class DisplacementManagementPage extends StatefulWidget {
  const DisplacementManagementPage({Key? key}) : super(key: key);

  @override
  _DisplacementManagementPageState createState() =>
      _DisplacementManagementPageState();
}

class _DisplacementManagementPageState
    extends State<DisplacementManagementPage> {
  String _searchQuery = "";
  String? _selectedUserFilter; // Filter by user ID
  List<Map<String, dynamic>> _users = []; // List of users for filter dropdown

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  // Fetch all users (with basic info) to populate the filter dropdown.
  Future<void> _fetchUsers() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('users').get();
    setState(() {
      _users = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'uid': doc.id,
          'name': "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}"
              .trim()
        };
      }).toList();
    });
  }

  // Launch Google Maps with the provided latitude and longitude.
  void _launchGoogleMaps(double latitude, double longitude) async {
    final url = 'https://www.google.com/maps?q=$latitude,$longitude';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Could not launch $url")));
    }
  }

  // Delete a displacement record after confirmation.
  Future<void> _deleteDisplacement(DocumentSnapshot doc) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Displacement"),
        content: Text("Are you sure you want to delete this displacement?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                "Delete",
                style: TextStyle(color: Colors.red),
              )),
        ],
      ),
    );
    if (confirm == true) {
      await doc.reference.delete();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Displacement deleted")));
    }
  }

  // Build a card widget for each displacement record.
  Widget _buildDisplacementCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    final country = data['country'] ?? 'Unknown Country';
    final city = data['city'] ?? 'Unknown City';
    final location = "Country: $country\nCity: $city";
    final startDate = data['startDate'] ?? 'Unknown Start Date';
    final endDate = data['endDate'] ?? 'Not Defined';
    final details = data['details'] ?? 'No Details';
    final gpsLocation = data['gpsLocation'] as Map<String, dynamic>?;
    // Retrieve the user ID from the parent document reference.
    final userId = doc.reference.parent.parent?.id ?? "Unknown User";

    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location and GPS button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    location,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF003366)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (gpsLocation != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      double lat = gpsLocation['latitude'];
                      double lng = gpsLocation['longitude'];
                      _launchGoogleMaps(lat, lng);
                    },
                    icon: Icon(Icons.map, size: 16),
                    label: Text(
                      "View GPS",
                      style: TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0073E6),
                      padding:
                      EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                else
                  Text(
                    "No GPS",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            SizedBox(height: 8),
            Text("From: $startDate",
                style: TextStyle(fontSize: 14, color: Colors.black87)),
            Text("To: $endDate",
                style: TextStyle(fontSize: 14, color: Colors.black87)),
            SizedBox(height: 8),
            Text("Details:",
                style:
                TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text(details,
                style: TextStyle(fontSize: 14, color: Colors.black54)),
            SizedBox(height: 8),
            Text("User ID: $userId",
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey)),
            // Action buttons for Edit and Delete
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    // Navigate to an edit displacement page.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditDisplacementPage(
                          displacementDoc: doc,
                          userId: userId,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _deleteDisplacement(doc);
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Show a dialog to select a user before adding a new displacement.
  Future<void> _showAddDisplacementDialog() async {
    String? selectedUser;
    await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Select User"),
            content: DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: InputDecoration(
                labelText: "User",
                border: OutlineInputBorder(),
              ),
              value: selectedUser,
              items: _users.map((user) {
                return DropdownMenuItem<String>(
                  value: user['uid'],
                  child: Text(user['name'].toString()),
                );
              }).toList(),
              onChanged: (value) {
                selectedUser = value;
              },
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text("Cancel")),
              ElevatedButton(
                  onPressed: () {
                    if (selectedUser != null) {
                      Navigator.pop(context);
                      // Navigate to your add displacement page with the chosen user.
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddDisplacementPage(userId: selectedUser!),
                        ),
                      );
                    }
                  },
                  child: Text("Proceed")),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Displacement Management"),
        backgroundColor: Color(0xFF003366),
      ),
      body: Column(
        children: [
          // Search bar and user filter dropdown
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Search field
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search by country, city, details...",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                SizedBox(width: 16),
                // User filter dropdown
                DropdownButton<String>(
                  hint: Text("All Users"),
                  value: _selectedUserFilter,
                  items: _users.map((user) {
                    return DropdownMenuItem<String>(
                      value: user['uid'],
                      child: Text(user['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedUserFilter = value;
                    });
                  },
                ),
              ],
            ),
          ),
          // Displacement list via collection group query
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('displacements')
                  .orderBy('addedDate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("No displacements found."));
                }
                // Filter results based on search query and selected user.
                final displacements = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  final country =
                      data['country']?.toString().toLowerCase() ?? "";
                  final city =
                      data['city']?.toString().toLowerCase() ?? "";
                  final details =
                      data['details']?.toString().toLowerCase() ?? "";
                  bool matchesSearch = country.contains(_searchQuery) ||
                      city.contains(_searchQuery) ||
                      details.contains(_searchQuery);
                  // Get user id from parent.
                  String userId = doc.reference.parent.parent?.id ?? "";
                  bool matchesUser = _selectedUserFilter == null
                      ? true
                      : (userId == _selectedUserFilter);
                  return matchesSearch && matchesUser;
                }).toList();
                return ListView.builder(
                  itemCount: displacements.length,
                  itemBuilder: (context, index) {
                    return _buildDisplacementCard(displacements[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF003366),
        child: Icon(Icons.add),
        onPressed: _showAddDisplacementDialog,
      ),
    );
  }
}

// --- Placeholder for Edit Displacement Page ---
// You can create a full edit page by adapting your AddDisplacementPage
class EditDisplacementPage extends StatefulWidget {
  final DocumentSnapshot displacementDoc;
  final String userId;

  const EditDisplacementPage(
      {Key? key, required this.displacementDoc, required this.userId})
      : super(key: key);

  @override
  _EditDisplacementPageState createState() => _EditDisplacementPageState();
}

class _EditDisplacementPageState extends State<EditDisplacementPage> {
  // You would prefill fields using widget.displacementDoc
  // and then update the document on form submission.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Displacement"),
        backgroundColor: Color(0xFF003366),
      ),
      body: Center(
        child: Text("Edit Displacement Form goes here."),
      ),
    );
  }
}
