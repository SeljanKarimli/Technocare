import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'image_url.dart';

enum AppImagePlaceholderVariant { neutral, product, project, hero }

class AppRemoteImage extends StatefulWidget {
  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final String? semanticLabel;
  final AppImagePlaceholderVariant placeholderVariant;
  final int? targetWidth;

  const AppRemoteImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.placeholderVariant = AppImagePlaceholderVariant.neutral,
    this.targetWidth,
  });

  @override
  State<AppRemoteImage> createState() => _AppRemoteImageState();
}

class _AppRemoteImageState extends State<AppRemoteImage> {
  var _candidateIndex = 0;
  var _retryToken = 0;
  var _advanceScheduled = false;
  var _exhausted = false;

  List<String> get _candidates => AppImageUrl.candidates(
    widget.source,
    targetWidth: widget.targetWidth,
    useGateway: kIsWeb,
  );

  @override
  void didUpdateWidget(covariant AppRemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.targetWidth != widget.targetWidth) {
      _candidateIndex = 0;
      _retryToken = 0;
      _advanceScheduled = false;
      _exhausted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source.trim();
    if (source.isEmpty) return _statusWidget(isError: true);

    if (AppImageUrl.isAsset(source)) {
      return Image.asset(
        source,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
        semanticLabel: widget.semanticLabel,
        errorBuilder: (_, __, ___) => _statusWidget(isError: true),
      );
    }

    final candidates = _candidates;
    if (_exhausted || candidates.isEmpty) {
      return _statusWidget(isError: true);
    }
    final safeIndex = _candidateIndex.clamp(0, candidates.length - 1);
    final requestUrl = _withRetryToken(candidates[safeIndex]);
    final requestUri = Uri.tryParse(requestUrl);
    final useHtmlFallback =
        kIsWeb &&
        safeIndex == candidates.length - 1 &&
        requestUri?.host.toLowerCase() == 'technocare.az';

    final image = kIsWeb
        ? Image.network(
            requestUrl,
            key: ValueKey<String>('web-image:$requestUrl'),
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            alignment: widget.alignment,
            cacheWidth: useHtmlFallback ? null : widget.targetWidth,
            webHtmlElementStrategy: useHtmlFallback
                ? WebHtmlElementStrategy.prefer
                : WebHtmlElementStrategy.never,
            frameBuilder: (context, child, frame, synchronouslyLoaded) =>
                synchronouslyLoaded || frame != null
                ? child
                : _statusWidget(isError: false),
            errorBuilder: (_, __, ___) => _networkError(),
          )
        : CachedNetworkImage(
            key: ValueKey<String>('native-image:$requestUrl'),
            imageUrl: requestUrl,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            alignment: widget.alignment,
            memCacheWidth: widget.targetWidth,
            maxWidthDiskCache: widget.targetWidth,
            placeholder: (_, __) => _statusWidget(isError: false),
            errorWidget: (_, __, ___) => _networkError(),
          );

    if (widget.semanticLabel == null || widget.semanticLabel!.trim().isEmpty) {
      return image;
    }
    return Semantics(image: true, label: widget.semanticLabel, child: image);
  }

  Widget _networkError() {
    _scheduleAdvance();
    return _statusWidget(isError: false);
  }

  void _scheduleAdvance() {
    if (_advanceScheduled) return;
    _advanceScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hasNext = _candidateIndex + 1 < _candidates.length;
      setState(() {
        _advanceScheduled = false;
        if (hasNext) {
          _candidateIndex++;
        } else {
          _exhausted = true;
        }
      });
    });
  }

  void _retry() {
    setState(() {
      _candidateIndex = 0;
      _retryToken++;
      _advanceScheduled = false;
      _exhausted = false;
    });
  }

  String _withRetryToken(String value) {
    if (_retryToken == 0) return value;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return value;
    return uri
        .replace(
          queryParameters: <String, String>{
            ...uri.queryParameters,
            'tc_retry': _retryToken.toString(),
          },
        )
        .toString();
  }

  Widget _statusWidget({required bool isError}) {
    final icon = switch (widget.placeholderVariant) {
      AppImagePlaceholderVariant.product => Icons.inventory_2_outlined,
      AppImagePlaceholderVariant.project => Icons.factory_outlined,
      AppImagePlaceholderVariant.hero => Icons.precision_manufacturing_outlined,
      AppImagePlaceholderVariant.neutral => Icons.image_outlined,
    };
    final background =
        widget.placeholderVariant == AppImagePlaceholderVariant.hero
        ? const Color(0xFF12331F)
        : widget.placeholderVariant == AppImagePlaceholderVariant.product
        ? const Color(0xFFF4F6F3)
        : const Color(0xFFEAF0EB);
    final foreground =
        widget.placeholderVariant == AppImagePlaceholderVariant.hero
        ? const Color(0xFF5C8A64)
        : const Color(0xFF2F7623);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ColoredBox(
        color: background,
        child: Center(
          child: isError
              ? Semantics(
                  button: true,
                  label: 'Şəkli yenidən yüklə',
                  child: IconButton(
                    tooltip: 'Yenidən cəhd et',
                    onPressed: _retry,
                    icon: Icon(Icons.refresh_rounded, color: foreground),
                  ),
                )
              : Icon(icon, color: foreground, size: 42),
        ),
      ),
    );
  }
}
