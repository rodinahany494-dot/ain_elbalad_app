import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _SearchResult {
  final LatLng position;
  final String address;

  const _SearchResult({
    required this.position,
    required this.address,
  });
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _cairoLocation = LatLng(30.0444, 31.2357);
  static const String _nominatimSearchUrl =
      'https://nominatim.openstreetmap.org/search';

  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final Set<Marker> _markers = {};

  Timer? _searchDebounce;
  bool _isListening = false;
  bool _isSearching = false;
  bool _isFetchingCurrentLocation = false;
  LatLng? _selectedPoint;
  String? _selectedAddress;
  LatLng? _searchBiasCenter;
  String? _searchBiasArea;
  List<_SearchResult> _results = [];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _speech.stop();
    _mapController?.dispose();
    super.dispose();
  }

  String _formatAddress(Placemark place, String fallback) {
    final parts = <String?>[
      place.street,
      place.subLocality,
      place.locality,
      place.administrativeArea,
      place.country,
    ]
        .where((part) => part != null && part.trim().isNotEmpty)
        .map((part) => part!.trim())
        .toList();
    if (parts.isEmpty) return fallback;
    return parts.join(', ');
  }

  Future<void> _animateAndSelect(
    LatLng target,
    String address, {
    bool pop = false,
  }) async {
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, 16),
    );

    if (!mounted) return;
    setState(() {
      _searchController.text = address;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );
      _results = [
        _SearchResult(position: target, address: address),
      ];
      _markers
        ..clear()
        ..add(_buildSelectedMarker(target, address));
      _selectedPoint = target;
      _selectedAddress = address;
    });

    if (pop && mounted) {
      Navigator.pop(context, {
        'address': address,
        'latitude': target.latitude,
        'longitude': target.longitude,
      });
    }
  }

  Future<void> _searchLocations(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final effectiveQuery = _buildSearchQuery(q);
      final queryParameters = <String, String>{
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '10',
        'q': effectiveQuery,
        'countrycodes': 'eg',
        'accept-language': 'ar',
      };

      if (_searchBiasCenter != null) {
        final delta = 0.8;
        queryParameters['viewbox'] =
            '${_searchBiasCenter!.longitude - delta},${_searchBiasCenter!.latitude + delta},${_searchBiasCenter!.longitude + delta},${_searchBiasCenter!.latitude - delta}';
      }

      final uri = Uri.parse(_nominatimSearchUrl).replace(
        queryParameters: queryParameters,
      );

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'ain_elbalad_app/1.0',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Search failed');
      }

      final raw = jsonDecode(response.body);
      final items = raw is List ? raw : const <dynamic>[];
      final results = <_SearchResult>[];

      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        final displayName = item['display_name']?.toString() ?? q;
        if (lat == null || lon == null) continue;
        results.add(
          _SearchResult(
            position: LatLng(lat, lon),
            address: displayName,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      if (!mounted) return;
      setState(() {
        _results = [];
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find this location.')),
      );
    }
  }

  void _scheduleSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchLocations(query);
    });
  }

  String _buildSearchQuery(String query) {
    final parts = <String>[query];
    if (_searchBiasArea != null && _searchBiasArea!.trim().isNotEmpty) {
      parts.add(_searchBiasArea!.trim());
    }
    parts.add('Egypt');
    return parts.join(', ');
  }

  Future<void> _useCurrentLocation() async {
    if (_isFetchingCurrentLocation) return;

    setState(() => _isFetchingCurrentLocation = true);

    try {
      debugPrint('Current location button tapped');
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        if (!mounted) return;
        setState(() => _isFetchingCurrentLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('Location permission before request: $permission');
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('Location permission after request: $permission');
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        if (!mounted) return;
        setState(() => _isFetchingCurrentLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required.')),
        );
        return;
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() => _isFetchingCurrentLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required.')),
        );
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            forceLocationManager: true,
            timeLimit: Duration(seconds: 12),
          ),
        ).timeout(const Duration(seconds: 12));
      } catch (e) {
        debugPrint('Primary location fetch failed: $e');
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        throw Exception('No location available');
      }

      final target = LatLng(position.latitude, position.longitude);

      String address = 'Current location';
      String? areaLabel;
      try {
        final places = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (places.isNotEmpty) {
          address = _formatAddress(places.first, address);
          areaLabel = places.first.administrativeArea?.trim().isNotEmpty == true
              ? places.first.administrativeArea!.trim()
              : places.first.locality?.trim();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _searchBiasCenter = target;
          _searchBiasArea = areaLabel;
        });
      }

      await _animateAndSelect(target, address);
    } catch (e) {
      debugPrint('Current location error: $e');
      if (!mounted) return;
      final message = e.toString().contains('No location available')
          ? 'No GPS fix yet. Please wait a moment and try again.'
          : 'Could not get current location.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isFetchingCurrentLocation = false);
      }
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      _searchLocations(_searchController.text);
      return;
    }

    final available = await _speech.initialize();
    if (!mounted) return;
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition is not available.')),
      );
      return;
    }

    setState(() => _isListening = true);
    _speech.listen(
      localeId: 'ar_EG',
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _searchController.text = result.recognizedWords;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: _searchController.text.length),
          );
        });
      },
    );
  }

  Future<void> _selectResult(_SearchResult result) async {
    if (!mounted) return;
    Navigator.pop(context, {
      'address': result.address,
      'latitude': result.position.latitude,
      'longitude': result.position.longitude,
    });
  }

  Future<void> _updateSelectionFromPoint(LatLng point) async {
    String address = 'Selected location';
    try {
      final places = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (places.isNotEmpty) {
        address = _formatAddress(places.first, address);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _selectedPoint = point;
      _selectedAddress = address;
      _searchController.text = address;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );
      _markers
        ..clear()
        ..add(_buildSelectedMarker(point, address));
    });
  }

  Marker _buildSelectedMarker(LatLng point, String address) {
    return Marker(
      markerId: const MarkerId('selected'),
      position: point,
      infoWindow: InfoWindow(title: address),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRed,
      ),
      draggable: true,
      onDragEnd: (newPosition) async {
        await _updateSelectionFromPoint(newPosition);
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newPosition, 16),
        );
      },
    );
  }

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  void _goTrack() {
    Navigator.pushNamed(context, '/track');
  }

  void _goCreate() {
    Navigator.pushNamed(context, '/create');
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _cairoLocation,
                zoom: 14,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              markers: _markers,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              myLocationEnabled: true,
            ),
          ),
          Positioned(
            top: 45,
            left: 15,
            right: 15,
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    if (_selectedPoint != null && _selectedAddress != null) {
                      Navigator.pop(context, {
                        'address': _selectedAddress,
                        'latitude': _selectedPoint!.latitude,
                        'longitude': _selectedPoint!.longitude,
                      });
                      return;
                    }
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 24,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      size: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 18,
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _scheduleSearch,
                            onSubmitted: _searchLocations,
                            textDirection: TextDirection.rtl,
                            decoration: const InputDecoration(
                              hintText: 'search here',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _toggleListening,
                          child: Icon(
                            Icons.mic,
                            color: _isListening
                                ? Colors.red
                                : const Color(0xFF0A3D91),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isSearching || _results.isNotEmpty)
            Positioned(
              top: 85,
              left: 15,
              right: 15,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x20000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.location_on,
                              color: Color(0xFF0A3D91),
                            ),
                            title: Text(
                              item.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectResult(item),
                          );
                        },
                      ),
              ),
            ),
          Positioned(
            bottom: 120,
            right: 15,
            child: GestureDetector(
              onTap: _useCurrentLocation,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isFetchingCurrentLocation
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF0A3D91),
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.my_location,
                            color: Color(0xFF0A3D91),
                            size: 16,
                          ),
                  ),
                ),
              ),
            ),
          ),
          if (!keyboardOpen)
            Positioned(
              bottom: 25,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  width: 343,
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A3D91),
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 12),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                    GestureDetector(
                      onTap: _useCurrentLocation,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFA500),
                          shape: BoxShape.circle,
                        ),
                        child: _isFetchingCurrentLocation
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.location_on_outlined,
                                color: Colors.white,
                                size: 26,
                              ),
                      ),
                    ),
                      GestureDetector(
                        onTap: _goHome,
                        child: const Icon(
                          Icons.home_outlined,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                      GestureDetector(
                        onTap: _goTrack,
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                      GestureDetector(
                        onTap: _goCreate,
                        child: const Icon(
                          Icons.note_add_outlined,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
