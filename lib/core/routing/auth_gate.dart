import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_controller.dart';
import 'routes.dart';

final authPromptCoordinatorProvider = Provider<AuthPromptCoordinator>(
  AuthPromptCoordinator.new,
);

/// Bir vaqtda faqat bitta login oynasini ochadi.
class AuthPromptCoordinator {
  AuthPromptCoordinator(this._ref);

  final Ref _ref;
  Completer<bool>? _activePrompt;

  Future<bool> require(BuildContext context, WidgetRef ref) {
    if (ref.read(authControllerProvider).isAuthenticated) {
      return Future.value(true);
    }
    final active = _activePrompt;
    if (active != null) return active.future;

    final prompt = Completer<bool>();
    _activePrompt = prompt;
    _open(context, prompt);
    return prompt.future;
  }

  void _open(BuildContext context, Completer<bool> prompt) {
    var returnTo = Routes.home;
    try {
      returnTo = GoRouterState.of(context).uri.toString();
    } on Object {
      // Modal/sheet context route state'ga ega bo'lmasligi mumkin.
    }

    try {
      unawaited(
        context
            .push<bool>(Routes.authPhoneFor(returnTo: returnTo, modal: true))
            .then((result) {
              // Success PhoneScreen tomonidan route pop bo'lgandan keyingi
              // frame'da yakunlanadi; aks holda continuation yangi route'ni
              // pop animatsiyasining oldiga chiqarib yuborishi mumkin.
              if (result == true) return;
              _completeIfCurrent(
                prompt,
                _ref.read(authControllerProvider).isAuthenticated,
              );
            }),
      );
    } on Object {
      // Context o'lik (widget deactivated) — push tashladi. Completer ochiq
      // qolsa keyingi BARCHA login so'rovlari shu o'lik future'ni kutib
      // sessiya davomida osilib qolardi.
      _completeIfCurrent(prompt, false);
    }
  }

  void complete(bool authenticated) {
    final active = _activePrompt;
    if (active != null) _completeIfCurrent(active, authenticated);
  }

  void _completeIfCurrent(Completer<bool> prompt, bool value) {
    if (!identical(_activePrompt, prompt) || prompt.isCompleted) return;
    _activePrompt = null;
    prompt.complete(value);
  }
}

Future<bool> requireAuthentication(BuildContext context, WidgetRef ref) {
  return ref.read(authPromptCoordinatorProvider).require(context, ref);
}

/// Login muvaffaqiyatli bo'lgach berilgan himoyalangan route'ni ochadi.
Future<void> pushAuthenticated(
  BuildContext context,
  WidgetRef ref,
  String location,
) async {
  // Auth almashganda caller widget qayta qurilishi mumkin. Router instance'ni
  // oldindan ushlab qolish continuation'ni eski BuildContext'ga bog'lamaydi.
  final router = GoRouter.of(context);
  if (!await requireAuthentication(context, ref)) {
    return;
  }
  await router.push<Object?>(location);
}
