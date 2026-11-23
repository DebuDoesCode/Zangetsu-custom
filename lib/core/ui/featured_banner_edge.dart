import 'dart:async';

import 'package:flutter/foundation.dart'
    show ValueListenable, listEquals, visibleForTesting;
import 'package:flutter/material.dart';

import '../models/media_item.dart';
import 'banner_image_preloader.dart';
import '../theme/app_colors.dart';
import 'banner_actions.dart';
import 'featured_carousel.dart' show heroHeightFor;
import 'featured_hero.dart' show HeroMeta;
import 'image_fade.dart';
import 'mobile_hero_art.dart';
import 'native_cover_provider.dart';
import 'poster_palette.dart';
import 'route_observer.dart';
import 'tmdb_hero_banner.dart';

/// Full-bleed Home banner with centered title art and one details action.
class FeaturedBannerEdge extends StatefulWidget {
  const FeaturedBannerEdge({
    super.key,
    required this.items,
    required this.onInfo,
    this.meta,
    this.reading = false,
    this.isActive = true,
    this.onArtColor,
    this.backgroundTint,
    this.paletteLoader,
    this.anilifeLayout = false,
  });

  /// Anilife-style content block: meta row, title art, genres, dots and an
  /// n / total counter, with the whole banner tappable instead of a button.
  final bool anilifeLayout;

  final List<MediaItem> items;
  final void Function(MediaItem) onInfo;
  final Future<HeroMeta?> Function(MediaItem)? meta;
  final bool reading;
  final bool isActive;

  /// Reports the visible artwork's dominant colour (null when there is none),
  /// so Home can tint its background. Mirrors [FeaturedCarousel].
  final ValueChanged<Color?>? onArtColor;

  /// Background tint Home is currently painting behind the banner. The bottom
  /// gradient melts into it so the banner and the page never form a seam.
  final ValueListenable<Color?>? backgroundTint;

  @visibleForTesting
  final Future<Color?> Function(String, Map<String, String>?)? paletteLoader;

  @override
  State<FeaturedBannerEdge> createState() => _FeaturedBannerEdgeState();
}

class _FeaturedBannerEdgeState extends State<FeaturedBannerEdge>
    with RouteAware {
  late List<MediaItem> _pages;
  int _index = 0;
  Timer? _timer;
  final _imagePreloader = BannerImagePreloader();
  PageRoute<dynamic>? _route;
  bool _routeIsCurrent = true;

  /// TMDB backdrop per AniList anime item (by id), once resolved — AniList's
  /// own `bannerImage` is often missing or low-res. Items with no entry here
  /// just keep their own banner.
  final Map<String, String> _tmdbBanners = {};

  bool get _isVisible => widget.isActive && _routeIsCurrent;

  /// Current background tint from [widget.backgroundTint] (null → theme bg).
  Color? _bgTint;

  @override
  void initState() {
    super.initState();
    _pages = widget.items.take(6).toList();
    _bgTint = widget.backgroundTint?.value;
    widget.backgroundTint?.addListener(_onBackgroundTint);
    _startTimer();
    _syncTintAfterFrame();
    _loadTmdbBanners();
  }

  /// Each title's TMDB backdrop resolves (and precaches) independently; one
  /// already on screen when its backdrop lands just crossfades to it via
  /// [_artwork]'s own AnimatedSwitcher.
  void _loadTmdbBanners() => loadTmdbBanners(
    _pages,
    _tmdbBanners,
    context: context,
    mounted: () => mounted,
    onResolved: (id, url) => setState(() => _tmdbBanners[id] = url),
  );

  String? _bannerFor(MediaItem item) => tmdbBannerFor(item, _tmdbBanners);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    appRouteObserver.unsubscribe(this);
    if (route is PageRoute<dynamic>) {
      _route = route;
      _routeIsCurrent = route.isCurrent;
      appRouteObserver.subscribe(this, route);
    } else {
      _route = null;
      _routeIsCurrent = true;
    }
    _startTimer();
  }

  @override
  void didPush() => _setRouteCurrent(true);

  @override
  void didPopNext() => _setRouteCurrent(true);

  @override
  void didPushNext() => _setRouteCurrent(false);

  @override
  void didPop() => _setRouteCurrent(false);

  void _setRouteCurrent(bool current) {
    if (_routeIsCurrent == current) return;
    _routeIsCurrent = current;
    _startTimer();
    if (_isVisible) _syncTintAfterFrame();
  }

  void _syncTintAfterFrame() {
    // The notifier must not be written during this build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTint();
    });
  }

  @override
  void didUpdateWidget(FeaturedBannerEdge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backgroundTint != widget.backgroundTint) {
      oldWidget.backgroundTint?.removeListener(_onBackgroundTint);
      _bgTint = widget.backgroundTint?.value;
      widget.backgroundTint?.addListener(_onBackgroundTint);
    }
    final next = widget.items.take(6).toList();
    final changed = !listEquals(next, _pages);
    if (changed) {
      setState(() {
        _pages = next;
        _index = 0;
      });
      _loadTmdbBanners();
    }
    if (changed || oldWidget.isActive != widget.isActive) _startTimer();
    if (changed ||
        (!oldWidget.isActive && widget.isActive) ||
        (oldWidget.onArtColor == null && widget.onArtColor != null)) {
      _syncTintAfterFrame();
    }
  }

  void _onBackgroundTint() {
    if (!mounted) return;
    setState(() => _bgTint = widget.backgroundTint?.value);
  }

  @override
  void dispose() {
    _imagePreloader.dispose();
    appRouteObserver.unsubscribe(this);
    widget.backgroundTint?.removeListener(_onBackgroundTint);
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_isVisible && _pages.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _go(1));
    }
  }

  void _go(int delta) {
    if (!mounted || !_isVisible || _pages.isEmpty) return;
    setState(() => _index = (_index + delta + _pages.length) % _pages.length);
    _syncTint();
  }

  /// Extracts the visible item's artwork colour for the caller's background
  /// tint. A slow decode that resolves after the banner moved on is discarded.
  Future<void> _syncTint() async {
    if (!_isVisible || widget.onArtColor == null) return;
    if (_pages.isEmpty) {
      widget.onArtColor?.call(null);
      return;
    }
    final item = _pages[_index];
    final banner = _bannerFor(item);
    final art = mobileHeroArt(item.cover, banner);
    if (art == null || art.isEmpty) {
      widget.onArtColor?.call(null);
      return;
    }
    final poster = item.cover?.trim();
    final backdrop = banner?.trim();
    final sampleArt = adaptiveArtUrl(poster, backdrop) ?? art;
    final usingBackdrop =
        (poster == null || poster.isEmpty) &&
        backdrop != null &&
        backdrop.isNotEmpty;
    final c = await (widget.paletteLoader ?? extractAdaptiveColor)(
      adaptiveSampleUrl(sampleArt, backdrop: usingBackdrop),
      item.coverHeaders,
    );
    if (!mounted ||
        !_isVisible ||
        _pages.isEmpty ||
        !identical(_pages[_index], item)) {
      return;
    }
    widget.onArtColor?.call(c);
  }

  @override
  Widget build(BuildContext context) {
    final height = heroHeightFor(context);
    if (_pages.isEmpty) return SizedBox(height: height);

    if (_isVisible) {
      final mq = MediaQuery.of(context);
      _imagePreloader.warm(
        context,
        _pages,
        _index,
        artwork: (item) {
          final url = mobileHeroArt(item.cover, _bannerFor(item));
          return url == null || url.isEmpty
              ? null
              : ResizeImage(
                  nativeCoverProvider(url, item.coverHeaders),
                  width: mobileHeroDecodeWidth(
                    item.sourceId,
                    (mq.size.width * mq.devicePixelRatio).round(),
                  ),
                );
        },
      );
    }

    final item = _pages[_index];
    final pageColor = _bgTint ?? AppColors.bg;
    return RepaintBoundary(
      child: SizedBox(
        key: const ValueKey('featuredEdgeBanner'),
        width: double.infinity,
        height: height,
        child: GestureDetector(
          key: const ValueKey('edgeBannerGesture'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.anilifeLayout ? () => widget.onInfo(item) : null,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -80) {
              _go(1);
              _startTimer();
            } else if (velocity > 80) {
              _go(-1);
              _startTimer();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 650),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: KeyedSubtree(
                  key: ValueKey(item.id),
                  child: _artwork(item),
                ),
              ),
              IgnorePointer(
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: pageColor),
                  duration: adaptiveColourDuration,
                  curve: adaptiveColourCurve,
                  builder: (context, colour, _) => DecoratedBox(
                    key: const ValueKey('edgeBannerScrim'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          if (widget.backgroundTint == null) ...const [
                            Color(0x66000000),
                            Color(0x33000000),
                            Color(0xCC0B0B0F),
                          ] else ...[
                            (colour ?? AppColors.bg).withValues(alpha: 0.02),
                            (colour ?? AppColors.bg).withValues(alpha: 0.12),
                            (colour ?? AppColors.bg).withValues(alpha: 0.34),
                          ],
                          colour ?? AppColors.bg,
                        ],
                        stops: const [0, 0.28, 0.74, 1],
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 650),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: widget.anilifeLayout
                    ? _anilifeContent(item)
                    : Align(
                  alignment: Alignment.bottomCenter,
                  key: ValueKey('edgeBannerContent-${item.id}'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 64),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BannerTitleLogo(
                          item: item,
                          maxHeight: 84,
                          maxWidthFactor: 0.78,
                          fontSize: 30,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 18,
                          child: Center(
                            child: BannerMetaLine(
                              metaFuture: widget.meta?.call(item),
                              reading: widget.reading,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: 148,
                          height: 48,
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            child: InkWell(
                              key: const ValueKey('edgeBannerViewButton'),
                              onTap: () => widget.onInfo(item),
                              borderRadius: BorderRadius.circular(24),
                              child: Center(
                                child: Text(
                                  'View Details',
                                  style: TextStyle(
                                    color: AppColors.bg,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.anilifeLayout && _pages.length > 1)
                Positioned(
                  right: 16,
                  // Clears the status bar + header row + genre chips.
                  top: MediaQuery.paddingOf(context).top + 112,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${_index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: ' / ${_pages.length}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_pages.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 18,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      final active = index == _index;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          width: active ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: widget.anilifeLayout && active
                                ? AppColors.accent
                                : Colors.white.withValues(
                                    alpha: active ? 1 : 0.55,
                                  ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Anilife-style content block: a meta row (episodes · year) over big title
  /// art, with the genres underneath in plain sentence case. Dots + the n / N
  /// counter are drawn by [build].
  Widget _anilifeContent(MediaItem item) {
    return Align(
      alignment: Alignment.bottomCenter,
      key: ValueKey('anilifeBannerContent-${item.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnilifeMetaRow(
              metaFuture: widget.meta?.call(item),
              reading: widget.reading,
            ),
            const SizedBox(height: 14),
            BannerTitleLogo(
              item: item,
              maxHeight: 96,
              maxWidthFactor: 0.86,
              fontSize: 32,
            ),
            const SizedBox(height: 12),
            _AnilifeGenreLine(metaFuture: widget.meta?.call(item)),
          ],
        ),
      ),
    );
  }

  Widget _artwork(MediaItem item) {
    final url = mobileHeroArt(item.cover, _bannerFor(item));
    final provider = url == null || url.isEmpty
        ? null
        : nativeCoverProvider(url, item.coverHeaders);
    final width =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round();
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF473958), Color(0xFF15151D)],
            ),
          ),
        ),
        if (provider != null)
          // Keyed on the resolved url: when the TMDB backdrop lands for this
          // (already-visible) item, this crossfades to it instead of popping
          // — precached in _loadTmdbBanners first, so it's never a blank
          // frame. The outer page-to-page switch (keyed on item.id) is
          // unaffected since that key doesn't change.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            layoutBuilder: (currentChild, previousChildren) => Stack(
              fit: StackFit.expand,
              children: [...previousChildren, ?currentChild],
            ),
            child: Image(
              key: ValueKey(url),
              image: ResizeImage(
                provider,
                width: mobileHeroDecodeWidth(item.sourceId, width),
              ),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              frameBuilder: imageFadeIn,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}

/// "TV  •  ▣ 8  •  2024" — whatever [HeroMeta] has, dot-separated, white.
class _AnilifeMetaRow extends StatelessWidget {
  const _AnilifeMetaRow({required this.metaFuture, required this.reading});

  final Future<HeroMeta?>? metaFuture;
  final bool reading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: FutureBuilder<HeroMeta?>(
        future: metaFuture,
        builder: (context, snap) {
          final m = snap.data;
          if (m == null) return const SizedBox.shrink();
          final style = TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          );
          final items = <Widget>[
            if (m.episodeCount > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    reading ? Icons.menu_book_rounded : Icons.closed_caption,
                    size: 17,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 5),
                  Text('${m.episodeCount}', style: style),
                ],
              ),
            if (m.year != null && m.year!.isNotEmpty)
              Text(m.year!, style: style),
          ];
          if (items.isEmpty) return const SizedBox.shrink();
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                items[i],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// "Action · Adventure · Comedy" in sentence case under the title art.
class _AnilifeGenreLine extends StatelessWidget {
  const _AnilifeGenreLine({required this.metaFuture});

  final Future<HeroMeta?>? metaFuture;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: FutureBuilder<HeroMeta?>(
        future: metaFuture,
        builder: (context, snap) {
          final genres = snap.data?.genres.take(3).toList() ?? const [];
          if (genres.isEmpty) return const SizedBox.shrink();
          return Text(
            genres.join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 16,
              letterSpacing: 0.4,
            ),
          );
        },
      ),
    );
  }
}
