import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class AddPartnerPage extends StatefulWidget {
  @override
  _AddPartnerPageState createState() => _AddPartnerPageState();
}

class _AddPartnerPageState extends State<AddPartnerPage> {
  final _formKey = GlobalKey<FormState>();

  // Basic controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController(); // Address field
  final TextEditingController contactEmailController = TextEditingController();
  final TextEditingController contactPhoneController = TextEditingController();
  final TextEditingController commentController = TextEditingController(); // New optional comment field

  // Supplier-specific controllers
  final TextEditingController serviceNameController = TextEditingController();
  final TextEditingController brandNameController = TextEditingController();

  // Partnership type dropdown
  String selectedPartnershipType = '';

  // Country dropdown – default prompt value is "Select Country"
  String selectedCountry = "Select Country";

  // Persons in the organization
  List<Map<String, String>> persons = [];

  // Partner logo file (for the logo image)
  XFile? partnerLogo;

  // Full list of world countries
  final List<String> _countries = [
    "Select Country",
    "Afghanistan",
    "Albania",
    "Algeria",
    "Andorra",
    "Angola",
    "Antigua and Barbuda",
    "Argentina",
    "Armenia",
    "Australia",
    "Austria",
    "Azerbaijan",
    "Bahamas",
    "Bahrain",
    "Bangladesh",
    "Barbados",
    "Belarus",
    "Belgium",
    "Belize",
    "Benin",
    "Bhutan",
    "Bolivia",
    "Bosnia and Herzegovina",
    "Botswana",
    "Brazil",
    "Brunei",
    "Bulgaria",
    "Burkina Faso",
    "Burundi",
    "Côte d'Ivoire",
    "Cabo Verde",
    "Cambodia",
    "Cameroon",
    "Canada",
    "Central African Republic",
    "Chad",
    "Chile",
    "China",
    "Colombia",
    "Comoros",
    "Congo (Congo-Brazzaville)",
    "Costa Rica",
    "Croatia",
    "Cuba",
    "Cyprus",
    "Czechia (Czech Republic)",
    "Democratic Republic of the Congo",
    "Denmark",
    "Djibouti",
    "Dominica",
    "Dominican Republic",
    "Ecuador",
    "Egypt",
    "El Salvador",
    "Equatorial Guinea",
    "Eritrea",
    "Estonia",
    "Eswatini (fmr. 'Swaziland')",
    "Ethiopia",
    "Fiji",
    "Finland",
    "France",
    "Gabon",
    "Gambia",
    "Georgia",
    "Germany",
    "Ghana",
    "Greece",
    "Grenada",
    "Guatemala",
    "Guinea",
    "Guinea-Bissau",
    "Guyana",
    "Haiti",
    "Holy See",
    "Honduras",
    "Hungary",
    "Iceland",
    "India",
    "Indonesia",
    "Iran",
    "Iraq",
    "Ireland",
    "Israel",
    "Italy",
    "Jamaica",
    "Japan",
    "Jordan",
    "Kazakhstan",
    "Kenya",
    "Kiribati",
    "Kuwait",
    "Kyrgyzstan",
    "Laos",
    "Latvia",
    "Lebanon",
    "Lesotho",
    "Liberia",
    "Libya",
    "Liechtenstein",
    "Lithuania",
    "Luxembourg",
    "Madagascar",
    "Malawi",
    "Malaysia",
    "Maldives",
    "Mali",
    "Malta",
    "Marshall Islands",
    "Mauritania",
    "Mauritius",
    "Mexico",
    "Micronesia",
    "Moldova",
    "Monaco",
    "Mongolia",
    "Montenegro",
    "Morocco",
    "Mozambique",
    "Myanmar (formerly Burma)",
    "Namibia",
    "Nauru",
    "Nepal",
    "Netherlands",
    "New Zealand",
    "Nicaragua",
    "Niger",
    "Nigeria",
    "North Korea",
    "North Macedonia",
    "Norway",
    "Oman",
    "Pakistan",
    "Palau",
    "Palestine State",
    "Panama",
    "Papua New Guinea",
    "Paraguay",
    "Peru",
    "Philippines",
    "Poland",
    "Portugal",
    "Qatar",
    "Romania",
    "Russia",
    "Rwanda",
    "Saint Kitts and Nevis",
    "Saint Lucia",
    "Saint Vincent and the Grenadines",
    "Samoa",
    "San Marino",
    "Sao Tome and Principe",
    "Saudi Arabia",
    "Senegal",
    "Serbia",
    "Seychelles",
    "Sierra Leone",
    "Singapore",
    "Slovakia",
    "Slovenia",
    "Solomon Islands",
    "Somalia",
    "South Africa",
    "South Korea",
    "South Sudan",
    "Spain",
    "Sri Lanka",
    "Sudan",
    "Suriname",
    "Sweden",
    "Switzerland",
    "Syria",
    "Tajikistan",
    "Tanzania",
    "Thailand",
    "Timor-Leste",
    "Togo",
    "Tonga",
    "Trinidad and Tobago",
    "Tunisia",
    "Turkey",
    "Turkmenistan",
    "Tuvalu",
    "Uganda",
    "Ukraine",
    "United Arab Emirates",
    "United Kingdom",
    "United States of America",
    "Uruguay",
    "Uzbekistan",
    "Vanuatu",
    "Venezuela",
    "Vietnam",
    "Yemen",
    "Zambia",
    "Zimbabwe",
  ];

  /// Add a new empty person to the list
  void addPerson() {
    setState(() {
      persons.add({
        'name': '',
        'position': '',
        'email': '',
        'phone': '',
      });
    });
  }

  /// Remove a person by index
  void removePerson(int index) {
    setState(() {
      persons.removeAt(index);
    });
  }

  /// Helper method to pick a partner logo image using ImagePicker
  Future<void> _pickLogoImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile =
      await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          partnerLogo = pickedFile;
        });
      }
    } catch (e) {
      print("Error picking partner logo: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking partner logo: $e")),
      );
    }
  }

  /// Helper method to upload partner logo to Firebase Storage
  Future<String?> _uploadLogoImage() async {
    if (partnerLogo == null) return null;
    try {
      final String fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${partnerLogo!.name}";
      final Reference storageRef =
      FirebaseStorage.instance.ref().child("partnerLogos").child(fileName);
      TaskSnapshot snapshot;
      if (kIsWeb) {
        final bytes = await partnerLogo!.readAsBytes();
        snapshot = await storageRef.putData(bytes);
      } else {
        final File localFile = File(partnerLogo!.path);
        snapshot = await storageRef.putFile(localFile);
      }
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading partner logo: $e");
      return null;
    }
  }

  /// Validate and save the partner data
  Future<void> savePartner() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Upload partner logo if one is selected
    String? logoUrl = await _uploadLogoImage();

    final Map<String, dynamic> partnerData = {
      'name': nameController.text.trim(),
      'address': addressController.text.trim(), // Added address field
      'partnershipType': selectedPartnershipType,
      'country': selectedCountry,
      'contactDetails': {
        'email': contactEmailController.text.trim(),
        'phone': contactPhoneController.text.trim(),
      },
      'persons': persons,
      if (logoUrl != null) 'logoUrl': logoUrl,
    };

    // Include comment if provided (optional)
    if (commentController.text.trim().isNotEmpty) {
      partnerData['comment'] = commentController.text.trim();
    }

    if (selectedPartnershipType == 'Supplier') {
      partnerData['supplierDetails'] = {
        'serviceName': serviceNameController.text.trim(),
        'brandName': brandNameController.text.trim(),
      };
    }

    try {
      await FirebaseFirestore.instance.collection('partners').add(partnerData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partner added successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add partner: $e')),
      );
    }
  }

  /// A helper method to build a required TextFormField with validation
  Widget buildRequiredTextFormField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Partner'),
        centerTitle: true,
        backgroundColor: const Color(0xFF003366),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Add Partner Information",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003366),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Partner Name
                  buildRequiredTextFormField(
                    controller: nameController,
                    label: 'Partner Name *',
                  ),
                  const SizedBox(height: 16),
                  // Address Field (Obligatory)
                  buildRequiredTextFormField(
                    controller: addressController,
                    label: 'Address *',
                  ),
                  const SizedBox(height: 16),
                  // Partnership Type Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedPartnershipType.isEmpty
                        ? null
                        : selectedPartnershipType,
                    decoration: const InputDecoration(
                      labelText: 'Partnership Type *',
                      border: OutlineInputBorder(),
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Select Type'),
                      ),
                      ...['Supplier', 'Distributor', 'Client', 'Ministry of Health', 'Land transport company','Flight transport company','Maritime transport company','Hospital']
                          .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                          .toList(),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a partnership type';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        selectedPartnershipType = value ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Supplier-specific fields if "Supplier" is selected
                  if (selectedPartnershipType == 'Supplier') ...[
                    TextFormField(
                      controller: serviceNameController,
                      decoration: const InputDecoration(
                        labelText: 'Service Name',
                        border: OutlineInputBorder(),
                        contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: brandNameController,
                      decoration: const InputDecoration(
                        labelText: 'Brand Name',
                        border: OutlineInputBorder(),
                        contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Country Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedCountry,
                    decoration: const InputDecoration(
                      labelText: 'Country *',
                      border: OutlineInputBorder(),
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _countries.map((country) {
                      return DropdownMenuItem(
                        value: country,
                        child: Text(country),
                      );
                    }).toList(),
                    validator: (value) {
                      if (value == null || value == "Select Country") {
                        return 'Please select a country';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        selectedCountry = value ?? "Select Country";
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Contact Email
                  buildRequiredTextFormField(
                    controller: contactEmailController,
                    label: 'Contact Email *',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  // Contact Phone
                  buildRequiredTextFormField(
                    controller: contactPhoneController,
                    label: 'Contact Phone *',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  // Optional Comment Field
                  TextFormField(
                    controller: commentController,
                    decoration: const InputDecoration(
                      labelText: 'Comment (Optional)',
                      border: OutlineInputBorder(),
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // Partner Logo Section
                  const Text(
                    "Partner Logo (Optional)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickLogoImage,
                        icon: const Icon(Icons.image),
                        label: const Text("Select Logo"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8D1B3D),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          partnerLogo == null
                              ? "No logo selected"
                              : partnerLogo!.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Persons in Organization
                  const Text(
                    'Persons in Organization',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(persons.length, (index) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            TextFormField(
                              onChanged: (value) {
                                persons[index]['name'] = value;
                              },
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                border: OutlineInputBorder(),
                                contentPadding:
                                EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              onChanged: (value) {
                                persons[index]['position'] = value;
                              },
                              decoration: const InputDecoration(
                                labelText: 'Position',
                                border: OutlineInputBorder(),
                                contentPadding:
                                EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              onChanged: (value) {
                                persons[index]['email'] = value;
                              },
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                                contentPadding:
                                EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              onChanged: (value) {
                                persons[index]['phone'] = value;
                              },
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                border: OutlineInputBorder(),
                                contentPadding:
                                EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => removePerson(index),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  ElevatedButton.icon(
                    onPressed: addPerson,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Person'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0073E6),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Save Partner button
                  ElevatedButton(
                    onPressed: savePartner,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Save Partner',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
