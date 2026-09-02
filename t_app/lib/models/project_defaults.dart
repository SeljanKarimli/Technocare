import 'project_galleries.dart';
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
      imageUrl: 'assets/images/projects/ady-stadler.webp',
      content:
          'Layihənin məqsədi STADLER sürət qatarlarında istifadə olunan xüsusi ABB sənaye invertorlarının etibarlı işini bərpa etmək idi. İnvertorların elektron idarəetmə plataları, güc modulları (IGBT blokları), qapalı dövrə idarəetmə siqnalları və enerji hissəsi mərhələli şəkildə diaqnostika edildi.\n\nNasaz komponentlər bərpa və əvəz olundu, idarəetmə parametrləri yoxlanıldı, qurğular laboratoriya və istismar sınaqlarından keçirildi. Son mərhələdə invertorlar qatar üzərinə yenidən montaj edilərək real iş rejimində test olundu.',
      images: ProjectGalleries.adyStadler,
      url:
          'https://technocare.az/layiheler/abb-invertorlarinin-temiri-stadler-qatar',
    ),
    SiteProject(
      id: 'norm-sement',
      name: 'NORM Sement',
      description: 'Reqlammer qurğusunun diaqnostikası və təmiri.',
      imageUrl: 'assets/images/projects/norm-sement.webp',
      content:
          'NORM Sement zavodunun stoklama bunkerində yerləşən xammal boşaldıcı reqlammer qurğusunun mexaniki, elektrik və idarəetmə hissələri birlikdə analiz edildi. Performans azalmasının səbəbləri müəyyənləşdirildi və qurğunun əsas idarəetmə elementləri texniki baxışdan keçirildi.\n\nSiemens G150 440 kW və Siemens MicroMaster 440 160 kW invertorlarında nasaz komponentlər dəyişdirildi, proqram parametrləri bərpa edildi və elektrik bağlantıları yoxlanıldı. Sistem sınaqdan keçirilərək yenidən istehsalat dövriyyəsinə verildi.',
      images: ProjectGalleries.normSement,
      url:
          'https://technocare.az/layiheler/reqlammer-qurgusunun-temiri-norm-sement',
    ),
    SiteProject(
      id: 'baku-steel',
      name: 'Baku Steel Company',
      description: 'Mitsubishi 355 kW invertorunun təmiri.',
      imageUrl: 'assets/images/projects/baku-steel.webp',
      content:
          'Metal əritmə ocağının kompressor sistemində yükləmə və boşaltma rejimləri, elektrik göstəriciləri və idarəetmə əlaqələri analiz edildi. Problemin mənbəyi Mitsubishi 355 kW invertor və əlaqəli idarəetmə elementləri üzrə dəqiqləşdirildi.\n\nİnvertor komponent səviyyəsində təmir edildi, proqramlaşdırıldı və kompressor sisteminə yenidən qoşuldu. Yerində aparılan yük testləri ilə sistemin sabit işləməsi və istehsalat rejiminə uyğunluğu təsdiqləndi.',
      images: ProjectGalleries.bakuSteel,
      url:
          'https://technocare.az/layiheler/mitsubishi-355kw-invertorunun-temiri-baku-steel-company',
    ),
    SiteProject(
      id: 'packaging-1000kg',
      name: '1000 Kiloqramlıq Paketləmə Qurğusu',
      description:
          '1000 kq-lıq sənaye paketləmə qurğusunun avtomatlaşdırılması.',
      imageUrl: 'assets/images/projects/packaging-1000kg.webp',
      content:
          'Tamamilə yerli mühəndislik həlli kimi hazırlanan qurğu 1000 kq-lıq məhsulun dəqiq dozalanması və paketlənməsi üçün sıfırdan layihələndirildi. Elektrik, avtomatika və pnevmatika sxemləri hazırlanaraq bütün komponentlər vahid idarəetmə sistemində birləşdirildi.\n\nÇəki ölçmə, doldurma və boşaltma ardıcıllığı avtomatlaşdırıldı, təhlükəsizlik bloklamaları və operator idarəetməsi quruldu. Montajdan sonra ölçmə dəqiqliyi, yük altında işləmə və təkrarlanan paketləmə sınaqları aparılaraq qurğu istismara verildi.',
      images: ProjectGalleries.packaging1000kg,
      url: 'https://technocare.az/layiheler/1000-kq-paketleme-qurgusu',
    ),
    SiteProject(
      id: 'qafqaz-hotel',
      name: 'Qafqaz Hotel',
      description: 'Enerji şəbəkəsinin güc analizi.',
      imageUrl: 'assets/images/projects/qafqaz-hotel.webp',
      content:
          'QAFQAZ Otellər Qrupunun enerji şəbəkəsində real yük paylanması, gərginlik, cərəyan və güc göstəriciləri ölçüldü. Requlyator–generator–şəbəkə sinxronizasiya sistemində yaranan qeyri-sabitliyin səbəbləri müəyyən edildi.\n\nSinxronizasiya parametrləri yenidən tənzimləndi, qoruma və idarəetmə əlaqələri yoxlanıldı. Görülən işlər enerji itkilərinin azaldılmasına, şəbəkənin daha stabil işləməsinə və ehtiyat generatorların təhlükəsiz qoşulmasına xidmət etdi.',
      images: ProjectGalleries.qafqazHotel,
      url: 'https://technocare.az/layiheler/enerji-sebekesinin-guc-analizi',
    ),
    SiteProject(
      id: 'zulfu-haciyev-gemisi',
      name: 'Zülfü Hacıyev Adına Gəmi',
      description: 'Kran gəmisində generator güc sisteminin analizi.',
      imageUrl: 'assets/images/projects/zulfu-haciyev-gemisi.webp',
      content:
          'Kran gəmisinin generator güc sistemi yerində texniki baxışdan keçirildi. Generatorların gərginlik, cərəyan, yük paylanması və müxtəlif iş rejimlərində davranışı ölçülərək enerji sisteminin real vəziyyəti qiymətləndirildi.\n\nÖlçmə nəticələri əsasında yüklərin balanslaşdırılması, sistemin təhlükəsizliyi və səmərəliliyi üzrə texniki tövsiyələr hazırlandı. Məqsəd gəmidə fasiləsiz enerji təchizatını və kran əməliyyatları zamanı generatorların stabil işini təmin etmək idi.',
      images: ProjectGalleries.zulfuHaciyevGemisi,
      url:
          'https://technocare.az/layiheler/generator-guc-sisteminin-analizi-kran-gemisi',
    ),
    SiteProject(
      id: 'liebherr',
      name: 'LİEBHERR',
      description: 'Liebherr kran və LICCON monitorunun təmiri.',
      imageUrl: 'assets/images/projects/liebherr.webp',
      content:
          'LIEBHERR kranının mexaniki, elektrik və elektron idarəetmə hissələri kompleks diaqnostikadan keçirildi. Nasazlıq kodları və idarəetmə siqnalları analiz edildi, LICCON monitor və əlaqəli elektron modullar ayrıca yoxlanıldı.\n\nAşkarlanan nasazlıqlar aradan qaldırıldı, monitor və idarəetmə elementləri bərpa edildi. Funksional və təhlükəsizlik sınaqlarından sonra kranın əsas əməliyyatları yoxlanılaraq avadanlıq yenidən istismara hazır vəziyyətə gətirildi.',
      images: ProjectGalleries.liebherr,
      url:
          'https://technocare.az/layiheler/liebherr-kran-temiri-liccon-monitor-temiri',
    ),
    SiteProject(
      id: 'x-ray',
      name: 'X-RAY',
      description: 'EZX-60 dental rentgen aparatının təmiri.',
      imageUrl: 'assets/images/projects/x-ray.webp',
      content:
          'EZX-60 dental rentgen cihazının elektrik, mexaniki və proqram idarəetmə hissələri mərhələli şəkildə analiz edildi. Şüalanma və idarəetmə prosesinə təsir edən komponentlər yoxlanılaraq nasaz sahələr müəyyənləşdirildi.\n\nTəmir işlərindən sonra cihazın bağlantıları, idarəetmə funksiyaları və iş parametrləri test edildi. Yekun sınaqlar cihazın stabil işləməsini və tibbi istifadə üçün tələb olunan dəqiqliyin bərpa olunduğunu təsdiqlədi.',
      images: ProjectGalleries.xRay,
      url: 'https://technocare.az/layiheler/ezx-60-dental-xray-temiri',
    ),
    SiteProject(
      id: 'invertek',
      name: 'Inverter',
      description: 'Invertek tezlik çeviricisinin təmiri.',
      imageUrl: 'assets/images/projects/invertek.webp',
      content:
          'Greenhouse şirkətinə məxsus Invertek invertorunun elektron və idarəetmə sistemləri ətraflı diaqnostika edildi. Güc hissəsi, elektron platalar və işləmə parametrləri yoxlanılaraq performans azalmasına səbəb olan nasazlıqlar müəyyən edildi.\n\nNasaz komponentlər bərpa olundu, idarəetmə parametrləri yenidən quruldu və invertor müxtəlif yük rejimlərində sınaqdan keçirildi. Təmir nəticəsində qurğunun sabit işi və istehsalat sisteminə uyğunluğu bərpa edildi.',
      images: ProjectGalleries.invertek,
      url: 'https://technocare.az/layiheler/invertek-invertor-temiri',
    ),
    SiteProject(
      id: 'azerboru',
      name: 'Azərboru ASC',
      description: 'Mitsubishi 355 kW invertorunun təmiri.',
      imageUrl: 'assets/images/projects/baku-steel.webp',
      content:
          'Azərboru ASC-nin istehsalatında istifadə olunan Lupamat vidalı kompressor sistemi və onun xəbərləşmə əlaqələri kompleks şəkildə analiz edildi. Sistemin iş rejimi, elektrik bağlantıları və idarəetmə arxitekturasındakı problemlər müəyyənləşdirildi.\n\nMitsubishi 355 kW invertor təmir edildi, yerində proqramlaşdırıldı və kompressor sisteminə inteqrasiya olundu. Xəbərləşmə sistemi yenidən qurulduqdan sonra qurğu yük altında sınaqdan keçirildi və sabit istehsalat rejiminə qaytarıldı.',
      images: ProjectGalleries.azerboru,
      url:
          'https://technocare.az/layiheler/mitsubishi-355kw-invertor-temiri-azerboru-asc',
    ),
    SiteProject(
      id: 'sts-crane',
      name: 'STS Kran',
      description: 'STS-45 sahil kranının avtomatika sistemi.',
      imageUrl: 'assets/images/projects/sts-crane.webp',
      content:
          'Maksimum 90 ton, faydalı 45 ton yükdaşıma qabiliyyətinə malik STS-45 sahil kranının konstruksiya və montaj hissəsi ADO-G, elektrik və avtomatika hissəsi isə Technocare tərəfindən icra edildi. Layihə liman əməliyyatları üçün yüksək dəqiqlik və təhlükəsizlik tələbləri əsasında hazırlandı.\n\nElektrik, elektronika, PLC əsaslı avtomatika və proqramlaşdırma layihələri hazırlanaraq idarə şitləri, sensorlar, hərəkət mexanizmləri və təhlükəsizlik bloklamaları inteqrasiya edildi. Montaj və sahə testlərindən sonra kranın bütün əsas hərəkətləri yük rejimində yoxlanıldı.',
      images: ProjectGalleries.stsCrane,
      url: 'https://technocare.az/layiheler/sts-45-sahil-krani-avtomatika',
    ),
    SiteProject(
      id: 'kindeff-lift',
      name: 'KİNDEFF - LİFT',
      description:
          'EN 81-20 standartına uyğun lift idarə şitinin hazırlanması.',
      imageUrl: 'assets/images/projects/kindeff-lift.webp',
      content:
          'Kindeff Lift şirkətinin sərnişin və mətbəx liftləri üçün EN 81-20 təhlükəsizlik standartına uyğun idarə şitləri layihələndirildi. İdarəetmə məntiqi, qoruma dövrələri, mərtəbə siqnalları və təhlükəsizlik zənciri liftin xüsusiyyətlərinə uyğun quruldu.\n\nŞitlərin yığılması və proqramlaşdırılmasından sonra bütün giriş-çıxış siqnalları sınaqdan keçirildi. Sistemlər obyektlərdə quraşdırıldı, hərəkət və təhlükəsizlik testləri aparıldı və liftlər dövriyyəyə alındı.',
      images: ProjectGalleries.kindeffLift,
      url:
          'https://technocare.az/layiheler/en-81-20-lift-idare-siti-hazirlanmasi-kindeff',
    ),
    SiteProject(
      id: 'sabran-agro',
      name: 'Şabran Aqrokompleksi',
      description: 'ATV61 160 kW invertorunun təmiri.',
      imageUrl: 'assets/images/projects/sabran-agro.webp',
      content:
          'Aqrokompleksin suvarma sistemində istifadə olunan 160 kW ATV61 invertorunda ilkin diaqnostika aparıldı. Güc və idarəetmə modullarındakı nasazlıqlar müəyyən edilərək zəruri komponentlər dəyişdirildi və elektron hissələr bərpa olundu.\n\nSuvarma prosesinin daha dəqiq və enerjiyə qənaətli idarəsi üçün invertor yenidən proqramlaşdırıldı. Mühərrikin sürətlənmə, dayanma və müxtəlif yük rejimləri sahədə test edilərək sistem yenidən istismara verildi.',
      images: ProjectGalleries.sabranAgro,
      url:
          'https://technocare.az/layiheler/atv61-160kw-invertor-temiri-sabran-aqrokompleksi',
    ),
    SiteProject(
      id: 'ziehl-abegg',
      name: 'ZİEHL - ABEGG',
      description: 'Havalandırma fanının texniki analizi.',
      imageUrl: 'assets/images/projects/ziehl-abegg.webp',
      content:
          'ZIEHL-ABEGG sənaye havalandırma fanının elektrik, elektron və idarəetmə göstəriciləri analiz edildi. Fanın işləmə parametrlərinə və avtomatika sistemi ilə məlumat mübadiləsinə təsir edən problemlər müəyyənləşdirildi.\n\nXəbərləşmə sistemi yenidən quruldu, idarəetmə siqnalları və qoruma funksiyaları yoxlanıldı. Sonda fan müxtəlif sürət və yük rejimlərində test edilərək sistemin stabil və təhlükəsiz işi təsdiqləndi.',
      images: ProjectGalleries.ziehlAbegg,
      url:
          'https://technocare.az/layiheler/ziehl-abegg-havalandirma-fani-analizi',
    ),
    SiteProject(
      id: 'atv71',
      name: 'ATV71',
      description: 'ATV71 160 kW invertorunun təmiri.',
      imageUrl: 'assets/images/projects/atv71.webp',
      content:
          'Qum çıxarma qurğusunun mühərrik sürətini və momentini idarə edən 160 kW ATV71 invertoru tam diaqnostikadan keçirildi. Güc elementləri, idarəetmə platası və giriş-çıxış siqnalları yoxlanılaraq nasazlığın səbəbi müəyyən edildi.\n\nİnvertor təmir və proqramlaşdırmadan sonra yerində quraşdırıldı. Mühərrikin sürətlənmə, yük dəyişməsi və davamlı iş rejimləri sınaqdan keçirildi, qurğunun stabil fəaliyyəti bərpa olundu.',
      images: ProjectGalleries.atv71,
      url:
          'https://technocare.az/layiheler/atv71-160kw-invertor-temiri-qum-cixarma-qurgusu',
    ),
    SiteProject(
      id: 'saatli-sand',
      name: 'Saatlı Qum Çıxarma',
      description: 'ATV900 invertorunun proqramlaşdırılması.',
      imageUrl: 'assets/images/projects/saatli-sand.webp',
      content:
          'Araz çayı üzərində yerləşən qum çıxarma qurğusunun ATV900 invertorunda mövcud parametrlər, yüklənmə göstəriciləri və enerji sərfiyyatı analiz edildi. Prosesə uyğun olmayan idarəetmə parametrləri və iş rejimləri müəyyənləşdirildi.\n\nİnvertor mühərrikin real yük profilinə uyğun yenidən proqramlaşdırıldı. Sahədə start, dayanma, sürət və yük dəyişməsi testləri aparıldı; nəticədə prosesin daha stabil və səmərəli idarə olunması təmin edildi.',
      images: ProjectGalleries.saatliSand,
      url:
          'https://technocare.az/layiheler/atv900-invertor-proqramlanmasi-saatli',
    ),
    SiteProject(
      id: 'electrical-breakers',
      name: 'Elektrik Açarları',
      description: 'Sənaye elektrik açarlarının təmiri.',
      imageUrl: 'assets/images/projects/electrical-breakers.webp',
      content:
          'Sənaye elektrik açarlarının kontakt müqaviməti xüsusi ölçü cihazları ilə yoxlanıldı, normadan kənar göstəricilər və mexaniki problemlər müəyyən edildi. Açma-bağlama mexanizmləri, kontakt səthləri, bobinlər və qoruma elementləri ayrıca qiymətləndirildi.\n\nAçarlar təmizləndi, sazlandı və nasaz hissələr bərpa olundu. Təmir sonrası kontakt müqaviməti, mexaniki əməliyyat və qoruma testləri yenidən aparılaraq avadanlıqların təhlükəsiz işi təsdiqləndi.',
      images: ProjectGalleries.electricalBreakers,
      url: 'https://technocare.az/layiheler/elektrik-acari-temiri',
    ),
    SiteProject(
      id: 'siemens-g150',
      name: 'Siemens G150 440 kW',
      description: 'Siemens G150 440 kW invertorunun təmiri.',
      imageUrl: 'assets/images/projects/siemens-g150.webp',
      content:
          'Siemens G150 440 kW invertorunun giriş-çıxış gərginliyi, cərəyanı və tezlik göstəriciləri ölçülərək nasazlıq analizi aparıldı. IGBT modulları, kondensatorlar, rezistorlar, güc dövrələri və idarəetmə elementləri ayrı-ayrılıqda yoxlanıldı.\n\nNasaz komponentlər dəyişdirildi, elektron hissələr bərpa olundu və parametrlər sazlandı. İnvertor yüksüz və yük altında test edilərək performansı, temperatur rejimi və stabil işi təsdiqləndi.',
      images: ProjectGalleries.siemensG150,
      url:
          'https://technocare.az/layiheler/siemens-g150-440-kw-invertor-temiri',
    ),
    SiteProject(
      id: 'siemens-micromaster',
      name: 'Siemens MicroMaster 440',
      description: '160 kW MicroMaster 440 invertorunun təmiri.',
      imageUrl: 'assets/images/projects/siemens-g150.webp',
      content:
          'Nasos və fan sistemlərində istifadə olunan Siemens MicroMaster 440 160 kW invertorunda performans problemləri üzrə vizual və elektron diaqnostika aparıldı. Elektrik bağlantıları, dövrə kartları, güc elementləri və idarəetmə siqnalları yoxlanıldı.\n\nNasaz hissələr təmir edildi, proqram parametrləri tətbiq sahəsinə uyğun optimallaşdırıldı. Sınaqlar zamanı mühərrik idarəetməsi, enerji sərfiyyatı və müxtəlif iş rejimlərində sabitlik yoxlanılaraq invertor istismara hazır vəziyyətə gətirildi.',
      images: ProjectGalleries.siemensMicromaster,
      url:
          'https://technocare.az/Layiheler/siemens-micromaster-440-160kw-invertor-temiri',
    ),
    SiteProject(
      id: 'chick-master',
      name: 'Chick Master',
      description: 'PLC və HMI avadanlıqlarının təmiri.',
      imageUrl: 'assets/images/projects/chick-master.webp',
      content:
          'Chick Master inkubator sisteminin iki kamerasında PLC və HMI avadanlıqlarının sıradan çıxması səbəbindən idarəetmə tam dayanmışdı. Hər iki kameranın qidalanma, giriş-çıxış və idarəetmə dövrələri ayrılıqda analiz edildi.\n\nPLC və HMI qurğuları komponent səviyyəsində təmir edildi, proqram və əlaqə parametrləri bərpa olundu. Temperatur, havalandırma və digər proses siqnalları simulyasiya edilərək kameraların avtomatik işi test edildi və sistem yenidən istifadəyə verildi.',
      images: ProjectGalleries.chickMaster,
      url: 'https://technocare.az/layiheler/chick-master-plc-hmi-temiri',
    ),
    SiteProject(
      id: 'slip-ring',
      name: 'Slip Ring Layihəsi',
      description: 'Sənaye slip ring avadanlığının təmiri.',
      imageUrl: 'assets/images/projects/slip-ring.webp',
      content:
          'Dönən və sabit hissələr arasında elektrik və siqnal ötürən slip ring qurğusunun halqaları, fırçaları və daxili bağlantıları analiz edildi. Davamlılıq, izolyasiya və kontakt müqaviməti ölçülərək ötürmədə itki və qeyri-sabitliyə səbəb olan sahələr müəyyənləşdirildi.\n\nKontakt səthləri və mexaniki hissələr bərpa olundu, sıradan çıxmış elementlər dəyişdirildi. Təmir sonrası qurğu müxtəlif sürət və yük rejimlərində sınaqdan keçirildi, elektrik ötürməsinin sabitliyi təsdiqləndi.',
      images: ProjectGalleries.slipRing,
      url: 'https://technocare.az/layiheler/slip-ring-temiri',
    ),
    SiteProject(
      id: 'ammann',
      name: 'Ammann Zavodu',
      description: 'Zavodun elektrik sistemləri üzrə test işləri.',
      imageUrl: 'assets/images/projects/ammann.webp',
      content:
          'Ammann zavodunun dövriyyəyə alınması üçün elektrik və istehsalat avadanlıqları komponent-komponent yoxlanıldı. Bütün asinxron mühərriklərdə izolyasiya müqaviməti ölçüldü, kabelləmə və elektrik şəbəkəsi üzrə texniki nəzarət aparıldı.\n\nKompensasiya panelinin kontaktor, kondensator və idarəetmə hissələri funksional analizdən keçirildi. Aşkarlanan problemlər aradan qaldırıldıqdan sonra avadanlıqlar ayrı-ayrılıqda və ümumi istehsalat rejimində test edilərək zavod işə hazırlandı.',
      images: ProjectGalleries.ammann,
      url: 'https://technocare.az/layiheler/amman-zavodu-elektrik-testleri',
    ),
    SiteProject(
      id: 'airport-gpu',
      name: 'Hava Limanlarında GPU Sistemi Proqramlanması və Test İşləri',
      description:
          'Teleskopik trap GPU sisteminin proqramlaşdırılması və testi.',
      imageUrl: 'assets/images/projects/airport-gpu.webp',
      content:
          'Sıradan çıxmış teleskopik trap qurğusunun GPU idarəetmə blokunun bərpası və digər sistemlərlə əlaqəsinin yenidən qurulması layihənin əsas məqsədi idi. Elektrik dövrələri, giriş-çıxış siqnalları və idarəetmə blokları diaqnostika edildi.\n\nİdarəetmə proqramı bərpa və yenidən konfiqurasiya olundu, əlaqə protokolları sazlandı. Təhlükəsizlik siqnalları, hərəkət ardıcıllığı və GPU funksiyaları sahədə test edilərək qurğunun fasiləsiz işləməsi təmin edildi.',
      images: ProjectGalleries.airportGpu,
      url: 'https://technocare.az/teleskopik-trap-gpu-proqramlasdirma-test',
    ),
    SiteProject(
      id: 'cotton-plant',
      name: 'Pambıq Yenidən Emal Zavodu',
      description: 'Pambıq emalı istehsalat xəttinin avtomatlaşdırılması.',
      imageUrl: 'assets/images/projects/cotton-plant.webp',
      content:
          'Zavodun köhnə kontaktor və zaman relesi əsaslı idarəetmə sistemi müasir PLC və HMI arxitekturası ilə əvəz edildi. Məqsəd havalandırma və pressləmə sahələrində prosesi daha sürətli, etibarlı və minimum insan müdaxiləsi ilə idarə etmək idi.\n\nYeni elektrik və avtomatika sxemləri hazırlandı, sensorlar və icra mexanizmləri PLC-yə qoşuldu, operator üçün HMI ekranları yaradıldı. Bloklama, qəza və ardıcıllıq sınaqlarından sonra istehsalat xətti avtomatik rejimdə istismara verildi.',
      images: ProjectGalleries.cottonPlant,
      url: 'https://technocare.az/pambiq-zavodu-avtomatlasdirilma',
    ),
    SiteProject(
      id: 'azergold',
      name: 'AzerGold - Şəbəkə Güc Sistemi və Kompensasiya Analizi',
      description: '2500 kVAr/1000 kVAr kompensasiya sisteminin analizi.',
      imageUrl: 'assets/images/projects/azergold.webp',
      content:
          'AzerGold QSC-nin 2500 kVAr gücündə trafo mərkəzində enerji axınları, gərginlik sabitliyi, yüklənmə balansı və güc itkiləri üzrə geniş texniki analiz aparıldı. Məqsəd enerji təsərrüfatının real vəziyyətini müəyyənləşdirmək və etibarlılıq üçün baza məlumatı toplamaq idi.\n\n1000 kVAr-lıq reaktiv güc kompensasiya sisteminin iş rejimləri və pillələri ayrıca yoxlanıldı. Ölçmə nəticələri əsasında şəbəkə balansı, kompensasiya səviyyəsi və gələcək optimallaşdırma üçün texniki tövsiyələr hazırlandı.',
      images: ProjectGalleries.azergold,
      url: 'https://technocare.az/azergold-kompensasiya-analizi',
    ),
    SiteProject(
      id: 'baur-titron',
      name: 'Baur Titron təmiri – Mobil Elektrotexniki Test Laboratoriyası',
      description: 'Mobil elektrotexniki test laboratoriyasının təmiri.',
      imageUrl: 'assets/images/projects/baur-titron.webp',
      content:
          '80 kV gücə və 0,01–0,1 Hz sabit tezlikli yüksək gərginlik test imkanına malik Baur Titron mobil laboratoriyası kompleks diaqnostikadan keçirildi. Məqsəd ölçmə dəqiqliyini, etibarlılığı və idarəetmə sisteminin stabil işini bərpa etmək idi.\n\nLaboratoriyanın CPU və PLC blokları təmir edildi, proqram təminatı və idarəetmə ardıcıllığı bərpa olundu. Ölçmə, qoruma və yüksək gərginlik test funksiyaları kalibrasiya və sınaqdan keçirilərək mobil laboratoriya yenidən texniki istifadəyə hazırlandı.',
      images: ProjectGalleries.baurTitron,
      url: 'https://technocare.az/layiheler/baur-titron-temiri',
    ),
  ];
}
