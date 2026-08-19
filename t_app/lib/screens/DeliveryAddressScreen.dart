import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For making HTTP requests
import 'dart:convert'; // For JSON encoding/decoding
import 'package:provider/provider.dart'; // For state management
import 'package:shared_preferences/shared_preferences.dart'; // For storing JWT token
import 'dart:io'; // Import for HttpClient

import '../navigation.dart'; 

class DeliveryAddressScreen extends StatefulWidget {
  const DeliveryAddressScreen({super.key});

  @override
  State<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  List<Map<String, dynamic>> addresses = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  // Get JWT token from shared preferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

// In your authentication logic (login success callback)
Future<void> _syncLocalAddresses(String token) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final localAddressesJson = prefs.getString('local_addresses') ?? '[]';
    final List<dynamic> localAddresses = json.decode(localAddressesJson);

    for (var localAddress in localAddresses) {
      final addressData = {
        'label': localAddress['label'],
        'fullAddress': localAddress['fullAddress'] ?? localAddress['address'],
        'isDefault': localAddress['isDefault'] ?? false,
        'city': localAddress['city'],
        'state': localAddress['state'],
        'country': localAddress['country'] ?? 'Azərbaycan',
        'postalCode': localAddress['postalCode'],
      };

    final response = await http.post(
      Uri.parse('http://technocareapi.runasp.net/api/Addresses/guest'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode(addressData),
    );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Synced address: ${localAddress['label']}');
      }
    }

    // Clear local addresses after successful sync
    await prefs.remove('local_addresses');
  } catch (e) {
    print('Error syncing addresses: $e');
  }
}


Future<void> _loadAddresses() async {
  try {
    final token = await _getToken();
    
    final response = await http.get(
      Uri.parse('http://technocareapi.runasp.net/api/Addresses'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        addresses = data.map((address) => {
          'id': address['id'],
          'label': address['label'],
          'address': address['fullAddress'],
          'isDefault': address['isDefault'],
          'city': address['city'],
          'state': address['state'],
          'country': address['country'],
          'postalCode': address['postalCode'],
        }).toList();
        isLoading = false;
      });
    }
  } catch (e) {
    setState(() {
      isLoading = false;
    });
  }
}


// Update _deleteAddress method
Future<void> _deleteAddress(String addressId) async {
  try {
    final token = await _getToken();
    if (token == null) return;

    final response = await http.delete(
      Uri.parse('http://technocareapi.runasp.net/api/Addresses/$addressId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 204) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ünvan silindi')),
      );
      _loadAddresses();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ünvan silinərkən xəta baş verdi')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Xəta: $e')),
    );
  }
}

// Update _setDefaultAddress method
Future<void> _setDefaultAddress(String addressId) async {
  try {
    final token = await _getToken();
    if (token == null) return;

    final response = await http.patch(
      Uri.parse('http://technocareapi.runasp.net/api/Addresses/$addressId/set-default'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 204) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Əsas ünvan təyin edildi')),
      );
      _loadAddresses();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Əsas ünvan təyin edilərkən xəta baş verdi')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Xəta: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Çatdırılma ünvanı', style: TextStyle(color: Colors.black)),
      ),
      body: Column(
        children: [
          if (isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (errorMessage != null)
            Expanded(
              child: Center(
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (addresses.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Heç bir ünvan tapılmadı',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'İlk ünvanınızı əlavə edin',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAddresses,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: addresses.length,
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  address['label'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                if (address['isDefault'])
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      'Əsas',
                                      style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(address['address']),
                            if (address['city'] != null && address['city'].isNotEmpty)
                              Text('Şəhər: ${address['city']}'),
                            if (address['state'] != null && address['state'].isNotEmpty)
                              Text('Rayon: ${address['state']}'),
                            if (address['postalCode'] != null && address['postalCode'].isNotEmpty)
                              Text('Poçt kodu: ${address['postalCode']}'),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!address['isDefault'])
                                  TextButton(
                                    onPressed: () {
                                      _setDefaultAddress(address['id']);
                                    },
                                    child: const Text('Əsas et', style: TextStyle(color: Colors.blue)),
                                  ),
                                TextButton(
                                  onPressed: () {
                                    _navigateToEditAddress(context, address);
                                  },
                                  child: const Text('Redaktə et', style: TextStyle(color: Colors.green)),
                                ),
                                TextButton(
  onPressed: () {
    _showDeleteDialog(address['id'], address['label'], address['isLocal'] ?? false);
  },
  child: const Text('Sil', style: TextStyle(color: Colors.red)),
),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _navigateToAddAddress(context);
                },
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Yeni Ünvan əlavə et'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String addressId, String addressLabel, bool isLocal) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Ünvanı Sil'),
        content: Text('"$addressLabel" ünvanını silmək istədiyinizə əminsiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ləğv et'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAddress(addressId); // Only 1 parameter
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    },
  );
}

  void _navigateToAddAddress(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditAddressScreen(
          onAddressSaved: _loadAddresses,
        ),
      ),
    );
  }

  void _navigateToEditAddress(BuildContext context, Map<String, dynamic> address) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditAddressScreen(
          address: address,
          onAddressSaved: _loadAddresses,
        ),
      ),
    );
  }
}
