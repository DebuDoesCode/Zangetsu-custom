// Anilife-style pieces of the player controls: the "Ends at" pill, the
// outlined skip pill and the labelled bottom pills. Used by the overlay only
// when the Anilife style is selected in Settings.
part of 'player_screen.dart';

/// Whether the Anilife look is active (shared with the Home banner setting).
bool get _anilifePlayerStyle =>
    BannerStyle.current.value == BannerStyle.anilifeId;

/// "1:44 PM — Ends at 1:49 PM" — wall-clock now, and when the episode will
/// finish at the current playback speed.
class _AnilifeEndsAtPill extends StatelessWidget {
  const _AnilifeEndsAtPill({required this.controller});

  final PlayerCubit controller;

  static String _fmt(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final p = controller.player;
    return StreamBuilder<Duration>(
      stream: p.stream.position,
      initialData: p.state.position,
      builder: (context, snap) {
        final dur = p.state.duration;
        if (dur <= Duration.zero) return const SizedBox.shrink();
        final pos = snap.data ?? p.state.position;
        final rate = p.state.rate <= 0 ? 1.0 : p.state.rate;
        final left = dur - pos;
        final remaining = Duration(
          milliseconds: (left.inMilliseconds / rate).round(),
        );
        final now = DateTime.now();
        final ends = now.add(remaining.isNegative ? Duration.zero : remaining);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Text(
            '${_fmt(now)} \u2014 Ends at ${_fmt(ends)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}

/// "+85S" — outlined rounded square, white, replacing the MegaSkip chip.
class _AnilifeSkipPill extends StatelessWidget {
  const _AnilifeSkipPill({required this.seconds, required this.onTap});

  final int seconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.white, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Text(
            '+${seconds}S',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// A bottom-bar pill: icon plus optional text label. With no label it is a
/// circle.
class _AnilifePill extends StatelessWidget {
  const _AnilifePill({
    required this.icon,
    required this.onTap,
    this.label,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final hasLabel = label != null;
    return _withTooltip(
      hasLabel ? null : tooltip,
      Semantics(
        button: true,
        label: label ?? tooltip,
        child: Material(
          color: Colors.black.withValues(alpha: 0.45),
          shape: hasLabel ? const StadiumBorder() : const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: hasLabel
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 11)
                  : const EdgeInsets.all(11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  if (hasLabel) ...[
                    const SizedBox(width: 8),
                    Text(
                      label!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
