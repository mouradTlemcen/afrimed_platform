import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPage extends StatelessWidget {
  final LatLng initialLocation = LatLng(25.276987, 55.296249); // Example: Dubai

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Google Map'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: initialLocation,
          zoom: 12,
        ),
        onMapCreated: (GoogleMapController controller) {
          // Optional: Add functionality here when the map is initialized
        },
      ),
    );
  }
}
