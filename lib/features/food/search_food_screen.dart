import 'package:flutter/material.dart';

class SearchFoodScreen extends StatefulWidget {
  final String mealName; // Riceve il nome del pasto (es. 'Colazione')

  const SearchFoodScreen({super.key, required this.mealName});

  @override
  State<SearchFoodScreen> createState() => _SearchFoodScreenState();
}

class _SearchFoodScreenState extends State<SearchFoodScreen> {
  // Colori del tuo tema
  static const Color bgColor = Color(0xFF101817);
  static const Color cardColor = Color(0xFF17221F);
  static const Color textSecondary = Color(0xFFA1AFA9);
  static const Color primaryTeal = Color(0xFF127B6D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Aggiungi a ${widget.mealName}',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barra di ricerca
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              autofocus: true, // Apre subito la tastiera
              decoration: InputDecoration(
                hintText: 'Cerca un alimento...',
                hintStyle: const TextStyle(color: textSecondary),
                prefixIcon: const Icon(Icons.search, color: textSecondary),
                filled: true,
                fillColor: cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                // TODO: Chiamata a Supabase o API (es. OpenFoodFacts) per cercare il cibo
              },
            ),
          ),
          
          // Risultati (Per ora un messaggio fittizio)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu, size: 48, color: textSecondary),
                  SizedBox(height: 16),
                  Text(
                    'Cerca un alimento da aggiungere',
                    style: TextStyle(color: textSecondary, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}