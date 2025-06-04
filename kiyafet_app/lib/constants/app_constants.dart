import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF22343A); // Koyu mavi
  static const Color primaryLight = Color(0xFF4B5C63); // Açık mavi ton
  static const Color primaryDark = Color(0xFF162024); // Daha koyu mavi
  static const Color accent = Color(0xFFB74A2A); // Kırmızı
  static const Color background = Color(0xFFF5E3C3); // Bej
  static const Color backgroundSecondary = Color(0xFFF5F5F5); // Açık bej/gri
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFF57C00);
  static const Color text = Color(0xFF22343A); // Koyu mavi
  static const Color textSecondary = Color(0xFF757575);
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.text,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.text,
  );
  
  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: AppColors.text,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );
}

class AppSizes {
  static const double buttonHeight = 48.0;
  static const double buttonWidth = 250.0;
  static const double borderRadius = 10.0;
  static const double padding = 16.0;
  static const double spacing = 20.0;
}

class AppStrings {
  static const String appName = 'Yörükler Giyim';
  static const String inventory = 'Envanter';
  static const String dailySales = 'Satış';
  static const String incomeExpense = 'Gelir-Gider Hareketleri';
  static const String creditBook = 'Veresiye Defteri';
  static const String addProduct = 'Ürün Ekle';
  static const String editProduct = 'Ürünü Düzenle';
  static const String deleteProduct = 'Ürünü Sil';
  static const String cancel = 'İptal';
  static const String save = 'Kaydet';
  static const String delete = 'Sil';
  static const String search = 'Ara';
  static const String noResults = 'Sonuç bulunamadı';
  static const String error = 'Hata';
  static const String success = 'Başarılı';
  static const String warning = 'Uyarı';
}

class AppIcons {
  static const IconData inventory = Icons.inventory_2;
  static const IconData sales = Icons.shopping_cart;
  static const IconData incomeExpense = Icons.account_balance_wallet;
  static const IconData creditBook = Icons.book;
  static const IconData add = Icons.add;
  static const IconData edit = Icons.edit;
  static const IconData delete = Icons.delete;
  static const IconData search = Icons.search;
  static const IconData barcode = Icons.qr_code_scanner;
  static const IconData history = Icons.history;
  static const IconData settings = Icons.settings;
}

class AppAssets {
  static const String logo = 'assets/simge.png';
} 