import 'package:codeflow/auth%20and%20cloud/auth_provider.dart';
import 'package:codeflow/screens/PaymentHistoryScreen.dart';
import 'package:codeflow/screens/login_screen.dart';
import 'package:codeflow/resources%20screens/all_resources.dart';
import 'package:codeflow/screens/contact_screen.dart';
import 'package:codeflow/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:codeflow/utils/showAlert.dart'; // Import showAlert

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;
  final List<Widget> _widgetOptions = <Widget>[
    const AllResources(),
    ContactScreen(),
    SettingsPage(),
    PaymentHistoryScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<bool> showAlert(BuildContext context, String message) async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirmation'),
              content: Text(message),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Logout'),
                ),
              ],
            );
          },
        ) ??
        false; // Return false if the dialog is dismissed.
  }

  @override
  Widget build(BuildContext context) {
    final authStateChangesNotifier = ref.watch(authStateChangesProvider);

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          'CodeFlow',
          style: GoogleFonts.poppins(color: Colors.white), // Apply Poppins font
        ),
        backgroundColor: Colors.black, // Black app bar
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: authStateChangesNotifier.value != null
                ? () async {
                    final shouldLogout = await showAlert(
                      context,
                      'Are you sure you want to logout?', // Custom showAlert text
                    );
                    if (shouldLogout) {
                      ref.watch(authRepositoryProvider).signOut();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  }
                : null,
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.black, // Black background for the drawer
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.black, // Black drawer header
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    authStateChangesNotifier.value?.email![0].toUpperCase() ??
                        '',
                    style: const TextStyle(fontSize: 40.0),
                  ),
                ),
                accountName: Text(
                  authStateChangesNotifier.value?.displayName ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white, // White text
                  ),
                ),
                accountEmail: Text(
                  authStateChangesNotifier.value?.email ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white, // White text
                  ),
                ),
              ),
              _buildDrawerItem(
                icon: Icons.library_books,
                text: 'Latest Resources',
                index: 0,
              ),
              _buildDrawerItem(
                icon: Icons.contact_mail,
                text: 'Contact Us',
                index: 1,
              ),
              _buildDrawerItem(
                icon: Icons.settings,
                text: 'Settings',
                index: 2,
              ),
              _buildDrawerItem(
                icon: Icons.payments,
                text: 'Payment History',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
      {required IconData icon, required String text, required int index}) {
    return ListTile(
      leading: Icon(icon,
          color: _selectedIndex == index
              ? Colors.blue
              : Colors.white), // Blue for selected, White for others
      title: Text(
        text,
        style: GoogleFonts.poppins(
          color: _selectedIndex == index
              ? Colors.blue
              : Colors.white, // Blue for selected, White for others
          fontWeight:
              _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: _selectedIndex == index,
      onTap: () {
        _onItemTapped(index);
        Navigator.pop(context);
      },
    );
  }
}
