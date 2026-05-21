import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MinPriceFlutterApp());
}

class MinPriceFlutterApp extends StatelessWidget {
  const MinPriceFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'minprice.kz',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const MinPriceShell(),
    );
  }
}

enum AppTab { home, catalog, discounts, favorites, cart }

class AppTheme {
  static const primary = Color(0xFF12B5D6);
  static const primaryLight = Color(0xFF73D9F2);
  static const primaryDeep = Color(0xFF0D8CB3);
  static const savingsGreen = Color(0xFF24B87F);
  static const discountRed = Color(0xFFE06173);
  static const warningAmber = Color(0xFFF59E28);
  static const darkBackground = Color(0xFF1F1F24);
  static const darkCard = Color(0xFF2E2E35);
  static const lightBackground = Color(0xFFF4F5FA);
  static const lightCard = Color(0xFFFFFFFF);
  static const muted = Color(0xFF8E8E99);

  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: savingsGreen,
      surface: lightCard,
    ),
    fontFamily: 'SF Pro Display',
  );

  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      secondary: savingsGreen,
      surface: darkCard,
    ),
    fontFamily: 'SF Pro Display',
  );

  static LinearGradient get brandGradient => const LinearGradient(
    colors: [primaryLight, primary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static Color card(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCard : lightCard;

  static Color subtle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white.withAlpha(140)
      : Colors.black.withAlpha(110);

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white.withAlpha(28)
      : Colors.black.withAlpha(18);
}

abstract class KeyValueStore {
  String? readString(String key);
  void writeString(String key, String value);
  void remove(String key);
}

class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, String>? seed]) : _values = seed ?? {};

  final Map<String, String> _values;

  @override
  String? readString(String key) => _values[key];

  @override
  void writeString(String key, String value) {
    _values[key] = value;
  }

  @override
  void remove(String key) {
    _values.remove(key);
  }
}

class FileKeyValueStore implements KeyValueStore {
  FileKeyValueStore(this.file);

  factory FileKeyValueStore.appDefault() {
    final dir = Directory.systemTemp;
    return FileKeyValueStore(File('${dir.path}/minprice_flutter_state.json'));
  }

  final File file;
  Map<String, String>? _cache;

  @override
  String? readString(String key) => _read()[key];

  @override
  void writeString(String key, String value) {
    final values = _read();
    values[key] = value;
    _write(values);
  }

  @override
  void remove(String key) {
    final values = _read();
    values.remove(key);
    _write(values);
  }

  Map<String, String> _read() {
    if (_cache != null) return _cache!;
    try {
      if (!file.existsSync()) {
        _cache = {};
      } else {
        final raw = jsonDecode(file.readAsStringSync());
        _cache = raw is Map
            ? raw.map((key, value) => MapEntry('$key', '$value'))
            : <String, String>{};
      }
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }

  void _write(Map<String, String> values) {
    _cache = values;
    try {
      file.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(values));
    } catch (_) {}
  }
}

class ApiClient {
  ApiClient({
    this.baseUrl = 'https://backend.minprice.kz/api',
    KeyValueStore? storage,
  }) : storage = storage ?? FileKeyValueStore.appDefault();

  static const guestUuidKey = 'guest_uuid';

  final String baseUrl;
  final KeyValueStore storage;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);
  String? _guestUuid;

  Future<dynamic> getJson(
    String path, [
    Map<String, Object?> query = const {},
  ]) {
    return _send('GET', path, query: query);
  }

  Future<dynamic> postJson(
    String path, [
    Map<String, Object?> body = const {},
  ]) {
    return _send('POST', path, body: body);
  }

  Future<dynamic> patchJson(
    String path, [
    Map<String, Object?> body = const {},
  ]) {
    return _send('PATCH', path, body: body);
  }

  Future<void> ensureSession() async {
    _guestUuid ??= storage.readString(guestUuidKey);
    if (_guestUuid != null) return;
    try {
      final value = await _send(
        'POST',
        '/session/init/',
        initializeSession: false,
      );
      if (value is Map && value['guestUuid'] is String) {
        _guestUuid = value['guestUuid'] as String;
      } else if (value is Map && value['guest_uuid'] is String) {
        _guestUuid = value['guest_uuid'] as String;
      }
      final guest = _guestUuid;
      if (guest != null) {
        storage.writeString(guestUuidKey, guest);
      }
    } catch (_) {
      _guestUuid = null;
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> body = const {},
    bool initializeSession = true,
  }) async {
    if (initializeSession) {
      await ensureSession();
    }
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: _cleanQuery(query));
    final request = await _client.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set('X-App-Version', '1.0.3');
    request.headers.set('X-App-Build', '6');
    request.headers.set('X-Platform', Platform.isAndroid ? 'android' : 'ios');
    request.headers.set('X-OS-Version', Platform.operatingSystemVersion);
    request.headers.set('X-Device-Model', Platform.localHostname);
    final guest = _guestUuid;
    if (guest != null) {
      request.headers.set('X-Guest-UUID', guest);
    }
    if (body.isNotEmpty) {
      request.add(utf8.encode(jsonEncode(body)));
    }
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, text);
    }
    if (text.trim().isEmpty) return null;
    return jsonDecode(text);
  }

  Map<String, String> _cleanQuery(Map<String, Object?> query) {
    final result = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.isEmpty) {
        result[entry.key] = value;
      } else {
        result[entry.key] = '$value';
      }
    }
    return result;
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}

class StorePrice {
  const StorePrice({
    required this.chainName,
    required this.price,
    this.chainSlug = '',
    this.chainLogo,
    this.currency = '₸',
    this.previousPrice,
    this.inStock = true,
  });

  final String chainName;
  final String chainSlug;
  final String? chainLogo;
  final double price;
  final double? previousPrice;
  final String currency;
  final bool inStock;

  factory StorePrice.fromJson(Map<String, dynamic> json) {
    return StorePrice(
      chainName: _string(json['chain_name'] ?? json['store_name'], 'Магазин'),
      chainSlug: _string(json['chain_slug'] ?? json['store_source'], ''),
      chainLogo: _nullableString(json['chain_logo']),
      price: _double(json['price']),
      previousPrice: _nullableDouble(json['previous_price']),
      currency: _string(json['currency'], '₸'),
      inStock: json['in_stock'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'chain_name': chainName,
    'chain_slug': chainSlug,
    'chain_logo': chainLogo,
    'price': price,
    'previous_price': previousPrice,
    'currency': currency,
    'in_stock': inStock,
  };
}

class Product {
  const Product({
    required this.uuid,
    required this.title,
    required this.imageUrl,
    this.brand,
    this.measureUnit,
    this.minPrice,
    this.maxPrice,
    this.previousPrice,
    this.stores = const [],
  });

  final String uuid;
  final String title;
  final String imageUrl;
  final String? brand;
  final String? measureUnit;
  final double? minPrice;
  final double? maxPrice;
  final double? previousPrice;
  final List<StorePrice> stores;

  double get cheapestPrice {
    if (stores.isNotEmpty) {
      return stores
          .where((store) => store.inStock)
          .fold<double>(
            double.infinity,
            (minValue, store) => math.min(minValue, store.price),
          );
    }
    return minPrice ?? 0;
  }

  StorePrice? get cheapestStore {
    final available = [...stores.where((store) => store.inStock)];
    available.sort((left, right) => left.price.compareTo(right.price));
    return available.firstOrNull;
  }

  int get discountPercent {
    final oldPrice =
        previousPrice ??
        stores
            .map((store) => store.previousPrice)
            .whereType<double>()
            .fold<double?>(
              null,
              (maxValue, value) =>
                  maxValue == null ? value : math.max(maxValue, value),
            );
    final current = cheapestPrice;
    if (oldPrice == null || oldPrice <= current || current <= 0) return 0;
    return (((oldPrice - current) / oldPrice) * 100).round();
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final storesJson = _list(json['stores'] ?? json['prices']);
    final stores = storesJson
        .whereType<Map>()
        .map((item) => StorePrice.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final priceRange = json['price_range'];
    final priceRangeMap = priceRange is Map ? priceRange : const {};
    return Product(
      uuid: _string(json['uuid'] ?? json['id'], ''),
      title: _string(json['title'] ?? json['name'], 'Товар'),
      imageUrl: _absoluteImage(_string(json['image_url'] ?? json['image'], '')),
      brand: _nullableString(json['brand']),
      measureUnit: _nullableString(json['measure_unit']),
      minPrice: _nullableDouble(json['min_price'] ?? priceRangeMap['min']),
      maxPrice: _nullableDouble(json['max_price'] ?? priceRangeMap['max']),
      previousPrice: _nullableDouble(json['previous_price']),
      stores: stores,
    );
  }

  Product copyWith({
    String? uuid,
    String? title,
    String? imageUrl,
    String? brand,
    String? measureUnit,
    double? minPrice,
    double? maxPrice,
    double? previousPrice,
    List<StorePrice>? stores,
  }) {
    return Product(
      uuid: uuid ?? this.uuid,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      brand: brand ?? this.brand,
      measureUnit: measureUnit ?? this.measureUnit,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      previousPrice: previousPrice ?? this.previousPrice,
      stores: stores ?? this.stores,
    );
  }

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'title': title,
    'image_url': imageUrl,
    'brand': brand,
    'measure_unit': measureUnit,
    'min_price': minPrice,
    'max_price': maxPrice,
    'previous_price': previousPrice,
    'stores': stores.map((store) => store.toJson()).toList(),
  };
}

class Category {
  const Category({required this.id, required this.name, this.icon});

  final int id;
  final String name;
  final String? icon;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: _int(json['id']),
    name: _string(json['name'] ?? json['title'], 'Категория'),
    icon: _nullableString(json['icon']),
  );
}

class City {
  const City({required this.id, required this.name});

  final int id;
  final String name;

  factory City.fromJson(Map<String, dynamic> json) =>
      City(id: _int(json['id']), name: _string(json['name'], 'Астана'));
}

class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get lineTotal => product.cheapestPrice * quantity;

  factory CartLine.fromJson(Map<String, dynamic> json) {
    return CartLine(
      product: Product.fromJson(
        Map<String, dynamic>.from(json['product'] as Map),
      ),
      quantity: math.max(0, _int(json['quantity'])),
    );
  }

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'quantity': quantity,
  };
}

class CartController extends ChangeNotifier {
  CartController({this.onChanged});

  final VoidCallback? onChanged;
  final Map<String, CartLine> _lines = {};

  List<CartLine> get items => _lines.values.toList(growable: false);

  int quantityFor(String uuid) => _lines[uuid]?.quantity ?? 0;

  int get totalItems =>
      _lines.values.fold(0, (sum, line) => sum + line.quantity);

  double get minimumTotal =>
      _lines.values.fold(0, (sum, line) => sum + line.lineTotal);

  void add(Product product) {
    setQuantity(product.uuid, quantityFor(product.uuid) + 1, product: product);
  }

  void decrement(Product product) {
    setQuantity(product.uuid, quantityFor(product.uuid) - 1, product: product);
  }

  void setQuantity(String uuid, int quantity, {Product? product}) {
    if (quantity <= 0) {
      _lines.remove(uuid);
      _markChanged();
      return;
    }
    final existing = _lines[uuid];
    final resolvedProduct = product ?? existing?.product;
    if (resolvedProduct == null) return;
    _lines[uuid] = CartLine(product: resolvedProduct, quantity: quantity);
    _markChanged();
  }

  void restore(List<CartLine> lines) {
    _lines
      ..clear()
      ..addEntries(
        lines
            .where((line) => line.quantity > 0 && line.product.uuid.isNotEmpty)
            .map((line) => MapEntry(line.product.uuid, line)),
      );
    notifyListeners();
  }

  List<Map<String, dynamic>> toJson() =>
      items.map((line) => line.toJson()).toList();

  void _markChanged() {
    onChanged?.call();
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _markChanged();
  }
}

class PriceDropAlert {
  const PriceDropAlert({
    required this.product,
    required this.oldPrice,
    required this.newPrice,
    required this.percent,
  });

  final Product product;
  final double oldPrice;
  final double newPrice;
  final int percent;
}

class PriceAlertManager {
  PriceAlertManager({Map<String, double>? storedPrices})
    : storedPrices = storedPrices ?? {};

  static const availableThresholds = [3, 5, 10, 15, 20, 30];

  final Map<String, double> storedPrices;

  static bool isDailyCheckDue({
    required DateTime now,
    required DateTime? nextCheckAt,
  }) {
    return nextCheckAt == null || !now.isBefore(nextCheckAt);
  }

  static DateTime nextInitialCheckDate({
    required DateTime after,
    double Function() random = _randomFraction,
  }) {
    final today = _randomCheckDate(after, random);
    if (today.isAfter(after.add(const Duration(minutes: 5)))) {
      return today;
    }
    return nextDailyCheckDate(afterCompletedCheckAt: after, random: random);
  }

  static DateTime nextDailyCheckDate({
    required DateTime afterCompletedCheckAt,
    double Function() random = _randomFraction,
  }) {
    return _randomCheckDate(
      afterCompletedCheckAt.add(const Duration(days: 1)),
      random,
    );
  }

  static DateTime _randomCheckDate(DateTime date, double Function() random) {
    final start = DateTime(date.year, date.month, date.day, 9);
    final end = DateTime(date.year, date.month, date.day, 21);
    final fraction = random().clamp(0, 0.999999);
    final span = end.difference(start).inSeconds;
    return start.add(Duration(seconds: (span * fraction).floor()));
  }

  static double _randomFraction() => math.Random().nextDouble();

  void seedPrices(List<Product> products) {
    for (final product in products) {
      if (product.uuid.isEmpty || storedPrices.containsKey(product.uuid)) {
        continue;
      }
      final price = product.cheapestPrice;
      if (price > 0) {
        storedPrices[product.uuid] = price;
      }
    }
  }

  PriceDropAlert? evaluatePriceDrop(
    Product product, {
    required int thresholdPercent,
  }) {
    final newPrice = product.cheapestPrice;
    final oldPrice = storedPrices[product.uuid];
    if (newPrice <= 0) return null;
    storedPrices[product.uuid] = newPrice;
    if (oldPrice == null || newPrice >= oldPrice || oldPrice <= 0) return null;
    final pct = ((oldPrice - newPrice) / oldPrice * 100);
    if (pct < thresholdPercent) return null;
    return PriceDropAlert(
      product: product,
      oldPrice: oldPrice,
      newPrice: newPrice,
      percent: math.max(1, pct.floor()),
    );
  }
}

class AppController extends ChangeNotifier {
  AppController({ApiClient? api, KeyValueStore? storage})
    : storage = storage ?? FileKeyValueStore.appDefault(),
      api =
          api ?? ApiClient(storage: storage ?? FileKeyValueStore.appDefault()) {
    cart = CartController(onChanged: _persistCart);
    cart.addListener(notifyListeners);
  }

  static const favoritesKey = 'favorites_v1';
  static const cartKey = 'cart_v1';
  static const priceAlertsEnabledKey = 'price_alerts_enabled';
  static const priceAlertThresholdKey = 'price_alert_threshold_pct';
  static const nextPriceCheckKey = 'price_alert_next_check';

  final ApiClient api;
  final KeyValueStore storage;
  late final CartController cart;
  final PriceAlertManager priceAlerts = PriceAlertManager();
  final Set<String> favoriteIds = {};
  final Map<String, Product> _productCache = {};

  AppTab tab = AppTab.home;
  City city = const City(id: 1, name: 'Астана');
  bool loadingHome = true;
  bool loadingCatalog = false;
  bool loadingSearch = false;
  String? error;
  List<Product> bestDeals = [];
  List<Product> discounts = [];
  List<Category> categories = [];
  List<Product> catalogProducts = [];
  List<Product> searchResults = [];
  Category? selectedCategory;
  bool priceAlertsEnabled = false;
  int priceAlertThreshold = 5;
  DateTime? nextPriceCheckAt;

  List<Product> get favorites =>
      favoriteIds.map((id) => _productCache[id]).whereType<Product>().toList();

  void restoreLocalState() {
    final favoriteProducts = _decodeProducts(storage.readString(favoritesKey));
    favoriteIds
      ..clear()
      ..addAll(favoriteProducts.map((product) => product.uuid));
    _remember(favoriteProducts);
    priceAlerts.seedPrices(favoriteProducts);
    priceAlertsEnabled = storage.readString(priceAlertsEnabledKey) == 'true';
    priceAlertThreshold =
        int.tryParse(storage.readString(priceAlertThresholdKey) ?? '') ?? 5;
    nextPriceCheckAt = DateTime.tryParse(
      storage.readString(nextPriceCheckKey) ?? '',
    );

    final rawCart = storage.readString(cartKey);
    if (rawCart != null) {
      try {
        final decoded = jsonDecode(rawCart);
        if (decoded is List) {
          cart.restore(
            decoded
                .whereType<Map>()
                .map(
                  (item) => CartLine.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(),
          );
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  void setPriceAlertsEnabled(
    bool enabled, {
    DateTime? now,
    double Function() random = PriceAlertManager._randomFraction,
  }) {
    priceAlertsEnabled = enabled;
    storage.writeString(priceAlertsEnabledKey, '$enabled');
    if (enabled) {
      nextPriceCheckAt ??= PriceAlertManager.nextInitialCheckDate(
        after: now ?? DateTime.now(),
        random: random,
      );
      storage.writeString(
        nextPriceCheckKey,
        nextPriceCheckAt!.toIso8601String(),
      );
      priceAlerts.seedPrices(favorites);
    } else {
      nextPriceCheckAt = null;
      storage.remove(nextPriceCheckKey);
    }
    notifyListeners();
  }

  void setPriceAlertThreshold(int threshold) {
    final safeThreshold =
        PriceAlertManager.availableThresholds.contains(threshold)
        ? threshold
        : 5;
    priceAlertThreshold = safeThreshold;
    storage.writeString(priceAlertThresholdKey, '$safeThreshold');
    notifyListeners();
  }

  void selectTab(AppTab value) {
    tab = value;
    notifyListeners();
  }

  Future<void> bootstrap() async {
    await loadHome();
  }

  Future<void> loadHome() async {
    loadingHome = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        api.getJson('/categories/'),
        api.getJson('/best-deals/', {
          'city_id': city.id,
          'page': 0,
          'page_size': 20,
        }),
        api.getJson('/discounts/', {
          'city_id': city.id,
          'page': 0,
          'page_size': 20,
        }),
      ]);
      categories = _parseCategories(results[0]);
      bestDeals = _remember(_parseProducts(results[1]));
      discounts = _remember(_parseProducts(results[2]));
    } catch (exception) {
      error = exception is ApiException && exception.statusCode == 429
          ? 'Сервер ограничил частые запросы. Повторите позже.'
          : 'Не удалось загрузить данные.';
      bestDeals = _demoProducts();
      discounts = _demoProducts(discounted: true);
      categories = _demoCategories();
    } finally {
      loadingHome = false;
      notifyListeners();
    }
  }

  Future<void> loadCategory(Category category) async {
    selectedCategory = category;
    loadingCatalog = true;
    notifyListeners();
    try {
      catalogProducts = _remember(
        _parseProducts(
          await api.getJson('/search/', {
            'q': category.name.length > 6
                ? category.name.substring(0, 6)
                : category.name,
            'city_id': city.id,
            'canonical_category': category.id,
            'page': 0,
            'hitsPerPage': 24,
          }),
        ),
      );
    } catch (_) {
      catalogProducts = _demoProducts(discounted: category.id.isEven);
    } finally {
      loadingCatalog = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      searchResults = [];
      notifyListeners();
      return;
    }
    loadingSearch = true;
    notifyListeners();
    try {
      searchResults = _remember(
        _parseProducts(
          await api.getJson('/search/', {
            'q': query.trim(),
            'city_id': city.id,
            'page': 0,
            'hitsPerPage': 30,
          }),
        ),
      );
    } catch (_) {
      final source = [
        ...bestDeals,
        ...discounts,
        ..._demoProducts(discounted: true),
      ];
      searchResults = source
          .where(
            (product) =>
                product.title.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    } finally {
      loadingSearch = false;
      notifyListeners();
    }
  }

  void toggleFavorite(Product product) {
    _productCache[product.uuid] = product;
    if (!favoriteIds.add(product.uuid)) {
      favoriteIds.remove(product.uuid);
    }
    _persistFavorites();
    priceAlerts.seedPrices(favorites);
    notifyListeners();
  }

  bool isFavorite(Product product) => favoriteIds.contains(product.uuid);

  List<Product> _remember(List<Product> products) {
    for (final product in products) {
      if (product.uuid.isNotEmpty) {
        _productCache[product.uuid] = product;
      }
    }
    return products;
  }

  List<Product> _decodeProducts(String? raw) {
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
          .where((product) => product.uuid.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _persistFavorites() {
    storage.writeString(
      favoritesKey,
      jsonEncode(favorites.map((product) => product.toJson()).toList()),
    );
  }

  void _persistCart() {
    storage.writeString(cartKey, jsonEncode(cart.toJson()));
  }
}

class MinPriceShell extends StatefulWidget {
  const MinPriceShell({super.key});

  @override
  State<MinPriceShell> createState() => _MinPriceShellState();
}

class _MinPriceShellState extends State<MinPriceShell> {
  late final AppController controller;
  bool searchOpen = false;

  @override
  void initState() {
    super.initState();
    controller = AppController();
    controller.restoreLocalState();
    unawaited(controller.bootstrap());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: _screenFor(controller.tab)),
              Positioned(
                left: 18,
                right: 18,
                bottom: MediaQuery.paddingOf(context).bottom + 12,
                child: BottomDock(
                  controller: controller,
                  onSearch: () => setState(() => searchOpen = true),
                  onScan: () => _showScannerStub(context),
                ),
              ),
              if (searchOpen)
                SearchOverlay(
                  controller: controller,
                  onClose: () => setState(() => searchOpen = false),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _screenFor(AppTab tab) {
    return switch (tab) {
      AppTab.home => HomeScreen(controller: controller),
      AppTab.catalog => CatalogScreen(controller: controller),
      AppTab.discounts => ProductGridScreen(
        title: 'Скидки',
        subtitle: 'Товары с заметным снижением цены',
        products: controller.discounts,
        controller: controller,
        loading: controller.loadingHome,
      ),
      AppTab.favorites => FavoritesScreen(controller: controller),
      AppTab.cart => CartScreen(controller: controller),
    };
  }

  void _showScannerStub(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Сканер'),
        content: const Text(
          'В черновике порт готовит точку входа. Камеру подключим через mobile_scanner.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ок'),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.loadHome,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 20,
              20,
              6,
            ),
            sliver: SliverToBoxAdapter(
              child: HeaderBar(controller: controller),
            ),
          ),
          if (controller.error != null)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              sliver: SliverToBoxAdapter(
                child: ErrorBanner(text: controller.error!),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                icon: CupertinoIcons.sparkles,
                title: 'Лучшие цены',
                subtitle: 'Собрано по минимуму',
                color: AppTheme.savingsGreen,
              ),
            ),
          ),
          ProductGrid(
            products: controller.bestDeals,
            controller: controller,
            loading: controller.loadingHome,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                icon: CupertinoIcons.flame_fill,
                title: 'Скидки',
                subtitle: 'Цена стала ниже',
                color: AppTheme.discountRed,
              ),
            ),
          ),
          ProductGrid(
            products: controller.discounts,
            controller: controller,
            loading: controller.loadingHome,
            bottomPadding: 168,
          ),
        ],
      ),
    );
  }
}

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border(context)),
          ),
          alignment: Alignment.center,
          child: const Text(
            'M',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'minprice.kz',
            style: TextStyle(
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
            ),
          ),
        ),
        CapsuleButton(
          icon: CupertinoIcons.location_solid,
          text: controller.city.name,
          onPressed: () {},
        ),
      ],
    );
  }
}

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final categories = controller.categories.isEmpty
        ? _demoCategories()
        : controller.categories;
    return CustomScrollView(
      slivers: [
        ScreenTitle(
          title: 'Каталог',
          topPadding: MediaQuery.paddingOf(context).top + 28,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          sliver: SliverGrid.builder(
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.8,
            ),
            itemBuilder: (context, index) {
              final category = categories[index];
              final selected = controller.selectedCategory?.id == category.id;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => controller.loadCategory(category),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary.withAlpha(34)
                        : AppTheme.card(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? AppTheme.primary.withAlpha(130)
                          : AppTheme.border(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.square_grid_2x2_fill,
                        color: selected ? AppTheme.primary : AppTheme.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          category.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              icon: CupertinoIcons.cart_badge_plus,
              title: controller.selectedCategory?.name ?? 'Популярное',
              subtitle: 'Выберите категорию или товар',
              color: AppTheme.primary,
            ),
          ),
        ),
        ProductGrid(
          products: controller.catalogProducts.isEmpty
              ? controller.bestDeals
              : controller.catalogProducts,
          controller: controller,
          loading: controller.loadingCatalog || controller.loadingHome,
          bottomPadding: 168,
        ),
      ],
    );
  }
}

class ProductGridScreen extends StatelessWidget {
  const ProductGridScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.products,
    required this.controller,
    required this.loading,
  });

  final String title;
  final String subtitle;
  final List<Product> products;
  final AppController controller;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        ScreenTitle(
          title: title,
          topPadding: MediaQuery.paddingOf(context).top + 28,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          sliver: SliverToBoxAdapter(
            child: Text(
              subtitle,
              style: TextStyle(color: AppTheme.subtle(context), fontSize: 17),
            ),
          ),
        ),
        ProductGrid(
          products: products,
          controller: controller,
          loading: loading,
          bottomPadding: 168,
        ),
      ],
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final products = controller.favorites;
    return CustomScrollView(
      slivers: [
        ScreenTitle(
          title: 'Избранное',
          topPadding: MediaQuery.paddingOf(context).top + 28,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          sliver: SliverToBoxAdapter(
            child: PriceAlertSettingsCard(controller: controller),
          ),
        ),
        if (products.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: CupertinoIcons.star_fill,
              title: 'Пока пусто',
              subtitle: 'Сохраняйте товары, чтобы быстро следить за ценой.',
            ),
          )
        else
          ProductGrid(
            products: products,
            controller: controller,
            loading: false,
            bottomPadding: 168,
          ),
      ],
    );
  }
}

class PriceAlertSettingsCard extends StatelessWidget {
  const PriceAlertSettingsCard({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final next = controller.nextPriceCheckAt;
    final subtitle = controller.priceAlertsEnabled
        ? 'Проверка раз в день${next == null ? '' : ', следующий слот ${_two(next.hour)}:${_two(next.minute)}'}'
        : 'Без частых запросов к серверу';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.discountRed.withAlpha(22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.bell_fill,
                  color: AppTheme.discountRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Снижение цены',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.subtle(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: controller.priceAlertsEnabled,
                activeThumbColor: AppTheme.primary,
                onChanged: controller.setPriceAlertsEnabled,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final threshold in PriceAlertManager.availableThresholds)
                ChoiceChip(
                  label: Text('$threshold%'),
                  selected: controller.priceAlertThreshold == threshold,
                  onSelected: (_) =>
                      controller.setPriceAlertThreshold(threshold),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final cart = controller.cart;
    final items = cart.items;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 22,
            20,
            12,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Корзина',
                    style: TextStyle(
                      fontSize: 42,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: items.isEmpty ? null : cart.clear,
                  icon: const Icon(CupertinoIcons.trash),
                ),
              ],
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: CupertinoIcons.cart_fill,
              title: 'Корзина пуста',
              subtitle: 'Добавляйте товары из поиска или каталога',
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: CartSummaryCard(cart: cart)),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                icon: CupertinoIcons.sparkles,
                title: 'Лучшие цены',
                subtitle: 'Сумма пересчитывается от количества',
                color: AppTheme.savingsGreen,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            sliver: SliverList.separated(
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  CartLineTile(line: items[index], controller: controller),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 168),
            sliver: SliverToBoxAdapter(
              child: StoreComparisonCard(items: items),
            ),
          ),
        ],
      ],
    );
  }
}

class SearchOverlay extends StatefulWidget {
  const SearchOverlay({
    super.key,
    required this.controller,
    required this.onClose,
  });

  final AppController controller;
  final VoidCallback onClose;

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final textController = TextEditingController();
  Timer? debounce;

  @override
  void dispose() {
    debounce?.cancel();
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Row(
                children: [
                  Expanded(
                    child: SearchField(
                      controller: textController,
                      autofocus: true,
                      onChanged: (value) {
                        debounce?.cancel();
                        debounce = Timer(const Duration(milliseconds: 280), () {
                          unawaited(controller.search(value));
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: widget.onClose,
                    child: const Text('Готово'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  ProductGrid(
                    products: controller.searchResults,
                    controller: controller,
                    loading: controller.loadingSearch,
                    bottomPadding: 40,
                  ),
                  if (!controller.loadingSearch &&
                      controller.searchResults.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: CupertinoIcons.search,
                        title: 'Поиск товаров',
                        subtitle: 'Введите название, бренд или штрихкод.',
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

class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.products,
    required this.controller,
    required this.loading,
    this.bottomPadding = 0,
  });

  final List<Product> products;
  final AppController controller;
  final bool loading;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    if (loading && products.isEmpty) {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, bottomPadding),
        sliver: SliverGrid.builder(
          itemCount: 6,
          gridDelegate: _productGridDelegate,
          itemBuilder: (_, _) => const ProductSkeletonCard(),
        ),
      );
    }
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, bottomPadding),
      sliver: SliverGrid.builder(
        itemCount: products.length,
        gridDelegate: _productGridDelegate,
        itemBuilder: (context, index) =>
            ProductCard(product: products[index], controller: controller),
      ),
    );
  }
}

const _productGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: 10,
  crossAxisSpacing: 10,
  childAspectRatio: 0.56,
);

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.controller,
  });

  final Product product;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final quantity = controller.cart.quantityFor(product.uuid);
    final price = product.cheapestPrice;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showProductSheet(context, product, controller),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.2,
                  child: ProductImage(url: product.imageUrl),
                ),
                if (product.discountPercent > 0)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: DiscountBadge(percent: product.discountPercent),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => controller.toggleFavorite(product),
                    icon: Icon(
                      controller.isFavorite(product)
                          ? CupertinoIcons.star_fill
                          : CupertinoIcons.star,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (product.previousPrice != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6, bottom: 2),
                            child: Text(
                              '${_money(product.previousPrice!)} ₸',
                              style: TextStyle(
                                color: AppTheme.subtle(context),
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Text(
                          '${_money(price)} ₸',
                          style: const TextStyle(
                            color: AppTheme.savingsGreen,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _smartTitle(product.title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.06,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: StoreRows(product: product)),
                  ],
                ),
              ),
            ),
            QuantityStrip(
              quantity: quantity,
              onAdd: () => controller.cart.add(product),
              onMinus: () => controller.cart.decrement(product),
            ),
          ],
        ),
      ),
    );
  }
}

class StoreRows extends StatelessWidget {
  const StoreRows({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final stores = [...product.stores]
      ..sort((left, right) => left.price.compareTo(right.price));
    final visible = stores.take(3).toList();
    if (visible.isEmpty) {
      return Text(
        product.cheapestStore?.chainName ?? 'Цена по минимуму',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.subtle(context),
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Column(
      children: [
        for (final indexed in visible.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                StoreLogo(name: indexed.$2.chainName),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    indexed.$2.chainName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: indexed.$1 == 0 ? null : AppTheme.subtle(context),
                    ),
                  ),
                ),
                if (indexed.$1 == 0) const MinBadge(),
                const SizedBox(width: 4),
                Text(
                  '${_money(indexed.$2.price)} ₸',
                  style: TextStyle(
                    color: indexed.$1 == 0
                        ? AppTheme.primary
                        : AppTheme.subtle(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class QuantityStrip extends StatelessWidget {
  const QuantityStrip({
    super.key,
    required this.quantity,
    required this.onAdd,
    required this.onMinus,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onMinus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      color: AppTheme.primary.withAlpha(30),
      child: quantity == 0
          ? TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(CupertinoIcons.plus),
              label: const Text('Добавить'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  onPressed: onMinus,
                  icon: const Icon(CupertinoIcons.minus),
                ),
                Text(
                  '$quantity',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(CupertinoIcons.plus),
                ),
              ],
            ),
    );
  }
}

class CartSummaryCard extends StatelessWidget {
  const CartSummaryCard({super.key, required this.cart});

  final CartController cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ИТОГО ПО МИНИМУМУ',
            style: TextStyle(
              color: AppTheme.subtle(context),
              letterSpacing: 1.6,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '${_money(cart.minimumTotal)} ₸',
                  style: const TextStyle(
                    color: AppTheme.savingsGreen,
                    fontSize: 42,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${cart.totalItems} товаров',
                style: TextStyle(
                  color: AppTheme.subtle(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(18),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      gradient: AppTheme.brandGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withAlpha(50),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '✨ По минимуму',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '🏪 Один магазин',
                      style: TextStyle(
                        color: AppTheme.subtle(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CartLineTile extends StatelessWidget {
  const CartLineTile({super.key, required this.line, required this.controller});

  final CartLine line;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final product = line.product;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 74,
              height: 74,
              child: ProductImage(url: product.imageUrl),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.cheapestStore?.chainName ?? 'По минимуму',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.subtle(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_money(product.cheapestPrice)} ₸ / шт',
                  style: TextStyle(
                    color: AppTheme.subtle(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_money(line.lineTotal)} ₸',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SquareIconButton(
                    icon: line.quantity == 1
                        ? CupertinoIcons.trash
                        : CupertinoIcons.minus,
                    color: line.quantity == 1
                        ? AppTheme.discountRed
                        : AppTheme.primary,
                    onPressed: () => controller.cart.decrement(product),
                  ),
                  SizedBox(
                    width: 42,
                    child: Center(
                      child: Text(
                        '${line.quantity}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  SquareIconButton(
                    icon: CupertinoIcons.plus,
                    color: AppTheme.primary,
                    onPressed: () => controller.cart.add(product),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StoreComparisonCard extends StatelessWidget {
  const StoreComparisonCard({super.key, required this.items});

  final List<CartLine> items;

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final line in items) {
      final store = line.product.cheapestStore?.chainName ?? 'По минимуму';
      totals[store] = (totals[store] ?? 0) + line.lineTotal;
    }
    final sorted = totals.entries.toList()
      ..sort((left, right) => left.value.compareTo(right.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          icon: Icons.storefront_rounded,
          title: 'Один магазин',
          subtitle: 'Черновое сравнение полной корзины',
          color: AppTheme.primary,
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Column(
            children: [
              for (final indexed in sorted.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: indexed.$1 == 0
                        ? AppTheme.savingsGreen.withAlpha(25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      StoreLogo(name: indexed.$2.key),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          indexed.$2.key,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (indexed.$1 == 0) const MinBadge(),
                      const SizedBox(width: 8),
                      Text(
                        '${_money(indexed.$2.value)} ₸',
                        style: TextStyle(
                          color: indexed.$1 == 0 ? AppTheme.savingsGreen : null,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class BottomDock extends StatelessWidget {
  const BottomDock({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onScan,
  });

  final AppController controller;
  final VoidCallback onSearch;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onSearch,
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: AppTheme.card(context).withAlpha(225),
                    borderRadius: BorderRadius.circular(27),
                    border: Border.all(color: AppTheme.border(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.search,
                        color: AppTheme.subtle(context),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Поиск товаров...',
                        style: TextStyle(
                          color: AppTheme.subtle(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              style: IconButton.styleFrom(fixedSize: const Size(54, 54)),
              onPressed: onScan,
              icon: const Icon(
                CupertinoIcons.camera_viewfinder,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.card(context).withAlpha(236),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              DockTab(
                tab: AppTab.home,
                icon: CupertinoIcons.house_fill,
                label: 'Главная',
                controller: controller,
              ),
              DockTab(
                tab: AppTab.catalog,
                icon: CupertinoIcons.square_grid_2x2_fill,
                label: 'Каталог',
                controller: controller,
              ),
              DockTab(
                tab: AppTab.discounts,
                icon: CupertinoIcons.flame_fill,
                label: 'Скидки',
                controller: controller,
              ),
              DockTab(
                tab: AppTab.favorites,
                icon: CupertinoIcons.star_fill,
                label: 'Избранное',
                badge: controller.favoriteIds.length,
                controller: controller,
              ),
              DockTab(
                tab: AppTab.cart,
                icon: CupertinoIcons.cart_fill,
                label: 'Корзина',
                badge: controller.cart.totalItems,
                controller: controller,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DockTab extends StatelessWidget {
  const DockTab({
    super.key,
    required this.tab,
    required this.icon,
    required this.label,
    required this.controller,
    this.badge = 0,
  });

  final AppTab tab;
  final IconData icon;
  final String label;
  final int badge;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final active = controller.tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.selectTab(tab),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: active ? 58 : 46,
                  height: 34,
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.primary.withAlpha(40)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: active
                        ? Border.all(color: AppTheme.primary.withAlpha(80))
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: active ? AppTheme.primary : AppTheme.subtle(context),
                    size: 27,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? AppTheme.primary : AppTheme.subtle(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (badge > 0)
              Positioned(
                top: 0,
                right: 11,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: const BoxDecoration(
                    color: AppTheme.discountRed,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge > 99 ? '99' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withAlpha(22),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.subtle(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle({super.key, required this.title, required this.topPadding});

  final String title;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, 14),
      sliver: SliverToBoxAdapter(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 42,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withAlpha(12)
            : Colors.black.withAlpha(8),
        alignment: Alignment.center,
        child: const Icon(
          CupertinoIcons.cube_box_fill,
          size: 34,
          color: AppTheme.primary,
        ),
      );
    }
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(
          CupertinoIcons.cube_box_fill,
          size: 34,
          color: AppTheme.primary,
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CupertinoActivityIndicator());
        },
      ),
    );
  }
}

class ProductSkeletonCard extends StatelessWidget {
  const ProductSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.subtle(context).withAlpha(20),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Container(height: 50, color: AppTheme.primary.withAlpha(20)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(34, 60, 34, 180),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(28),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primary, size: 54),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.subtle(context),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningAmber.withAlpha(32),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warningAmber.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: AppTheme.warningAmber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(CupertinoIcons.search),
        hintText: 'Поиск товаров...',
        filled: true,
        fillColor: AppTheme.card(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
      ),
    );
  }
}

class CapsuleButton extends StatelessWidget {
  const CapsuleButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onPressed,
  });

  final IconData icon;
  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.primary,
        backgroundColor: AppTheme.primary.withAlpha(24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
    );
  }
}

class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon, color: color, size: 20),
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class StoreLogo extends StatelessWidget {
  const StoreLogo({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final normalized = name.toLowerCase();
    final color = normalized.contains('magnum')
        ? const Color(0xFFE91E63)
        : normalized.contains('arbuz')
        ? const Color(0xFF22C55E)
        : normalized.contains('small')
        ? Colors.white
        : AppTheme.primary.withAlpha(30);
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppTheme.border(context)),
      ),
      alignment: Alignment.center,
      child: Text(
        _storeMark(name),
        style: TextStyle(
          fontSize: 8,
          color: normalized.contains('small')
              ? AppTheme.discountRed
              : Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class MinBadge extends StatelessWidget {
  const MinBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(38),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'MIN',
        style: TextStyle(
          color: AppTheme.primary,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class DiscountBadge extends StatelessWidget {
  const DiscountBadge({super.key, required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.discountRed,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: AppTheme.discountRed.withAlpha(80), blurRadius: 12),
        ],
      ),
      child: Text(
        '↘ $percent%',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

void _showProductSheet(
  BuildContext context,
  Product product,
  AppController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final quantity = controller.cart.quantityFor(product.uuid);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: 190,
                      width: double.infinity,
                      child: ProductImage(url: product.imageUrl),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 25,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_money(product.cheapestPrice)} ₸',
                    style: const TextStyle(
                      color: AppTheme.savingsGreen,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StoreRows(product: product),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => controller.toggleFavorite(product),
                        icon: Icon(
                          controller.isFavorite(product)
                              ? CupertinoIcons.star_fill
                              : CupertinoIcons.star,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: () => controller.cart.add(product),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              quantity == 0
                                  ? 'Добавить в корзину'
                                  : 'В корзине: $quantity',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

List<Product> _parseProducts(dynamic json) {
  final source = switch (json) {
    {'hits': final hits} => hits,
    {'results': final results} => results,
    {'products': final products} => products,
    {'items': final items} => items,
    {'data': final data} => data,
    List() => json,
    _ => const [],
  };
  return _list(source)
      .whereType<Map>()
      .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
      .where((product) => product.uuid.isNotEmpty)
      .toList();
}

List<Category> _parseCategories(dynamic json) {
  final source = switch (json) {
    {'results': final results} => results,
    {'categories': final categories} => categories,
    {'items': final items} => items,
    List() => json,
    _ => const [],
  };
  final parsed = _list(source)
      .whereType<Map>()
      .map((item) => Category.fromJson(Map<String, dynamic>.from(item)))
      .where((category) => category.id != 0)
      .toList();
  return parsed.isEmpty ? _demoCategories() : parsed;
}

List<dynamic> _list(dynamic value) => value is List ? value : const [];

String _absoluteImage(String value) {
  if (value.isEmpty || value.startsWith('http')) return value;
  if (value.startsWith('/')) return 'https://backend.minprice.kz$value';
  return 'https://backend.minprice.kz/$value';
}

String _string(dynamic value, String fallback) {
  if (value is String && value.trim().isNotEmpty) return value;
  return fallback;
}

String? _nullableString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) return value;
  return null;
}

double _double(dynamic value) => _nullableDouble(value) ?? 0;

double? _nullableDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _money(double value) {
  final rounded = value.round();
  final text = rounded.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final fromEnd = text.length - i;
    buffer.write(text[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(' ');
  }
  return buffer.toString();
}

String _two(int value) => value.toString().padLeft(2, '0');

String _smartTitle(String title) {
  final words = title.split(RegExp(r'\s+'));
  if (title.length <= 42 || words.length <= 5) return title;
  return '${words.take(3).join(' ')}... ${words.skip(words.length - 2).join(' ')}';
}

String _storeMark(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('magnum')) return 'GO';
  if (lower.contains('small')) return 'SM';
  if (lower.contains('arbuz')) return 'a';
  if (lower.contains('galmart')) return 'G';
  return name.characters.take(2).toString().toUpperCase();
}

List<Category> _demoCategories() => const [
  Category(id: 1, name: 'Овощи и фрукты'),
  Category(id: 2, name: 'Молоко и яйца'),
  Category(id: 3, name: 'Чай и кофе'),
  Category(id: 4, name: 'Сладости'),
  Category(id: 5, name: 'Бытовая химия'),
  Category(id: 6, name: 'Хлеб'),
];

List<Product> _demoProducts({bool discounted = false}) => [
  Product(
    uuid: discounted ? 'demo-milka' : 'demo-tomato',
    title: discounted
        ? 'Шоколад молочный Milka с печеньем LU 87г'
        : 'Помидоры розовые Казахстан 1кг',
    imageUrl: '',
    minPrice: discounted ? 995 : 899,
    previousPrice: discounted ? 1895 : null,
    stores: [
      StorePrice(
        chainName: 'MagnumGO',
        chainSlug: 'magnumgo',
        price: discounted ? 995 : 899,
      ),
      StorePrice(
        chainName: 'Galmart',
        chainSlug: 'galmart',
        price: discounted ? 1689 : 1105,
      ),
      StorePrice(
        chainName: 'Arbuz',
        chainSlug: 'arbuz',
        price: discounted ? 1800 : 1200,
      ),
    ],
  ),
  Product(
    uuid: discounted ? 'demo-nivea' : 'demo-tea',
    title: discounted
        ? 'Дезодорант-спрей Nivea Черное и Белое шелк'
        : 'Чай Greenfield Summer Bouquet пакетированный 25шт',
    imageUrl: '',
    minPrice: discounted ? 1365 : 665,
    previousPrice: discounted ? 2528 : null,
    stores: [
      StorePrice(
        chainName: discounted ? 'MagnumGO' : 'SMALL',
        chainSlug: 'small',
        price: discounted ? 1365 : 665,
      ),
      StorePrice(
        chainName: 'Arbuz',
        chainSlug: 'arbuz',
        price: discounted ? 2050 : 1200,
      ),
      StorePrice(
        chainName: 'Galmart',
        chainSlug: 'galmart',
        price: discounted ? 2105 : 1245,
      ),
    ],
  ),
];
