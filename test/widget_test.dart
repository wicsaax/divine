import 'package:flutter_test/flutter_test.dart';

import 'package:divine/core/bazi.dart';
import 'package:divine/core/biblio.dart';
import 'package:divine/core/ziwei.dart';
import 'package:divine/core/generic.dart';
import 'package:divine/core/iching.dart';
import 'package:divine/core/lenormand.dart';
import 'package:divine/core/numerology.dart';
import 'package:divine/core/ogham.dart';
import 'package:divine/core/plum.dart';
import 'package:divine/core/runes.dart';
import 'package:divine/core/tarot.dart';
import 'package:divine/core/yesno.dart';

void main() {
  group('static data integrity', () {
    test('tarot deck has 78 cards', () {
      expect(tarotDeck.length, 78);
    });

    test('elder futhark has 24 runes', () {
      expect(elderFuthark.length, 24);
    });

    test('iching has 64 hexagrams with unique binaries', () {
      expect(hexagrams.length, 64);
      final binaries = hexagrams.map((h) => h.binary).toSet();
      expect(binaries.length, 64);
    });
  });

  group('engines run end-to-end', () {
    test('tarot all spreads', () {
      final e = TarotEngine();
      for (final v in e.variants) {
        final r = e.perform(variantKey: v.key);
        expect(r.items.isNotEmpty, true);
      }
    });

    test('iching coin', () {
      final r = IChingEngine().perform(variantKey: 'coin');
      expect(r.items.length, 6);
      expect(r.extras['originalNumber'], inInclusiveRange(1, 64));
    });

    test('runes all spreads', () {
      final e = RunesEngine();
      for (final v in e.variants) {
        final r = e.perform(variantKey: v.key);
        expect(r.items.isNotEmpty, true);
      }
    });

    test('plum blossom produces valid hexagram + change', () {
      final r = PlumBlossomEngine().perform(variantKey: 'random');
      expect(r.extras['originalNumber'], inInclusiveRange(1, 64));
      expect(r.extras['derivedNumber'], inInclusiveRange(1, 64));
      expect(r.extras['changingYao'], inInclusiveRange(1, 6));
    });

    test('numerology computes life path from valid birthdate', () {
      final r = NumerologyEngine()
          .perform(variantKey: 'life_path', inputs: {'birthdate': '1990-06-15'});
      // 1+9+9+0 + 6 + 1+5 = 31 → 4
      expect(r.extras['lifePath'], 4);
    });

    test('numerology rejects bad input', () {
      expect(
        () => NumerologyEngine().perform(variantKey: 'life_path', inputs: {'birthdate': 'oops'}),
        throwsArgumentError,
      );
    });

    test('lenormand both spreads', () {
      final e = LenormandEngine();
      for (final v in e.variants) {
        final r = e.perform(variantKey: v.key);
        expect(r.items.isNotEmpty, true);
      }
    });

    test('yesno all variants produce a tendency', () {
      final e = YesNoEngine();
      for (final v in e.variants) {
        final r = e.perform(variantKey: v.key);
        expect(r.extras['tendency'], isNotNull);
      }
    });

    test('biblio gives a reference for every variant', () {
      final e = BiblioEngine();
      for (final v in e.variants) {
        final r = e.perform(variantKey: v.key);
        expect(r.extras['reference'], isNotNull);
      }
    });

    test('ogham all spreads', () {
      final e = OghamEngine();
      for (final v in e.variants) {
        final r = e.perform(variantKey: v.key);
        expect(r.items.isNotEmpty, true);
      }
    });

    test('generic engine returns variant info', () {
      final e = GenericEngine();
      for (final v in e.variants) {
        final r = e.perform(variantKey: v.key);
        expect(r.variantName, v.name);
      }
    });

    test('bazi computes four pillars from real lunar calendar', () {
      final e = BaziEngine();
      final r = e.perform(variantKey: 'overall', inputs: {
        'birthdate': '1990-06-15',
        'birthtime': '14:30',
        'gender': '男',
      });
      expect(r.items.length, 4);
      final pillars = r.extras['pillars'] as Map;
      expect((pillars['year'] as String).length, 2);
      expect((pillars['day'] as String).length, 2);
      expect((r.extras['dayMaster'] as String).length, 1);
    });

    test('ziwei produces 12 palaces with 14 main stars', () {
      final e = ZiWeiEngine();
      final r = e.perform(variantKey: 'overall', inputs: {
        'birthdate': '1990-06-15',
        'birthtime': '14:30',
        'gender': '男',
      });
      // 12 palace items
      expect(r.items.length, 12);
      final palaces = (r.extras['palaces'] as List).cast<Map>();
      // 14 main stars total across all palaces
      final allStars = palaces.expand((p) => (p['stars'] as List)).toList();
      expect(allStars.length, 14);
      // Each palace 干支 should be 2 chars
      for (final p in palaces) {
        expect((p['ganZhi'] as String).length, 2);
      }
      // Five-element bureau should be one of the 5
      expect(
        r.extras['bureau'],
        isIn(['水二局', '木三局', '金四局', '土五局', '火六局']),
      );
    });

    test('ziwei requires birth time', () {
      final e = ZiWeiEngine();
      expect(
        () => e.perform(variantKey: 'overall', inputs: {
          'birthdate': '1990-06-15',
        }),
        throwsArgumentError,
      );
    });

    test('bazi handles unknown birth time', () {
      final e = BaziEngine();
      final r = e.perform(variantKey: 'overall', inputs: {
        'birthdate': '1990-06-15',
      });
      final pillars = r.extras['pillars'] as Map;
      expect(pillars['hour'], '');
    });
  });
}
