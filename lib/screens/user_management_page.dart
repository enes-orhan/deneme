import 'package:flutter/material.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class UserManagementPage extends StatefulWidget {
  final AuthService authService;

  const UserManagementPage({
    Key? key,
    required this.authService,
  }) : super(key: key);

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<User> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await widget.authService.getUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Kullanıcılar yüklenirken bir hata oluştu: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _showAddUserDialog() async {
    final usernameController = TextEditingController();
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'personel';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Yeni Kullanıcı Ekle'),
        content: StatefulBuilder(
          builder: (context, setState) => Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'Kullanıcı Adı',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Kullanıcı adı gerekli'
                        : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'İsim',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'İsim gerekli' : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Şifre gerekli'
                        : value.length < 6
                            ? 'Şifre en az 6 karakter olmalı'
                            : null,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: InputDecoration(
                      labelText: 'Yetki',
                      prefixIcon: Icon(Icons.admin_panel_settings),
                    ),
                    items: [
                      DropdownMenuItem(value: 'admin', child: Text('Yönetici')),
                      DropdownMenuItem(
                          value: 'personel', child: Text('Personel')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => role = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          CustomButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final newUser = User(
                  username: usernameController.text.trim(),
                  name: nameController.text.trim(),
                  password: passwordController.text,
                  role: role,
                );

                final success = await widget.authService.addUser(newUser);
                Navigator.pop(context);

                if (success) {
                  _showSuccess('Kullanıcı başarıyla eklendi');
                  _loadUsers();
                } else {
                  _showError('Bu kullanıcı adı zaten kullanılıyor');
                }
              }
            },
            text: 'Ekle',
            semanticLabel: 'Kullanıcı Ekle Butonu',
          ),
        ],
      ),
    );
  }

  Future<void> _showEditUserDialog(User user) async {
    final usernameController = TextEditingController(text: user.username);
    final nameController = TextEditingController(text: user.name);
    final passwordController = TextEditingController();
    String role = user.role;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kullanıcı Düzenle'),
        content: StatefulBuilder(
          builder: (context, setState) => Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomTextField(
                    controller: usernameController,
                    label: 'Kullanıcı Adı',
                    semanticLabel: 'Kullanıcı Adı Alanı',
                    autofillHints: const [AutofillHints.username],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Kullanıcı adı giriniz';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  CustomTextField(
                    controller: nameController,
                    label: 'Ad Soyad',
                    semanticLabel: 'Ad Soyad Alanı',
                    autofillHints: const [AutofillHints.name],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ad soyad giriniz';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  CustomTextField(
                    controller: passwordController,
                    label: 'Şifre (Boş bırakırsanız değişmez)',
                    semanticLabel: 'Şifre Alanı',
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    validator: (value) {
                      if (value != null && value.isNotEmpty && value.length < 6) {
                        return 'Şifre en az 6 karakter olmalı';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: InputDecoration(
                      labelText: 'Yetki',
                      prefixIcon: Icon(Icons.admin_panel_settings),
                    ),
                    items: [
                      DropdownMenuItem(value: 'admin', child: Text('Yönetici')),
                      DropdownMenuItem(
                          value: 'personel', child: Text('Personel')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => role = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          CustomButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                // Şifre güncelleme durumu
                final password = passwordController.text.isEmpty
                    ? user.password
                    : passwordController.text;

                final updatedUser = user.copyWith(
                  username: usernameController.text.trim(),
                  name: nameController.text.trim(),
                  password: password,
                  role: role,
                );

                final success =
                    await widget.authService.updateUser(updatedUser);
                Navigator.pop(context);

                if (success) {
                  _showSuccess('Kullanıcı başarıyla güncellendi');
                  _loadUsers();
                } else {
                  _showError('Bu kullanıcı adı zaten kullanılıyor');
                }
              }
            },
            text: 'Güncelle',
            semanticLabel: 'Kullanıcı Güncelle Butonu',
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteUser(User user) async {
    // Admin kendisini silemez kontrolü
    final currentUser = widget.authService.currentUser;
    if (currentUser?.id == user.id) {
      _showError('Kendi hesabınızı silemezsiniz');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kullanıcı Sil'),
        content: Text('${user.name} (${user.username}) kullanıcısını silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          CustomButton(
            onPressed: () => Navigator.pop(context, true),
            text: 'Sil',
            semanticLabel: 'Kullanıcı Sil Butonu',
            backgroundColor: Colors.red,
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.authService.deleteUser(user.id);
      if (success) {
        _showSuccess('Kullanıcı başarıyla silindi');
        _loadUsers();
      } else {
        _showError('Kullanıcı silinemedi');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kullanıcı Yönetimi'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Text(
                    'Henüz kullanıcı yok',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: user.isActive
                              ? (user.role == 'admin'
                                  ? Colors.purple
                                  : AppColors.primary)
                              : Colors.grey,
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: user.role == 'admin'
                                    ? Colors.purple.shade100
                                    : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                user.role == 'admin' ? 'Yönetici' : 'Personel',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: user.role == 'admin'
                                      ? Colors.purple.shade800
                                      : Colors.blue.shade800,
                                ),
                              ),
                            ),
                            if (!user.isActive) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Devre Dışı',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text('Kullanıcı Adı: ${user.username}'),
                            Text(
                                'Son Giriş: ${user.lastLoginAt.day}.${user.lastLoginAt.month}.${user.lastLoginAt.year}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEditUserDialog(user),
                              tooltip: 'Düzenle',
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDeleteUser(user),
                              tooltip: 'Sil',
                            ),
                          ],
                        ),
                        onTap: () => _showEditUserDialog(user),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        backgroundColor: AppColors.primary,
        child: Icon(Icons.person_add),
        tooltip: 'Kullanıcı Ekle',
      ),
    );
  }
} 