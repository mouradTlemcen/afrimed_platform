// File: lib/personnel_map_page.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

class PersonnelMapPage extends StatefulWidget {
  @override
  _PersonnelMapPageState createState() => _PersonnelMapPageState();
}

class _PersonnelMapPageState extends State<PersonnelMapPage> {
  GoogleMapController? _mapController;
  // Cache for generated marker icons (key: first name).
  final Map<String, BitmapDescriptor> _markerIcons = {};

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Generate a custom pin marker icon with a red pin and the user's first name.
  /// The text is drawn with a font size of 12.
  Future<BitmapDescriptor> _getMarkerIcon(String firstName) async {
    final double markerWidth = 80;
    final double markerHeight = 100;
    final double circleRadius = 30;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final Paint paint = Paint()..color = Colors.red;
    // Draw red circle (the head of the pin)
    canvas.drawCircle(Offset(markerWidth / 2, circleRadius), circleRadius, paint);

    // Draw triangle pointer below the circle.
    Path trianglePath = Path();
    trianglePath.moveTo(markerWidth / 2 - 10, circleRadius + 10);
    trianglePath.lineTo(markerWidth / 2 + 10, circleRadius + 10);
    trianglePath.lineTo(markerWidth / 2, markerHeight);
    trianglePath.close();
    canvas.drawPath(trianglePath, paint);

    // Draw first name in white on the circle.
    final TextSpan textSpan = TextSpan(
      text: firstName,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    final TextPainter textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final double textX = (markerWidth - textPainter.width) / 2;
    final double textY = circleRadius - textPainter.height / 2;
    textPainter.paint(canvas, Offset(textX, textY));

    final ui.Image image = await recorder.endRecording().toImage(markerWidth.toInt(), markerHeight.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List bytes = byteData!.buffer.asUint8List();

    final bitmapDescriptor = BitmapDescriptor.fromBytes(bytes);
    _markerIcons[firstName] = bitmapDescriptor;
    return bitmapDescriptor;
  }

  /// Build markers from Firestore snapshot.
  Future<Set<Marker>> _buildMarkers(QuerySnapshot snapshot) async {
    Set<Marker> markers = {};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('gpsLocation')) {
        final gps = data['gpsLocation'] as Map<String, dynamic>;
        final latitude = gps['latitude'];
        final longitude = gps['longitude'];
        if (latitude != null && longitude != null) {
          final String firstName = data['firstName'] ?? "Unknown";
          final BitmapDescriptor icon = await _getMarkerIcon(firstName);
          markers.add(Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(latitude, longitude),
            icon: icon,
            infoWindow: InfoWindow(title: firstName),
          ));
        }
      }
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Personnel Locations"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("No data available."));
          }
          return FutureBuilder<Set<Marker>>(
            future: _buildMarkers(snapshot.data!),
            builder: (context, markerSnapshot) {
              if (markerSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final markers = markerSnapshot.data ?? {};
              LatLng initialPosition = markers.isNotEmpty ? markers.first.position : const LatLng(0, 0);
              return GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: initialPosition,
                  zoom: 10,
                ),
                markers: markers,
                gestureRecognizers: {
                  Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
                  Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
                },
              );
            },
          );
        },
      ),
    );
  }
}
