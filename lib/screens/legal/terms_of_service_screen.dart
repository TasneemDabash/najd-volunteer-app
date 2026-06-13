import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatefulWidget {
  const TermsOfServiceScreen({super.key});

  @override
  State<TermsOfServiceScreen> createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen> {
  bool _showArabic = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showArabic ? 'شروط الاستخدام' : 'Terms of Service'),
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
          'قبول الشروط',
          'باستخدامك لتطبيق نجد، فإنك توافق على هذه الشروط والأحكام. '
          'إذا كنت لا توافق على أي جزء من هذه الشروط، يرجى عدم استخدام التطبيق.',
        ),
        _buildSection(
          'وصف الخدمة',
          'نجد هو تطبيق لإدارة وتنسيق العمل التطوعي. يتيح للمتطوعين:\n'
          '• التسجيل كمتطوعين وإدارة ملفاتهم الشخصية\n'
          '• استلام المهام والمشاركة في الأعمال التطوعية\n'
          '• التواصل مع فريق الدعم والمنسقين\n'
          '• تتبع ساعات التطوع والإنجازات',
        ),
        _buildSection(
          'أهلية الاستخدام',
          '• يجب أن يكون عمرك 13 عاماً أو أكثر لاستخدام التطبيق\n'
          '• يجب أن تكون 18 عاماً أو أكثر للتسجيل كمتطوع رسمي\n'
          '• يجب تقديم معلومات صحيحة ودقيقة عند التسجيل',
        ),
        _buildSection(
          'حساب المستخدم',
          '• أنت مسؤول عن الحفاظ على سرية معلومات حسابك\n'
          '• يجب إخطارنا فوراً بأي استخدام غير مصرح به\n'
          '• نحتفظ بحق تعليق أو إنهاء الحسابات المخالفة',
        ),
        _buildSection(
          'السلوك المقبول',
          'يجب على المستخدمين:\n'
          '• التصرف باحترام ومهنية مع الآخرين\n'
          '• تقديم معلومات صادقة ودقيقة\n'
          '• الالتزام بتعليمات السلامة والأمان\n'
          '• احترام خصوصية المستفيدين والمتطوعين الآخرين',
        ),
        _buildSection(
          'السلوك المحظور',
          'يُحظر على المستخدمين:\n'
          '• نشر محتوى مسيء أو غير لائق\n'
          '• انتحال شخصية الآخرين\n'
          '• استخدام التطبيق لأغراض غير قانونية\n'
          '• محاولة اختراق أو تعطيل الخدمة\n'
          '• جمع بيانات المستخدمين دون إذن',
        ),
        _buildSection(
          'الملكية الفكرية',
          'جميع حقوق الملكية الفكرية للتطبيق ومحتواه محفوظة. '
          'لا يجوز نسخ أو توزيع أو تعديل أي جزء من التطبيق دون إذن كتابي.',
        ),
        _buildSection(
          'إخلاء المسؤولية',
          '• التطبيق مقدم "كما هو" دون ضمانات\n'
          '• لا نتحمل مسؤولية أي أضرار ناتجة عن الاستخدام\n'
          '• المتطوعون مسؤولون عن سلامتهم أثناء تنفيذ المهام\n'
          '• ننصح بالحصول على التأمين المناسب',
        ),
        _buildSection(
          'التعديلات',
          'نحتفظ بحق تعديل هذه الشروط في أي وقت. '
          'سيتم إخطارك بالتغييرات الجوهرية. '
          'استمرارك في استخدام التطبيق يعني قبولك للتعديلات.',
        ),
        _buildSection(
          'إنهاء الخدمة',
          '• يمكنك إلغاء حسابك في أي وقت\n'
          '• نحتفظ بحق إنهاء الخدمة للمخالفين\n'
          '• عند الإنهاء، قد يتم حذف بياناتك وفقاً لسياسة الخصوصية',
        ),
        _buildSection(
          'القانون المطبق',
          'تخضع هذه الشروط لقوانين المملكة العربية السعودية. '
          'أي نزاعات تُحل عبر الوسائل القانونية المعمول بها.',
        ),
        _buildSection(
          'اتصل بنا',
          'لأي أسئلة حول هذه الشروط:\n'
          'البريد الإلكتروني: support@najd-app.com\n'
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
          'Acceptance of Terms',
          'By using the Najd app, you agree to these terms and conditions. '
          'If you do not agree to any part of these terms, please do not use the app.',
        ),
        _buildSection(
          'Service Description',
          'Najd is an app for managing and coordinating volunteer work. It allows volunteers to:\n'
          '• Register as volunteers and manage their profiles\n'
          '• Receive tasks and participate in volunteer activities\n'
          '• Communicate with support team and coordinators\n'
          '• Track volunteer hours and achievements',
        ),
        _buildSection(
          'Eligibility',
          '• You must be 13 years or older to use the app\n'
          '• You must be 18 years or older to register as an official volunteer\n'
          '• You must provide accurate and truthful information when registering',
        ),
        _buildSection(
          'User Account',
          '• You are responsible for maintaining the confidentiality of your account\n'
          '• You must notify us immediately of any unauthorized use\n'
          '• We reserve the right to suspend or terminate violating accounts',
        ),
        _buildSection(
          'Acceptable Conduct',
          'Users must:\n'
          '• Act respectfully and professionally with others\n'
          '• Provide honest and accurate information\n'
          '• Follow safety and security instructions\n'
          '• Respect the privacy of beneficiaries and other volunteers',
        ),
        _buildSection(
          'Prohibited Conduct',
          'Users are prohibited from:\n'
          '• Posting offensive or inappropriate content\n'
          '• Impersonating others\n'
          '• Using the app for illegal purposes\n'
          '• Attempting to hack or disrupt the service\n'
          '• Collecting user data without permission',
        ),
        _buildSection(
          'Intellectual Property',
          'All intellectual property rights for the app and its content are reserved. '
          'No part of the app may be copied, distributed, or modified without written permission.',
        ),
        _buildSection(
          'Disclaimer',
          '• The app is provided "as is" without warranties\n'
          '• We are not liable for any damages resulting from use\n'
          '• Volunteers are responsible for their safety during task execution\n'
          '• We recommend obtaining appropriate insurance',
        ),
        _buildSection(
          'Modifications',
          'We reserve the right to modify these terms at any time. '
          'You will be notified of material changes. '
          'Your continued use of the app means acceptance of the modifications.',
        ),
        _buildSection(
          'Service Termination',
          '• You can cancel your account at any time\n'
          '• We reserve the right to terminate service for violators\n'
          '• Upon termination, your data may be deleted per the Privacy Policy',
        ),
        _buildSection(
          'Governing Law',
          'These terms are governed by the laws of the Kingdom of Saudi Arabia. '
          'Any disputes will be resolved through applicable legal means.',
        ),
        _buildSection(
          'Contact Us',
          'For any questions about these terms:\n'
          'Email: support@najd-app.com\n'
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
