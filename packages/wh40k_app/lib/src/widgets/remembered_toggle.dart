import 'package:flutter/material.dart';

/// Keeps a fold open across the moment the list throws its widget away.
///
/// **The bug this exists for.** A `ListView` builds only what is near the
/// screen and disposes the rest, taking any `State` with it. A block the
/// player opened, scrolled past, and scrolled back to had folded itself shut
/// again — the app changed something the player had set, with no action from
/// them, which §7.7 says it must never do.
///
/// The open flag therefore lives in the route's [PageStorageBucket], which
/// outlives the element. The identifier is explicit rather than derived from
/// position, so a block keeps its state even if the list around it reorders;
/// it has to be unique within the route, which is why callers namespace it.
mixin RemembersToggle<T extends StatefulWidget> on State<T> {
  /// Unique within the route. Namespace it — `'cards:opponent'`, not
  /// `'opponent'` — since every remembered toggle shares one bucket.
  Object get toggleId;

  /// Used the first time only. What the player did afterwards outranks it.
  bool get initiallyOpen;

  late bool open;
  bool _restored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    final remembered =
        PageStorage.maybeOf(context)?.readState(context, identifier: toggleId);
    open = remembered is bool ? remembered : initiallyOpen;
  }

  void setOpen(bool value) {
    setState(() => open = value);
    PageStorage.maybeOf(context)
        ?.writeState(context, value, identifier: toggleId);
  }

  void toggleOpen() => setOpen(!open);
}
