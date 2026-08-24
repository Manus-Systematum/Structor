import 'package:flutter/widgets.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// What each weapon keyword does, available to any widget that draws one.
///
/// An inherited scope rather than a parameter because the widgets that show a
/// keyword — the weapon table, on the turn page and the army page — sit four
/// and five levels below where the data is loaded, and every level in between
/// would otherwise carry a map it does not use.
///
/// Absent or empty is a normal state, not a failure: a keyword nobody
/// published wording for stays a plain chip (§3.14).
class WeaponKeywordScope extends InheritedWidget {
  final Map<String, WeaponKeywordText> keywords;

  const WeaponKeywordScope({
    super.key,
    required this.keywords,
    required super.child,
  });

  static Map<String, WeaponKeywordText> of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WeaponKeywordScope>()
          ?.keywords ??
      const {};

  @override
  bool updateShouldNotify(WeaponKeywordScope old) => old.keywords != keywords;
}
