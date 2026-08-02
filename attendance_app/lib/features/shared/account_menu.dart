import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/features/shared/profile_screen.dart';
import 'package:attendance_app/features/shared/settings_screen.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// App-bar overflow menu shared by both dashboards: Profile, Settings, Sign out.
class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (value) {
        switch (value) {
          case 'profile':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          case 'settings':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          case 'signout':
            Provider.of<UserProvider>(context, listen: false).signOut();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person_outline_rounded),
            title: Text('Profile'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'signout',
          child: ListTile(
            leading: Icon(Icons.logout_rounded),
            title: Text('Sign out'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
