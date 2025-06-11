import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';

import '../services/auth_service.dart';
import '../models/income_expense_entry.dart';
import '../utils/logger.dart';
import '../widgets/custom_button.dart';
import 'inventory_page.dart';
import 'daily_sales_page.dart';
import 'credit_book_page.dart';
import 'income_expense_details_page.dart';
import 'login_page.dart';
import 'user_management_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Provider'dan servisleri al
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;
    
    Logger.info('HomePage build ediliyor. Kullanıcı: ${currentUser?.name ?? 'Yok'}', tag: 'UI');
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.appName,
          style: AppTextStyles.heading1.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        actions: [
          if (currentUser != null) 
            PopupMenuButton<String>(
              icon: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  currentUser.name.isNotEmpty ? currentUser.name[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              offset: Offset(0, 45),
              onSelected: (value) async {
                if (value == 'profile') {
                  // Profil sayfasına git
                } else if (value == 'users' && currentUser.role == 'admin') {
                  // Kullanıcı yönetimi sayfasına git
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => UserManagementPage(authService: authService)
                    )
                  );
                } else if (value == 'logout') {
                  // Çıkış yap
                  await authService.logout();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginPage(),
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('${currentUser.name} (${currentUser.role})'),
                    ],
                  ),
                ),
                if (currentUser.role == 'admin')
                  PopupMenuItem(
                    value: 'users',
                    child: Row(
                      children: [
                        Icon(Icons.group, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Kullanıcıları Yönet'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Çıkış Yap'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.background.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.padding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: AppSizes.spacing),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
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
                const SizedBox(height: AppSizes.spacing),
                Text(
                  AppStrings.appName,
                  style: AppTextStyles.heading1,
                  textAlign: TextAlign.center,
                ),
                if (currentUser != null) ...[
                  SizedBox(height: 8),
                  Text(
                    'Hoş geldiniz, ${currentUser.name}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.spacing * 2),
                
                // Daha kompakt menü butonları
                Container(
                  width: double.infinity,
                  child: Column(
                    children: [
                      _buildMenuButton(
                        context,
                        title: AppStrings.inventory,
                        icon: AppIcons.inventory,
                        color: AppColors.success,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const InventoryPage(),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 12),
                      _buildMenuButton(
                        context,
                        title: AppStrings.dailySales,
                        icon: AppIcons.sales,
                        color: AppColors.accent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DailySalesPage(),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 12),
                      _buildMenuButton(
                        context,
                        title: AppStrings.incomeExpense,
                        icon: AppIcons.incomeExpense,
                        color: AppColors.primaryLight,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const IncomeExpenseDetailsPage(
                                type: EntryType.gelir,
                                entries: [],
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 12),
                      _buildMenuButton(
                        context,
                        title: AppStrings.creditBook,
                        icon: AppIcons.creditBook,
                        color: AppColors.background,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreditBookPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildMenuButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth > 600 ? screenWidth * 0.6 : screenWidth - 32;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: buttonWidth,
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.7),
              color,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: color,
              ),
            ),
            SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
} 