import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For making HTTP requests
import 'dart:convert'; // For JSON encoding/decoding
import 'package:provider/provider.dart'; // For state management
import 'package:shared_preferences/shared_preferences.dart'; // For storing JWT token
import 'dart:io'; // Import for HttpClient

import '../navigation.dart'; 

class AddEditAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? address;
  final VoidCallback onAddressSaved;

  const AddEditAddressScreen({
    super.key,
    this.address,
    required this.onAddressSaved,
  });

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _fullAddressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  
  bool _isDefault = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.address != null) {
      _labelController.text = widget.address!['label'] ?? '';
      _fullAddressController.text = widget.address!['address'] ?? '';
      _cityController.text = widget.address!['city'] ?? '';
      _stateController.text = widget.address!['state'] ?? '';
      _postalCodeController.text = widget.address!['postalCode'] ?? '';
      _isDefault = widget.address!['isDefault'] ?? false;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _fullAddressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  // Get JWT token - user is always logged in
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token')!;
  }

  // Save address to backend
  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _getToken();
      final addressData = {
        'label': _labelController.text,
        'fullAddress': _fullAddressController.text,
        'isDefault': _isDefault,
        'city': _cityController.text,
        'state': _stateController.text,
        'country': 'Azərbaycan',
        'postalCode': _postalCodeController.text,
      };

      final response = await http.post(
        Uri.parse('http://technocareapi.runasp.net/api/Addresses'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(addressData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ünvan uğurla əlavə edildi'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onAddressSaved();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xəta baş verdi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı xətası'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        title: Text(widget.address == null ? 'Yeni Ünvan' : 'Ünvanı Redaktə et'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Label Field
                    TextFormField(
                      controller: _labelController,
                      decoration: const InputDecoration(
                        labelText: 'Ünvan başlığı',
                        hintText: 'Məsələn: Ev, İş, Ofis',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Zəhmət olmasa ünvan başlığı daxil edin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Full Address Field
                    TextFormField(
                      controller: _fullAddressController,
                      decoration: const InputDecoration(
                        labelText: 'Tam ünvan',
                        hintText: 'Küçə, ev, mənzil nömrəsi',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Zəhmət olmasa tam ünvan daxil edin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // City Field
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'Şəhər',
                        hintText: 'Bakı',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Zəhmət olmasa şəhər adı daxil edin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // State/Region Field
                    TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(
                        labelText: 'Rayon/Ərazi',
                        hintText: 'Nərimanov, Səbail, etc.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Postal Code Field
                    TextFormField(
                      controller: _postalCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Poçt kodu',
                        hintText: 'AZ1000',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Default Address Switch
                    SwitchListTile(
                      title: const Text('Əsas ünvan olaraq təyin et'),
                      subtitle: const Text('Bu ünvanı əsas çatdırılma ünvanı kimi istifadə et'),
                      value: _isDefault,
                      onChanged: (value) {
                        setState(() {
                          _isDefault = value;
                        });
                      },
                      activeColor: Colors.green,
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveAddress,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          widget.address == null ? 'Ünvanı Əlavə Et' : 'Yenilə',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    // Cancel Button
                    if (widget.address != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Ləğv et'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}