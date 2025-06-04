import 'package:flutter/material.dart';

class MGPSEquipmentPage extends StatelessWidget {
  final String mgpsReference;
  final String mgpsId;
  final String afrimedProjectId;
  final String projectDocId;

  const MGPSEquipmentPage({
    Key? key,
    required this.mgpsReference,
    required this.mgpsId,
    required this.afrimedProjectId,
    required this.projectDocId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MGPS Equipment: $mgpsReference'),
      ),
      body: Center(
        child: Text('MGPSEquipmentPage for ID $mgpsId'),
      ),
    );
  }
}
