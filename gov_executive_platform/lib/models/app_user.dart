import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'role_permissions.dart';

class AppUser {
  final String id; // Firebase Auth UID
  final String name;
  final String email;
  final String phone; // بصيغة دولية E.164 مثل ‎+9655xxxxxxx لإرسال واتساب
  final UserRole role;
  final String? customRoleId; // مرجع لمستند بمجموعة roles عند role == custom
  final String? departmentId; // null لمسؤول النظام والمستخدم التنفيذي
  // للاستخدام مع مدير الإدارة تحديداً: إدارة واحدة أو أكثر يديرها هذا الحساب.
  // بقية الأدوار (ضابط/مدير مشروع، دور مخصص) تستمر باستخدام departmentId المفرد أعلاه.
  final List<String> departmentIds;

  /// القسم (أو القسم الفرعي) الذي ينتمي إليه الموظف داخل إدارته — راجع
  /// [DepartmentSection]. يختاره الموظف عند التسجيل ويعتمده مسؤول النظام،
  /// و null يعني موظفاً تحت الإدارة مباشرةً بلا قسم.
  final String? sectionId;

  /// استثناء من شرط تأكيد البريد الوزاري.
  ///
  /// لا يكتبه إلا مسؤول النظام (قاعدة `/users/{uid}` تمنع المستخدم من تعديل
  /// سجلّه)، ويُستعمل لمن لا يملك بريداً وزارياً عاملاً أو لحساب خدمة.
  final bool emailVerificationExempt;

  /// استثناءات صلاحيات **فردية** تعلو على إعدادات الدور، في الاتجاهين معاً:
  /// `true` تمنح صلاحيةً لا يملكها دوره، و`false` تمنعه صلاحيةً يملكها دوره.
  /// مفتاح كل صلاحية هو `RolePermission.key`.
  ///
  /// لا يكتبها إلا مسؤول النظام عبر دالة سحابية تعيد ختم بطاقة الدخول —
  /// فالخادم يحتكم إلى البطاقة لا إلى هذا السجل.
  final Map<String, bool> permissionOverrides;

  /// الصلاحيات الممنوحة لهذا الفرد **مع نطاق الإدارات** التي تسري فيه —
  /// مفتاح `RolePermission.key` ← [GrantScope].
  ///
  /// وهي المكان الوحيد الذي تُمنح منه `mpr` و`apr`: لا يرثهما دور، ولا
  /// تُضبطان من شاشة «صلاحيات الأدوار». ولا يكتب هذا الحقل إلا مسؤول النظام
  /// عبر دالة سحابية تعيد ختم البطاقة — فالقواعد تحتكم إلى البطاقة وحدها.
  final Map<String, GrantScope> scopedGrants;

  /// نطاق صلاحية ممنوحة لهذا المستخدم، أو نطاق فارغ إن لم تُمنح.
  GrantScope scopeOf(RolePermission permission) =>
      scopedGrants[permission.key] ?? GrantScope.none;

  final UserStatus status;
  final DateTime createdAt;

  /// إن كان هذا الحساب **موقوفاً** ودُمج مع تسجيلٍ جديد بالبريد نفسه —
  /// معرِّف الحساب الجديد الذي نُقلت إليه أعماله ومهامّه.
  ///
  /// حقلٌ يكتبه الخادم وحده عند `pickMergeCandidate` (`functions/src/
  /// account_merge.ts`)، ولا يُكتب من العميل ولا يُنسخ في [copyWith] — فهو
  /// ليس تعديلاً يُجريه أحد، بل ختمٌ للتتبّع بعد فعلٍ تمّ فعلاً.
  final String? mergedIntoUid;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.customRoleId,
    this.departmentId,
    this.departmentIds = const [],
    this.sectionId,
    this.emailVerificationExempt = false,
    this.permissionOverrides = const {},
    this.scopedGrants = const {},
    required this.status,
    required this.createdAt,
    this.mergedIntoUid,
  });

  bool get active => status == UserStatus.approved;

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? customRoleId,
    String? departmentId,
    List<String>? departmentIds,
    String? sectionId,
    bool? emailVerificationExempt,
    Map<String, bool>? permissionOverrides,
    Map<String, GrantScope>? scopedGrants,
    UserStatus? status,
    bool clearSection = false,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      customRoleId: customRoleId ?? this.customRoleId,
      departmentId: departmentId ?? this.departmentId,
      departmentIds: departmentIds ?? this.departmentIds,
      sectionId: clearSection ? null : (sectionId ?? this.sectionId),
      emailVerificationExempt: emailVerificationExempt ?? this.emailVerificationExempt,
      permissionOverrides: permissionOverrides ?? this.permissionOverrides,
      scopedGrants: scopedGrants ?? this.scopedGrants,
      status: status ?? this.status,
      createdAt: createdAt,
      // لا مُعامَل له هنا عمداً: لا أحد يبني نسخةً بختمٍ جديد، فيبقى
      // كما كان — كبقية الحقول التي لا يكتبها العميل أصلاً.
      mergedIntoUid: mergedIntoUid,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.name,
        'customRoleId': customRoleId,
        'departmentId': departmentId,
        'departmentIds': departmentIds,
        'sectionId': sectionId,
        'emailVerificationExempt': emailVerificationExempt,
        'permissionOverrides': permissionOverrides,
        'scopedGrants': {for (final e in scopedGrants.entries) e.key: e.value.toMap()},
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return AppUser(
      id: doc.id,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: UserRole.fromName(json['role'] as String? ?? UserRole.employee.name),
      customRoleId: json['customRoleId'] as String?,
      departmentId: json['departmentId'] as String?,
      departmentIds: List<String>.from(json['departmentIds'] as List? ?? const []),
      sectionId: (json['sectionId'] as String?)?.isEmpty ?? true ? null : json['sectionId'] as String?,
      emailVerificationExempt: json['emailVerificationExempt'] == true,
      scopedGrants: {
        for (final e in (json['scopedGrants'] as Map? ?? const {}).entries)
          e.key.toString(): GrantScope.fromMap(e.value),
      },
      permissionOverrides: {
        for (final e in (json['permissionOverrides'] as Map? ?? const {}).entries)
          if (e.value is bool) e.key.toString(): e.value as bool,
      },
      status: UserStatus.fromName(json['status'] as String? ?? UserStatus.pending.name),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      mergedIntoUid: json['mergedIntoUid'] as String?,
    );
  }
}
