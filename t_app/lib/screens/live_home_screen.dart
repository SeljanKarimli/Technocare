import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/home_content.dart';
import '../models/shop_models.dart';
import '../repositories/shop_repository.dart';
import '../services/whatsapp_order_service.dart';
import 'shop_product_detail_page.dart';

class LiveHomeScreen extends StatefulWidget {
  final VoidCallback onOpenShop;

  const LiveHomeScreen({super.key, required this.onOpenShop});

  @override
  State<LiveHomeScreen> createState() => _LiveHomeScreenState();
}

class _LiveHomeScreenState extends State<LiveHomeScreen> {
  late Future<HomeContent> _content;

  @override
  void initState() {
    super.initState();
    _content = context.read<ShopRepository>().getHome();
  }

  Future<void> _refresh() async {
    final next = context.read<ShopRepository>().getHome(forceRefresh: true);
    setState(() => _content = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeContent>(
      future: _content,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _HomeSkeleton();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _HomeError(
            error: snapshot.error?.toString(),
            onRetry: _refresh,
          );
        }
        return RefreshIndicator(
          color: const Color(0xFF2F7623),
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount:
                snapshot.data!.sections.length +
                (snapshot.data!.isStale ? 2 : 1),
            itemBuilder: (context, index) {
              if (snapshot.data!.isStale && index == 0) {
                return _HomeOfflineBanner(cachedAt: snapshot.data!.cachedAt);
              }
              final sectionIndex = index - (snapshot.data!.isStale ? 1 : 0);
              if (sectionIndex == snapshot.data!.sections.length) {
                return const _ContactFooter();
              }
              return _HomeSectionView(
                section: snapshot.data!.sections[sectionIndex],
                onOpenShop: widget.onOpenShop,
              );
            },
          ),
        );
      },
    );
  }
}

class _HomeSectionView extends StatelessWidget {
  final HomeSection section;
  final VoidCallback onOpenShop;

  const _HomeSectionView({required this.section, required this.onOpenShop});

  @override
  Widget build(BuildContext context) {
    return switch (section.type) {
      'hero' => _HeroSection(section: section, onOpenShop: onOpenShop),
      'about' || 'mission' => _AboutSection(section: section),
      'categories' => _CategorySection(
        section: section,
        onOpenShop: onOpenShop,
      ),
      'brands' => _BrandSection(section: section),
      'best_sellers' => _BestSellerSection(section: section),
      'services' => _DarkCardSection(section: section),
      'quality' => _QualitySection(section: section),
      'projects' || 'partners' => _GallerySection(section: section),
      'contact' => const SizedBox.shrink(),
      _ => const SizedBox.shrink(),
    };
  }
}

class _HeroSection extends StatelessWidget {
  final HomeSection section;
  final VoidCallback onOpenShop;

  const _HeroSection({required this.section, required this.onOpenShop});

  @override
  Widget build(BuildContext context) {
    final image = section.images.isNotEmpty ? section.images.first : '';
    return SizedBox(
      height: 470,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image.isNotEmpty)
            CachedNetworkImage(
              imageUrl: image,
              fit: BoxFit.cover,
              placeholder: (_, __) => const _HeroBackdrop(),
              errorWidget: (_, __, ___) => const _HeroBackdrop(),
            )
          else
            const _HeroBackdrop(),
          Container(color: Colors.black.withValues(alpha: 0.48)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 78, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    section.eyebrow.isEmpty
                        ? 'TECHNOCARE'
                        : section.eyebrow.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF83DA58),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    section.title.isEmpty
                        ? 'Müasir texnoloji həllərlə sənayenizi gücləndiririk.'
                        : section.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (section.body.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      section.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onOpenShop,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Məhsullara bax'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2F7623),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2F7623), Color(0xFF132E22), Color(0xFF0D171C)],
      ),
    ),
    child: Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Icon(
          Icons.precision_manufacturing_outlined,
          size: 120,
          color: Color(0x3372CE50),
        ),
      ),
    ),
  );
}

class _HomeOfflineBanner extends StatelessWidget {
  final DateTime? cachedAt;
  const _HomeOfflineBanner({this.cachedAt});

  @override
  Widget build(BuildContext context) {
    final time = cachedAt?.toLocal();
    final updated = time == null
        ? ''
        : ' Son yenilənmə: ${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}.';
    return Container(
      color: const Color(0xFFFFF4D8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        'Offline məzmun göstərilir.$updated',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final HomeSection section;
  const _AboutSection({required this.section});

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      section: section,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CachedNetworkImage(
                imageUrl: section.images.first,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ColoredBox(
                  color: Color(0xFFEAF0EB),
                ),
                errorWidget: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFEAF0EB),
                  child: Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          if (section.metrics.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: section.metrics
                  .take(3)
                  .map(
                    (metric) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2F7623),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metric.value,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (metric.label.isNotEmpty)
                              Text(
                                metric.label,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final HomeSection section;
  final VoidCallback onOpenShop;
  const _CategorySection({required this.section, required this.onOpenShop});

  @override
  Widget build(BuildContext context) {
    final items = section.items.map(ShopTaxonomy.fromJson).toList();
    return _SectionShell(
      section: section,
      trailing: TextButton(onPressed: onOpenShop, child: const Text('Hamısı')),
      child: SizedBox(
        height: 205,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length > 12 ? 12 : items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, index) {
            final item = items[index];
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onOpenShop,
              child: Container(
                width: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3E8E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: item.imageUrl.isEmpty
                            ? const Center(
                                child: Icon(
                                  Icons.precision_manufacturing_outlined,
                                  color: Color(0xFF2F7623),
                                  size: 44,
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: item.imageUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandSection extends StatelessWidget {
  final HomeSection section;
  const _BrandSection({required this.section});

  @override
  Widget build(BuildContext context) {
    final brands = section.items.map(ShopTaxonomy.fromJson).toList();
    return _SectionShell(
      section: section,
      background: const Color(0xFFF5F7F4),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: brands
            .take(20)
            .map(
              (brand) => Container(
                width: (MediaQuery.sizeOf(context).width - 58) / 2,
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E9E3)),
                ),
                child: Text(
                  brand.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF37413B),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _BestSellerSection extends StatelessWidget {
  final HomeSection section;
  const _BestSellerSection({required this.section});

  @override
  Widget build(BuildContext context) {
    final products = section.items.map(ShopProduct.fromJson).toList();
    return _SectionShell(
      section: section,
      child: SizedBox(
        height: 310,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, index) =>
              _CompactProductCard(product: products[index]),
        ),
      ),
    );
  }
}

class _CompactProductCard extends StatelessWidget {
  final ShopProduct product;
  const _CompactProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShopProductDetailPage(product: product),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 190,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E9E3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: product.primaryImage.isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: product.primaryImage,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.brand.isNotEmpty)
                    Text(
                      product.brand.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF2F7623),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const SizedBox(height: 5),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    product.displayPrice,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkCardSection extends StatelessWidget {
  final HomeSection section;
  const _DarkCardSection({required this.section});

  @override
  Widget build(BuildContext context) {
    final links = section.links.isEmpty
        ? const [HomeLink('Daha ətraflı', 'https://technocare.az/xidmetler')]
        : section.links;
    return _SectionShell(
      section: section,
      child: Column(
        children: links
            .take(8)
            .map(
              (link) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF111917),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.engineering_outlined,
                      color: Color(0xFF72CE50),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        link.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _QualitySection extends StatelessWidget {
  final HomeSection section;
  const _QualitySection({required this.section});

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      section: section,
      background: const Color(0xFFF5F7F4),
      child: Column(
        children: [
          if (section.images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: section.images.first,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),
          for (final item in const [
            (
              'Layihələrin sıfırdan hazırlanması',
              Icons.settings_suggest_outlined,
            ),
            ('Peşəkar servis və texniki dəstək', Icons.headset_mic_outlined),
            (
              'Beynəlxalq standartlara uyğun məhsullar',
              Icons.verified_user_outlined,
            ),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF2F7623),
                child: Icon(item.$2, color: Colors.white, size: 20),
              ),
              title: Text(
                item.$1,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _GallerySection extends StatelessWidget {
  final HomeSection section;
  const _GallerySection({required this.section});

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      section: section,
      child: SizedBox(
        height: 210,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: section.images.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, index) => ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(
              imageUrl: section.images[index],
              width: 260,
              fit: BoxFit.cover,
              placeholder: (_, __) => const ColoredBox(
                color: Color(0xFFEAF0EB),
              ),
              errorWidget: (_, __, ___) => const ColoredBox(
                color: Color(0xFFEAF0EB),
                child: Icon(Icons.image_not_supported_outlined),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  final HomeSection section;
  final Widget child;
  final Widget? trailing;
  final Color background;

  const _SectionShell({
    required this.section,
    required this.child,
    this.trailing,
    this.background = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 34, 18, 34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (section.eyebrow.isNotEmpty)
              Text(
                section.eyebrow.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF2F7623),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    section.title.isEmpty
                        ? _fallbackTitle(section.type)
                        : section.title,
                    style: const TextStyle(
                      fontSize: 25,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF17201B),
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (section.body.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                section.body,
                maxLines: 7,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF667069),
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ],
            const SizedBox(height: 22),
            child,
          ],
        ),
      ),
    );
  }

  String _fallbackTitle(String type) => switch (type) {
    'categories' => 'Məhsul kateqoriyaları',
    'brands' => 'Brendlər',
    'best_sellers' => 'Ən çox satılan məhsullar',
    'services' => 'Peşəkar həllər',
    'quality' => 'Sənaye üçün müasir texnoloji həllər',
    'projects' => 'Layihələrimiz',
    'partners' => 'Müştərilərimiz və partnyorlarımız',
    _ => 'Technocare',
  };
}

class _ContactFooter extends StatelessWidget {
  const _ContactFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D171C),
      padding: const EdgeInsets.fromLTRB(22, 36, 22, 46),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Layihəniz var?',
            style: TextStyle(
              color: Color(0xFF72CE50),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bizimlə əlaqə saxlayın',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Texniki dəstək və korporativ satış komandamız sizə uyğun həlli seçməkdə kömək edəcək.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () async {
              final service = context.read<WhatsAppOrderService>();
              final uri = await service.createChatUri();
              var opened = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
              if (!opened) {
                opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
              }
              if (!opened && context.mounted) {
                final phone = await service.resolveTechnocarePhone();
                await Clipboard.setData(ClipboardData(text: '+$phone'));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'WhatsApp açılmadı. Əlaqə nömrəsi kopyalandı.',
                      ),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.chat_outlined),
            label: const Text('WhatsApp ilə yazın'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2F7623),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(height: 440, color: const Color(0xFFE3E8E1)),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              height: 170,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2EF),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeError extends StatelessWidget {
  final String? error;
  final Future<void> Function() onRetry;
  const _HomeError({this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 90),
        const Icon(
          Icons.cloud_off_outlined,
          size: 70,
          color: Color(0xFF2F7623),
        ),
        const SizedBox(height: 18),
        const Text(
          'Ana səhifə yüklənmədi',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          error ?? 'İnternet bağlantısını yoxlayın.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 22),
        FilledButton(onPressed: onRetry, child: const Text('Yenidən cəhd et')),
      ],
    );
  }
}
