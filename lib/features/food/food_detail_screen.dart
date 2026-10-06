import 'package:flutter/material.dart';
import '../../core/food_service.dart';

class FoodDetailScreen extends StatefulWidget {
  final Map<String, dynamic> foodData;

  const FoodDetailScreen({super.key, required this.foodData});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  static const Color bgColor = Color(0xFFFAFAFA);
  static const Color primaryTeal = Color(0xFF127B6D);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  
  static const Color colorP = Color(0xFF5A44F2);
  static const Color colorC = Color(0xFFF0A500);
  static const Color colorG = Color(0xFFEB5A0C);
  
  static const Color bgP = Color(0xFFF0EFFF);
  static const Color bgC = Color(0xFFFEF6E5);
  static const Color bgG = Color(0xFFFDEEE6);

  int _currentGrams = 170; 
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    // Inizializza lo stato leggendo se l'alimento è già preferito o no
    _isFavorite = widget.foodData['isFavorite'] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.foodData;
    final bool isVerified = food['verified'] ?? false;

    // Ricalcolo in base ai grammi (supponendo dati originali basati su 100g)
    double ratio = _currentGrams / 100.0;
    int calcKcal = ((food['kcal'] as num) * ratio).round();
    int calcP = ((food['p'] as num) * ratio).round();
    int calcC = ((food['c'] as num) * ratio).round();
    int calcG = ((food['g'] as num) * ratio).round();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Dettaglio alimento', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.more_horiz, color: textPrimary), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(food['name'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary)),
                      Text('${food['brand']} · naturale', style: const TextStyle(fontSize: 16, color: textSecondary)),
                    ],
                  ),
                ),
                _buildVerificationBadge(isVerified),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.shield_outlined, color: primaryTeal, size: 16),
                SizedBox(width: 4),
                Text('Piano definito dal nutrizionista', style: TextStyle(color: primaryTeal, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(child: _buildBigMacroCard('Proteine', 'P', calcP, colorP, bgP)),
                const SizedBox(width: 12),
                Expanded(child: _buildBigMacroCard('Carboidrati', 'C', calcC, colorC, bgC)),
                const SizedBox(width: 12),
                Expanded(child: _buildBigMacroCard('Grassi', 'G', calcG, colorG, bgG)),
              ],
            ),
            const SizedBox(height: 16),
            Center(child: Text('$calcKcal kcal · dato ricalcolato', style: const TextStyle(color: textSecondary))),
            const SizedBox(height: 32),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Quantità', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                      Text('Personalizzata', style: TextStyle(color: textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildQtyButton(Icons.remove, () {
                        if (_currentGrams > 10) setState(() => _currentGrams -= 10);
                      }),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(text: '$_currentGrams', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary)),
                            const TextSpan(text: ' g', style: TextStyle(fontSize: 18, color: textSecondary)),
                          ],
                        ),
                      ),
                      _buildQtyButton(Icons.add, () {
                        setState(() => _currentGrams += 10);
                      }, isFilled: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.sync, color: primaryTeal, size: 16),
                      SizedBox(width: 8),
                      Text('Macro ricalcolati in tempo reale', style: TextStyle(color: primaryTeal, fontSize: 12)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF3F9F8), borderRadius: BorderRadius.circular(16)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, color: primaryTeal),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Valori verificati sul prodotto. Controlla sempre la confezione in caso di variazioni.', style: TextStyle(color: textPrimary)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              // Tasto dinamico: Salva / Salvato
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isFavorite = !_isFavorite; // Inverte lo stato
                    });
                    FoodService.toggleFavorite(food['id'] ?? '0', _isFavorite);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isFavorite ? '${food['name']} salvato nei preferiti!' : 'Rimosso dai preferiti.'),
                        backgroundColor: _isFavorite ? primaryTeal : Colors.grey,
                      ),
                    );
                  },
                  icon: Icon(
                    _isFavorite ? Icons.bookmark : Icons.bookmark_border, 
                    color: _isFavorite ? Colors.white : primaryTeal
                  ),
                  label: Text(
                    _isFavorite ? 'Salvato' : 'Salva', 
                    style: TextStyle(color: _isFavorite ? Colors.white : primaryTeal, fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFavorite ? primaryTeal : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: primaryTeal),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _showMealSelectionSheet(context, food),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Aggiungi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTeal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBigMacroCard(String name, String letter, int amount, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: textColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(letter, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '$amount', style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold)),
                TextSpan(text: 'g', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(color: textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap, {bool isFilled = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isFilled ? primaryTeal : Colors.transparent,
          border: isFilled ? null : Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: isFilled ? Colors.white : textPrimary),
      ),
    );
  }

  Widget _buildVerificationBadge(bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: isVerified ? const Color(0xFFE6F4F1) : Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(isVerified ? Icons.verified_outlined : Icons.info_outline, size: 14, color: isVerified ? primaryTeal : textSecondary),
          const SizedBox(width: 6),
          Text(isVerified ? 'Verificato' : 'Non verific.', style: TextStyle(color: isVerified ? primaryTeal : textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showMealSelectionSheet(BuildContext context, Map<String, dynamic> food) {
    final meals = ['Colazione', 'Spuntino', 'Pranzo', 'Merenda', 'Cena'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Aggiungi al diario', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...meals.map((meal) => ListTile(
                title: Text(meal, style: const TextStyle(color: textPrimary)),
                trailing: const Icon(Icons.add_circle_outline, color: primaryTeal),
                onTap: () {
                  FoodService.addFoodToDiary(food, meal, _currentGrams);
                  
                  Navigator.pop(bottomSheetContext); 
                  Navigator.pop(context); 
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Aggiunto a $meal!'), backgroundColor: Colors.green),
                  );
                },
              )),
            ],
          ),
        );
      },
    );
  }
}