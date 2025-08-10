import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Provider/customerprovider.dart';
import '../Provider/lanprovider.dart';

class AddCustomer extends StatefulWidget {
  @override
  State<AddCustomer> createState() => _AddCustomerState();
}

class _AddCustomerState extends State<AddCustomer> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _address = '';
  String _phone = '';

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            // 'Add Customer',
            languageProvider.isEnglish ? 'Add Customer' : 'کسٹمر شامل کریں۔',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange[300],
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // 'Customer Details',
                languageProvider.isEnglish ? 'Customer Details' : 'کسٹمر کی تفصیلات',

                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[300],
                ),
              ),
              SizedBox(height: 20),
              TextFormField(
                decoration: InputDecoration(
                  labelText: languageProvider.isEnglish ? 'Name' : 'نام',

                  labelStyle: TextStyle(color: Colors.orange[300]),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.orange),
                  ),
                ),
                onSaved: (value) => _name = value!,
                validator: (value) =>
                value!.isEmpty ? 'Please enter the customer\'s name' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText:  languageProvider.isEnglish ? 'Address' : 'پتہ',
                  labelStyle: TextStyle(color: Colors.orange[300]),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.orange),
                  ),
                ),
                onSaved: (value) => _address = value!,
                validator: (value) =>
                value!.isEmpty ? 'Please enter the customer\'s address' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: languageProvider.isEnglish ? 'ُPhone Number' : 'موبائل نمبر',
                  labelStyle: TextStyle(color: Colors.orange[300]),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.orange),
                  ),
                ),
                keyboardType: TextInputType.phone,
                onSaved: (value) => _phone = value!,
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter the customer\'s phone number';
                  if (!RegExp(r'^[0-9]{10,15}$').hasMatch(value)) return 'Please enter a valid phone number';
                  return null;
                },
              ),
              SizedBox(height: 20),
              Align(
                alignment: Alignment.center,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[300],
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _saveCustomer(context),
                  child: Text(
                    // 'Save',
                    languageProvider.isEnglish ? 'Save' : 'محفوظ کریں۔',

                    style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),),

                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveCustomer(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      Provider.of<CustomerProvider>(context, listen: false).addCustomer(_name, _address, _phone);
      Navigator.pop(context);
    }
  }
}
