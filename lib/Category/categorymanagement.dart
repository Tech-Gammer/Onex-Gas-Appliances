import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import 'addcategory.dart';
import 'categorylistpage.dart';

class CategoryManagement extends StatelessWidget {
  const CategoryManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Provider.of<LanguageProvider>(context).isEnglish
            ? 'Category Management'
            : 'زمرہ کا انتظام'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddCategoryPage()),
                );
              },
              child: Text(Provider.of<LanguageProvider>(context).isEnglish
                  ? 'Add New Category'
                  : 'نیا زمرہ شامل کریں'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ListCategoriesPage()),
                );
              },
              child: Text(Provider.of<LanguageProvider>(context).isEnglish
                  ? 'View Categories'
                  : 'زمرے دیکھیں'),
            ),
          ],
        ),
      ),
    );
  }
}