import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AddShipmentTicketPage extends StatefulWidget {
  // Optionally pass the related curative ticket ID.
  final String? curativeTicketId;
  const AddShipmentTicketPage({Key? key, this.curativeTicketId}) : super(key: key);

  @override
  _AddShipmentTicketPageState createState() => _AddShipmentTicketPageState();
}

class _AddShipmentTicketPageState extends State<AddShipmentTicketPage> {
  final _formKey = GlobalKey<FormState>();

  // -------------------- Shipment Scope & Type --------------------
  final List<String> _shipmentScopeOptions = ["Local", "International"];
  String? _selectedShipmentScope;

  final List<String> _internationalShipmentTypes = [
    "Maritime-Land",
    "Flight-Land",
    "Only Land",
  ];
  String? _selectedInternationalType;

  // -------------------- Shipment Reason --------------------
  final List<String> _shipmentReasonOptions = [
    "curative maintenance",
    "ppm",
    "to complement an installation",
    "other"
  ];
  String? _selectedShipmentReason;

  // For fetching curative maintenance tickets if needed.
  List<Map<String, dynamic>> _curativeTicketList = [];
  String? _selectedCurativeTicketId;

  // -------------------- Carrier Lists (Dynamically Fetched) --------------------
  List<String> maritimeCarriers = [];
  List<String> flightCarriers = [];
  List<String> landCarriers = [];

  // For International multi-modal types:
  String? _selectedPrimaryCarrier; // from maritime or flight carriers.
  String? _selectedLandCarrier;    // from land carriers.

  // -------------------- Other Fields --------------------
  final TextEditingController _shipmentReferenceController = TextEditingController();
  // Shipment status is not chosen by the user – default will be "shipment initiated".

  // -------------------- Date Fields --------------------
  DateTime? _shipmentDate;
  DateTime? _expectedArrivalDate;

  final TextEditingController _descriptionController = TextEditingController();
  String? _createdBy;

  // For Delivered status.
  DateTime? _deliveredTime;

  // -------------------- NEW: Origin and Destination --------------------
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _createdBy = FirebaseAuth.instance.currentUser?.displayName ??
        FirebaseAuth.instance.currentUser?.email;
    // Fetch carrier lists.
    _fetchMaritimeCarriers();
    _fetchFlightCarriers();
    _fetchLandCarriers();
  }

  // -------------------- FETCH PARTNERS FOR CARRIERS --------------------
  Future<void> _fetchMaritimeCarriers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('partners')
          .where('partnershipType', isEqualTo: 'Maritime transport company')
          .get();
      List<String> carriers = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data["name"]?.toString() ?? "Unnamed maritime";
        carriers.add(name);
      }
      setState(() {
        maritimeCarriers = carriers;
      });
    } catch (e) {
      print("Error fetching maritime carriers: $e");
    }
  }

  Future<void> _fetchFlightCarriers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('partners')
          .where('partnershipType', isEqualTo: 'Flight transport company')
          .get();
      List<String> carriers = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data["name"]?.toString() ?? "Unnamed flight";
        carriers.add(name);
      }
      setState(() {
        flightCarriers = carriers;
      });
    } catch (e) {
      print("Error fetching flight carriers: $e");
    }
  }

  Future<void> _fetchLandCarriers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('partners')
          .where('partnershipType', isEqualTo: 'Land transport company')
          .get();
      List<String> carriers = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data["name"]?.toString() ?? "Unnamed land carrier";
        carriers.add(name);
      }
      setState(() {
        landCarriers = carriers;
      });
    } catch (e) {
      print("Error fetching land carriers: $e");
    }
  }

  // -------------------- FETCH CURATIVE TICKETS (if needed) --------------------
  Future<void> _fetchCurativeTickets() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('curative_maintenance_tickets')
          .get();
      List<Map<String, dynamic>> tickets = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {"id": doc.id, "title": data["ticketTitle"] ?? "Untitled Ticket"};
      }).toList();
      setState(() {
        _curativeTicketList = tickets;
      });
    } catch (e) {
      print("Error fetching curative maintenance tickets: $e");
    }
  }

  // -------------------- PICKERS --------------------
  Future<void> _pickShipmentDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _shipmentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _shipmentDate = picked);
  }

  Future<void> _pickExpectedArrivalDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expectedArrivalDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expectedArrivalDate = picked);
  }

  Future<void> _pickDeliveredTime() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: _deliveredTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _deliveredTime != null ? TimeOfDay.fromDateTime(_deliveredTime!) : TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      _deliveredTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  // -------------------- SAVE SHIPMENT TICKET (Step 1 implemented) --------------------
  Future<void> _saveShipmentTicket() async {
    if (!_formKey.currentState!.validate()) return;

    // Build shipment data.
    Map<String, dynamic> shipmentData = {
      "shipmentScope": _selectedShipmentScope,
      "shipmentType": _selectedInternationalType,
      "shipmentReason": _selectedShipmentReason,
      "shipmentReference": _shipmentReferenceController.text.trim(),
      "shipmentStatus": "shipment initiated", // Hardcoded default.
      "shipmentDate": _shipmentDate != null ? Timestamp.fromDate(_shipmentDate!) : null,
      "expectedArrivalDate": _expectedArrivalDate != null ? Timestamp.fromDate(_expectedArrivalDate!) : null,
      "origin": _originController.text.trim(),
      "destination": _destinationController.text.trim(),
      "description": _descriptionController.text.trim(),
      "createdBy": _createdBy,
      "createdAt": Timestamp.now(),
    };

    // For International shipments.
    if (_selectedShipmentScope == "International") {
      if (_selectedInternationalType == "Maritime-Land") {
        shipmentData["primaryCarrier"] = _selectedPrimaryCarrier;
        shipmentData["landCarrier"] = _selectedLandCarrier;
      } else if (_selectedInternationalType == "Flight-Land") {
        shipmentData["primaryCarrier"] = _selectedPrimaryCarrier;
        shipmentData["landCarrier"] = _selectedLandCarrier;
      } else if (_selectedInternationalType == "Only Land") {
        shipmentData["landCarrier"] = _selectedLandCarrier;
      }
    } else if (_selectedShipmentScope == "Local") {
      shipmentData["carrier"] = _selectedLandCarrier;
    }

    // If Local and a curative ticket ID exists, store it.
    if (_selectedShipmentScope == "Local" && widget.curativeTicketId != null) {
      shipmentData["curativeTicketId"] = widget.curativeTicketId;
    }

    // If shipment reason is "curative maintenance", store selected curative ticket.
    if (_selectedShipmentReason == "curative maintenance") {
      shipmentData["curativeMaintenanceTicketId"] = _selectedCurativeTicketId;
    }

    try {
      // Step 1: Create shipment ticket document.
      DocumentReference shipmentDocRef = await FirebaseFirestore.instance
          .collection("shipment_tickets")
          .add(shipmentData);
      String newShipmentId = shipmentDocRef.id;

      // Step 2: Update the corresponding task document (if curativeTicketId is provided)
      if (widget.curativeTicketId != null) {
        await FirebaseFirestore.instance
            .collection("tasks")
            .doc(widget.curativeTicketId)
            .update({"shipmentTicketId": newShipmentId});
        debugPrint("Updated task doc ${widget.curativeTicketId} with shipmentTicketId: $newShipmentId");
      }

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Shipment ticket created successfully!")));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error creating shipment ticket: $e"),
          backgroundColor: Colors.red));
    }
  }

  // -------------------- BUILD UI --------------------
  @override
  Widget build(BuildContext context) {
    Widget carrierWidget = Container();

    if (_selectedShipmentScope == "International") {
      carrierWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // International Shipment Type dropdown.
          DropdownButtonFormField<String>(
            decoration:
            InputDecoration(labelText: "International Shipment Type"),
            items: _internationalShipmentTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedInternationalType = value;
                _selectedPrimaryCarrier = null;
                _selectedLandCarrier = null;
              });
            },
            validator: (val) =>
            (val == null || val.isEmpty) ? "Select shipment type" : null,
          ),
          SizedBox(height: 12),
          if (_selectedInternationalType == "Maritime-Land") ...[
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: "Maritime Carrier"),
              items: maritimeCarriers.map((carrier) {
                return DropdownMenuItem<String>(
                  value: carrier,
                  child: Text(carrier),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPrimaryCarrier = value;
                });
              },
              validator: (val) => (val == null || val.isEmpty)
                  ? "Select maritime carrier"
                  : null,
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: "Land Carrier"),
              items: landCarriers.map((carrier) {
                return DropdownMenuItem<String>(
                  value: carrier,
                  child: Text(carrier),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLandCarrier = value;
                });
              },
              validator: (val) =>
              (val == null || val.isEmpty) ? "Select land carrier" : null,
            ),
          ] else if (_selectedInternationalType == "Flight-Land") ...[
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: "Flight Carrier"),
              items: flightCarriers.map((carrier) {
                return DropdownMenuItem<String>(
                  value: carrier,
                  child: Text(carrier),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPrimaryCarrier = value;
                });
              },
              validator: (val) => (val == null || val.isEmpty)
                  ? "Select flight carrier"
                  : null,
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: "Land Carrier"),
              items: landCarriers.map((carrier) {
                return DropdownMenuItem<String>(
                  value: carrier,
                  child: Text(carrier),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLandCarrier = value;
                });
              },
              validator: (val) =>
              (val == null || val.isEmpty) ? "Select land carrier" : null,
            ),
          ] else if (_selectedInternationalType == "Only Land") ...[
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: "Land Carrier"),
              items: landCarriers.map((carrier) {
                return DropdownMenuItem<String>(
                  value: carrier,
                  child: Text(carrier),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLandCarrier = value;
                });
              },
              validator: (val) =>
              (val == null || val.isEmpty) ? "Select land carrier" : null,
            ),
          ],
        ],
      );
    } else if (_selectedShipmentScope == "Local") {
      carrierWidget = DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: "Local Carrier"),
        items: landCarriers.map((carrier) {
          return DropdownMenuItem<String>(
            value: carrier,
            child: Text(carrier),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedLandCarrier = value;
          });
        },
        validator: (val) =>
        (val == null || val.isEmpty) ? "Select local carrier" : null,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Add Shipment Ticket"),
        backgroundColor: Colors.blue[800],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Shipment Scope Dropdown.
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: "Shipment Scope"),
                items: _shipmentScopeOptions.map((scope) {
                  return DropdownMenuItem<String>(
                    value: scope,
                    child: Text(scope),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedShipmentScope = value;
                    _selectedInternationalType = null;
                    _selectedPrimaryCarrier = null;
                    _selectedLandCarrier = null;
                  });
                },
                validator: (val) =>
                (val == null || val.isEmpty) ? "Select shipment scope" : null,
              ),
              SizedBox(height: 12),
              // Shipment Reason Dropdown.
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: "Shipment Reason"),
                items: _shipmentReasonOptions.map((reason) {
                  return DropdownMenuItem<String>(
                    value: reason,
                    child: Text(reason),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedShipmentReason = value;
                    if (value == "curative maintenance") {
                      _fetchCurativeTickets();
                    } else {
                      _curativeTicketList = [];
                      _selectedCurativeTicketId = null;
                    }
                  });
                },
                validator: (val) =>
                (val == null || val.isEmpty) ? "Select shipment reason" : null,
              ),
              SizedBox(height: 12),
              // Show curative maintenance tickets if reason is "curative maintenance"
              if (_selectedShipmentReason == "curative maintenance")
                DropdownButtonFormField<String>(
                  decoration:
                  InputDecoration(labelText: "Select Curative Maintenance Ticket"),
                  items: _curativeTicketList.map((ticket) {
                    return DropdownMenuItem<String>(
                      value: ticket["id"],
                      child: Text(ticket["title"]),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCurativeTicketId = value;
                    });
                  },
                  validator: (val) => (val == null || val.isEmpty)
                      ? "Select a curative maintenance ticket"
                      : null,
                ),
              SizedBox(height: 12),
              // Carrier Section.
              carrierWidget,
              SizedBox(height: 12),
              // Shipment Reference.
              TextFormField(
                controller: _shipmentReferenceController,
                decoration: InputDecoration(labelText: "Shipment Reference"),
                validator: (val) =>
                (val == null || val.isEmpty) ? "Enter shipment reference" : null,
              ),
              SizedBox(height: 12),
              // Origin Field.
              TextFormField(
                controller: _originController,
                decoration: InputDecoration(labelText: "Origin"),
                validator: (val) => (val == null || val.isEmpty) ? "Enter origin" : null,
              ),
              SizedBox(height: 12),
              // Destination Field.
              TextFormField(
                controller: _destinationController,
                decoration: InputDecoration(labelText: "Destination"),
                validator: (val) =>
                (val == null || val.isEmpty) ? "Enter destination" : null,
              ),
              SizedBox(height: 12),
              // Shipment Date.
              ListTile(
                title: Text(_shipmentDate == null
                    ? "Select Shipment Date"
                    : "Shipment Date: ${DateFormat('yyyy-MM-dd').format(_shipmentDate!)}"),
                trailing: Icon(Icons.calendar_today),
                onTap: _pickShipmentDate,
              ),
              // Expected Arrival Date.
              ListTile(
                title: Text(_expectedArrivalDate == null
                    ? "Select Expected Arrival Date"
                    : "Expected Arrival: ${DateFormat('yyyy-MM-dd').format(_expectedArrivalDate!)}"),
                trailing: Icon(Icons.calendar_today),
                onTap: _pickExpectedArrivalDate,
              ),
              SizedBox(height: 12),
              // Description.
              TextFormField(
                controller: _descriptionController,
                decoration:
                InputDecoration(labelText: "Description (Optional)"),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveShipmentTicket,
                child: Text("Save Shipment Ticket"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
