import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

import '../models/user.dart';
import '../utils/logger.dart';
import 'home_page.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import 'package:flutter/services.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;
  bool _keepLoggedIn = false;

  @override
  void initState() {
    super.initState();
    Logger.info('LoginPage initialized', tag: 'UI');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Provider'dan AuthService'i al
        final authService = Provider.of<AuthService>(context, listen: false);
        
        final user = await authService.login(
          _usernameController.text.trim(),
          _passwordController.text,
        );

        setState(() => _isLoading = false);

        if (user != null) {
          // Oturumu açık tut flag'ini kaydet
          await authService.setKeepLoggedIn(_keepLoggedIn);
          
          Logger.success('Giriş başarılı: ${user.name}', tag: 'AUTH');
          
          // Giriş başarılı, ana sayfaya yönlendir
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HomePage(),
              ),
            );
          }
        } else {
          // Giriş başarısız
          Logger.warn('Geçersiz giriş denemesi: ${_usernameController.text}', tag: 'AUTH');
          setState(() {
            _errorMessage = 'Geçersiz kullanıcı adı veya şifre';
          });
        }
      } catch (e, stackTrace) {
        Logger.error('Giriş hatası', tag: 'AUTH', error: e, stackTrace: stackTrace);
        
        setState(() {
          _isLoading = false;
          // Kullanıcıya daha açıklayıcı ve kullanıcı dostu hata mesajı göster
          if (e.toString().contains('Network')) {
            _errorMessage = 'Sunucuya ulaşılamıyor. Lütfen internet bağlantınızı kontrol edin.';
          } else if (e.toString().contains('timeout')) {
            _errorMessage = 'İşlem zaman aşımına uğradı. Lütfen tekrar deneyin.';
          } else {
            _errorMessage = 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.8),
              AppColors.primaryDark,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo ve Başlık
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      AppAssets.logo,
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppStrings.appName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Giriş Formu
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 15,
                          spreadRadius: 1,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Giriş Yap',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          
                          // Kullanıcı adı (erişilebilir custom widget)
                          CustomTextField(
                            controller: _usernameController,
                            label: 'Kullanıcı Adı',
                            prefixIcon: Icons.person,
                            semanticLabel: 'Kullanıcı Adı Giriş Alanı',
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Kullanıcı adı giriniz';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Şifre (erişilebilir custom widget)
                          CustomTextField(
                            controller: _passwordController,
                            label: 'Şifre',
                            prefixIcon: Icons.lock,
                            semanticLabel: 'Şifre Giriş Alanı',
                            obscureText: !_isPasswordVisible,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _login(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey,
                              ),
                              tooltip: _isPasswordVisible ? 'Şifreyi Gizle' : 'Şifreyi Göster',
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Şifre giriniz';
                              }
                              return null;
                            },
                          ),
                          
                          // Şifre alanından sonra ekle
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Checkbox(
                                value: _keepLoggedIn,
                                onChanged: (value) {
                                  setState(() {
                                    _keepLoggedIn = value ?? false;
                                  });
                                },
                              ),
                              const Text('Oturumu açık tut'),
                            ],
                          ),
                          
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                          
                          // Giriş Butonu (erişilebilir custom widget)
                          CustomButton(
                            onPressed: _isLoading ? null : _login,
                            text: 'Giriş Yap',
                            semanticLabel: 'Giriş Yap Butonu',
                            isLoading: _isLoading,
                            loadingIndicatorColor: Colors.white,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Yardım Notu
                          Center(
                            child: Text(
                              'Giriş yapmakta sorun yaşıyorsanız sistem yöneticinizle iletişime geçin',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 