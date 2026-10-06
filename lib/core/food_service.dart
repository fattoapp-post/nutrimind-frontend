import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FoodService {
  
  // Database mockato per il testing del pisello della fica
  static final List<Map<String, dynamic>> _mockDatabase = [
    {'id': '1', 'name': 'Yogurt greco 0%', 'brand': 'Fage', 'kcal': 100, 'p': 18, 'c': 7, 'g': 0, 'verified': true, 'usage': 15, 'date': '2023-10-01', 'isFavorite': true},
    {'id': '2', 'name': 'Petto di pollo', 'brand': '150 g', 'kcal': 245, 'p': 46, 'c': 0, 'g': 5, 'verified': true, 'usage': 42, 'date': '2023-10-05', 'isFavorite': false},
    {'id': '3', 'name': 'Riso basmati', 'brand': '80 g', 'kcal': 286, 'p': 7, 'c': 62, 'g': 1, 'verified': true, 'usage': 30, 'date': '2023-09-28', 'isFavorite': false},
    {'id': '4', 'name': 'Mandorle', 'brand': '25 g', 'kcal': 150, 'p': 5, 'c': 5, 'g': 13, 'verified': true, 'usage': 5, 'date': '2023-10-06', 'isFavorite': true},
    {'id': '5', 'name': 'Fiocchi d\'avena', 'brand': '50 g', 'kcal': 184, 'p': 7, 'c': 30, 'g': 4, 'verified': false, 'usage': 22, 'date': '2023-10-02', 'isFavorite': false},
    {'id': '6', 'name': 'Salmone', 'brand': '140 g', 'kcal': 286, 'p': 31, 'c': 0, 'g': 18, 'verified': false, 'usage': 8, 'date': '2023-10-04', 'isFavorite': false},
  ];

  static final List<Map<String, dynamic>> _diaryEntries = [];

  static Future<List<Map<String, dynamic>>> getUserFavorites() async {
    await Future.delayed(const Duration(milliseconds: 300)); 
    return List.from(_mockDatabase); 
  }

  static Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final lowerQuery = query.toLowerCase();
    return _mockDatabase.where((food) {
      return food['name'].toString().toLowerCase().contains(lowerQuery) ||
             food['brand'].toString().toLowerCase().contains(lowerQuery);
    }).toList();
  }

  static Future<void> toggleFavorite(String foodId, bool isFavorite) async {
    final index = _mockDatabase.indexWhere((f) => f['id'] == foodId);
    if (index != -1) {
      _mockDatabase[index]['isFavorite'] = isFavorite;
    }
  }

  static Future<void> addFoodToDiary(Map<String, dynamic> food, String mealName, int grams) async {
    double ratio = grams / 100.0;
    _diaryEntries.add({
      'foodId': food['id'],
      'name': food['name'],
      'meal': mealName,
      'grams': grams,
      'kcal': ((food['kcal'] as num) * ratio).round(),
      'p': ((food['p'] as num) * ratio).round(),
      'c': ((food['c'] as num) * ratio).round(),
      'g': ((food['g'] as num) * ratio).round(),
    });
  }

  // Restituisce tutti gli elementi aggiunti oggi
  static Future<List<Map<String, dynamic>>> getDiaryEntries() async {
    return List.from(_diaryEntries);
  }
}