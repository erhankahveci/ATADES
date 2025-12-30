import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';

class AddFaultScreen extends StatefulWidget {
  const AddFaultScreen({super.key});

  @override
  State<AddFaultScreen> createState() => _AddFaultScreenState();
}

class _AddFaultScreenState extends State<AddFaultScreen> {
  // Durum kontrol değişkenleri
  bool _isLocationSelected = false;
  bool _showPreview = false;

  // Harita ile ilgili değişkenler
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(39.9029, 41.2528);

  // Form kontrolcüleri ve durum değişkenleri
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  String? _selectedCategory;

  final List<String> _categories = [
    'Teknik Arıza',
    'Sağlık',
    'Güvenlik',
    'Çevre/Temizlik',
    'Kayıp-Buluntu',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();
    _determineUserCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  //Controller'ı kontrol ederek animasyon çalıştırıyoruz
  Future<void> _determineUserCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();

    // Controller varsa animasyon yap
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 17.0,
          ),
        ),
      );
    }

    setState(() {
      _selectedLocation = LatLng(position.latitude, position.longitude);
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 50,
      );
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      debugPrint('Fotoğraf seçimi sırasında hata oluştu: $e');
    }
  }

  Future<void> _submitFault() async {
    if (!_showPreview) {
      if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
        return;
      }

      if (_selectedCategory == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lütfen bildirim türünü seçiniz')),
          );
        }
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      String? photoUrl;

      if (_selectedImage != null) {
        final fileExt = _selectedImage!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = '$userId/$fileName';
        await _supabase.storage
            .from('fault_photos')
            .upload(filePath, _selectedImage!);
        photoUrl = _supabase.storage
            .from('fault_photos')
            .getPublicUrl(filePath);
      }

      await _supabase.from('faults').insert({
        'user_id': userId,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'department': _selectedCategory,
        'photo_url': photoUrl,
        'latitude': _selectedLocation.latitude,
        'longitude': _selectedLocation.longitude,
        'status': 'Açık',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bildiriminiz başarıyla oluşturuldu ve ilgili birime iletildi.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _showPreview
              ? 'Önizleme'
              : _isLocationSelected
              ? 'Bildirim Detayları'
              : 'Konum Seçin',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_showPreview) {
              setState(() => _showPreview = false);
            } else if (_isLocationSelected) {
              setState(() => _isLocationSelected = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _showPreview
          ? _buildPreviewStep()
          : _isLocationSelected
          ? _buildFormStep()
          : _buildMapStep(),
    );
  }

  Widget _buildMapStep() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _selectedLocation,
            zoom: 15.0,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          // Controller'ı kaydet
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            // İlk konuma git
            _determineUserCurrentLocation();
          },
          onCameraMove: (CameraPosition position) {
            _selectedLocation = position.target;
          },
        ),

        const Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: 40),
            child: Icon(Icons.location_on, size: 50, color: AppColors.error),
          ),
        ),

        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Haritayı kaydırarak bildirimin yapılacağı konumu işaretleyin.",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          bottom: 30,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton(
                heroTag: 'gps_btn',
                backgroundColor: Colors.white,
                onPressed: _determineUserCurrentLocation,
                child: const Icon(Icons.my_location, color: Colors.black),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _isLocationSelected = true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'BU KONUMU KULLAN',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Container(
                    width: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                    ),
                    child: const Icon(
                      Icons.map,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Seçilen Konum",
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${_selectedLocation.latitude.toStringAsFixed(5)}, ${_selectedLocation.longitude.toStringAsFixed(5)}",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.primary),
                    onPressed: () =>
                        setState(() => _isLocationSelected = false),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildInputLabel('Bildirim Kategorisi'),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              dropdownColor: Colors.white,
              hint: Text(
                "Kategori seçiniz",
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
              decoration: _inputDecoration(''),
              items: _categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          _getCategoryIcon(c),
                          const SizedBox(width: 10),
                          Text(c, style: const TextStyle(color: Colors.black)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
            const SizedBox(height: 16),

            _buildInputLabel('Başlık'),
            TextFormField(
              controller: _titleController,
              style: const TextStyle(color: Colors.black),
              decoration: _inputDecoration(
                'Örn: Kütüphane önünde kayıp cüzdan',
              ),
              validator: (val) => val!.isEmpty ? 'Başlık gerekli' : null,
            ),
            const SizedBox(height: 16),

            _buildInputLabel('Açıklama'),
            TextFormField(
              controller: _descController,
              style: const TextStyle(color: Colors.black),
              maxLines: 4,
              decoration: _inputDecoration('Detayları buraya yazınız...'),
              validator: (val) => val!.isEmpty ? 'Açıklama gerekli' : null,
            ),
            const SizedBox(height: 24),

            GestureDetector(
              onTap: () => _showImagePickerSheet(),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                  image: _selectedImage != null
                      ? DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _selectedImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 40,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Fotoğraf Ekle (İsteğe Bağlı)',
                            style: GoogleFonts.inter(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 16,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    setState(() => _selectedImage = null),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState != null &&
                    _formKey.currentState!.validate() &&
                    _selectedCategory != null) {
                  setState(() => _showPreview = true);
                } else if (_selectedCategory == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lütfen bildirim türünü seçiniz'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'ÖNİZLEME',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bildiriminizi göndermeden önce kontrol edin',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildPreviewCard(
            'Kategori',
            _selectedCategory ?? 'Belirtilmedi',
            icon: _selectedCategory != null
                ? _getCategoryIcon(_selectedCategory!)
                : const Icon(Icons.category, color: Colors.grey, size: 20),
          ),

          const SizedBox(height: 16),

          _buildPreviewCard(
            'Başlık',
            _titleController.text,
            icon: const Icon(Icons.title, color: AppColors.primary),
          ),

          const SizedBox(height: 16),

          _buildPreviewCard(
            'Açıklama',
            _descController.text,
            icon: const Icon(Icons.description, color: AppColors.primary),
            maxLines: 10,
          ),

          const SizedBox(height: 16),

          _buildPreviewCard(
            'Konum',
            '${_selectedLocation.latitude.toStringAsFixed(5)}, ${_selectedLocation.longitude.toStringAsFixed(5)}',
            icon: const Icon(Icons.location_on, color: AppColors.primary),
          ),

          const SizedBox(height: 16),

          if (_selectedImage != null)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.image, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Fotoğraf',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: Image.file(
                      _selectedImage!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _isLoading ? null : _submitFault,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'BİLDİRİMİ GÖNDER',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),

          const SizedBox(height: 12),

          OutlinedButton(
            onPressed: () => setState(() => _showPreview = false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'DÜZENLE',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(
    String label,
    String value, {
    Widget? icon,
    int maxLines = 3,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[icon, const SizedBox(width: 8)],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value.isEmpty ? 'Belirtilmedi' : value,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.black),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _getCategoryIcon(String category) {
    IconData icon;
    Color color;

    if (category.isEmpty) {
      return const Icon(Icons.category, color: Colors.grey, size: 20);
    }

    switch (category) {
      case 'Sağlık':
        icon = Icons.local_hospital;
        color = Colors.red;
        break;
      case 'Güvenlik':
        icon = Icons.security;
        color = Colors.blue;
        break;
      case 'Çevre/Temizlik':
        icon = Icons.cleaning_services;
        color = Colors.green;
        break;
      case 'Kayıp-Buluntu':
        icon = Icons.biotech;
        color = Colors.purple;
        break;
      case 'Teknik Arıza':
        icon = Icons.build;
        color = Colors.orange;
        break;
      default:
        icon = Icons.category;
        color = Colors.grey;
    }
    return Icon(icon, color: color, size: 20);
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text(
                'Kamera',
                style: TextStyle(color: Colors.black),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppColors.primary,
              ),
              title: const Text(
                'Galeri',
                style: TextStyle(color: Colors.black),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
          fontSize: 14,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[500]),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}
