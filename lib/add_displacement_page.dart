// File: lib/add_displacement_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'displacement_history_page.dart';

class AddDisplacementPage extends StatefulWidget {
  final String userId;

  const AddDisplacementPage({Key? key, required this.userId}) : super(key: key);

  @override
  _AddDisplacementPageState createState() => _AddDisplacementPageState();
}

class _AddDisplacementPageState extends State<AddDisplacementPage> {
  DateTime? startDate;
  DateTime? endDate;
  bool isEndDateDefined = false;

  // Controller for mission details.
  final TextEditingController detailsController = TextEditingController();

  // Project & Site selection.
  String? selectedProject;
  String? selectedSite;
  List<Map<String, dynamic>> projects = [];
  List<Map<String, dynamic>> sites = [];

  // Location dropdowns.
  String? selectedContinent;
  String? selectedCountry;
  String? selectedCity;
  Map<String, List<String>> continentCountries = {}; // e.g., {'Africa': ['Egypt', 'Algeria', ...]}
  List<String> cities = [];

  // GPS coordinates obtained via geocoding.
  LatLng? selectedGpsLocation;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
    _fetchContinentCountries();
  }

  /// Fetch projects from Firestore.
  Future<void> _fetchProjects() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('projects').get();
    setState(() {
      projects = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'docId': doc.id,
          'projectNumber': data['projectId'] ?? "Unknown",
        };
      }).toList();
    });
  }

  /// Fetch all country data from Rest Countries API and group them by continent.
  Future<void> _fetchContinentCountries() async {
    final url = Uri.parse('https://restcountries.com/v3.1/all');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);
      Map<String, List<String>> tempMap = {};
      for (var country in jsonData) {
        if (country.containsKey('continents') && country.containsKey('name')) {
          List<dynamic> continents = country['continents'];
          String countryName = country['name']['common'];
          for (var cont in continents) {
            String continent = cont.toString();
            if (tempMap.containsKey(continent)) {
              tempMap[continent]!.add(countryName);
            } else {
              tempMap[continent] = [countryName];
            }
          }
        }
      }
      setState(() {
        continentCountries = tempMap;
      });
    } else {
      print("Error fetching countries: ${response.statusCode}");
    }
  }

  /// Fetch cities for the selected country using the CountriesNow API.
  Future<void> _fetchCities(String country) async {
    final url = Uri.parse('https://countriesnow.space/api/v0.1/countries/cities');
    final response = await http.post(url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"country": country}));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['error'] == false && data['data'] is List) {
        setState(() {
          cities = List<String>.from(data['data']);
          selectedCity = null;
          selectedGpsLocation = null;
        });
      } else {
        setState(() {
          cities = [];
        });
      }
    } else {
      print("Error fetching cities: ${response.statusCode}");
    }
  }

  /// When a city is selected, use the Nominatim API to obtain GPS coordinates.
  Future<void> _getCoordinatesForCity(String city, String country) async {
    if (city.isEmpty || country.isEmpty) {
      print("City or country is empty.");
      return;
    }
    try {
      String query = "$city, $country";
      // Use Nominatim API to get coordinates. Note: include a proper User-Agent header.
      final url = Uri.parse("https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1");
      final response = await http.get(url, headers: {"User-Agent": "FlutterApp/1.0"});
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          final firstResult = results[0];
          double latitude = double.tryParse(firstResult["lat"]) ?? 0.0;
          double longitude = double.tryParse(firstResult["lon"]) ?? 0.0;
          if (latitude != 0.0 && longitude != 0.0) {
            setState(() {
              selectedGpsLocation = LatLng(latitude, longitude);
            });
          } else {
            print("No valid coordinates for: $query");
          }
        } else {
          print("No results from Nominatim for: $query");
        }
      } else {
        print("Nominatim error: ${response.statusCode}");
      }
    } catch (e, stack) {
      print("Geocoding error (Nominatim): $e");
      print(stack);
    }
  }

  /// Fetch sites for the selected project.
  Future<void> _fetchSites(String projectDocId) async {
    List<Map<String, dynamic>> allSites = [];
    QuerySnapshot lotSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectDocId)
        .collection('lots')
        .get();
    for (var lot in lotSnapshot.docs) {
      QuerySnapshot siteSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectDocId)
          .collection('lots')
          .doc(lot.id)
          .collection('sites')
          .get();
      for (var site in siteSnapshot.docs) {
        var data = site.data() as Map<String, dynamic>;
        allSites.add({
          'siteId': site.id,
          'siteName': data['siteName'] ?? "Unnamed Site",
        });
      }
    }
    setState(() {
      sites = allSites;
      if (sites.isEmpty) {
        selectedSite = "Global";
      } else {
        selectedSite = null;
      }
    });
  }

  // --- Date Picker Functions ---
  void _pickStartDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        startDate = picked;
      });
    }
  }

  void _pickEndDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        endDate = picked;
      });
    }
  }

  /// Submit the displacement.
  Future<void> addDisplacement() async {
    debugPrint("Selected Project: $selectedProject");
    debugPrint("Selected Site: $selectedSite");
    debugPrint("Selected Continent: $selectedContinent");
    debugPrint("Selected Country: $selectedCountry");
    debugPrint("Selected City: $selectedCity");
    debugPrint("Start Date: $startDate");
    debugPrint("GPS: $selectedGpsLocation");

    if (selectedProject == null ||
        selectedSite == null ||
        selectedContinent == null ||
        selectedCountry == null ||
        selectedCity == null ||
        startDate == null ||
        selectedGpsLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields!')),
      );
      return;
    }
    setState(() {
      isLoading = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('displacements')
          .add({
        'project': selectedProject,
        'site': selectedSite,
        'continent': selectedContinent,
        'country': selectedCountry,
        'city': selectedCity,
        'location': "$selectedCountry, $selectedCity",
        'gpsLocation': {
          'latitude': selectedGpsLocation!.latitude,
          'longitude': selectedGpsLocation!.longitude,
        },
        'startDate': startDate!.toIso8601String().split('T')[0],
        'endDate': isEndDateDefined
            ? (endDate != null ? endDate!.toIso8601String().split('T')[0] : 'Not Defined')
            : 'Not Defined',
        'details': detailsController.text.trim(),
        'addedDate': Timestamp.now(),
      });

      // Also update the user document with the new gpsLocation.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'gpsLocation': {
          'latitude': selectedGpsLocation!.latitude,
          'longitude': selectedGpsLocation!.longitude,
        },
      });

      // Show a success dialog and then redirect to Displacement History.
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Success'),
          content: const Text('Displacement added successfully!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DisplacementHistoryPage(userId: widget.userId),
                  ),
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add displacement: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Displacement'),
        backgroundColor: const Color(0xFF003366),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Project Dropdown
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Project',
                    border: OutlineInputBorder(),
                    prefixIcon:
                    Icon(Icons.work, color: Color(0xFF003366)),
                  ),
                  value: selectedProject,
                  items: [
                    const DropdownMenuItem<String>(
                      value: "All",
                      child: Text("Select a Project"),
                    ),
                    ...projects.map((proj) => DropdownMenuItem<String>(
                      value: proj['docId'] as String,
                      child:
                      Text(proj['projectNumber'].toString()),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedProject = value;
                      _fetchSites(value!);
                    });
                  },
                  hint: const Text("Select a Project"),
                ),
              ),
            ),
            // Site Dropdown
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Site',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city,
                        color: Color(0xFF003366)),
                  ),
                  value: selectedSite,
                  items: [
                    const DropdownMenuItem<String>(
                      value: "All",
                      child: Text("Select a Site"),
                    ),
                    ...sites.map((site) => DropdownMenuItem<String>(
                      value: site['siteName'] as String,
                      child:
                      Text(site['siteName'].toString()),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedSite = value;
                    });
                  },
                  hint: const Text("Select a Site"),
                ),
              ),
            ),
            // Continent Dropdown
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Continent',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.public,
                        color: Color(0xFF003366)),
                  ),
                  value: selectedContinent,
                  items: continentCountries.keys
                      .map((cont) => DropdownMenuItem<String>(
                    value: cont,
                    child: Text(cont),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedContinent = value;
                      selectedCountry = null;
                      selectedCity = null;
                      cities = [];
                      selectedGpsLocation = null;
                    });
                  },
                  hint: const Text("Select Continent"),
                ),
              ),
            ),
            // Country Dropdown
            if (selectedContinent != null)
              Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Country',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flag,
                          color: Color(0xFF003366)),
                    ),
                    value: selectedCountry,
                    items: continentCountries[selectedContinent]!
                        .map((country) => DropdownMenuItem<String>(
                      value: country,
                      child: Text(country),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCountry = value;
                        selectedCity = null;
                        selectedGpsLocation = null;
                        cities = [];
                      });
                      _fetchCities(value!);
                    },
                    hint: const Text("Select Country"),
                  ),
                ),
              ),
            // City Dropdown
            if (selectedCountry != null && cities.isNotEmpty)
              Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select City',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on,
                          color: Color(0xFF003366)),
                    ),
                    value: selectedCity,
                    items: cities
                        .map((city) => DropdownMenuItem<String>(
                      value: city,
                      child: Text(city),
                    ))
                        .toList(),
                    onChanged: (value) async {
                      setState(() {
                        selectedCity = value;
                      });
                      await _getCoordinatesForCity(value!, selectedCountry!);
                    },
                    hint: const Text("Select City"),
                  ),
                ),
              ),
            // Display GPS Coordinates (if available)
            if (selectedGpsLocation != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  "GPS: ${selectedGpsLocation!.latitude.toStringAsFixed(4)}, ${selectedGpsLocation!.longitude.toStringAsFixed(4)}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),
            // Date Fields Card
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Start Date',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF003366)),
                      ),
                      subtitle: Text(
                        startDate != null
                            ? '${startDate!.toLocal()}'.split(' ')[0]
                            : 'No date selected',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today,
                            color: Color(0xFF003366)),
                        onPressed: _pickStartDate,
                      ),
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: isEndDateDefined,
                          onChanged: (bool? value) {
                            setState(() {
                              isEndDateDefined = value ?? false;
                              if (!isEndDateDefined) endDate = null;
                            });
                          },
                        ),
                        const Text('Define End Date'),
                      ],
                    ),
                    if (isEndDateDefined)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'End Date',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF003366)),
                        ),
                        subtitle: Text(
                          endDate != null
                              ? '${endDate!.toLocal()}'.split(' ')[0]
                              : 'No date selected',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today,
                              color: Color(0xFF003366)),
                          onPressed: _pickEndDate,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Mission Description Card
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(
                    labelText: 'Mission Description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description,
                        color: Color(0xFF003366)),
                  ),
                  maxLines: 3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Submit Button
            Center(
              child: ElevatedButton(
                onPressed: isLoading ? null : addDisplacement,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 24),
                  backgroundColor: const Color(0xFF003366),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(
                    color: Colors.white)
                    : const Text('Add Displacement',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}