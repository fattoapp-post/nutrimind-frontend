import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/custom_bottom_nav.dart';
import '../../core/food_service.dart';
import '../food/scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color bgColor = Color(0xFF101817);
  static const Color cardColor = Color(0xFF17221F);
  static const Color borderColor = Color(0xFF1D2C29);
  static const Color primaryTeal = Color(0xFF127B6D);
  static const Color textSecondary = Color(0xFFA1AFA9);
  
  static const Color colorP = Color(0xFF5A44F2);
  static const Color colorC = Color(0xFFF0A500);
  static const Color colorG = Color(0xFFEB5A0C);

  String _userName = 'Utente';
  late DateTime _today;

  int currentKcal = 0; int maxKcal = 2000; 
  int currentP = 0; int maxP = 140;
  int currentC = 0; int maxC = 220;
  int currentG = 0; int maxG = 65;

  List<Map<String, dynamic>> _diaryEntries = [];

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _loadUserData();
    _loadDiaryData();
  }

  void _loadUserData() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.userMetadata?['name'] ?? 
                    user.email?.split('@')[0].capitalize() ?? 'Utente';
      });
    }
  }

  Future<void> _loadDiaryData() async {
    final entries = await FoodService.getDiaryEntries();
    if (mounted) {
      setState(() {
        _diaryEntries = entries;
        currentKcal = entries.fold(0, (sum, item) => sum + (item['kcal'] as int));
        currentP = entries.fold(0, (sum, item) => sum + (item['p'] as int));
        currentC = entries.fold(0, (sum, item) => sum + (item['c'] as int));
        currentG = entries.fold(0, (sum, item) => sum + (item['g'] as int));
      });
    }
  }

  String _getFormattedDate(DateTime date) {
    const days = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
    const months = ['gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'];
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }

  void _showAddMenu(String initialMeal) {
    const Color sheetBg = Color(0xFFFBFBFB);
    const Color strokeColor = Color(0xFFE5E7EB);
    const Color iconBg = Color(0xFFE6F4F1);
    const Color textPrimary = Color(0xFF1F2937);
    const Color textLight = Color(0xFF6B7280);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Aggiungi al diario', style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: textLight), onPressed: () => Navigator.pop(context))
                ],
              ),
              const SizedBox(height: 16),
              
              InkWell(
                onTap: () {
                  Navigator.pop(context); 
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()))
                    .then((barcode) {
                       if(barcode != null) {
                          _loadDiaryData();
                       }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: strokeColor)),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.qr_code_scanner, color: primaryTeal)),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Scansiona', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary)),
                            Text('Codice a barre', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenu('Diario'),
        backgroundColor: primaryTeal,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const CustomBottomNav(currentIndex: 0, isDarkMode: true),
      
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildDynamicCalendar(),
              const SizedBox(height: 24),
              _buildMacrosCard(),
              const SizedBox(height: 16),
              _buildNutritionistNote(),
              const SizedBox(height: 24),
              const Text('I tuoi pasti', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildMealsList(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ciao, $_userName', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_getFormattedDate(_today), style: const TextStyle(color: textSecondary, fontSize: 14)),
          ],
        ),
        Container(
          decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle, border: Border.all(color: borderColor)),
          child: IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: () {}),
        )
      ],
    );
  }

  Widget _buildDynamicCalendar() {
    const shortDays = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];
    final weekDays = List.generate(7, (index) => _today.add(Duration(days: index - 3)));

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: weekDays.length,
        itemBuilder: (context, index) {
          final date = weekDays[index];
          final isToday = date.day == _today.day && date.month == _today.month;
          final dayLabel = '${shortDays[date.weekday - 1]} ${date.day}';
          return Container(
            width: 50, margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isToday ? primaryTeal : cardColor,
              borderRadius: BorderRadius.circular(16),
              border: isToday ? null : Border.all(color: borderColor),
            ),
            alignment: Alignment.center,
            child: Text(dayLabel, style: TextStyle(color: isToday ? Colors.white : textSecondary, fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
          );
        },
      ),
    );
  }

  Widget _buildMacrosCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Macros di oggi', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text('$currentKcal / $maxKcal kcal', style: const TextStyle(color: textSecondary, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 20),
          _buildProgressBar('P', currentP, maxP, colorP),
          const SizedBox(height: 16),
          _buildProgressBar('C', currentC, maxC, colorC),
          const SizedBox(height: 16),
          _buildProgressBar('G', currentG, maxG, colorG),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, int current, int max, Color color) {
    double percent = current / max;
    if (percent > 1.0) percent = 1.0;
    if (percent < 0.0) percent = 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: '${current}g', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  TextSpan(text: ' / ${max}g', style: const TextStyle(color: textSecondary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(height: 8, width: double.infinity, decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4))),
            FractionallySizedBox(
              widthFactor: percent,
              child: Container(height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNutritionistNote() {
    return const Row(
      children: [
        Icon(Icons.shield_outlined, color: primaryTeal, size: 18),
        SizedBox(width: 8),
        Text('Piano definito dal nutrizionista', style: TextStyle(color: primaryTeal, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildMealsList() {
    return Column(
      children: [
        _buildMealRow('Colazione', '08:00'),
        const SizedBox(height: 12),
        _buildMealRow('Spuntino', '11:00'),
        const SizedBox(height: 12),
        _buildMealRow('Pranzo', '13:00'),
        const SizedBox(height: 12),
        _buildMealRow('Merenda', '16:30'),
        const SizedBox(height: 12),
        _buildMealRow('Cena', '20:00'),
      ],
    );
  }

  Widget _buildMealRow(String mealName, String time) {
    final mealItems = _diaryEntries.where((e) => e['meal'] == mealName).toList();
    final bool isEmpty = mealItems.isEmpty;
    
    int kcal = mealItems.fold(0, (sum, item) => sum + (item['kcal'] as int));
    int p = mealItems.fold(0, (sum, item) => sum + (item['p'] as int));
    int c = mealItems.fold(0, (sum, item) => sum + (item['c'] as int));
    int g = mealItems.fold(0, (sum, item) => sum + (item['g'] as int));

    return _buildMealCard(
      time: time,
      title: mealName,
      kcal: kcal,
      p: p,
      c: c,
      g: g,
      isEmpty: isEmpty,
      hasDot: !isEmpty,
      addedItems: mealItems, 
    );
  }

  Widget _buildMealCard({
    required String time,
    required String title,
    int? kcal, int? p, int? c, int? g,
    bool isEmpty = false,
    bool hasDot = false,
    required List<Map<String, dynamic>> addedItems,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _showAddMenu(title), 
            child: Row(
              crossAxisAlignment: isEmpty ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 45,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(time, style: const TextStyle(color: textSecondary, fontSize: 14)),
                      if (hasDot) ...[
                        const SizedBox(height: 4),
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      ]
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      if (isEmpty) ...[
                        const SizedBox(height: 4),
                        const Text('Nessun alimento · Tocca + per aggiungere', style: TextStyle(color: textSecondary, fontSize: 12)),
                      ] else ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildMacroPill('P', '${p}g', colorP),
                            _buildMacroPill('C', '${c}g', colorC),
                            _buildMacroPill('G', '${g}g', colorG),
                          ],
                        ),
                      ]
                    ],
                  ),
                ),
                if (isEmpty) 
                  const Icon(Icons.add_circle_outline, color: textSecondary)
                else 
                  Text('${kcal} kcal', style: const TextStyle(color: textSecondary, fontSize: 14)),
              ],
            ),
          ),
          
          if (!isEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: borderColor, height: 1),
            const SizedBox(height: 8),
            ...addedItems.map((item) => _buildAddedFoodItem(item)),
          ]
        ],
      ),
    );
  }

  Widget _buildAddedFoodItem(Map<String, dynamic> item) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: cardColor,
            title: Text('Modifica ${item['name']}', style: const TextStyle(color: Colors.white)),
            content: Text('Attualmente: ${item['grams']}g', style: const TextStyle(color: textSecondary)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Rimuovi', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla', style: TextStyle(color: primaryTeal)),
              ),
            ],
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 57), 
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['name']} · ${item['grams']}g',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text('P: ${item['p']}g', style: const TextStyle(color: colorP, fontSize: 11)),
                      Text('C: ${item['c']}g', style: const TextStyle(color: colorC, fontSize: 11)),
                      Text('G: ${item['g']}g', style: const TextStyle(color: colorG, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            Text('${item['kcal']} kcal', style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

extension StringExtension on String {
    String capitalize() {
      if (isEmpty) return this;
      return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
    }
}