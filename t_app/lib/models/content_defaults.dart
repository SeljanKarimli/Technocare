import 'site_content.dart';

class RequiredContentCatalog {
  RequiredContentCatalog._();

  static SiteContentCollection complete(
    String kind,
    SiteContentCollection remote,
  ) {
    final required = _requiredItems(kind);
    if (required.isEmpty) return remote;

    final consumed = <int>{};
    final completed = <SiteContentItem>[];
    for (final fallback in required) {
      final key = canonicalKey(kind, fallback.title);
      var matchIndex = -1;
      for (var index = 0; index < remote.items.length; index++) {
        if (!consumed.contains(index) &&
            canonicalKey(kind, remote.items[index].title) == key) {
          matchIndex = index;
          break;
        }
      }
      if (matchIndex < 0) {
        completed.add(fallback);
        continue;
      }
      consumed.add(matchIndex);
      completed.add(_merge(fallback, remote.items[matchIndex]));
    }

    for (var index = 0; index < remote.items.length; index++) {
      if (!consumed.contains(index)) completed.add(remote.items[index]);
    }

    return SiteContentCollection(
      schemaVersion: remote.schemaVersion,
      updatedAt: remote.updatedAt,
      sourceUrl: remote.sourceUrl,
      items: completed,
    );
  }

  static SiteContentCollection fallback(String kind) => SiteContentCollection(
    schemaVersion: 1,
    updatedAt: null,
    sourceUrl: kind == 'services'
        ? 'https://technocare.az/xidmetler'
        : kind == 'education'
        ? 'https://technocare.az/tedris'
        : '',
    items: _requiredItems(kind),
  );

  static String applicationField(String kind, String title) {
    final key = canonicalKey(kind, title);
    if (kind == 'services') {
      return switch (key) {
        'automation' => 'Avtomatika Xidməti',
        'electronics' => 'Elektronika Xidməti',
        'energy' => 'Energetika Xidməti',
        _ => '',
      };
    }
    if (kind == 'education') {
      return switch (key) {
        'automation' => 'Avtomatika Mühəndisliyi',
        'electronics' => 'Elektronika Mühəndisliyi',
        'electrical' => 'Elektrik Mühəndisliyi',
        _ => '',
      };
    }
    return '';
  }

  static String canonicalKey(String kind, String title) {
    final value = _normalize(title);
    if (kind == 'services') {
      if (value == 'avtomatika' || value.startsWith('avtomatika xidmet')) {
        return 'automation';
      }
      if (value == 'elektronika' || value.startsWith('elektronika xidmet')) {
        return 'electronics';
      }
      if (value == 'energetika' ||
          value.startsWith('energetika xidmet') ||
          value.startsWith('enerji xidmet')) {
        return 'energy';
      }
    }
    if (kind == 'education') {
      if (value.contains('avtomatika muhendisliyi')) return 'automation';
      if (value.contains('elektronika muhendisliyi')) return 'electronics';
      if (value.contains('elektrik muhendisliyi')) return 'electrical';
    }
    return 'remote:${_normalize(title)}';
  }

  static SiteContentItem _merge(
    SiteContentItem fallback,
    SiteContentItem remote,
  ) => SiteContentItem(
    id: remote.id == 0 ? fallback.id : remote.id,
    title: fallback.title,
    summary: _richer(fallback.summary, remote.summary),
    body: _richer(fallback.body, remote.body),
    imageUrl: remote.imageUrl.isEmpty ? fallback.imageUrl : remote.imageUrl,
    images: remote.images.isEmpty ? fallback.images : remote.images,
    url: remote.url.isEmpty ? fallback.url : remote.url,
  );

  static String _richer(String fallback, String remote) {
    final fallbackLength = fallback
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .length;
    final remoteLength = remote.replaceAll(RegExp(r'\s+'), ' ').trim().length;
    return remoteLength > fallbackLength ? remote : fallback;
  }

  static List<SiteContentItem> _requiredItems(String kind) => switch (kind) {
    'services' => _services,
    'education' => _education,
    _ => const <SiteContentItem>[],
  };

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ə', 'e')
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ç', 'c')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ğ', 'g')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  static const _services = <SiteContentItem>[
    SiteContentItem(
      id: -101,
      title: 'Avtomatika xidmətləri',
      summary:
          'PLC, SCADA və HMI sistemləri, sensor–aktuator inteqrasiyası və sənaye proseslərinin modernizasiyası.',
      body:
          'Technocare sənaye proseslərinin avtomatlaşdırılması üçün layihələndirmədən istismara verməyə qədər tam mühəndislik həlləri təqdim edir. Mövcud sistemlər analiz olunur, idarəetmə məntiqi hazırlanır, avadanlıqlar inteqrasiya edilir və sistem real iş şəraitində sınaqdan keçirilir.\n\nXidmətlərə PLC proqramlaşdırılması, SCADA və HMI ekranlarının hazırlanması, sensor və aktuatorların inteqrasiyası, elektrik idarəetmə panelləri, nasazlıq diaqnostikası və mövcud avtomatika sistemlərinin modernizasiyası daxildir.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/05/DSC1538-scaled.jpg',
      images: <String>[],
      url: 'https://technocare.az/xidmetler',
    ),
    SiteContentItem(
      id: -102,
      title: 'Elektronika xidmətləri',
      summary:
          'Sənaye elektronikasının diaqnostikası və təmiri, dövrə və PCB həlləri, sensor və mikrokontroller sistemləri.',
      body:
          'Elektronika xidməti sənaye cihazlarının və elektron modulların müasir ölçü və test avadanlıqları ilə analizini, nasazlığın aşkarlanmasını və peşəkar təmirini əhatə edir. Məqsəd avadanlığın etibarlı işləməsini bərpa etmək və dayanma müddətini azaltmaqdır.\n\nKomanda elektron dövrələrin və PCB-lərin yoxlanması, komponent səviyyəsində təmir, mikrokontroller və sensor həlləri, dövrə dizaynı, prototipləşdirmə və sistem inteqrasiyası üzrə xidmət göstərir.',
      imageUrl: 'https://technocare.az/wp-content/uploads/2025/06/x-ray.webp',
      images: <String>[],
      url: 'https://technocare.az/xidmetler',
    ),
    SiteContentItem(
      id: -103,
      title: 'Energetika xidmətləri',
      summary:
          'Elektrik sistemlərinin layihələndirilməsi, enerji paylanması, səmərəlilik, kompensasiya və bərpa olunan enerji həlləri.',
      body:
          'Energetika xidməti sənaye və kommersiya obyektlərinin elektrik sistemlərinin təhlükəsiz, dayanıqlı və səmərəli işləməsi üçün mühəndislik həlləri təqdim edir. Yüklər və istehlak göstəriciləri analiz olunur, uyğun paylama və mühafizə arxitekturası hazırlanır.\n\nXidmətlərə elektrik paylama şəbəkələrinin layihələndirilməsi və optimallaşdırılması, enerji səmərəliliyi analizi, reaktiv gücün kompensasiyası, elektrik panelləri, alternativ və bərpa olunan enerji sistemləri, test və texniki dəstək daxildir.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2024/03/Energetika-technocare.webp',
      images: <String>[],
      url: 'https://technocare.az/xidmetler',
    ),
  ];

  static const _education = <SiteContentItem>[
    SiteContentItem(
      id: -201,
      title: 'Avtomatika mühəndisliyi',
      summary:
          'PLC və SCADA proqramlaşdırması, idarəetmə dövrələri, sensorlar və real sənaye avtomatlaşdırması layihələri.',
      body:
          'Avtomatika mühəndisliyi proqramı sənaye proseslərinin avtomatik idarə olunmasını nəzəri və praktiki şəkildə öyrədir. Tədris elektrik və elektronikanın əsaslarından başlayaraq idarəetmə dövrələri, ölçmə alətləri, sensorlar, aktuatorlar və sənaye təhlükəsizliyi mövzularını əhatə edir.\n\nİştirakçılar PLC proqramlaşdırması, PLC dövrə dizaynı, SCADA və HMI sistemləri, sistem inteqrasiyası və real avadanlıqlarla praktiki layihələr üzərində işləyirlər. Proqram yeni başlayanlar və sənayedə avtomatlaşdırma üzrə inkişaf etmək istəyən mütəxəssislər üçün uyğundur.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/01/plc-km-6-7.jpg',
      images: <String>[],
      url: 'https://technocare.az/avtomatika-muhendisliyi-kurslari',
    ),
    SiteContentItem(
      id: -202,
      title: 'Elektronika mühəndisliyi',
      summary:
          'Elektron dövrələr, mikrokontrollerlər, sensorlar, PCB dizaynı, lehimləmə və real cihaz layihələri.',
      body:
          'Elektronika mühəndisliyi proqramı elektron siqnalların, dövrələrin və ağıllı cihazların iş prinsipini öyrədir. Kursda dövrə elementləri, ölçmə və analiz, analoq və rəqəmsal elektronika, mikrokontroller proqramlaşdırması və sensor texnologiyaları mərhələli şəkildə izah olunur.\n\nPraktiki məşğələlər zamanı iştirakçılar dövrə yığma, sensorlardan məlumat oxuma, PCB dizaynı, lehimləmə, nasazlıq axtarışı və real prototiplərin hazırlanması bacarıqları qazanırlar.',
      imageUrl: 'https://technocare.az/wp-content/uploads/2025/06/x-ray.webp',
      images: <String>[],
      url: 'https://technocare.az/elektronika-muhendisliyi-kursu',
    ),
    SiteContentItem(
      id: -203,
      title: 'Elektrik mühəndisliyi',
      summary:
          'Elektrik dövrələri, transformator və generatorlar, paylama şəbəkələri, mühafizə və ağıllı enerji sistemləri.',
      body:
          'Elektrik mühəndisliyi proqramı elektrik enerjisinin istehsalı, ötürülməsi, paylanması və təhlükəsiz istifadəsi üzrə baza və tətbiqi biliklər verir. Tədris elektrik dövrələri, ölçmə, transformatorlar, generatorlar, elektrik maşınları və mühafizə sistemlərini əhatə edir.\n\nİştirakçılar paylayıcı sistemlərin quruluşunu, elektrik sxemlərinin oxunmasını, enerji hesablamalarını, ağıllı enerji həllərini və alternativ enerji mənbələrini real layihələr və laboratoriya məşğələləri vasitəsilə öyrənirlər.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/Untitled-design-16.webp',
      images: <String>[],
      url: 'https://technocare.az/elektrik-muhendisliyi-kursu',
    ),
  ];
}
