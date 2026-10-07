import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_error.dart';
import '../../core/chat_service.dart';
import '../../core/notification_service.dart';
import '../../core/push_service.dart';
import '../../core/widgets/custom_bottom_nav.dart';
import '../../core/food_service.dart';
import '../../core/plan_service.dart';
import '../plan/macro_plan_editor_screen.dart';
import '../../core/models.dart';
import '../food/food_detail_screen.dart';
import '../food/scanner_screen.dart';
import '../food/search_food_screen.dart';
import '../chat/conversations_screen.dart';
import '../notifications/notifications_screen.dart';
import '../recipes/recipes_picker_screen.dart';
import '../nutritionist/create_food_screen.dart';
import '../shell/patient_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with ReloadOnTabVisible {
  @override
  int get tabIndex => PatientTab.diary;

  @override
  void onTabVisible() => _loadDiaryData();

  

  String _userName = 'Utente';
  late DateTime _today;
  late DateTime _selectedDate;

  int currentKcal = 0; int maxKcal = 2000;
  int currentP = 0; int maxP = 140;
  int currentC = 0; int maxC = 220;
  int currentG = 0; int maxG = 65;
  bool _hasPlan = false;
  String? _planName;
  MacroPlan? _plan;
  bool _canSelfManage = false;
  Map<MealSlot, double> _kcalBySlot = const {};

  List<DiaryEntry> _diaryEntries = [];
  List<NutritionistComment> _comments = [];
  int _unreadNotifications = 0;
  int _unreadMessages = 0;
  RealtimeChannel? _notificationsChannel;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _selectedDate = _today;
    _loadUserData();
    _loadDiaryData();
    _loadNotifications();
    _notificationsChannel = NotificationService.subscribe(() {
      _loadNotifications();
      _loadComments(_selectedDate);
    });
    // Push ricevuti con l'app aperta: il sistema non li mostra
    _pushSub = PushService.onForegroundMessage.listen((message) {
      final title = message.notification?.title;
      if (title != null && mounted) _showSnack(title);
      _loadNotifications();
    });
  }

  StreamSubscription<RemoteMessage>? _pushSub;

  @override
  void dispose() {
    _pushSub?.cancel();
    NotificationService.unsubscribe(_notificationsChannel);
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final items = await NotificationService.getUnread();
      // I messaggi hanno il loro badge: non si contano due volte
      final others = items.where((n) => !n.isMessage).length;
      final messages = await ChatService.unreadCount();
      if (mounted) {
        setState(() {
          _unreadNotifications = others;
          _unreadMessages = messages;
        });
      }
    } on AppError {
      // il badge non è essenziale: resta il valore precedente
    }
  }

  Future<void> _loadComments(DateTime date) async {
    try {
      final comments = await NotificationService.getMyComments(date, date);
      if (mounted && date == _selectedDate) setState(() => _comments = comments);
    } on AppError {
      if (mounted && date == _selectedDate) setState(() => _comments = []);
    }
  }

  Future<void> _markCommentRead(NutritionistComment c) async {
    try {
      await NotificationService.markCommentRead(c.id);
      _loadComments(_selectedDate);
    } on AppError catch (e) {
      if (mounted) _showSnack(e.message);
    }
  }

  Future<void> _loadUserData() async {
    final name = await loadDisplayName();
    if (mounted) setState(() => _userName = name);
    // Piano completo e autogestione: servono per le istruzioni e per
    // sapere se gli obiettivi sono modificabili dal paziente.
    try {
      final plan = await PlanService.getCurrentPlan();
      final canSelf = await PlanService.canSelfManage();
      if (mounted) {
        setState(() {
          _plan = plan;
          _canSelfManage = canSelf;
        });
      }
    } on AppError {
      // il diario funziona comunque: resta la riga senza istruzioni
    }
  }

  Future<void> _loadDiaryData() async {
    final date = _selectedDate;
    _loadComments(date);
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
        _planName = targets.planName;
        _kcalBySlot = targets.kcalBySlot;
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
      var food = await FoodService.getFoodByBarcode(barcode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (food == null) {
        // Non è né in catalogo né nel database esteso: proponi di inserirlo
        final create = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Prodotto non trovato'),
            content: Text('Il codice $barcode non è nel catalogo. Vuoi inserirlo tu copiando i valori dalla confezione?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Inserisci')),
            ],
          ),
        );
        if (create != true || !mounted) return;
        food = await Navigator.push<Food>(
          context,
          MaterialPageRoute(builder: (_) => CreateFoodScreen(personal: true, initialBarcode: barcode)),
        );
        if (food == null || !mounted) return;
      }
      final selected = food;
      final added = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => FoodDetailScreen(food: selected, initialSlot: slot, date: _selectedDate)),
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

  Future<void> _openPersonalMeals(MealSlot slot) async {
    List<PersonalMeal> meals;
    try {
      meals = await FoodService.getPersonalMeals();
    } on AppError catch (e) {
      if (mounted) _showSnack(e.message);
      return;
    }
    if (!mounted) return;
    final meal = await showModalBottomSheet<PersonalMeal>(
      context: context,
      builder: (ctx) => SafeArea(
        child: meals.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nessun pasto salvato. Tieni premuto su un pasto del diario per salvarlo.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(title: Text('Pasti salvati', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                  for (final m in meals)
                    ListTile(
                      leading: Icon(Icons.bookmark_outline, color: primaryTeal),
                      title: Text(m.name),
                      subtitle: m.defaultSlot == null ? null : Text(m.defaultSlot!.label),
                      onTap: () => Navigator.pop(ctx, m),
                    ),
                ],
              ),
      ),
    );
    if (meal == null) return;
    try {
      final count = await FoodService.logPersonalMeal(meal.id, _selectedDate, slot);
      if (!mounted) return;
      _showSnack(count == 0 ? 'Il pasto salvato non contiene alimenti.' : '${meal.name} aggiunto a ${slot.label}.');
      _loadDiaryData();
    } on AppError catch (e) {
      if (mounted) _showSnack(e.message);
    }
  }

  Future<void> _saveAsPersonalMeal(MealSlot slot, List<DiaryEntry> entries) async {
    final withFood = entries.where((e) => e.foodId != null).toList();
    if (withFood.isEmpty) return;
    final controller = TextEditingController(text: slot.label);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salva come pasto'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Nome')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Salva')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      await FoodService.createPersonalMeal(name, withFood, defaultSlot: slot);
      if (mounted) _showSnack('Pasto "$name" salvato.');
    } on AppError catch (e) {
      if (mounted) _showSnack(e.message);
    }
  }

  Future<void> _openRecipes(MealSlot slot) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RecipesPickerScreen(slot: slot, date: _selectedDate)),
    );
    if (added == true) _loadDiaryData();
  }

  Future<void> _openChats() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationsScreen()));
    _loadNotifications();
  }

  Future<void> _openNotifications() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    _loadNotifications();
    _loadComments(_selectedDate);
  }

  String _getFormattedDate(DateTime date) {
    const days = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
    const months = ['gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'];
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }

  void _showAddMenu(MealSlot slot) {
    // Il foglio segue il tema come il resto: prima era sempre chiaro
    final Color sheetBg = cardColor;
    final Color textLight = textSecondary;

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
                  Text('Aggiungi a ${slot.label}', style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(icon: Icon(Icons.close, color: textLight), onPressed: () => Navigator.pop(context))
                ],
              ),
              const SizedBox(height: 16),

              _buildAddOption(Icons.menu_book_outlined, 'Ricette', 'Del tuo nutrizionista e della community', () {
                Navigator.pop(context);
                _openRecipes(slot);
              }),
              const SizedBox(height: 12),
              _buildAddOption(Icons.search, 'Cerca', 'Catalogo alimenti', () {
                Navigator.pop(context);
                _openSearch(slot);
              }),
              const SizedBox(height: 12),
              _buildAddOption(Icons.qr_code_scanner, 'Scansiona', 'Codice a barre', () {
                Navigator.pop(context);
                _openScanner(slot);
              }),
              const SizedBox(height: 12),
              _buildAddOption(Icons.bookmarks_outlined, 'Pasti salvati', 'Registra un pasto ricorrente', () {
                Navigator.pop(context);
                _openPersonalMeals(slot);
              }),
              const SizedBox(height: 12),
              _buildAddOption(Icons.content_copy_outlined, 'Copia dal giorno prima', '${slot.label} del giorno precedente', () {
                Navigator.pop(context);
                _copyFromPreviousDay(slot);
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
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: tealSoft, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: primaryTeal)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary)),
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
    context.watchTheme();
    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenu(MealSlot.forNow()),
        backgroundColor: primaryTeal,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomBottomNav(currentIndex: PatientTab.diary),
      
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
              if (_loading) LinearProgressIndicator(color: primaryTeal, backgroundColor: cardColor),
              if (_error != null) ...[
                Row(
                  children: [
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
                    TextButton(onPressed: _loadDiaryData, child: Text('Riprova', style: TextStyle(color: primaryTeal))),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              _buildMacrosCard(),
              const SizedBox(height: 16),
              _buildNutritionistNote(),
              if (_comments.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildComments(),
              ],
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

  Widget _buildComments() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryTeal)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.chat_bubble_outline, color: primaryTeal, size: 18),
            SizedBox(width: 8),
            Text('Note del nutrizionista', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          for (final c in _comments)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (c.slot != null)
                          Text(c.slot!.label, style: TextStyle(color: textSecondary, fontSize: 12)),
                        Text(c.body, style: TextStyle(color: Colors.white, fontWeight: c.isRead ? FontWeight.normal : FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (!c.isRead)
                    TextButton(onPressed: () => _markCommentRead(c), child: Text('Letto', style: TextStyle(color: primaryTeal))),
                ],
              ),
            ),
        ],
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
            Text(_getFormattedDate(_selectedDate), style: TextStyle(color: textSecondary, fontSize: 14)),
          ],
        ),
        Row(children: [
          _roundIcon(Icons.chat_bubble_outline, 'Messaggi', _unreadMessages, _openChats),
          const SizedBox(width: 8),
          _roundIcon(Icons.notifications_outlined, 'Notifiche', _unreadNotifications, _openNotifications),
        ]),
      ],
    );
  }

  Widget _roundIcon(IconData icon, String tooltip, int badge, VoidCallback onPressed) => Container(
        decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle, border: Border.all(color: borderColor)),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Badge(
            isLabelVisible: badge > 0,
            label: Text('$badge'),
            child: Icon(icon, color: Colors.white),
          ),
        ),
      );

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
              Text('$currentKcal / $maxKcal kcal', style: TextStyle(color: textSecondary, fontSize: 14)),
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
                  TextSpan(text: ' / ${max}g', style: TextStyle(color: textSecondary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(height: 8, width: double.infinity, decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4))),
            FractionallySizedBox(
              widthFactor: percent,
              child: Container(height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
            ),
          ],
        ),
      ],
    );
  }

  /// Apre gli obiettivi: li modifica chi si autogestisce, gli altri
  /// leggono di chi e' il piano.
  Future<void> _openTargets() async {
    if (!_canSelfManage) {
      _showSnack(_hasPlan
          ? 'Gli obiettivi arrivano dal tuo nutrizionista.'
          : 'Collega un nutrizionista oppure imposta i tuoi obiettivi dal profilo.');
      return;
    }
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MacroPlanEditorScreen(current: _plan)),
    );
    if (saved == true && mounted) _loadDiaryData();
  }

  Widget _buildNutritionistNote() {
    final plan = _plan;
    final label = _hasPlan
        ? (plan != null && !plan.isSelfManaged
            ? (_planName == null || _planName!.isEmpty
                ? 'Piano del tuo nutrizionista'
                : 'Piano "${_planName!}" del nutrizionista')
            : 'Obiettivi che hai impostato tu')
        : (_canSelfManage
            ? 'Nessun obiettivo impostato · toccami per farlo'
            : 'Nessun piano attivo · obiettivi indicativi');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _openTargets,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(_hasPlan ? Icons.shield_outlined : Icons.info_outline, color: primaryTeal, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: TextStyle(color: primaryTeal, fontSize: 14, fontWeight: FontWeight.w500)),
                ),
                if (_canSelfManage) Icon(Icons.chevron_right, color: primaryTeal, size: 18),
              ],
            ),
          ),
        ),
        // Il "modus operandi" scritto dal professionista: sta qui perche'
        // e' il posto dove il paziente guarda i numeri ogni giorno.
        if (plan?.notes != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tealSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_outlined, color: primaryTeal, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(plan!.notes!, style: TextStyle(color: textPrimary, fontSize: 13, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
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
            onLongPress: isEmpty ? null : () => _saveAsPersonalMeal(slot, addedItems),
            child: Row(
              crossAxisAlignment: isEmpty ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 45,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(time, style: TextStyle(color: textSecondary, fontSize: 14)),
                      if (hasDot) ...[
                        const SizedBox(height: 4),
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle)),
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
                        Text('Nessun alimento · Tocca + per aggiungere', style: TextStyle(color: textSecondary, fontSize: 12)),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isEmpty)
                      Icon(Icons.add_circle_outline, color: textSecondary)
                    else
                      Text('$kcal kcal', style: TextStyle(color: textSecondary, fontSize: 14)),
                    if (_kcalBySlot[slot] != null)
                      Text(
                        'obiettivo ${_kcalBySlot[slot]!.round()}',
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          if (!isEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: borderColor, height: 1),
            const SizedBox(height: 8),
            ...addedItems.map((item) => _buildAddedFoodItem(item)),
          ]
        ],
      ),
    );
  }

  Future<void> _editEntry(DiaryEntry item) async {
    final controller = TextEditingController(text: item.grams.round().toString());
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: Text('Modifica ${item.name}', style: const TextStyle(color: Colors.white)),
        content: item.foodId == null
            ? Text('Attualmente: ${item.grams.round()}g', style: TextStyle(color: textSecondary))
            : TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Grammi',
                  labelStyle: TextStyle(color: textSecondary),
                  suffixText: 'g',
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'delete'),
            child: const Text('Rimuovi', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Annulla', style: TextStyle(color: textSecondary)),
          ),
          if (item.foodId != null)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'save'),
              child: Text('Salva', style: TextStyle(color: primaryTeal)),
            ),
        ],
      ),
    );
    final grams = double.tryParse(controller.text.replaceAll(',', '.'));
    controller.dispose();
    if (action == 'delete') {
      await _deleteEntry(item);
    } else if (action == 'save') {
      if (grams == null || grams <= 0 || grams > 5000) {
        _showSnack('Quantità non valida.');
        return;
      }
      if (grams.round() == item.grams.round()) return;
      try {
        await FoodService.updateEntryGrams(item, grams, _selectedDate);
        if (!mounted) return;
        _showSnack('${item.name} aggiornato a ${grams.round()} g.');
        _loadDiaryData();
      } on AppError catch (e) {
        if (mounted) _showSnack(e.message);
      }
    }
  }

  Future<void> _copyFromPreviousDay(MealSlot slot) async {
    final from = _selectedDate.subtract(const Duration(days: 1));
    try {
      final count = await FoodService.copyMeal(from: from, to: _selectedDate, slot: slot);
      if (!mounted) return;
      _showSnack(count == 0 ? 'Nessun alimento in ${slot.label} il giorno prima.' : '$count alimenti copiati in ${slot.label}.');
      if (count > 0) _loadDiaryData();
    } on AppError catch (e) {
      if (mounted) _showSnack(e.message);
    }
  }

  Widget _buildAddedFoodItem(DiaryEntry item) {
    return InkWell(
      onTap: () => _editEntry(item),
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
                      Text('P: ${item.proteinG.round()}g', style: TextStyle(color: colorP, fontSize: 11)),
                      Text('C: ${item.carbsG.round()}g', style: TextStyle(color: colorC, fontSize: 11)),
                      Text('G: ${item.fatG.round()}g', style: TextStyle(color: colorG, fontSize: 11)),
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