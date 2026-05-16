import 'package:flutter_test/flutter_test.dart';

import 'package:divine/core/biblio.dart';
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
  });
}
