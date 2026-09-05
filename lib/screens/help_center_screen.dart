import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key, this.showContact = false});
  final bool showContact;

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _messageController = TextEditingController();
  bool _submitting = false;

  final List<Map<String, String>> _faqs = [
    {
      'question': 'Bagaimana cara kerja sesi Video Call AI?',
      'answer': 'SoulTalk AI mendengarkan suara Anda secara real-time, memahami keluhan secara psikologis melalui Gemini API, kemudian merespons langsung menggunakan suara alami AI. Kamera digunakan secara opsional untuk mendeteksi emosi ekspresi wajah.'
    },
    {
      'question': 'Apakah data percakapan saya aman?',
      'answer': 'Tentu saja. Privasi Anda adalah prioritas utama kami. Semua rekaman suara dan transkrip percakapan dilindungi dengan enkripsi end-to-end dan tidak akan pernah dibagikan kepada pihak ketiga.'
    },
    {
      'question': 'Bagaimana cara AI mendeteksi suasana hati saya?',
      'answer': 'Sistem kami menganalisis nada suara Anda, pilihan kata saat bercakap-cakap, serta ekspresi mikro wajah jika kamera aktif untuk merangkum emosi dominan (seperti Tenang, Cemas, atau Lelah).'
    },
    {
      'question': 'Apakah SoulTalk AI dapat menggantikan psikolog asli?',
      'answer': 'SoulTalk AI dirancang sebagai asisten pertolongan pertama dan teman bercerita harian untuk meredakan ketegangan mental. Untuk diagnosa medis atau terapi mendalam, harap selalu berkonsultasi dengan profesional psikolog atau psikiater berlisensi.'
    }
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.showContact) {
      _tabController.index = 1;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submitMessage() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Harap tulis pesan atau keluhan Anda'),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _submitting = false);

    _messageController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Pesan terkirim! Tim kami akan segera membalas email Anda.', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pusat Bantuan'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Tanya Jawab (FAQ)'),
            Tab(text: 'Hubungi Kami'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // FAQs Tab
            ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _faqs.length,
              itemBuilder: (ctx, i) {
                final faq = _faqs[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.colorScheme.outline),
                    boxShadow: SoftShadow.soft,
                  ),
                  child: ExpansionTile(
                    shape: Border.all(color: Colors.transparent),
                    collapsedShape: Border.all(color: Colors.transparent),
                    title: Text(
                      faq['question']!,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          faq['answer']!,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Contact Tab
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Punya Kendala atau Pertanyaan?',
                    style: textTheme.titleMedium?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kirimkan pesan di bawah ini. Layanan pelanggan kami siap merespons keluhan Anda dalam waktu maksimal 24 jam.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Pesan Anda',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Tulis pesan, masukan, atau kendala teknis Anda di sini...',
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 100),
                        child: Icon(Icons.chat_bubble_outline_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submitMessage,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : const Text('Kirim Pesan'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
