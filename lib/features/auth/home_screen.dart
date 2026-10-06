import 'package:flutter/material.dart';
import '../../core/app_error.dart';
import '../../core/widgets/custom_bottom_nav.dart';
import '../../core/food_service.dart';
import '../../core/models.dart';
import '../food/food_detail_screen.dart';
import '../food/scanner_screen.dart';
import '../food/search_food_screen.dart';

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
  late DateTime _selectedDate;

  int currentKcal = 0; int maxKcal = 2000;
  int currentP = 0; int maxP = 140;
  int currentC = 0; int maxC = 220;
  int currentG = 0; int maxG = 65;
  bool _hasPlan = false;

  List<DiaryEntry> _diaryEntries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _selectedDate = _today;
    _loadUserData();
    _loadDiaryData();
  }

  Future<void> _loadUserData() async {
    final name = await loadDisplayName();
    if (mounted) setState(() => _userName = name);
  }

  Future<void> _loadDiaryData() async {
    final date = _selectedDate;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        FoodService.getDiaryEntries(date),
        FoodService.getDailyTargets(date),
      ]);
      if (!mounted || date != _selectedDate) return;
      final entries = results[0] as List<DiaryEntry>;
      final targets = results[1] as DailyTargets;
      setState(() {
        _diaryEntries = entries;
        currentKcal = entries.fold(0.0, (sum, e) => sum + e.kcal).round();
        currentP = entries.fold(0.0, (sum, e) => sum + e.proteinG).round();
        currentC = entries.fold(0.0, (sum, e) => sum + e.carbsG).round();
        currentG = entries.fold(0.0, (sum, e) => sum + e.fatG).round();
        maxKcal = targets.kcal.round();
        maxP = targets.proteinG.round();
        maxC = targets.carbsG.round();
        maxG = targets.fatG.round();
        _hasPlan = targets.fromPlan;
      });
    } on AppError catch (e) {
      if (mounted && date == _selectedDate) setState(() => _error = e.message);
    } finally {
      if (mounted && date == _selectedDate) setState(() => _loading = false);
    }
  }

  void _selectDate(DateTime date) {
    if (DateUtils.isSameDay(date, _selectedDate)) return;
    setState(() => _selectedDate = date);
    _loadDiaryData();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSearch(MealSlot slot) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SearchFoodScreen(slot: slot, date: _selectedDate)),
    );
    if (added == true) _loadDiaryData();
  }

  Future<void> _openScanner(MealSlot slot) async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
    if (barcode == null || !mounted) return;

    _showSnack('Cerco il prodotto...');
    try {
      final food = await FoodService.getFoodByBarcode(barcode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (food == null) {
        _showSnack('Prodotto non trovato. Prova a cercarlo per nome.');
        return;
      }
      final added = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => FoodDetailScreen(food: food, initialSlot: slot, date: _selectedDate)),
      );
      if (added == true) _loadDiaryData();
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnack(e.message);
    }
  }

  Future<void> _deleteEntry(DiaryEntry entry) async {
    try {
      await FoodService.deleteDiaryEntry(entry.id);
      if (!mounted) return;
      _showSnack('${entry.name} rimosso.');
      _loadDiaryData();
    } on AppError catch (e) {
      if (mounted) _showSnack(e.message);
    }
  }

  String _getFormattedDate(DateTime date) {
    const days = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
    const months = ['gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'];
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }

  static const Color _sheetStroke = Color(0xFFE5E7EB);
  static const Color _sheetIconBg = Color(0xFFE6F4F1);
  static const Color _sheetTextPrimary = Color(0xFF1F2937);

  void _showAddMenu(MealSlot slot) {
    const Color sheetBg = Color(0xFFFBFBFB);
    const Color textPrimary = _sheetTextPrimary;
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
                  Text('Aggiungi a ${slot.label}', style: const TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: textLight), onPressed: () => Navigator.pop(context))
                ],
              ),
              const SizedBox(height: 16),

              _buildAddOption(Icons.search, 'Cerca', 'Catalogo alimenti', () {
                Navigator.pop(context);
                _openSearch(slot);
              }),
              const SizedBox(height: 12),
              _buildAddOption(Icons.qr_code_scanner, 'Scansiona', 'Codice a barre', () {
                Navigator.pop(context);
                _openScanner(slot);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddOption(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _sheetStroke)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _sheetIconBg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: primaryTeal)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _sheetTextPrimary)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenu(MealSlot.forNow()),
        backgroundColor: primaryTeal,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const CustomBottomNav(currentIndex: 0, isDarkMode: true),
      
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDiaryData,
          child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildDynamicCalendar(),
              const SizedBox(height: 24),
              if (_loading) const LinearProgressIndicator(color: primaryTeal, backgroundColor: cardColor),
              if (_error != null) ...[
                Row(
                  children: [
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
                    TextButton(onPressed: _loadDiaryData, child: const Text('Riprova', style: TextStyle(color: primaryTeal))),
                  ],
                ),
                const SizedBox(height: 8),
              ],
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
            Text(_getFormattedDate(_selectedDate), style: const TextStyle(color: textSecondary, fontSize: 14)),
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
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          final dayLabel = '${shortDays[date.weekday - 1]} ${date.day}';
          return GestureDetector(
            onTap: () => _selectDate(date),
            child: Container(
              width: 50, margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? primaryTeal : cardColor,
                borderRadius: BorderRadius.circular(16),
                border: isSelected ? null : Border.all(color: borderColor),
              ),
              alignment: Alignment.center,
              child: Text(dayLabel, style: TextStyle(color: isSelected ? Colors.white : textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ),
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
    double percent = max > 0 ? current / max : 0;
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
    return Row(
      children: [
        Icon(_hasPlan ? Icons.shield_outlined : Icons.info_outline, color: primaryTeal, size: 18),
        const SizedBox(width: 8),
        Text(
          _hasPlan ? 'Piano definito dal nutrizionista' : 'Nessun piano attivo · obiettivi indicativi',
          style: const TextStyle(color: primaryTeal, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMealsList() {
    // Lo spuntino serale compare solo se ha voci registrate
    final slots = MealSlot.values
        .where((s) => s != MealSlot.eveningSnack || _diaryEntries.any((e) => e.slot == s))
        .toList();
    return Column(
      children: [
        for (var i = 0; i < slots.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _buildMealRow(slots[i]),
        ],
      ],
    );
  }

  Widget _buildMealRow(MealSlot slot) {
    final mealItems = _diaryEntries.where((e) => e.slot == slot).toList();
    final bool isEmpty = mealItems.isEmpty;

    int kcal = mealItems.fold(0.0, (sum, e) => sum + e.kcal).round();
    int p = mealItems.fold(0.0, (sum, e) => sum + e.proteinG).round();
    int c = mealItems.fold(0.0, (sum, e) => sum + e.carbsG).round();
    int g = mealItems.fold(0.0, (sum, e) => sum + e.fatG).round();

    return _buildMealCard(
      slot: slot,
      time: slot.time,
      title: slot.label,
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
    required MealSlot slot,
    required String time,
    required String title,
    int? kcal, int? p, int? c, int? g,
    bool isEmpty = false,
    bool hasDot = false,
    required List<DiaryEntry> addedItems,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _showAddMenu(slot),
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
                  Text('$kcal kcal', style: const TextStyle(color: textSecondary, fontSize: 14)),
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

  Widget _buildAddedFoodItem(DiaryEntry item) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: cardColor,
            title: Text('Modifica ${item.name}', style: const TextStyle(color: Colors.white)),
            content: Text('Attualmente: ${item.grams.round()}g', style: const TextStyle(color: textSecondary)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _deleteEntry(item);
                },
                child: const Text('Rimuovi', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
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
                    '${item.name} · ${item.grams.round()}g',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text('P: ${item.proteinG.round()}g', style: const TextStyle(color: colorP, fontSize: 11)),
                      Text('C: ${item.carbsG.round()}g', style: const TextStyle(color: colorC, fontSize: 11)),
                      Text('G: ${item.fatG.round()}g', style: const TextStyle(color: colorG, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            Text('${item.kcal.round()} kcal', style: const TextStyle(color: Colors.white, fontSize: 14)),
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