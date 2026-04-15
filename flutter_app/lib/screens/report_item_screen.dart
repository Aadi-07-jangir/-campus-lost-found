import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/items_provider.dart';
import '../services/claim_security_service.dart';
import '../utils/theme.dart';
import 'matches_screen.dart';

class ReportItemScreen extends StatefulWidget {
  const ReportItemScreen({super.key});
  @override
  State<ReportItemScreen> createState() => _ReportItemScreenState();
}

class _ReportItemScreenState extends State<ReportItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleC = TextEditingController();
  final _descC = TextEditingController();
  final _locC = TextEditingController();
  final List<TextEditingController> _questionControllers =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> _answerControllers =
      List.generate(3, (_) => TextEditingController());
  String _type = 'lost';
  Uint8List? _imgBytes;
  String? _imgName;
  bool _submitting = false;

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _locC.dispose();
    for (final controller in _questionControllers) {
      controller.dispose();
    }
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(ImageSource src) async {
    try {
      final p = await ImagePicker().pickImage(
          source: src, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (p != null) {
        final b = await p.readAsBytes();
        if (b.isNotEmpty) {
          setState(() {
            _imgBytes = b;
            _imgName = p.name;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image file was empty. Please try again.')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[IMAGE] Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Select Image',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                      child: _PickOpt(Icons.camera_alt_rounded, 'Camera', () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  })),
                  const SizedBox(width: 12),
                  Expanded(
                      child:
                          _PickOpt(Icons.photo_library_rounded, 'Gallery', () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  })),
                ]),
                const SizedBox(height: 12)
              ]))),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imgBytes == null || _imgBytes!.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please add a photo')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final prov = context.read<ItemsProvider>();
      final claimQuestions = List.generate(_questionControllers.length, (index) {
        return ClaimQuestion(
          prompt: _questionControllers[index].text.trim(),
          answer: _answerControllers[index].text.trim(),
        );
      }).where((q) => q.prompt.isNotEmpty && q.answer.isNotEmpty).toList();
      debugPrint('[SUBMIT] Reporting $_type item: title=${_titleC.text.trim()}, imageSize=${_imgBytes!.length}, questions=${claimQuestions.length}');
      final item = await prov.reportItem(
          type: _type,
          title: _titleC.text.trim(),
          description: _descC.text.trim(),
          imageBytes: _imgBytes!,
          fileName: _imgName ?? 'item.jpg',
          location: _locC.text.trim(),
          claimQuestions: claimQuestions);
      setState(() => _submitting = false);
      if (item != null && mounted) {
        if (prov.matches.isNotEmpty) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => MatchesScreen(reportedItem: item)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('${_type == "lost" ? "Lost" : "Found"} item reported!'),
              backgroundColor: AppTheme.success));
          Navigator.pop(context, true);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(prov.error ?? 'Failed to report item'),
            backgroundColor: AppTheme.danger));
      }
    } catch (e) {
      debugPrint('[SUBMIT] Unhandled error: $e');
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        child: SafeArea(
          child: _submitting
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    height: 92,
                    width: 92,
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('AI is processing...',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  Text('Generating caption and hunting for matches.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center)
                ]))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: AppTheme.glassGradient,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(children: [
                              Container(
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.surfaceMuted.withOpacity(0.82),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Report Item',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Submit a clean, verifiable report.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                height: 46,
                                width: 46,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceMuted,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.edit_note_rounded,
                                    color: AppTheme.primary),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                                child: _TypeBtn(
                                    'I Lost Something',
                                    Icons.search_off_rounded,
                                    AppTheme.lostColor,
                                    _type == 'lost',
                                    () => setState(() => _type = 'lost'))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _TypeBtn(
                                    'I Found Something',
                                    Icons.handshake_rounded,
                                    AppTheme.foundColor,
                                    _type == 'found',
                                    () => setState(() => _type = 'found'))),
                          ]),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: _showPicker,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 220,
                              decoration: BoxDecoration(
                                gradient: AppTheme.glassGradient,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusXl),
                                border: Border.all(
                                    color: _imgBytes != null
                                        ? AppTheme.primary
                                        : AppTheme.border,
                                    width: _imgBytes != null ? 2 : 1),
                                image: _imgBytes != null
                                    ? DecorationImage(
                                        image: MemoryImage(_imgBytes!),
                                        fit: BoxFit.cover)
                                    : null,
                              ),
                              child: _imgBytes == null
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                                color: AppTheme.primary
                                                    .withOpacity(0.14),
                                                shape: BoxShape.circle),
                                            child: const Icon(
                                                Icons.add_a_photo_rounded,
                                                size: 38,
                                                color: AppTheme.primary),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text('Add Photo',
                                              style: TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 18)),
                                          const SizedBox(height: 6),
                                          Text(
                                              'Use a clear photo for better matching.',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium),
                                        ])
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                              controller: _titleC,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                  labelText: 'Item Name *',
                                  hintText: 'e.g. Blue Wallet, iPhone 15',
                                  prefixIcon:
                                      Icon(Icons.label_outline_rounded)),
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Required' : null),
                          const SizedBox(height: 14),
                          TextFormField(
                              controller: _descC,
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                  labelText: 'Description *',
                                  hintText: 'Color, brand, markings...',
                                  prefixIcon: Icon(Icons.description_outlined),
                                  alignLabelWithHint: true),
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Required' : null),
                          const SizedBox(height: 14),
                          TextFormField(
                              controller: _locC,
                              decoration: const InputDecoration(
                                  labelText: 'Location',
                                  hintText: 'Where was it lost or found?',
                                  prefixIcon:
                                      Icon(Icons.location_on_outlined))),
                          if (_type == 'found') ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: AppTheme.glassGradient,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusLg),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warning
                                              .withOpacity(0.14),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: const Icon(
                                            Icons.verified_user_outlined,
                                            color: AppTheme.warning),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Secure Claim Setup',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge),
                                            const SizedBox(height: 4),
                                            Text(
                                                'We will auto-create a claim QR pass. Add up to 3 hidden ownership questions for safer pickup.',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  for (var i = 0; i < 3; i++) ...[
                                    TextFormField(
                                      controller: _questionControllers[i],
                                      decoration: InputDecoration(
                                        labelText: 'Question ${i + 1}',
                                        hintText:
                                            'e.g. What sticker is on the back?',
                                        prefixIcon: const Icon(
                                            Icons.help_outline_rounded),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _answerControllers[i],
                                      decoration: InputDecoration(
                                        labelText: 'Expected Answer ${i + 1}',
                                        hintText:
                                            'Hidden answer used during claim',
                                        prefixIcon: const Icon(
                                            Icons.lock_outline_rounded),
                                      ),
                                    ),
                                    if (i < 2) const SizedBox(height: 14),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _type == 'lost'
                                    ? const [
                                        AppTheme.lostColor,
                                        AppTheme.accent
                                      ]
                                    : const [
                                        AppTheme.foundColor,
                                        AppTheme.secondary
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: (_type == 'lost'
                                          ? AppTheme.lostColor
                                          : AppTheme.foundColor)
                                      .withOpacity(0.28),
                                  blurRadius: 24,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: SizedBox(
                                height: 58,
                                child: ElevatedButton.icon(
                                    onPressed: _submit,
                                    icon: Icon(_type == 'lost'
                                        ? Icons.search_rounded
                                        : Icons.upload_rounded),
                                    label: Text(_type == 'lost'
                                        ? 'Report Lost Item'
                                        : 'Report Found Item'),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        foregroundColor: Colors.white))),
                          ),
                          const SizedBox(height: 30),
                        ]),
                  ),
                ),
        ),
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool sel;
  final VoidCallback onTap;
  const _TypeBtn(this.label, this.icon, this.color, this.sel, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: sel
                ? color.withOpacity(0.14)
                : AppTheme.cardBg.withOpacity(0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: sel ? color : AppTheme.border, width: sel ? 1.8 : 1),
          ),
          child: Column(children: [
            Icon(icon, color: sel ? color : AppTheme.textHint, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: sel ? color : AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
                textAlign: TextAlign.center)
          ])));
}

class _PickOpt extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickOpt(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
              color: AppTheme.surfaceSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border)),
          child: Column(children: [
            Icon(icon, size: 32, color: AppTheme.primary),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppTheme.textPrimary))
          ])));
}
