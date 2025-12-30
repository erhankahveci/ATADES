// lib/data/models/user_profile.dart

class UserProfile {
  final String id;
  final String? email;
  final String? fullName;
  final String? department;
  final String role;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    this.email,
    this.fullName,
    this.department,
    required this.role,
    required this.createdAt,
  });

  // JSON'dan model oluştur (Supabase'den gelen data)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      department: json['department'] as String?,
      role: json['role'] as String? ?? 'User',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // Model'i JSON'a çevir (Supabase'e gönderirken)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'department': department,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Admin kontrolü
  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  // İsim kısaltması (Profil avatarı için - AA, BB gibi)
  String get initials {
    if (fullName == null || fullName!.isEmpty) {
      return email?.substring(0, 2).toUpperCase() ?? '??';
    }

    final parts = fullName!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName!.substring(0, 2).toUpperCase();
  }

  // Görüntüleme ismi (UI'da gösterilecek isim)
  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) {
      return fullName!;
    }
    return email?.split('@').first ?? 'Kullanıcı';
  }

  // Kopya oluştur (Profil güncellemesi için)
  UserProfile copyWith({
    String? email,
    String? fullName,
    String? department,
    String? role,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      department: department ?? this.department,
      role: role ?? this.role,
      createdAt: createdAt,
    );
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, name: $fullName, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}