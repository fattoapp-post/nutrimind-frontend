import 'package:flutter_test/flutter_test.dart';
import 'package:nutrimind/core/community_models.dart';
import 'package:nutrimind/core/models.dart';

/// Questi test proteggono il contratto con il database: enum, vincoli e
/// campi calcolati. Un valore che il database rifiuta qui si vede subito,
/// invece di scoprirlo quando l'utente prova a salvare.
void main() {
  group('MealSlot', () {
    test('copre esattamente i valori dell\'enum meal_slot', () {
      expect(
        MealSlot.values.map((s) => s.value).toList(),
        ['breakfast', 'morning_snack', 'lunch', 'afternoon_snack', 'dinner', 'evening_snack'],
      );
    });

    test('non esiste lo slot "snack", che il database rifiuterebbe', () {
      expect(MealSlot.values.any((s) => s.value == 'snack'), isFalse);
    });

    test('fromValue riconosce i valori del database', () {
      expect(MealSlot.fromValue('evening_snack'), MealSlot.eveningSnack);
      expect(MealSlot.fromValue('afternoon_snack'), MealSlot.afternoonSnack);
    });

    test('fromValue su un valore ignoto non lancia', () {
      expect(MealSlot.fromValue('snack'), MealSlot.morningSnack);
      expect(MealSlot.fromValue(null), MealSlot.morningSnack);
    });

    test('ogni slot ha un\'etichetta e un orario', () {
      for (final slot in MealSlot.values) {
        expect(slot.label, isNotEmpty, reason: slot.value);
        expect(slot.time, matches(RegExp(r'^\d{2}:\d{2}$')), reason: slot.value);
      }
    });
  });

  group('Food', () {
    Map<String, dynamic> row({String name = 'Pesto alla genovese', String? brand = 'Barilla'}) => {
          'id': '11111111-1111-1111-1111-111111111111',
          'name': name,
          'brand': brand,
          'source': 'openfoodfacts',
          'verification': 'unverified',
          'kcal': 492,
          'protein_g': 4.7,
          'carbs_g': 11,
          'fat_g': 47,
        };

    test('legge una riga di foods con i numeri come arrivano da Postgres', () {
      final food = Food.fromJson({...row(), 'kcal': '492.00', 'protein_g': 4.7});
      expect(food.name, 'Pesto alla genovese');
      expect(food.proteinG, 4.7);
      expect(food.isVerified, isFalse);
    });

    test('il sottotitolo mostra la marca quando è diversa dal nome', () {
      expect(Food.fromJson(row()).subtitle, 'Barilla');
    });

    test('il sottotitolo non ripete la marca uguale al nome', () {
      expect(Food.fromJson(row(name: 'Nutella', brand: 'Nutella')).subtitle, isEmpty);
      expect(Food.fromJson(row(name: 'Nutella', brand: ' nutella ')).subtitle, isEmpty);
    });

    test('senza marca il sottotitolo mostra solo la porzione', () {
      final food = Food.fromJson({...row(brand: null), 'serving_label': 'Porzione 30 g'});
      expect(food.subtitle, 'Porzione 30 g');
    });
  });

  group('NutrientFilters', () {
    test('senza limiti non è attivo', () {
      expect(NutrientFilters.none.hasBounds, isFalse);
      expect(NutrientFilters.none.isActive, isFalse);
      expect(NutrientFilters.none.toParams(), isEmpty);
    });

    test('manda alla RPC solo i parametri impostati', () {
      const f = NutrientFilters(minProtein: 50, maxFat: 10, sort: 'protein_desc');
      expect(f.toParams(), {'p_min_protein': 50.0, 'p_max_fat': 10.0, 'p_sort': 'protein_desc'});
    });

    test('il solo ordinamento non è un limite di ricerca', () {
      const f = NutrientFilters(sort: 'kcal_asc');
      expect(f.hasBounds, isFalse);
      expect(f.isActive, isTrue);
      expect(f.activeCount, 1);
    });

    test('il riassunto è leggibile', () {
      const f = NutrientFilters(minProtein: 50, maxFat: 10);
      expect(f.summary, 'Proteine ≥ 50 g · Grassi ≤ 10 g');
    });

    test('i valori decimali nel riassunto hanno un decimale solo', () {
      expect(const NutrientFilters(minProtein: 7.5).summary, 'Proteine ≥ 7.5 g');
    });

    test('gli ordinamenti noti hanno tutti un\'etichetta', () {
      for (final key in NutrientFilters.sortLabels.keys) {
        expect(NutrientFilters(sort: key).summary, isNotEmpty, reason: key);
      }
    });
  });

  group('OffProduct', () {
    const pesto = OffProduct(name: 'Pesto', kcal: 492, proteinG: 4.7, carbsG: 11, fatG: 47);
    const bresaola = OffProduct(name: 'Bresaola', kcal: 151, proteinG: 33, carbsG: 0.5, fatG: 2);

    test('i filtri si applicano anche ai prodotti del catalogo esteso', () {
      const soloProteici = NutrientFilters(minProtein: 30, maxFat: 10);
      expect(bresaola.matches(soloProteici), isTrue);
      expect(pesto.matches(soloProteici), isFalse);
    });

    test('senza filtri passa qualsiasi prodotto', () {
      expect(pesto.matches(NutrientFilters.none), isTrue);
    });

    test('non ripete la marca uguale al nome, come per gli alimenti locali', () {
      const nutella = OffProduct(name: 'Nutella', brand: 'Nutella', kcal: 539);
      const barilla = OffProduct(name: 'Pesto alla genovese', brand: 'Barilla', kcal: 492);
      expect(nutella.brandLabel, isNull);
      expect(barilla.brandLabel, 'Barilla');
    });

    test('legge le chiavi normalizzate dalla Edge Function, non quelle di OFF', () {
      final p = OffProduct.fromJson({
        'barcode': '8076809513753',
        'name': 'Pesto alla genovese',
        'brand': 'Barilla',
        'kcal': 492,
        'protein_g': 4.7,
        'nutriscore_grade': 'e',
      });
      expect(p.barcode, '8076809513753');
      expect(p.nutriscoreGrade, 'E');
      expect(p.fatG, 0, reason: 'un campo assente vale zero, non null');
    });
  });

  group('AppNotification', () {
    AppNotification build(String type, Map<String, dynamic> data) => AppNotification.fromJson({
          'id': '22222222-2222-2222-2222-222222222222',
          'type': type,
          'title': 'Titolo',
          'body': 'Corpo',
          'data': data,
        });

    test('un messaggio di chat arriva come system con data.kind', () {
      expect(build('system', {'kind': 'new_message'}).isMessage, isTrue);
    });

    test('una notifica di sistema vera non è un messaggio', () {
      expect(build('system', {'kind': 'maintenance'}).isMessage, isFalse);
      expect(build('new_comment', const {}).isMessage, isFalse);
    });

    test('espone la conversazione a cui tornare', () {
      final n = build('system', {'kind': 'new_message', 'conversation_id': 'abc'});
      expect(n.conversationId, 'abc');
    });
  });

  group('Etichette allineate ai vincoli del database', () {
    test('goal_tags: solo i cinque valori ammessi da suggested_meals', () {
      expect(
        goalTagLabels.keys.toSet(),
        {'high_protein', 'low_carb', 'low_fat', 'high_fiber', 'balanced'},
      );
    });

    test('dietary_restrictions: i nove valori ammessi da patient_settings', () {
      expect(
        dietaryRestrictionLabels.keys.toSet(),
        {'vegetarian', 'vegan', 'gluten_free', 'lactose_free', 'nut_free', 'halal', 'kosher', 'no_pork', 'no_fish'},
      );
    });
  });
}
