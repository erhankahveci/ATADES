import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CreateNotificationScreen extends StatelessWidget {
  const CreateNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Yeni Bildirim"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text("Bildirim Oluşturma Ekranı (Yapılacak)")),
    );
  }
}
