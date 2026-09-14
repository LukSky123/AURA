import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../domain.dart';
import '../../theme/aura_theme.dart';

class Screen3Contacts extends StatefulWidget {
  const Screen3Contacts({
    super.key,
    required this.initialContacts,
    required this.onNext,
  });

  final List<TrustedContact> initialContacts;
  final ValueChanged<List<TrustedContact>> onNext;

  @override
  State<Screen3Contacts> createState() => _Screen3ContactsState();
}

class _Screen3ContactsState extends State<Screen3Contacts> {
  late final List<TrustedContact> _contacts;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _showProUpsell = false;

  @override
  void initState() {
    super.initState();
    _contacts = List.from(widget.initialContacts);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _addContact() {
    if (_contacts.length >= 2) {
      setState(() => _showProUpsell = true);
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) return;

    setState(() {
      _contacts.add(TrustedContact(
        id: const Uuid().v4(),
        name: name,
        phone: phone,
      ));
      _nameController.clear();
      _phoneController.clear();
    });
  }

  void _removeContact(int index) {
    setState(() {
      _contacts.removeAt(index);
      _showProUpsell = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool canProceed = _contacts.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AuraColors.surface,
                          border: Border.all(
                            color: AuraColors.cyan.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.contact_emergency_rounded,
                            color: AuraColors.cyan,
                            size: 44,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        'Emergency Circle Setup',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'AURA automatically dispatches your live GPS coordinates to these contacts when threat acoustics are detected.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AuraColors.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Hard block notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: canProceed
                            ? AuraColors.cyan.withValues(alpha: 0.08)
                            : AuraColors.crimson.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: canProceed
                              ? AuraColors.cyan.withValues(alpha: 0.3)
                              : AuraColors.crimson.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            canProceed ? Icons.check_circle_outline : Icons.error_outline_rounded,
                            color: canProceed ? AuraColors.cyan : AuraColors.crimson,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              canProceed
                                  ? 'Circle active: ${_contacts.length} of 2 contacts configured (Free tier).'
                                  : 'Required: You must add at least 1 emergency contact to activate protection.',
                              style: TextStyle(
                                color: canProceed ? AuraColors.cyan : AuraColors.crimson,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Existing Contacts List
                    if (_contacts.isNotEmpty) ...[
                      const Text(
                        'Configured Contacts',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _contacts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final c = _contacts[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AuraColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AuraColors.cyan.withValues(alpha: 0.15),
                                  child: Text(
                                    c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: AuraColors.cyan,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        c.phone,
                                        style: const TextStyle(
                                          color: AuraColors.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white38),
                                  onPressed: () => _removeContact(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Add Contact Inputs (if < 2)
                    if (_contacts.length < 2) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AuraColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add Emergency Contact',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Contact Name (e.g. Mum, Sister)',
                                hintStyle: const TextStyle(color: AuraColors.onSurfaceVariant, fontSize: 12),
                                filled: true,
                                fillColor: AuraColors.surfaceLow,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Phone Number (+234...)',
                                hintStyle: const TextStyle(color: AuraColors.onSurfaceVariant, fontSize: 12),
                                filled: true,
                                fillColor: AuraColors.surfaceLow,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed: _addContact,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('ADD TO EMERGENCY CIRCLE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AuraColors.surfaceHigh,
                                  foregroundColor: AuraColors.cyan,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Pro Upsell banner (if at max 2 contacts)
                    if (_contacts.length >= 2 || _showProUpsell) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AuraColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AuraColors.cyan.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'AURA Pro Supports 5 Contacts',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Upgrade to Pro at the end of onboarding for unlimited cloud SMS and family sirens.',
                                    style: TextStyle(color: AuraColors.onSurfaceVariant, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Continue Button (HARD BLOCKED if contacts is empty)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: canProceed ? () => widget.onNext(_contacts) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canProceed ? AuraColors.cyan : AuraColors.surfaceHigh,
                  foregroundColor: canProceed ? AuraColors.background : Colors.white24,
                  disabledBackgroundColor: AuraColors.surfaceHigh,
                  disabledForegroundColor: Colors.white24,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'CONTINUE',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
