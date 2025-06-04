// File: lib/users_map_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class UsersMapPage extends StatefulWidget {
  const UsersMapPage({Key? key}) : super(key: key);

  @override
  _UsersMapPageState createState() => _UsersMapPageState();
}

class _UsersMapPageState extends State<UsersMapPage> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  /// Fetch all users with a valid gpsLocation and add them as markers.
  Future<void> _fetchUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    final markers = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('gpsLocation')) {
        final gps = data['gpsLocation'];
        if (gps is Map &&
            gps.containsKey('latitude') &&
            gps.containsKey('longitude')) {
          final lat = gps['latitude'] is double
              ? gps['latitude']
              : double.tryParse(gps['latitude'].toString());
          final lng = gps['longitude'] is double
              ? gps['longitude']
              : double.tryParse(gps['longitude'].toString());
          if (lat != null && lng != null) {
            return Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}",
                snippet: data['email'] ?? '',
              ),
            );
          }
        }
      }
      return null;
    }).whereType<Marker>().toSet();

    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Users Map"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(0, 0),
          zoom: 2,
        ),
        markers: _markers,
        onMapCreated: (controller) {
          _mapController = controller;
        },
      ),
    );
  }
}