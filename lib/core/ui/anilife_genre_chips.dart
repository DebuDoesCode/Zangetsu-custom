import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'genre_chips.dart' show kGenres;

/// Anilife-style filter row that floats over the Home banner: a filled accent
/// "All" pill followed by outlined, translucent genre pills.
///
/// "All" starts selected and is purely visual for now; tapping any chip hands
/// the genre (null for All) to [onTap].
class AnilifeGenreChips extends StatefulWidget {
  const AnilifeGenreChips({super.key, required this.onTap});

  final void Function(String? genre) onTap;

  @override
  State<AnilifeGenreChips> createState() => _AnilifeGenreChipsState();
}

class _AnilifeGenreChipsState extends State<AnilifeGenreChips> {
  String? _selected; // null = All

  @override
  Widget build(BuildContext context) {
    final labels = <String?>[null, ...kGenres];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final genre = labels[i];
          final selected = genre == _selected;
          return GestureDetector(
            onTap: () {
              setState(() => _selected = genre);
              widget.onTap(genre);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.accent
                    : Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(22),
                border: selected
                    ? null
                    : Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1.2,
                      ),
              ),
              child: Text(
                genre ?? 'All',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
