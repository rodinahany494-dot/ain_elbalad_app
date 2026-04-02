import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import 'app_session.dart';

enum _NavItem { location, home, track, create }

Widget _buildUnifiedNavBar({
  required _NavItem active,
  required VoidCallback onLocation,
  required VoidCallback onHome,
  required VoidCallback onTrack,
  required VoidCallback onCreate,
}) {
  const blue = Color(0xFF004E98);
  const activeYellow = Color(0xFFFFB200);

  Widget iconItem(IconData icon, _NavItem item, VoidCallback onTap) {
    final isActive = item == active;
    if (isActive) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: activeYellow,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      );
    }
    return IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(icon, color: Colors.white, size: 24),
    );
  }

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Center(
      child: SizedBox(
        width: 343,
        height: 48,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: blue,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              iconItem(Icons.location_on_outlined, _NavItem.location, onLocation),
              iconItem(Icons.home, _NavItem.home, onHome),
              iconItem(Icons.local_shipping_outlined, _NavItem.track, onTrack),
              iconItem(Icons.note_add_outlined, _NavItem.create, onCreate),
            ],
          ),
        ),
      ),
    ),
  );
}

Map<String, dynamic> _extractDataMap(dynamic body) {
  if (body is! Map<String, dynamic>) {
    throw Exception('Invalid response format');
  }
  if (body['status'] == false) {
    final msg = body['message']?.toString() ?? 'Request failed';
    throw Exception(msg);
  }
  final data = body['data'];
  if (data is Map<String, dynamic>) return data;
  if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
    return data.first as Map<String, dynamic>;
  }
  return <String, dynamic>{};
}

String? _normalizeImageUrl(dynamic value) {
  final url = value?.toString() ?? '';
  if (url.isEmpty) return null;
  if (url.startsWith('http://127.0.0.1') || url.startsWith('http://localhost')) {
    return url.replaceFirst(RegExp(r'^http://(127\.0\.0\.1|localhost)(:\d+)?'), ApiConfig.baseUrl);
  }
  if (url.startsWith('/')) return '${ApiConfig.baseUrl}$url';
  return url;
}

class ReportSummary {
  final int reportId;
  final String title;
  final String description;
  final String locationAddress;
  final String currentStatus;
  final String reportDate;
  final String? photoUrl;
  final String? department;

  ReportSummary({
    required this.reportId,
    required this.title,
    required this.description,
    required this.locationAddress,
    required this.currentStatus,
    required this.reportDate,
    required this.photoUrl,
    this.department,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    final location = (json['location_address'] ??
            json['location'] ??
            json['address'] ??
            json['area'] ??
            '')
        .toString();
    final status = (json['current_status'] ?? json['status'] ?? '').toString();
    final date = (json['report_date'] ?? json['date'] ?? '').toString();
    return ReportSummary(
      reportId: (json['report_id'] ?? 0) as int,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      locationAddress: location,
      currentStatus: status,
      reportDate: date,
      photoUrl: _normalizeImageUrl(json['photo_url'] ?? json['photo']),
      department: (json['department'] ?? json['category'])?.toString(),
    );
  }
}

class StatusUpdateItem {
  final String newStatus;
  final String content;
  final String date;
  final String time;
  final String timestamp;

  StatusUpdateItem({
    required this.newStatus,
    required this.content,
    required this.date,
    required this.time,
    required this.timestamp,
  });

  factory StatusUpdateItem.fromJson(Map<String, dynamic> json) {
    return StatusUpdateItem(
      newStatus: (json['status'] ?? json['new_status'] ?? '').toString(),
      content: (json['info'] ?? json['content'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
      timestamp: (json['timestamp'] ?? json['date'] ?? '').toString(),
    );
  }
}

class ReportDetails {
  final int reportId;
  final String title;
  final String description;
  final String reportType;
  final String locationAddress;
  final String latitude;
  final String longitude;
  final String priorityLevel;
  final String currentStatus;
  final String reportDate;
  final String? photoUrl;
  final List<StatusUpdateItem> statusUpdates;
  final String? department;

  ReportDetails({
    required this.reportId,
    required this.title,
    required this.description,
    required this.reportType,
    required this.locationAddress,
    required this.latitude,
    required this.longitude,
    required this.priorityLevel,
    required this.currentStatus,
    required this.reportDate,
    required this.photoUrl,
    required this.statusUpdates,
    this.department,
  });

  factory ReportDetails.fromJson(Map<String, dynamic> json) {
    final detailsJson = (json['details'] is Map<String, dynamic>)
        ? json['details'] as Map<String, dynamic>
        : json;
    final timeline = (json['timeline'] as List<dynamic>? ??
            detailsJson['timeline'] as List<dynamic>? ??
            detailsJson['status_updates'] as List<dynamic>? ??
            [])
        .map((e) => StatusUpdateItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return ReportDetails(
      reportId: (detailsJson['report_id'] ?? 0) as int,
      title: (detailsJson['title'] ?? '').toString(),
      description: (detailsJson['description'] ?? '').toString(),
      reportType: (detailsJson['report_type'] ?? '').toString(),
      locationAddress: (detailsJson['location_address'] ?? '').toString(),
      latitude: (detailsJson['latitude'] ?? '').toString(),
      longitude: (detailsJson['longitude'] ?? '').toString(),
      priorityLevel: (detailsJson['priority_level'] ?? '').toString(),
      currentStatus: (detailsJson['current_status'] ?? '').toString(),
      reportDate: (detailsJson['report_date'] ?? '').toString(),
      photoUrl: _normalizeImageUrl(detailsJson['photo_url'] ?? detailsJson['photo']),
      statusUpdates: timeline,
      department: (detailsJson['department'] ?? detailsJson['category'] ?? detailsJson['ai_category'])?.toString(),
    );
  }
}

Future<Map<String, String>> _authHeaders({bool isMultipart = false}) async {
  final token = await AppSession.token();
  final headers = <String, String>{
    'Accept': 'application/json',
  };
  if (!isMultipart) {
    headers['Content-Type'] = 'application/json';
  }
  if (token != null && token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  }
  return headers;
}

String _formatDate(String iso) {
  if (iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day.toString().padLeft(2, '0')} '
        '${_monthName(dt.month)} ${dt.year}';
  } catch (_) {
    return iso;
  }
}

String _formatTime(String iso) {
  if (iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  } catch (_) {
    return '';
  }
}

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (month < 1 || month > 12) return '';
  return months[month - 1];
}

// ====================================================================
// 8. Create Ticket Screen
// ====================================================================
class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  static const double fsBody = 14; // Helper text
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  File? _image;
  String _locationAddress = 'Unknown';
  double _latitude = 0;
  double _longitude = 0;
  bool _isListening = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 85);
    if (!mounted) return;
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
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
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _descriptionController.text = result.recognizedWords;
          _descriptionController.selection = TextSelection.fromPosition(
            TextPosition(offset: _descriptionController.text.length),
          );
        });
      },
    );
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a description.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final uri = Uri.parse(ApiConfig.createReport);
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(await _authHeaders(isMultipart: true));
      request.fields['title'] = description;
      request.fields['description'] = description;
      request.fields['latitude'] = _latitude.toString();
      request.fields['longitude'] = _longitude.toString();
      request.fields['location_address'] = _locationAddress;
      if (_image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', _image!.path));
      }
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _showSuccessDialog();
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit ticket.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit ticket.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: SizedBox(
            width: 260,
            height: 280,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: Color(0xFF3CCB37),
                    child: Icon(Icons.check, color: Colors.white, size: 44),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Your ticket has been\nsubmitted successfully',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMap() async {
    final result = await Navigator.pushNamed(context, '/map');
    if (!mounted || result is! Map) return;

    final address = result['address']?.toString();
    final latitude = result['latitude'];
    final longitude = result['longitude'];

    setState(() {
      if (address != null && address.isNotEmpty) {
        _locationAddress = address;
      }
      if (latitude is num) {
        _latitude = latitude.toDouble();
      }
      if (longitude is num) {
        _longitude = longitude.toDouble();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const double cardWidth = 343;
    const double cardHeight = 286;
    const double buttonWidth = 343;
    const double buttonHeight = 96;
    const Color brandBlue = Color(0xFF004AAD);
    const Color accentOrange = Color(0xFFFFA500);
    const Color uploadBlue = Color(0xFF2A6BA9);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create My Ticket',
          style: TextStyle(color: Color(0xFF004AAD), fontSize: 24),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Center(
              child: Container(
                width: cardWidth,
                height: cardHeight,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.zero,
                ),
                child: _image == null
                    ? const Icon(Icons.camera_alt_outlined,
                        size: 90, color: Colors.white)
                    : ClipRRect(
                        borderRadius: BorderRadius.zero,
                        child: Image.file(_image!, fit: BoxFit.cover),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Adding a photo is optional',
              style: TextStyle(color: Color(0xFF5F5F5F), fontSize: 12),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: buttonWidth,
              height: buttonHeight,
              child: ElevatedButton(
                onPressed: _showImageSourceSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: uploadBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Upload Photo',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Icon(Icons.camera_alt_outlined,
                        color: Colors.white, size: 40),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _openMap,
                  child: const Icon(Icons.location_on, color: brandBlue, size: 24),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 311,
                  height: 40,
                  child: TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText: 'Add description',
                      hintStyle: const TextStyle(fontSize: 14),
                      prefixIcon: IconButton(
                        onPressed: _toggleListening,
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? brandBlue : accentOrange,
                          size: 24,
                        ),
                      ),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.send,
                            color: _isSubmitting ? Colors.grey : brandBlue),
                        onPressed: _isSubmitting ? null : _submitReport,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(0),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(0),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(0),
                        borderSide:
                            const BorderSide(color: brandBlue, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),
            ],
          ),
        ),
    );
  }
}
// ====================================================================
// 9. My Tickets Screen
// ====================================================================
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  late Future<List<ReportSummary>> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _ticketsFuture = _fetchTickets();
  }

  Future<List<ReportSummary>> _fetchTickets() async {
    final uri = Uri.parse(ApiConfig.myTickets);
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to load tickets');
    }
    final body = jsonDecode(res.body);
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ReportSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Tickets',
          style: TextStyle(color: Color(0xFF004AAD), fontSize: 24), // AppBar title
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<ReportSummary>>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load tickets: ${snapshot.error}'),
            );
          }
          final tickets = snapshot.data ?? [];
          if (tickets.isEmpty) {
            return const Center(child: Text('No tickets yet'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final t = tickets[index];
              final issueName =
                  (t.department?.isNotEmpty == true) ? t.department! : t.title;
              String show(String v) => v.trim().isEmpty ? '-' : v;
              final hasPhoto = t.photoUrl != null && t.photoUrl!.isNotEmpty;
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TicketDetailsScreen(
                      reportId: t.reportId,
                      issueNameOverride: t.department,
                    ),
                  ),
                ),
                child: Container(
                  width: 343,
                  height: 143,
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCDCEA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: hasPhoto
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 127,
                              height: 127,
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  t.photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Container(color: Colors.grey[400]),
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: SizedBox(
                                height: 127,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      show(issueName),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      show(t.locationAddress),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'ID #${t.reportId}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  Text(
                                    show(t.currentStatus),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    show(
                                      '${_formatDate(t.reportDate)} - ${_formatTime(t.reportDate)}',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black,
                                    ),
                                  ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              show(issueName),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              show(t.locationAddress),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'ID #${t.reportId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              show(t.currentStatus),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              show(
                                '${_formatDate(t.reportDate)} - ${_formatTime(t.reportDate)}',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ====================================================================
// 10. Ticket Details Screen
// ====================================================================
class TicketDetailsScreen extends StatefulWidget {
  final int reportId;
  final String? issueNameOverride;
  const TicketDetailsScreen({
    super.key,
    required this.reportId,
    this.issueNameOverride,
  });

  @override
  State<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _TicketDetailsScreenState extends State<TicketDetailsScreen> {
  final Color brandBlue = const Color(0xFF004E98);
  final Color lightBlueCard = const Color(0xFFCCDCEA);
  late Future<ReportDetails> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _fetchDetails();
  }

  Future<ReportDetails> _fetchDetails() async {
    final uri = Uri.parse(ApiConfig.trackReport(widget.reportId));
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to load ticket details');
    }
    final body = jsonDecode(res.body);
    final data = _extractDataMap(body);
    final details = (data['details'] is Map<String, dynamic>)
        ? data['details'] as Map<String, dynamic>
        : data;
    return ReportDetails.fromJson(details);
  }

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  void _goCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTicketScreen()),
    );
  }

  void _goTrack() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackTicketScreen(reportId: widget.reportId),
      ),
    );
  }

  void _showMapNotReady() {
    Navigator.pushNamed(
      context,
      '/map',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Text(
          'Ticket Details',
          style: TextStyle(
            color: brandBlue,
            fontSize: 24,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<ReportDetails>(
              future: _detailsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load details: ${snapshot.error}'),
                  );
                }
                final d = snapshot.data!;
                final issueName = (widget.issueNameOverride?.isNotEmpty == true)
                    ? widget.issueNameOverride!
                    : (d.department?.isNotEmpty == true
                        ? d.department!
                        : (d.title.isNotEmpty ? d.title : '-'));
                final description = d.description.isNotEmpty ? d.description : '-';
                final location = d.locationAddress.isNotEmpty ? d.locationAddress : '-';
                final status = d.currentStatus.isNotEmpty ? d.currentStatus : '-';
                final issueDate = d.reportDate.isNotEmpty
                    ? '${_formatDate(d.reportDate)} - ${_formatTime(d.reportDate)}'
                    : '-';
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Container(
                      width: 343,
                      decoration: BoxDecoration(
                        color: lightBlueCard,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 327,
                                height: 304,
                                color: Colors.grey[300],
                                child: d.photoUrl == null || d.photoUrl!.isEmpty
                                    ? const Icon(Icons.image,
                                        size: 50, color: Colors.white)
                                    : Image.network(d.photoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) {
                                          return const Icon(Icons.image,
                                              size: 50, color: Colors.white);
                                        }),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const Text(
                                'ID',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 24,
                                  color: Color(0xFF000000),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '#${d.reportId}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 20,
                                  color: Color(0xFF404040),
                                ),
                              ),
                            ],
                          ),
                          const Divider(
                              height: 25, thickness: 1, color: Colors.white70),
                          _buildDetailRow('Issue Name :', issueName),
                          _buildDetailRow('Description :', description),
                          _buildDetailRow('Location :', location),
                          _buildDetailRow('Status :', status),
                          _buildDetailRow('Issue Date :', issueDate),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _buildUnifiedNavBar(
            active: _NavItem.home,
            onLocation: _showMapNotReady,
            onHome: _goHome,
            onTrack: _goTrack,
            onCreate: _goCreate,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              color: Color(0xFF000000),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                color: Color(0xFF404040),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Nav bar handled by _buildUnifiedNavBar
}

// ====================================================================
// 11. Track Ticket Screen
// ====================================================================
class TrackTicketScreen extends StatefulWidget {
  final int? reportId;
  const TrackTicketScreen({super.key, this.reportId});

  @override
  State<TrackTicketScreen> createState() => _TrackTicketScreenState();
}

class _TrackTicketScreenState extends State<TrackTicketScreen> {
  final Color primaryBlue = const Color(0xFF004E98);
  final Color lightCardBg = const Color(0xFFD3E3F2);
  final Color accentYellow = const Color(0xFFF9B021);
  Future<ReportDetails>? _trackFuture;
  Future<List<ReportSummary>>? _ticketsFuture;

  @override
  void initState() {
    super.initState();
    if (widget.reportId != null) {
      _trackFuture = _fetchTrack(widget.reportId!);
    } else {
      _trackFuture = _fetchLatestTrack();
    }
  }

  Future<ReportDetails> _fetchLatestTrack() async {
    final tickets = await (_ticketsFuture ??= _fetchTicketsForTrack());
    if (tickets.isEmpty) {
      throw Exception('No tickets yet');
    }
    return _fetchTrack(tickets.first.reportId);
  }

  Future<List<ReportSummary>> _fetchTicketsForTrack() async {
    final uri = Uri.parse(ApiConfig.myTickets);
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to load tickets');
    }
    final body = jsonDecode(res.body);
    if (body is Map<String, dynamic> && body['status'] == false) {
      throw Exception(body['message']?.toString() ?? 'Failed to load tickets');
    }
    if (body is! Map<String, dynamic>) {
      throw Exception('Invalid response format');
    }
    dynamic data = body['data'];
    if (data is Map<String, dynamic> && data['data'] is List) {
      data = data['data'];
    }
    final list = data is List ? data : <dynamic>[];
    return list
        .map((e) => ReportSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ReportDetails> _fetchTrack(int reportId) async {
    final uri = Uri.parse(ApiConfig.trackReport(reportId));
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to load tracking data');
    }
    final body = jsonDecode(res.body);
    final data = _extractDataMap(body);
    return ReportDetails.fromJson(data);
  }

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  void _goCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTicketScreen()),
    );
  }

  void _goTrack() {
    if (widget.reportId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackTicketScreen(reportId: widget.reportId),
      ),
    );
  }

  void _showMapNotReady() {
    Navigator.pushNamed(
      context,
      '/map',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 92,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            "Track My Ticket",
            style: TextStyle(
              color: Color(0xFF004E98),
              fontWeight: FontWeight.bold,
              fontSize: 24,
              fontFamily: 'Roboto',
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<ReportDetails>(
        future: _trackFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load tracking: ${snapshot.error}'),
            );
          }
          final d = snapshot.data!;
          return Column(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Container(
                    width: 343,
                    height: 101,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightCardBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 75,
                            height: 75,
                            color: Colors.white.withOpacity(0.6),
                            child: d.photoUrl == null || d.photoUrl!.isEmpty
                                ? Icon(Icons.image, color: primaryBlue)
                                : Image.network(d.photoUrl!, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                d.title,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                              ),
                              Text(
                                d.locationAddress,
                                style: TextStyle(
                                    color: Colors.grey[800], fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Text("ID ",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  Text("#${d.reportId}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                ],
                              ),
                              Text(
                                _formatDate(d.reportDate),
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 28, left: 50.0, right: 50.0),
                child: Divider(thickness: 1),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  itemCount: d.statusUpdates.length,
                  itemBuilder: (context, index) {
                    final u = d.statusUpdates[index];
                    return _buildStep(
                      u,
                      index,
                      index == d.statusUpdates.length - 1,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Icons.thumb_up_off_alt;
      case 'under review':
        return Icons.search;
      case 'technician assigned':
        return Icons.settings_outlined;
      case 'in progress':
        return Icons.local_shipping_outlined;
      case 'fixed':
        return Icons.check_box_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildStep(StatusUpdateItem update, int index, bool isLast) {
    final day = _formatDate(update.timestamp);
    final time = _formatTime(update.timestamp);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration:
                    BoxDecoration(color: accentYellow, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: VerticalDivider(color: accentYellow, thickness: 1.5),
                ),
            ],
          ),
          const SizedBox(width: 15),
          Icon(_statusIcon(update.newStatus), size: 28, color: primaryBlue),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(update.newStatus,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryBlue)),
                Text(update.content,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 25),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(day,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              Text(time,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.all(15),
      height: 60,
      decoration: BoxDecoration(
          color: primaryBlue, borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            onPressed: _showMapNotReady,
            icon: const Icon(Icons.location_on_outlined, color: Colors.white),
          ),
          IconButton(
            onPressed: _goHome,
            icon: const Icon(Icons.home_outlined, color: Colors.white),
          ),
          InkWell(
            onTap: _goTrack,
            borderRadius: BorderRadius.circular(18),
            child: CircleAvatar(
              backgroundColor: accentYellow,
              radius: 18,
              child: const Icon(Icons.local_shipping,
                  color: Colors.white, size: 20),
            ),
          ),
          IconButton(
            onPressed: _goCreate,
            icon: const Icon(Icons.note_add_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
