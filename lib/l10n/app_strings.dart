/// Arabic UI strings for the app (locale is fixed to `ar` in main.dart).
abstract final class AppStrings {
  // Common
  static const required_ = 'مطلوب';
  static const cancel = 'إلغاء';
  static const save = 'حفظ';
  static const edit = 'تعديل';
  static const delete = 'حذف';
  static const retry = 'إعادة المحاولة';
  static const refresh = 'تحديث';
  static const online = 'متصل';
  static const offline = 'غير متصل';
  static const notSet = 'غير محدد';
  static const errorPrefix = 'خطأ:';

  // Tasks
  static const tasks = 'المهام';
  static const myTasks = 'مهامي';
  static const createTask = 'إنشاء مهمة';
  static const taskDetails = 'تفاصيل المهمة';
  static const taskTitle = 'عنوان المهمة';
  static const description = 'الوصف';
  static const location = 'الموقع';
  static const pickLocation = 'اختر موقعاً';
  static const scheduledDate = 'التاريخ المحدد';
  static const requiredSkills = 'المهارات المطلوبة';
  static const assignVolunteers = 'تعيين متطوعين';
  static const closestFirst = 'الأقرب أولاً';
  static const taskCreated = 'تم إنشاء المهمة';
  static const pickLocationError = 'يرجى اختيار موقع من القائمة';
  static const pickSkillError = 'يرجى اختيار مهارة واحدة على الأقل';
  static const noVolunteersToAssign =
      'لا يوجد متطوعون للتعيين بعد. يحتاج المستخدمون دور «متطوع» وملف شخصي.';
  static const createTaskHero =
      'خطط للعمل، أضف المهارات، وعيّن المتطوعين اختيارياً.';
  static const assignedVolunteers = 'المتطوعون المعيّنون';
  static const noVolunteersAssigned = 'لم يُعيَّن متطوعون بعد.';
  static const assign = 'تعيين';
  static const markActive = 'تعيين كنشطة';
  static const markCompleted = 'تعيين كمكتملة';
  static const markPending = 'إعادة للانتظار';
  static const taskNotFound = 'المهمة غير موجودة';
  static const assignmentUpdated = 'تم تحديث التعيين';
  static const noVolunteersAvailable = 'لا يوجد متطوعون متاحون.';
  static const coordinates = 'الإحداثيات';
  static const scheduled = 'الموعد';
  static const all = 'الكل';

  // Filters
  static const filterVolunteers = 'تصفية المتطوعين';
  static const onlineOnly = 'متصلون فقط';
  static const availableOnly = 'متاحون فقط';
  static const matchSkills = 'مطابقة المهارات';
  static const searchVolunteers = 'بحث بالاسم أو المدينة...';
  static const km = 'كم';

  // Templates
  static const suggestedTasks = 'مهام مقترحة';
  static const permanentTasks = 'مهام دائمة';
  static const useTemplate = 'استخدام قالب';
  static const manageTemplates = 'إدارة قوالب المهام';
  static const addTemplate = 'إضافة قالب';
  static const templateTitle = 'عنوان القالب';
  static const templateKindPermanent = 'دائم';
  static const templateKindSuggested = 'مقترح';
  static const templateSaved = 'تم حفظ القالب';
  static const templateDeleted = 'تم حذف القالب';
  static const usageCount = 'مرات الاستخدام';

  // Publish requests
  static const requestPublishTask = 'طلب نشر مهمة';
  static const publishRequests = 'طلبات نشر المهام';
  static const submitForReview = 'إرسال للمراجعة';
  static const requestSubmitted =
      'تم إرسال طلبك. سيراجعه فريق الدعم أو الإدارة.';
  static const pendingPublishRequest = 'لديك طلب نشر قيد الانتظار';
  static const approve = 'قبول';
  static const reject = 'رفض';
  static const requestApproved = 'تم قبول الطلب وإنشاء المهمة';
  static const requestRejected = 'تم رفض الطلب';
  static const rejectionReason = 'سبب الرفض';
  static const myPublishRequests = 'طلبات النشر الخاصة بي';
  static const statusPending = 'قيد الانتظار';
  static const statusApproved = 'مقبول';
  static const statusRejected = 'مرفوض';
}
