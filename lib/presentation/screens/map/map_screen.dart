// lib/presentation/screens/map/map_screen.dart

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import 'widgets/map_pin_card.dart';
import '../home/add_fault_screen.dart';
import '../detail/notification_detail_screen.dart';

class MapScreen extends StatefulWidget {
  final Map<String, dynamic>? initialFocusFault;

  const MapScreen({super.key, this.initialFocusFault});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final _supabase = Supabase.instance.client;

  final TextEditingController _searchController = TextEditingController();

  static const CameraPosition _kUniversityCamera = CameraPosition(
    target: LatLng(39.9029, 41.2528),
    zoom: 15.0,
  );

  // FILTRE DEGISKENLERI
  String _selectedCategory = 'Tümü';
  bool _showOnlyOpen = false;
  bool _showOnlyFollowed = false;
  String _searchQuery = '';

  Map<String, dynamic>? _selectedFault;
  Marker? _userLocationMarker;
  bool _isLegendVisible = true;

  final Set<Marker> _allFaultMarkers = {};
  Set<Marker> _displayedMarkers = {};
  List<Map<String, dynamic>> _faultsData = [];
  final Map<String, BitmapDescriptor> _markerCache = {};

  // Realtime Dinleyici
  StreamSubscription? _faultsSubscription;

  // Admin Yetki Kontrol Degiskenleri
  bool _isAdmin = false;
  String? _adminDepartment;

  final List<String> _categories = [
    'Tümü',
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
    _initMapData();
  }

  Future<void> _initMapData() async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId != null) {
      try {
        final profile = await _supabase
            .from('profiles')
            .select('role, department')
            .eq('id', userId)
            .single();

        if (mounted) {
          setState(() {
            _isAdmin = (profile['role'] == 'admin');
            _adminDepartment = profile['department'];
          });
        }
      } catch (e) {
        debugPrint("Profil cekme hatasi: $e");
      }
    }

    _listenToFaults();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFocusFault != null &&
        widget.initialFocusFault != oldWidget.initialFocusFault) {
      _focusOnFault(widget.initialFocusFault!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _faultsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _focusOnFault(Map<String, dynamic> fault) async {
    final double? lat = (fault['latitude'] as num?)?.toDouble();
    final double? lng = (fault['longitude'] as num?)?.toDouble();

    if (lat == null || lng == null) return;

    try {
      final controller = await _controller.future;

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: 18.0),
        ),
      );

      if (mounted) {
        setState(() {
          _selectedFault = fault;
        });
      }
    } catch (e) {
      debugPrint("Odaklanma hatasi: $e");
    }
  }

  void _listenToFaults() {
    final filterBuilder = _supabase.from('faults').stream(primaryKey: ['id']);
    SupabaseStreamBuilder finalStream = filterBuilder;

    if (_isAdmin &&
        _adminDepartment != null &&
        _adminDepartment != 'Genel' &&
        _adminDepartment != 'Tümü') {
      finalStream = filterBuilder.eq('category', _adminDepartment!);
    }

    _faultsSubscription = finalStream.order('created_at').listen((
      List<Map<String, dynamic>> data,
    ) async {
      final userId = _supabase.auth.currentUser?.id;
      Set<dynamic> followedIds = {};

      if (userId != null) {
        try {
          final followRes = await _supabase
              .from('follows')
              .select('fault_id')
              .eq('user_id', userId);

          if (followRes != null) {
            followedIds = (followRes as List).map((e) => e['fault_id']).toSet();
          }
        } catch (e) {
          debugPrint('Takip verisi hatasi: $e');
        }
      }

      final processedData = data.map((f) {
        return {...f, 'is_followed': followedIds.contains(f['id'])};
      }).toList();

      if (mounted) {
        setState(() {
          _faultsData = processedData;
        });
        await _generateMarkers();
      }
    });
  }

  Future<BitmapDescriptor> _createSimplePinMarker(String status) async {
    final String cacheKey = "pin_classic_$status";
    if (_markerCache.containsKey(cacheKey)) return _markerCache[cacheKey]!;

    Color color;
    if (status == 'Çözüldü') {
      color = AppColors.success;
    } else if (status == 'İnceleniyor') {
      color = AppColors.warning;
    } else {
      color = AppColors.error;
    }

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    const int size = 130;
    final Canvas canvas = Canvas(pictureRecorder);

    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.location_on.codePoint),
      style: TextStyle(
        fontSize: size.toDouble(),
        fontFamily: Icons.location_on.fontFamily,
        color: color,
        shadows: [
          Shadow(
            blurRadius: 5.0,
            color: Colors.black38,
            offset: const Offset(2.0, 2.0),
          ),
        ],
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(0, 0));

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size,
      size,
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    final bitmap = BitmapDescriptor.fromBytes(uint8List);
    _markerCache[cacheKey] = bitmap;
    return bitmap;
  }

  Future<void> _generateMarkers() async {
    _allFaultMarkers.clear();

    for (var fault in _faultsData) {
      final double? lat = (fault['latitude'] as num?)?.toDouble();
      final double? lng = (fault['longitude'] as num?)?.toDouble();
      final String status = fault['status'] ?? 'Açık';

      if (lat == null || lng == null) continue;

      final icon = await _createSimplePinMarker(status);

      final marker = Marker(
        markerId: MarkerId(fault['id'].toString()),
        position: LatLng(lat, lng),
        icon: icon,
        anchor: const Offset(0.5, 1.0),
        onTap: () {
          setState(() {
            _selectedFault = fault;
            FocusScope.of(context).unfocus();
          });
        },
      );
      _allFaultMarkers.add(marker);
    }

    if (mounted) _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      final query = _searchQuery.toLowerCase().trim();

      final filteredIds = _faultsData
          .where((f) {
            if (f['status'] == 'Sonlandırıldı') return false;

            final category = f['category'] ?? f['department'] ?? 'Diğer';

            if (_selectedCategory != 'Tümü' && category != _selectedCategory) {
              return false;
            }

            if (_showOnlyOpen && f['status'] == 'Çözüldü') return false;
            if (_showOnlyFollowed && f['is_followed'] != true) return false;

            if (query.isNotEmpty) {
              final title = (f['title'] ?? '').toString().toLowerCase();
              final description = (f['description'] ?? '')
                  .toString()
                  .toLowerCase();
              if (!title.contains(query) && !description.contains(query)) {
                return false;
              }
            }
            return true;
          })
          .map((f) => f['id'].toString())
          .toSet();

      _displayedMarkers = _allFaultMarkers
          .where((m) => filteredIds.contains(m.markerId.value))
          .toSet();

      if (_userLocationMarker != null) {
        _displayedMarkers.add(_userLocationMarker!);
      }
    });
  }

  String _calculateTimeAgo(String? dateString) {
    if (dateString == null) return '';
    String rawDate = dateString.replaceAll('Z', '').replaceAll('+00:00', '');
    final date = DateTime.parse(rawDate);
    final now = DateTime.now();

    final diff = now.difference(date);

    if (diff.inDays > 7) return "${date.day}.${date.month}.${date.year}";
    if (diff.inDays >= 1) return "${diff.inDays} gün önce";
    if (diff.inHours >= 1) return "${diff.inHours} sa. önce";
    if (diff.inMinutes >= 1) return "${diff.inMinutes} dk. önce";
    return "Az önce";
  }

  Future<void> _launchNavigation(double lat, double lng) async {
    final Uri url = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _goToMyLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position pos = await Geolocator.getCurrentPosition();
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 16),
      ),
    );

    setState(() {
      _userLocationMarker = Marker(
        markerId: const MarkerId('user_loc'),
        position: LatLng(pos.latitude, pos.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: "Konumunuz"),
        zIndex: 2,
      );
      _displayedMarkers.add(_userLocationMarker!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kUniversityCamera,
            markers: _displayedMarkers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
            onMapCreated: (c) {
              if (!_controller.isCompleted) _controller.complete(c);
              if (widget.initialFocusFault != null) {
                _focusOnFault(widget.initialFocusFault!);
              }
            },
            onTap: (_) {
              setState(() {
                _selectedFault = null;
                FocusScope.of(context).unfocus();
              });
            },
          ),

          Positioned(
            top: -40,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.cardShadow,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: (val) {
                          _searchQuery = val;
                          _applyFilters();
                        },
                        decoration: InputDecoration(
                          hintText: "Bildirim ara...",
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textHint,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.primary,
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _applyFilters();
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _categories.contains(_selectedCategory)
                                    ? _selectedCategory
                                    : 'Tümü',
                                isExpanded: true,
                                dropdownColor: Colors.white,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: AppColors.primary,
                                ),
                                style: GoogleFonts.inter(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedCategory = newValue;
                                      _applyFilters();
                                    });
                                  }
                                },
                                items: _categories
                                    .map<DropdownMenuItem<String>>((
                                      String value,
                                    ) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(
                                          value,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    })
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildSquareFilter(
                          icon: Icons.check_circle_outline,
                          isSelected: _showOnlyOpen,
                          color: AppColors.error,
                          bgColor: const Color(0xFFFFEBEE),
                          onTap: () => setState(() {
                            _showOnlyOpen = !_showOnlyOpen;
                            _applyFilters();
                          }),
                        ),
                        const SizedBox(width: 8),
                        _buildSquareFilter(
                          icon: Icons.bookmark_border,
                          isSelected: _showOnlyFollowed,
                          color: AppColors.primary,
                          bgColor: const Color(0xFFE3F2FD),
                          onTap: () => setState(() {
                            _showOnlyFollowed = !_showOnlyFollowed;
                            _applyFilters();
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_selectedFault == null)
            Positioned(left: 16, top: 130, child: _buildLegend()),

          if (_selectedFault != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: MapPinCard(
                title: _selectedFault!['title'] ?? 'Başlıksız',
                description: _selectedFault!['description'] ?? '',
                status: _selectedFault!['status'] ?? 'Açık',
                department:
                    _selectedFault!['category'] ??
                    _selectedFault!['department'] ??
                    'Genel',
                timeAgo: _calculateTimeAgo(_selectedFault!['created_at']),
                onClose: () => setState(() => _selectedFault = null),
                onDetail: () async {
                  final deletedFaultId = _selectedFault!['id']; // ID'yi sakla

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          NotificationDetailScreen(faultData: _selectedFault!),
                    ),
                  );

                  // Silme yapıldıysa
                  if (result is Map && result['deleted'] == true) {
                    debugPrint("🔄 Harita verisi ANLIK güncelleniyor...");

                    if (mounted) {
                      // 1. Lokal state'ten hemen kaldır (ANLIK ETKİ)
                      setState(() {
                        _faultsData.removeWhere(
                          (f) => f['id'] == deletedFaultId,
                        );
                        _selectedFault = null; // Seçili fault'u temizle
                      });

                      // 2. Marker'ları yeniden oluştur
                      await _generateMarkers();

                      // 3. Stream zaten güncelleme yapacak, ama garantiye alalım
                      _faultsSubscription?.cancel();
                      _listenToFaults();
                    }
                  } else {
                    setState(() => _selectedFault = null);
                  }
                },
                onNavigate: () {
                  final lat = _selectedFault!['latitude'];
                  final lng = _selectedFault!['longitude'];
                  if (lat != null && lng != null) _launchNavigation(lat, lng);
                },
              ),
            ),

          if (_selectedFault == null)
            Positioned(
              bottom: 24,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    heroTag: 'my_loc',
                    onPressed: _goToMyLocation,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton.extended(
                    heroTag: 'add_fault',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddFaultScreen(),
                        ),
                      );
                    },
                    backgroundColor: AppColors.primary,
                    icon: const Icon(
                      Icons.add_a_photo_outlined,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Bildirim Yap',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSquareFilter({
    required IconData icon,
    required bool isSelected,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.5) : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: isSelected ? color : Colors.grey[600],
          size: 24,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FloatingActionButton.small(
          heroTag: 'legend_toggle',
          backgroundColor: Colors.white,
          elevation: 4,
          onPressed: () => setState(() => _isLegendVisible = !_isLegendVisible),
          child: Icon(
            _isLegendVisible ? Icons.layers_clear : Icons.layers,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isLegendVisible ? 125 : 0,
          width: _isLegendVisible ? 140 : 0,
          padding: _isLegendVisible
              ? const EdgeInsets.all(12)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: _isLegendVisible
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "DURUM RENKLERİ",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                      const Divider(height: 12),
                      _buildLegendItem("Açık", AppColors.error),
                      _buildLegendItem("İnceleniyor", AppColors.warning),
                      _buildLegendItem("Çözüldü", AppColors.success),
                    ],
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.location_on, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
