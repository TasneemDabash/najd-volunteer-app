import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/layouts/admin_layout.dart';
import '../screens/layouts/support_layout.dart';
import '../screens/layouts/volunteer_layout.dart';
import '../screens/splash_screen.dart';

class RoleBasedRoot extends StatelessWidget {
  const RoleBasedRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading || auth.isProfileLoading) {
          return const SplashScreen();
        }
        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }

        final role = auth.role;
        switch (role) {
          case UserRole.support:
            return const SupportLayout();
          case UserRole.admin:
            return const AdminLayout();
          case UserRole.volunteer:
            return const VolunteerLayout();
        }
      },
    );
  }
}

