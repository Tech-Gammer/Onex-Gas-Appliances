import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';

class AddCategoryPage extends StatefulWidget {
  const AddCategoryPage({super.key});

  @override
  State<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _categoryNameController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref().child('category');
  final Color _primaryColor = Color(0xFFFF8A65);
  final Color _secondaryColor = Color(0xFFFFB74D);
  final Color _backgroundColor = Colors.grey[50]!;
  final Color _cardColor = Colors.white;
  final Color _textColor = Colors.grey[800]!;
  @override
  void dispose() {
    _categoryNameController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _database.push().set({
          'name': _categoryNameController.text.trim(),
          'createdAt': ServerValue.timestamp,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              Provider.of<LanguageProvider>(context, listen: false).isEnglish
                  ? 'Category added successfully!'
                  : 'زمرہ کامیابی سے شامل ہو گیا!'
          )),
        );
        _categoryNameController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              Provider.of<LanguageProvider>(context, listen: false).isEnglish
                  ? 'Failed to add category: $e'
                  : 'زمرہ شامل کرنے میں ناکام: $e'
          )),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.isEnglish
            ? 'Add New Category'
            : 'نیا زمرہ شامل کریں'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _categoryNameController,
                decoration: InputDecoration(
                  labelText: languageProvider.isEnglish
                      ? 'Category Name'
                      : 'زمرہ کا نام',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return languageProvider.isEnglish
                        ? 'Please enter category name'
                        : 'براہ کرم زمرہ کا نام درج کریں';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addCategory,
                child: Text(languageProvider.isEnglish
                    ? 'Add Category'
                    : 'زمرہ شامل کریں'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}