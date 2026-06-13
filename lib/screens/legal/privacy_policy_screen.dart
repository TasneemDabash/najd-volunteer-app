import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  bool _showArabic = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showArabic ? 'سياسة الخصوصية' : 'Privacy Policy'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _showArabic = !_showArabic),
            child: Text(
              _showArabic ? 'English' : 'عربي',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Directionality(
        textDirection: _showArabic ? TextDirection.rtl : TextDirection.ltr,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _showArabic ? _buildArabicContent() : _buildEnglishContent(),
        ),
      ),
    );
  }

  Widget _buildArabicContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          'مقدمة',
          'مرحباً بك في تطبيق نجد. نحن نقدر خصوصيتك ونلتزم بحماية بياناتك الشخصية. '
          'توضح هذه السياسة كيفية جمعنا واستخدامنا وحمايتنا لمعلوماتك.',
        ),
        _buildSection(
          'البيانات التي نجمعها',
          '• معلومات الحساب: الاسم، البريد الإلكتروني، رقم الهاتف\n'
          '• معلومات الموقع: لتحديد المهام القريبة منك\n'
          '• بيانات الاستخدام: كيفية تفاعلك مع التطبيق\n'
          '• الوسائط: الصور والتسجيلات الصوتية المتعلقة بالمهام\n'
          '• معلومات المهارات: لمطابقتك مع المهام المناسبة',
        ),
        _buildSection(
          'كيف نستخدم بياناتك',
          '• تقديم خدمات التطوع وإدارة المهام\n'
          '• التواصل معك بشأن المهام والتحديثات\n'
          '• تحسين تجربة المستخدم والتطبيق\n'
          '• ضمان أمان وسلامة المجتمع\n'
          '• الامتثال للمتطلبات القانونية',
        ),
        _buildSection(
          'مشاركة البيانات',
          '• لا نبيع بياناتك الشخصية لأطراف ثالثة\n'
          '• قد نشارك بياناتك مع منسقي المهام لتنفيذ الأعمال التطوعية\n'
          '• قد نشارك البيانات مع السلطات عند الضرورة القانونية\n'
          '• نستخدم خدمات سحابية آمنة لتخزين البيانات',
        ),
        _buildSection(
          'أمان البيانات',
          '• نستخدم تشفير SSL/TLS لحماية البيانات أثناء النقل\n'
          '• البيانات مخزنة في خوادم آمنة مع تشفير متقدم\n'
          '• الوصول للبيانات محدود للموظفين المصرح لهم فقط\n'
          '• نجري مراجعات أمنية دورية',
        ),
        _buildSection(
          'حقوقك',
          '• الوصول: يحق لك طلب نسخة من بياناتك\n'
          '• التصحيح: يمكنك تحديث معلوماتك في أي وقت\n'
          '• الحذف: يمكنك طلب حذف حسابك وبياناتك\n'
          '• الاعتراض: يمكنك الاعتراض على معالجة بياناتك',
        ),
        _buildSection(
          'استخدام الكاميرا والميكروفون',
          '• الكاميرا: تُستخدم لمكالمات الفيديو مع فريق الدعم والمتطوعين\n'
          '• الميكروفون: يُستخدم للرسائل الصوتية والمكالمات\n'
          '• لن نصل لهذه الميزات إلا بإذنك الصريح',
        ),
        _buildSection(
          'استخدام الموقع',
          '• نستخدم موقعك لعرض المهام القريبة منك\n'
          '• يمكنك تعطيل خدمات الموقع في أي وقت من إعدادات جهازك\n'
          '• لا نتتبع موقعك في الخلفية دون علمك',
        ),
        _buildSection(
          'الأطفال',
          'تطبيقنا غير موجه للأطفال دون سن 13 عاماً. '
          'لا نجمع معلومات من الأطفال عن علم.',
        ),
        _buildSection(
          'التغييرات على السياسة',
          'قد نحدث هذه السياسة من وقت لآخر. '
          'سنخطرك بأي تغييرات جوهرية عبر التطبيق أو البريد الإلكتروني.',
        ),
        _buildSection(
          'اتصل بنا',
          'لأي أسئلة حول هذه السياسة، يرجى التواصل معنا:\n'
          'البريد الإلكتروني: privacy@najd-app.com\n'
          'أو عبر صفحة الدعم في التطبيق',
        ),
        const SizedBox(height: 16),
        Text(
          'آخر تحديث: يونيو 2026',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildEnglishContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          'Introduction',
          'Welcome to Najd App. We value your privacy and are committed to protecting your personal data. '
          'This policy explains how we collect, use, and protect your information.',
        ),
        _buildSection(
          'Data We Collect',
          '• Account Information: Name, email, phone number\n'
          '• Location Data: To identify nearby tasks and incidents\n'
          '• Usage Data: How you interact with the app\n'
          '• Media: Photos and audio recordings related to tasks\n'
          '• Skills Information: To match you with suitable tasks',
        ),
        _buildSection(
          'How We Use Your Data',
          '• Provide volunteer services and task management\n'
          '• Communicate with you about tasks and updates\n'
          '• Improve user experience and app functionality\n'
          '• Ensure community safety and security\n'
          '• Comply with legal requirements',
        ),
        _buildSection(
          'Data Sharing',
          '• We do not sell your personal data to third parties\n'
          '• We may share data with task coordinators for volunteer operations\n'
          '• We may share data with authorities when legally required\n'
          '• We use secure cloud services for data storage',
        ),
        _buildSection(
          'Data Security',
          '• We use SSL/TLS encryption to protect data in transit\n'
          '• Data is stored on secure servers with advanced encryption\n'
          '• Access to data is limited to authorized personnel only\n'
          '• We conduct regular security audits',
        ),
        _buildSection(
          'Your Rights',
          '• Access: You can request a copy of your data\n'
          '• Correction: You can update your information at any time\n'
          '• Deletion: You can request deletion of your account and data\n'
          '• Objection: You can object to the processing of your data',
        ),
        _buildSection(
          'Camera and Microphone Usage',
          '• Camera: Used for video calls with support team and volunteers\n'
          '• Microphone: Used for voice messages and calls\n'
          '• We only access these features with your explicit permission',
        ),
        _buildSection(
          'Location Usage',
          '• We use your location to show nearby tasks\n'
          '• You can disable location services anytime in device settings\n'
          '• We do not track your location in the background without your knowledge',
        ),
        _buildSection(
          'Children',
          'Our app is not intended for children under 13 years of age. '
          'We do not knowingly collect information from children.',
        ),
        _buildSection(
          'Policy Changes',
          'We may update this policy from time to time. '
          'We will notify you of any material changes via the app or email.',
        ),
        _buildSection(
          'Contact Us',
          'For any questions about this policy, please contact us:\n'
          'Email: privacy@najd-app.com\n'
          'Or through the support page in the app',
        ),
        const SizedBox(height: 16),
        Text(
          'Last updated: June 2026',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }
}
