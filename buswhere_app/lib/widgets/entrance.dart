import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Fades and lifts its child in once, after [delay]. Skipped when the phone
/// asks for reduced motion.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.delay = Duration.zero, this.offset = 12});
  final Widget child;
  final Duration delay;
  final double offset;
  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: BW.base);
  late final _a = CurvedAnimation(parent: _c, curve: BW.easeOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else if (_c.status == AnimationStatus.dismissed) {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        child: widget.child,
        builder: (_, child) => Opacity(
          opacity: _a.value,
          child: Transform.translate(offset: Offset(0, widget.offset * (1 - _a.value)), child: child),
        ),
      );
}
