import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'addcategory.dart';

class ListCategoriesPage extends StatefulWidget {
  const ListCategoriesPage({super.key});

  @override
  State<ListCategoriesPage> createState() => _ListCategoriesPageState();
}

class _ListCategoriesPageState extends State<ListCategoriesPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref().child('category');
  final TextEditingController _editController = TextEditingController();
  final Color _primaryColor = Color(0xFFFF8A65);
  final Color _secondaryColor = Color(0xFFFFB74D);
  final Color _backgroundColor = Colors.grey[50]!;
  final Color _cardColor = Colors.white;
  final Color _textColor = Colors.grey[800]!;
  Future<void> _deleteCategory(String key) async {
    try {
      await _database.child(key).remove();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            Provider.of<LanguageProvider>(context, listen: false).isEnglish
                ? 'Category deleted successfully!'
                : 'زمرہ کامیابی سے حذف ہو گیا!'
        )),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            Provider.of<LanguageProvider>(context, listen: false).isEnglish
                ? 'Failed to delete category: $e'
                : 'زمرہ حذف کرنے میں ناکام: $e'
        )),
      );
    }
  }

  Future<void> _updateCategory(String key, String currentName) async {
    _editController.text = currentName;

    return showDialog(
      context: context,
      builder: (context) {
        final languageProvider = Provider.of<LanguageProvider>(context);
        return AlertDialog(
          title: Text(languageProvider.isEnglish
              ? 'Edit Category'
              : 'زمرہ میں ترمیم کریں'),
          content: TextField(
            controller: _editController,
            decoration: InputDecoration(
              hintText: languageProvider.isEnglish
                  ? 'Enter new name'
                  : 'نیا نام درج کریں',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _database.child(key).update({
                    'name': _editController.text.trim(),
                    'updatedAt': ServerValue.timestamp,
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(
                        languageProvider.isEnglish
                            ? 'Category updated successfully!'
                            : 'زمرہ کامیابی سے اپ ڈیٹ ہو گیا!'
                    )),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(
                        languageProvider.isEnglish
                            ? 'Failed to update category: $e'
                            : 'زمرہ اپ ڈیٹ کرنے میں ناکام: $e'
                    )),
                  );
                }
              },
              child: Text(languageProvider.isEnglish ? 'Update' : 'اپ ڈیٹ کریں'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.isEnglish
            ? 'All Categories'
            : 'تمام زمرے'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddCategoryPage()),
              );
            },
            tooltip: languageProvider.isEnglish ? 'Add New' : 'نیا شامل کریں',
          ),
        ],
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
      body: FirebaseAnimatedList(
        query: _database,
        defaultChild: const Center(child: CircularProgressIndicator()),
        itemBuilder: (context, snapshot, animation, index) {
          final category = snapshot.value as Map<dynamic, dynamic>;
          final categoryName = category['name'] ?? 'No Name';
          final key = snapshot.key!;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              title: Text(categoryName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _updateCategory(key, categoryName),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteCategory(key),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }
}