import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddLotsAndSitesPage extends StatefulWidget {
  final String projectId;

  AddLotsAndSitesPage({required this.projectId});

  @override
  _AddLotsAndSitesPageState createState() => _AddLotsAndSitesPageState();
}

class _AddLotsAndSitesPageState extends State<AddLotsAndSitesPage> {
  final List<TextEditingController> lotNameControllers = [];
  final List<TextEditingController> siteNumberControllers = [];
  final List<List<TextEditingController>> siteNameControllers = [];
  final List<List<String?>> siteConfigurations = [];

  int numberOfLots = 0;

  // PSA Configuration Options
  final List<String> psaConfigurations = [
    "Containerized",
    "Skid Inside Room",
    "Free Equipment Inside Room"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Lots and PSA Sites'),
        backgroundColor: const Color(0xFF003366),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextFormField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Number of Lots"),
              onChanged: (value) {
                setState(() {
                  int newNumberOfLots = int.tryParse(value) ?? 0;
                  numberOfLots = (newNumberOfLots > 0) ? newNumberOfLots : 0;

                  // Resize lists safely
                  while (lotNameControllers.length < numberOfLots) {
                    lotNameControllers.add(TextEditingController());
                    siteNumberControllers.add(TextEditingController());
                    siteNameControllers.add([]);
                    siteConfigurations.add([]);
                  }
                  while (lotNameControllers.length > numberOfLots) {
                    lotNameControllers.removeLast();
                    siteNumberControllers.removeLast();
                    siteNameControllers.removeLast();
                    siteConfigurations.removeLast();
                  }
                });
              },
            ),
            const SizedBox(height: 20),

            Column(
              children: List.generate(numberOfLots, (lotIndex) {
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: lotNameControllers[lotIndex],
                          decoration: InputDecoration(labelText: "Lot ${lotIndex + 1} Name"),
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Number of PSA Sites"),
                          onChanged: (value) {
                            setState(() {
                              int numberOfSites = int.tryParse(value) ?? 0;
                              while (siteNameControllers[lotIndex].length < numberOfSites) {
                                siteNameControllers[lotIndex].add(TextEditingController());
                                siteConfigurations[lotIndex].add(null);
                              }
                              while (siteNameControllers[lotIndex].length > numberOfSites) {
                                siteNameControllers[lotIndex].removeLast();
                                siteConfigurations[lotIndex].removeLast();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 10),

                        Column(
                          children: List.generate(siteNameControllers[lotIndex].length, (siteIndex) {
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      controller: siteNameControllers[lotIndex][siteIndex],
                                      decoration: InputDecoration(labelText: "Site ${siteIndex + 1} Name"),
                                    ),
                                    const SizedBox(height: 10),

                                    DropdownButtonFormField<String>(
                                      value: siteConfigurations[lotIndex][siteIndex],
                                      onChanged: (newValue) {
                                        setState(() {
                                          siteConfigurations[lotIndex][siteIndex] = newValue;
                                        });
                                      },
                                      items: psaConfigurations.map((config) {
                                        return DropdownMenuItem<String>(
                                          value: config,
                                          child: Text(config),
                                        );
                                      }).toList(),
                                      decoration: const InputDecoration(labelText: 'PSA Site Configuration'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _saveAllLotsAndSites,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Save All', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Save all Lots and Sites in Firestore with `isLinked: false`
  /// ✅ Save all Lots and Sites in Firestore with `isLinked: false` and `Linked to PSA: Not linked`
  Future<void> _saveAllLotsAndSites() async {
    if (numberOfLots == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one lot!')),
      );
      return;
    }

    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (int lotIndex = 0; lotIndex < numberOfLots; lotIndex++) {
      String lotName = lotNameControllers[lotIndex].text.trim();
      if (lotName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lot names cannot be empty!')),
        );
        return;
      }

      DocumentReference lotRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('lots')
          .doc();

      batch.set(lotRef, {
        'lotName': lotName,
        'siteCount': siteNameControllers[lotIndex].length,
        'addedDate': Timestamp.now(),
      });

      for (int siteIndex = 0; siteIndex < siteNameControllers[lotIndex].length; siteIndex++) {
        String siteName = siteNameControllers[lotIndex][siteIndex].text.trim();
        String? psaConfig = siteConfigurations[lotIndex][siteIndex];

        if (siteName.isEmpty || psaConfig == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Site names and configurations cannot be empty!')),
          );
          return;
        }

        DocumentReference siteRef = lotRef.collection('sites').doc();
        batch.set(siteRef, {
          'siteName': siteName,
          'psaConfiguration': psaConfig,
          'isLinked': false,  // ✅ Existing field for PSA linkage tracking
          'Linked to PSA': 'Not linked',  // ✅ New field added as requested
          'addedDate': Timestamp.now(),
        });
      }
    }

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lots and PSA Sites saved successfully!')),
    );

    Navigator.pop(context);
  }

}
