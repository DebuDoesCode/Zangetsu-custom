import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../aniyomi/aniyomi_image_provider.dart';
import '../mihon/mihon_image_provider.dart';
import '../theme/app_colors.dart';
import 'image_fade.dart';

/// Anilife-style "Continue Watching" card: a rounded 16:9 thumbnail with a
/// centred play glyph, an info button top-left and a resume bar along the
/// base, and the title + episode label *under* the image (not over it).
///
/// Height budget for the host row: thumbnail ([cellWidth] * 9 / 16) plus
/// [captionHeight].
class AnilifeContinueCard extends StatefulWidget {
  const AnilifeContinueCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.headers,
    required this.progress,
    this.subtitle,
    this.onTap,
    this.onInfo,
    this.cellWidth = 190,
  });

  /// Space reserved under the thumbnail for the two caption lines.
  static const double captionHeight = 46;

  final String title;
  final String? imageUrl;
  final Map<String, String>? headers;
  final double progress;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Info button (and long-press) — opens the media info sheet.
  final VoidCallback? onInfo;
  final double cellWidth;

  @override
  State<AnilifeContinueCard> createState() => _AnilifeContinueCardState();
}

class _AnilifeContinueCardState extends State<AnilifeContinueCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final memW = (widget.cellWidth * dpr).round();
    final p = widget.progress.clamp(0.0, 1.0);
    final sub = widget.subtitle;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onInfo,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _thumb(memW),
                      // Soft scrim so the glyphs read on bright art.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x55000000), Color(0x22000000)],
                          ),
                        ),
                      ),
                      const Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _CircleButton(
                          icon: Icons.info,
                          onTap: widget.onInfo,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 4,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                            FractionallySizedBox(
                              alignment: AlignmentDirectional.centerStart,
                              widthFactor: p,
                              child: ColoredBox(color: AppColors.accent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (sub != null && sub.isNotEmpty)
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(int memW) {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      return ColoredBox(color: AppColors.surface2);
    }
    final h = widget.headers;
    if (h?['x-ani-src'] != null || h?['x-mihon-src'] != null) {
      // Cloudflare-walled Aniyomi/Mihon art loads through the source client.
      return Image(
        image: ResizeImage(
          h?['x-ani-src'] != null
              ? AniyomiImage(int.parse(h!['x-ani-src']!), url)
              : MihonImage(int.parse(h!['x-mihon-src']!), url),
          width: memW,
        ),
        fit: BoxFit.cover,
        frameBuilder: imageFadeIn,
        errorBuilder: (_, _, _) => ColoredBox(color: AppColors.surface2),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: h,
      memCacheWidth: memW,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => ColoredBox(color: AppColors.surface2),
      errorWidget: (_, _, _) => ColoredBox(color: AppColors.surface2),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
