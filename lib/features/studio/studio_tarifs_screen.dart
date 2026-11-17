import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/bko_toast.dart';

class StudioTarifsScreen extends StatefulWidget {
  const StudioTarifsScreen({super.key});

  @override
  State<StudioTarifsScreen> createState() => _StudioTarifsScreenState();
}

class _StudioTarifsScreenState extends State<StudioTarifsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _myBookings = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final offersRes = await BkoApi.get('/studio-offers');
      final offersList = offersRes is Map && offersRes['data'] is List
          ? (offersRes['data'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      List<Map<String, dynamic>> bookingsList = [];
      try {
        final bookingsRes = await BkoApi.get('/studio/bookings/my');
        if (bookingsRes is Map && bookingsRes['data'] is List) {
          bookingsList = (bookingsRes['data'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _offers = offersList;
        _myBookings = bookingsList;
      });
    } catch (e) {
      if (mounted) {
        BkoToast.showError(context, title: 'Erreur', message: 'Impossible de charger les tarifs studio.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openBookingSheet(Map<String, dynamic> offer) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: BkoTheme.getBgSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _MobileStudioBookingSheet(
        offer: offer,
        onBooked: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = BkoTheme.getBgObsidian(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);
    final textPrimary = BkoTheme.getTextPrimary(context);
    final textSecondary = BkoTheme.getTextSecondary(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('Tarifs & Studio Bamako'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: BkoTheme.goldAccent))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: BkoTheme.goldAccent,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Formules & Services Studio',
                    style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Micros Shure SM7B, caméras 4K et ingénieur du son dédié à Bamako.',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ..._offers.map((offer) {
                    final features = offer['features'] is List
                        ? (offer['features'] as List).map((e) => e.toString()).toList()
                        : <String>[];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: offer['isPopular'] == true ? BkoTheme.goldAccent : border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  offer['name']?.toString() ?? 'Offre Studio',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                '${offer['price'] ?? ''} ${offer['unit'] ?? 'FCFA'}',
                                style: const TextStyle(
                                  color: BkoTheme.goldAccent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (offer['description'] != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              offer['description'].toString(),
                              style: TextStyle(color: textSecondary, fontSize: 12),
                            ),
                          ],
                          if (features.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ...features.take(4).map(
                                  (f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        const Icon(IconsaxPlusLinear.tick_circle,
                                            color: BkoTheme.goldAccent, size: 15),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            f,
                                            style: TextStyle(color: textPrimary, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => _openBookingSheet(offer),
                              style: FilledButton.styleFrom(
                                backgroundColor: BkoTheme.goldAccent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Réserver cette formule',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_myBookings.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Mes réservations studio',
                      style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    ..._myBookings.map((b) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    b['reference']?.toString() ?? '',
                                    style: const TextStyle(
                                      color: BkoTheme.goldAccent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    b['status']?.toString() ?? 'PENDING',
                                    style: TextStyle(color: textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${b['preferredDate'] ?? 'Date à convenir'} • ${b['timeSlot'] ?? ''} • ${b['studioLocation'] ?? ''}',
                                style: TextStyle(color: textPrimary, fontSize: 12),
                              ),
                              if (b['estimatedPrice'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  b['estimatedPrice'].toString(),
                                  style: const TextStyle(
                                    color: BkoTheme.goldAccent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
    );
  }
}

class _MobileStudioBookingSheet extends StatefulWidget {
  final Map<String, dynamic> offer;
  final VoidCallback onBooked;

  const _MobileStudioBookingSheet({required this.offer, required this.onBooked});

  @override
  State<_MobileStudioBookingSheet> createState() => _MobileStudioBookingSheetState();
}

class _MobileStudioBookingSheetState extends State<_MobileStudioBookingSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _timeSlot = 'MATIN';
  String _studioLocation = 'STUDIO_PRINCIPAL';
  List<String> _bookedSlots = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String get _isoDate {
    final y = _selectedDate.year.toString().padLeft(4, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final d = _selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _checkAvailability() async {
    try {
      final res = await BkoApi.get(
        '/studio/bookings/availability?date=$_isoDate&studioLocation=$_studioLocation',
      );
      if (!mounted) return;
      final list = res is Map && res['data'] is Map && res['data']['bookedSlots'] is List
          ? (res['data']['bookedSlots'] as List).map((e) => e.toString()).toList()
          : <String>[];
      setState(() => _bookedSlots = list);
    } catch (_) {}
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (name.length < 2 || !email.contains('@') || digits.length < 8) {
      BkoToast.showError(
        context,
        title: 'Champs requis',
        message: 'Veuillez renseigner votre nom, email et numéro à 8 chiffres.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final needType = (widget.offer['name']?.toString().toLowerCase().contains('express') ?? false)
          ? 'VIDEO_PODCAST'
          : 'AUDIO_PODCAST';
      await BkoApi.post('/studio/bookings', {
        'needType': needType,
        'offerId': widget.offer['id'],
        'contactName': name,
        'email': email,
        'phone': digits.substring(0, digits.length > 8 ? 8 : digits.length),
        'countryCode': '+223',
        'preferredDate': _isoDate,
        'timeSlot': _timeSlot,
        'durationHours': 2,
        'studioLocation': _studioLocation,
        'estimatedPrice': '${widget.offer['price'] ?? ''} ${widget.offer['unit'] ?? 'FCFA'}',
      });
      if (!mounted) return;
      BkoHaptics.tapDown();
      Navigator.of(context).pop();
      widget.onBooked();
      BkoToast.showSuccess(
        context,
        title: 'Demande enregistrée',
        message: 'Votre créneau studio a été transmis à l\'équipe !',
      );
    } catch (e) {
      if (!mounted) return;
      BkoToast.showError(context, title: 'Créneau indisponible', message: e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final textPrimary = BkoTheme.getTextPrimary(context);
    final border = BkoTheme.getBorderSubtle(context);
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Réserver : ${widget.offer['name'] ?? 'Studio'}',
              style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 120)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                  _checkAvailability();
                }
              },
              icon: const Icon(IconsaxPlusLinear.calendar, color: BkoTheme.goldAccent, size: 18),
              label: Text('Date : $_isoDate', style: TextStyle(color: textPrimary)),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _studioLocation,
              decoration: InputDecoration(
                labelText: 'Espace studio',
                filled: true,
                fillColor: surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'STUDIO_PRINCIPAL', child: Text('Studio Principal / Annexe')),
                DropdownMenuItem(value: 'SALLE_CONFERENCE', child: Text('Salle de Conférence')),
                DropdownMenuItem(value: 'SALLE_VIP', child: Text('Salle VIP')),
                DropdownMenuItem(value: 'EXTERIEUR', child: Text('Extérieur (Bamako)')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _studioLocation = v);
                  _checkAvailability();
                }
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _timeSlot,
              decoration: InputDecoration(
                labelText: 'Créneau horaire',
                filled: true,
                fillColor: surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'MATIN', child: Text('Matin (09h00 - 12h00)')),
                DropdownMenuItem(value: 'APRES_MIDI', child: Text('Après-midi (14h00 - 17h00)')),
                DropdownMenuItem(value: 'SOIREE', child: Text('Soirée (18h00 - 21h00)')),
                DropdownMenuItem(value: 'JOURNEE', child: Text('Journée complète')),
              ].map((item) {
                final booked = _bookedSlots.contains(item.value);
                return DropdownMenuItem<String>(
                  value: item.value,
                  enabled: !booked,
                  child: Text(booked ? '${(item.child as Text).data} (Réservé)' : (item.child as Text).data ?? ''),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null && !_bookedSlots.contains(v)) setState(() => _timeSlot = v);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameCtrl,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Votre nom *',
                filled: true,
                fillColor: surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Email *',
                filled: true,
                fillColor: surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 11,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Téléphone Mali (+223, 8 chiffres) *',
                hintText: '66 00 00 00',
                filled: true,
                fillColor: surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: BkoTheme.goldAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _submitting ? 'Envoi...' : 'Confirmer la demande',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
