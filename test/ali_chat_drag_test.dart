import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bko_app/features/chat/bko_ali_chat_widget.dart';

// Isolate gesture/modal behavior from the audio service used by idle reminders.
class _TestChatNotifier extends AliChatNotifier {
  _TestChatNotifier(super.ref);
  @override
  void setChatOpen(bool open) {
    state = state.copyWith(isChatOpen: open, unreadCount: open ? 0 : state.unreadCount);
  }
}

void main() {
  testWidgets('drag follows successive movements and next tap opens Ali', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({'bko_ali_pos_x': 40.0, 'bko_ali_pos_y': 120.0});
    await tester.pumpWidget(ProviderScope(overrides: [
      aliChatProvider.overrideWith((ref) => _TestChatNotifier(ref)),
    ], child: const MaterialApp(home: Scaffold(
      body: Stack(children: [BkoAliDraggableBubble()]),
    ))));
    await tester.pumpAndSettle();
    final bubble = find.byKey(const ValueKey('ali-chat-bubble'));
    final initial = tester.getCenter(bubble);
    final gesture = await tester.startGesture(initial);
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump(); // Let Flutter recognize the pan gesture first.
    final dragOrigin = tester.getCenter(bubble);
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(tester.getCenter(bubble).dx - dragOrigin.dx, 60);
    await gesture.up();
    await tester.pump();
    expect(find.text('Ali'), findsNothing, reason: 'drag must not open the sheet');
    await tester.tap(bubble);
    await tester.pumpAndSettle();
    expect(find.text('Ali'), findsOneWidget, reason: 'a completed drag must not block a later tap');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
