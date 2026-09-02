import 'site_project.dart';

class ProjectDefaults {
  ProjectDefaults._();

  static List<SiteProject> search(String query) {
    final value = _normalize(query);
    if (value.isEmpty) return items;
    return items
        .where(
          (project) => _normalize(
            '${project.name} ${project.description} ${project.content}',
          ).contains(value),
        )
        .toList(growable: false);
  }

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ə', 'e')
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ç', 'c')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ğ', 'g');

  static const items = <SiteProject>[
    SiteProject(
      id: 'ady-stadler',
      name: 'Azərbaycan Dəmir Yolları',
      description: 'Stadler qatarında ABB invertorlarının təmiri.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/Untitled-design-5-e1711804052540.webp',
      content: '',
      images: <String>[],
      url:
          'https://technocare.az/layiheler/abb-invertorlarinin-temiri-stadler-qatar',
    ),
    SiteProject(
      id: 'norm-sement',
      name: 'NORM Sement',
      description: 'Reqlammer qurğusunun diaqnostikası və təmiri.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/Untitled-design-4-e1711802879653.webp',
      content: '',
      images: <String>[],
      url:
          'https://technocare.az/layiheler/reqlammer-qurgusunun-temiri-norm-sement',
    ),
    SiteProject(
      id: 'baku-steel',
      name: 'Baku Steel Company',
      description: 'Mitsubishi 355 kW invertorunun təmiri.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/Untitled-design-2-e1711802191555.webp',
      content: '',
      images: <String>[],
      url:
          'https://technocare.az/layiheler/mitsubishi-355kw-invertorunun-temiri-baku-steel-company',
    ),
    SiteProject(
      id: 'packaging-1000kg',
      name: '1000 Kiloqramlıq Paketləmə Qurğusu',
      description:
          '1000 kq-lıq sənaye paketləmə qurğusunun avtomatlaşdırılması.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/WhatsApp-Image-2025-03-17-at-11.15.59-1536x1152-1.webp',
      content: '',
      images: <String>[],
      url: 'https://technocare.az/layiheler/1000-kq-paketleme-qurgusu',
    ),
    SiteProject(
      id: 'qafqaz-hotel',
      name: 'Qafqaz Hotel',
      description: 'Enerji şəbəkəsinin güc analizi.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/Untitled-design-3-e1711802272240-1.webp',
      content: '',
      images: <String>[],
      url: 'https://technocare.az/layiheler/enerji-sebekesinin-guc-analizi',
    ),
    SiteProject(
      id: 'zulfu-haciyev-gemisi',
      name: 'Zülfü Hacıyev Adına Gəmi',
      description: 'Kran gəmisində generator güc sisteminin analizi.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/Untitled_design_7-transformed-e1711958257181.webp',
      content: '',
      images: <String>[],
      url:
          'https://technocare.az/layiheler/generator-guc-sisteminin-analizi-kran-gemisi',
    ),
    SiteProject(
      id: 'liebherr',
      name: 'LİEBHERR',
      description: 'Liebherr kran və LICCON monitorunun təmiri.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/Untitled-design-11-e1711960238509.webp',
      content: '',
      images: <String>[],
      url:
          'https://technocare.az/layiheler/liebherr-kran-temiri-liccon-monitor-temiri',
    ),
    SiteProject(
      id: 'x-ray',
      name: 'X-RAY',
      description: 'EZX-60 dental rentgen aparatının təmiri.',
      imageUrl: 'https://technocare.az/wp-content/uploads/2025/06/x-ray.webp',
      content: '',
      images: <String>[],
      url: 'https://technocare.az/layiheler/ezx-60-dental-xray-temiri',
    ),
    SiteProject(
      id: 'invertek',
      name: 'Inverter',
      description: 'Invertek tezlik çeviricisinin təmiri.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/Untitled-design-6-e1711805431160.webp',
      content: '',
      images: <String>[],
      url: 'https://technocare.az/layiheler/invertek-invertor-temiri',
    ),
    SiteProject(
      id: 'azerboru',
      name: 'Azərboru ASC',
      description: 'Mitsubishi 355 kW invertorunun təmiri.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/Untitled-design-2-e1711802191555.webp',
      content: '',
      images: <String>[],
      url:
          'https://technocare.az/layiheler/mitsubishi-355kw-invertor-temiri-azerboru-asc',
    ),
    SiteProject(
      id: 'sts-crane',
      name: 'STS Kran',
      description: 'STS-45 sahil kranının avtomatika sistemi.',
      imageUrl: 'https://technocare.az/wp-content/uploads/2025/06/STSkran.webp',
      content: '',
      images: <String>[],
      url: 'https://technocare.az/layiheler/sts-45-sahil-krani-avtomatika',
    ),
    SiteProject(
      id: 'kindeff-lift',
      name: 'KİNDEFF - LİFT',
      description:
          'EN 81-20 standartına uyğun lift idarə şitinin hazırlanması.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/Untitled-design-17-e1712136156372.webp',
      content: '',
      images: <String>[],
      url:
          'https://technocare.az/layiheler/en-81-20-lift-idare-siti-hazirlanmasi-kindeff',
    ),
    SiteProject(
      id: 'sabran-agro',
      name: 'Şabran Aqrokompleksi',
      description: 'ATV61 160 kW invertorunun təmiri.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/center-pivot-2-e1712060553725.webp',
      content: '',
      images: <String>[],
      url:
          'https://technocare.az/layiheler/atv61-160kw-invertor-temiri-sabran-aqrokompleksi',
    ),
    SiteProject(
      id: 'ziehl-abegg',
      name: 'ZİEHL - ABEGG',
      description: 'Havalandırma fanının texniki analizi.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/Untitled-design-13-e1712058102667.webp',
      content: '',
      images: <String>[],
      url:
          'https://technocare.az/layiheler/ziehl-abegg-havalandirma-fani-analizi',
    ),
    SiteProject(
      id: 'atv71',
      name: 'ATV71',
      description: 'ATV71 160 kW invertorunun təmiri.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/ATV71-e1711801444141.webp',
      content: '',
      images: <String>[],
      url:
          'https://technocare.az/layiheler/atv71-160kw-invertor-temiri-qum-cixarma-qurgusu',
    ),
    SiteProject(
      id: 'saatli-sand',
      name: 'Saatlı Qum Çıxarma',
      description: 'ATV900 invertorunun proqramlaşdırılması.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/Untitled-design-14-e1712058975512.webp',
      content: '',
      images: <String>[],
      url:
          'https://technocare.az/layiheler/atv900-invertor-proqramlanmasi-saatli',
    ),
    SiteProject(
      id: 'electrical-breakers',
      name: 'Elektrik Açarları',
      description: 'Sənaye elektrik açarlarının təmiri.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/Untitled-design-16.webp',
      content: '',
      images: <String>[],
      url: 'https://technocare.az/layiheler/elektrik-acari-temiri',
    ),
    SiteProject(
      id: 'siemens-g150',
      name: 'Siemens G150 440 kW',
      description: 'Siemens G150 440 kW invertorunun təmiri.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/proqramlanma-invertor-1080x1080-1-scaled-e1722410226275.webp',
      content: '',
      images: <String>[],
      url:
          'https://technocare.az/layiheler/siemens-g150-440-kw-invertor-temiri',
    ),
    SiteProject(
      id: 'siemens-micromaster',
      name: 'Siemens MicroMaster 440',
      description: '160 kW MicroMaster 440 invertorunun təmiri.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/proqramlanma-invertor-1080x1080-1-scaled-e1722410226275.webp',
      content: '',
      images: <String>[],
      url:
          'https://technocare.az/Layiheler/siemens-micromaster-440-160kw-invertor-temiri',
    ),
    SiteProject(
      id: 'chick-master',
      name: 'Chick Master',
      description: 'PLC və HMI avadanlıqlarının təmiri.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/chick-master1.webp',
      content: '',
      images: <String>[],
      url: 'https://technocare.az/layiheler/chick-master-plc-hmi-temiri',
    ),
    SiteProject(
      id: 'slip-ring',
      name: 'Slip Ring Layihəsi',
      description: 'Sənaye slip ring avadanlığının təmiri.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/06/slip-ring-1080x1080-2-scaled-e1722429471360.webp',
      content: '',
      images: <String>[],
      url: 'https://technocare.az/layiheler/slip-ring-temiri',
    ),
    SiteProject(
      id: 'ammann',
      name: 'Ammann Zavodu',
      description: 'Zavodun elektrik sistemləri üzrə test işləri.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/07/WhatsApp-Image-2025-07-01-at-11.56.17-scaled.jpeg',
      content: '',
      images: <String>[],
      url: 'https://technocare.az/layiheler/amman-zavodu-elektrik-testleri',
    ),
    SiteProject(
      id: 'airport-gpu',
      name: 'Hava Limanlarında GPU Sistemi Proqramlanması və Test İşləri',
      description:
          'Teleskopik trap GPU sisteminin proqramlaşdırılması və testi.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/07/e9fd8ccc45e761a0d134dae41814b906-1.jpg',
      content: '',
      images: <String>[],
      url: 'https://technocare.az/teleskopik-trap-gpu-proqramlasdirma-test',
    ),
    SiteProject(
      id: 'cotton-plant',
      name: 'Pambıq Yenidən Emal Zavodu',
      description: 'Pambıq emalı istehsalat xəttinin avtomatlaşdırılması.',
      imageUrl: 'https://technocare.az/wp-content/uploads/2025/07/pambiq.jpg',
      content: '',
      images: <String>[],
      url: 'https://technocare.az/pambiq-zavodu-avtomatlasdirilma',
    ),
    SiteProject(
      id: 'azergold',
      name: 'AzerGold - Şəbəkə Güc Sistemi və Kompensasiya Analizi',
      description: '2500 kVAr/1000 kVAr kompensasiya sisteminin analizi.',
      imageUrl:
          'https://technocare.az/wp-content/uploads/2025/09/AzerGHold.png',
      content: '',
      images: <String>[],
      url: 'https://technocare.az/azergold-kompensasiya-analizi',
    ),
    SiteProject(
      id: 'baur-titron',
      name: 'Baur Titron təmiri – Mobil Elektrotexniki Test Laboratoriyası',
      description: 'Mobil elektrotexniki test laboratoriyasının təmiri.',
      imageUrl: 'https://technocare.az/wp-content/uploads/2026/04/braun.png',
      content: '',
      images: <String>[],
      url: 'https://technocare.az/layiheler/baur-titron-temiri',
    ),
  ];
}
