import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/widgets/inputs/medito_segmented_tabs.dart';

void main() {
  testWidgets('segments read as tabs with their position', (tester) async {
    final handle = tester.ensureSemantics();
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => MeditoSegmentedTabs(
              labels: const ['Timer', 'Stopwatch'],
              selectedIndex: selected,
              onChanged: (i) => setState(() => selected = i),
            ),
          ),
        ),
      ),
    );

    final timer = tester.getSemantics(find.text('Timer'));
    expect(timer.getSemanticsData().role, SemanticsRole.tab);
    expect(
      timer,
      matchesSemantics(
        label: 'Timer',
        hint: 'Tab 1 of 2',
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );

    tester.semantics.tap(find.semantics.byLabel('Stopwatch'));
    await tester.pump();
    expect(selected, 1);
    handle.dispose();
  });
}
