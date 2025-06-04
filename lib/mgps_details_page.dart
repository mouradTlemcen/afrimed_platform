import 'package:flutter/material.dart';

class MGPSDetailsPage extends StatelessWidget {
  final String mgpsId;

  const MGPSDetailsPage({Key? key, required this.mgpsId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MGPS Details: $mgpsId'),
      ),
      body: const Center(child: Text('MGPSDetailsPage Placeholder')),
    );
  }
}
