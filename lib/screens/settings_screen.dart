import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import 'my_profile_screen.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/terms_of_service_screen.dart';
import 'settings/request_role_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('ملفي الشخصي'),
            subtitle: const Text('عرض وتعديل ملفك الشخصي'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('طلب صلاحيات'),
            subtitle: const Text('طلب الترقية لمنسق أو دعم فني'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RequestRoleScreen()),
            ),
          ),
          ListTile(
            leading: Icon(Icons.sync, color: AppTheme.secondary),
            title: const Text('إعادة تحميل الحساب والصلاحيات'),
            subtitle: Text(
              'استخدم بعد تغيير دورك (مدير / دعم / متطوع). '
              'الدور الحالي: ${auth.role.name}',
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () async {
              await auth.refreshProfile();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم التحديث. الدور: ${auth.role.name}'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'القانونية والسياسات',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('سياسة الخصوصية'),
            subtitle: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('شروط الاستخدام'),
            subtitle: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('عن التطبيق'),
            subtitle: const Text('الإصدار 1.0.0'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'نجد',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2026 Najd App. جميع الحقوق محفوظة.',
              children: [
                const SizedBox(height: 16),
                const Text(
                  'تطبيق لإدارة وتنسيق العمل التطوعي',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('تسجيل الخروج'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تسجيل الخروج'),
                  content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تسجيل الخروج')),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await auth.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
