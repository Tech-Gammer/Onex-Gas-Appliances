import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';

import 'Provider/lanprovider.dart';

class UsersPage extends StatefulWidget {
  @override
  _UsersPageState createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref("users");
  List<Map<String, dynamic>> _usersList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  void _fetchUsers() async {
    try {
      final DataSnapshot snapshot = await _databaseRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _usersList = data.entries.map((e) {
            return {
              "name": e.value["name"],
              "email": e.value["email"],
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error fetching users: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildUserList() {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return isDesktop
        ? GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      padding: EdgeInsets.all(16),
      itemCount: _usersList.length,
      itemBuilder: (context, index) => _UserCard(user: _usersList[index]),
    )
        : ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: _usersList.length,
      separatorBuilder: (_, __) => SizedBox(height: 12),
      itemBuilder: (context, index) => _UserCard(user: _usersList[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.isEnglish ? 'User Profiles' : 'صارفین کا پروفائل',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? _LoadingIndicator(languageProvider: languageProvider)
          : _usersList.isEmpty
          ? _EmptyState(languageProvider: languageProvider)
          : _buildUserList(),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        hoverColor: Colors.teal.shade50,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange[300],
                radius: 28,
                child: Text(
                  user["name"][0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user["name"],
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.teal.shade900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      user["email"],
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (languageProvider.isEnglish)
                Icon(Icons.chevron_right, color: Colors.grey.shade400)
              else
                Icon(Icons.chevron_left, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  final LanguageProvider languageProvider;

  const _LoadingIndicator({required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: Colors.orange[300],
            strokeWidth: 2,
          ),
          SizedBox(height: 16),
          Text(
            languageProvider.isEnglish
                ? 'Loading Users...'
                : 'صارفین لوڈ ہو رہے ہیں...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final LanguageProvider languageProvider;

  const _EmptyState({required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.group_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            languageProvider.isEnglish
                ? 'No Users Found'
                : 'کوئی صارف موجود نہیں',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            languageProvider.isEnglish
                ? 'Registered users will appear here'
                : 'رجسٹرڈ صارفین یہاں ظاہر ہوں گے',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

