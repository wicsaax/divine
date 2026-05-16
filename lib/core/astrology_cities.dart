// 简易城市数据库 (中国主要城市 + 国际常见).
// 用户填城市名 → 自动取 lat/lon/tz, 不必手填.
// 不在表内的城市建议直接填 "lat,lon" (例: "31.23,121.47"), 引擎也支持.

class City {
  final String name;
  final List<String> aliases;
  final double lat;     // 纬度, 北纬正
  final double lon;     // 经度, 东经正
  final double tzHours; // 与 UTC 的小时差 (东 8 区为 +8)
  const City(this.name, this.aliases, this.lat, this.lon, this.tzHours);
}

const List<City> cities = [
  // 中国
  City('北京',   ['Beijing', 'beijing'],   39.9042, 116.4074, 8.0),
  City('上海',   ['Shanghai', 'shanghai'], 31.2304, 121.4737, 8.0),
  City('广州',   ['Guangzhou'],            23.1291, 113.2644, 8.0),
  City('深圳',   ['Shenzhen'],             22.5431, 114.0579, 8.0),
  City('杭州',   ['Hangzhou'],             30.2741, 120.1551, 8.0),
  City('南京',   ['Nanjing'],              32.0603, 118.7969, 8.0),
  City('武汉',   ['Wuhan'],                30.5928, 114.3055, 8.0),
  City('成都',   ['Chengdu'],              30.5728, 104.0668, 8.0),
  City('重庆',   ['Chongqing'],            29.5630, 106.5516, 8.0),
  City('西安',   ['Xi\'an', 'Xian'],       34.3416, 108.9398, 8.0),
  City('天津',   ['Tianjin'],              39.3434, 117.3616, 8.0),
  City('苏州',   ['Suzhou'],               31.2989, 120.5853, 8.0),
  City('青岛',   ['Qingdao'],              36.0671, 120.3826, 8.0),
  City('郑州',   ['Zhengzhou'],            34.7466, 113.6253, 8.0),
  City('长沙',   ['Changsha'],             28.2282, 112.9388, 8.0),
  City('厦门',   ['Xiamen'],               24.4798, 118.0894, 8.0),
  City('哈尔滨', ['Harbin'],               45.8038, 126.5350, 8.0),
  City('沈阳',   ['Shenyang'],             41.8057, 123.4315, 8.0),
  City('大连',   ['Dalian'],               38.9140, 121.6147, 8.0),
  City('昆明',   ['Kunming'],              25.0389, 102.7183, 8.0),
  City('福州',   ['Fuzhou'],               26.0745, 119.2965, 8.0),
  City('合肥',   ['Hefei'],                31.8206, 117.2272, 8.0),
  City('济南',   ['Jinan'],                36.6512, 117.1201, 8.0),
  City('南宁',   ['Nanning'],              22.8170, 108.3669, 8.0),
  City('南昌',   ['Nanchang'],             28.6829, 115.8581, 8.0),
  City('贵阳',   ['Guiyang'],              26.6470, 106.6302, 8.0),
  City('兰州',   ['Lanzhou'],              36.0611, 103.8343, 8.0),
  City('乌鲁木齐',['Urumqi'],              43.8256, 87.6168,  8.0),
  City('拉萨',   ['Lhasa'],                29.6520, 91.1721,  8.0),
  City('呼和浩特',['Hohhot'],              40.8414, 111.7519, 8.0),
  City('香港',   ['Hong Kong', 'HongKong'],22.3193, 114.1694, 8.0),
  City('澳门',   ['Macao', 'Macau'],       22.1987, 113.5439, 8.0),
  City('台北',   ['Taipei'],               25.0330, 121.5654, 8.0),
  // 海外常见
  City('东京',   ['Tokyo'],                35.6762, 139.6503, 9.0),
  City('首尔',   ['Seoul'],                37.5665, 126.9780, 9.0),
  City('新加坡', ['Singapore'],            1.3521,  103.8198, 8.0),
  City('曼谷',   ['Bangkok'],              13.7563, 100.5018, 7.0),
  City('伦敦',   ['London'],               51.5074, -0.1278,  0.0),
  City('巴黎',   ['Paris'],                48.8566, 2.3522,   1.0),
  City('柏林',   ['Berlin'],               52.5200, 13.4050,  1.0),
  City('纽约',   ['New York', 'NewYork'],  40.7128, -74.0060, -5.0),
  City('洛杉矶', ['Los Angeles'],          34.0522, -118.2437,-8.0),
  City('旧金山', ['San Francisco'],        37.7749, -122.4194,-8.0),
  City('悉尼',   ['Sydney'],               -33.8688, 151.2093, 10.0),
  City('莫斯科', ['Moscow'],               55.7558, 37.6173,  3.0),
];

/// 模糊查找城市. 返回 null 表示没找到.
City? findCity(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return null;
  for (final c in cities) {
    if (c.name == query) return c;
    if (c.aliases.any((a) => a.toLowerCase() == q)) return c;
    if (q.contains(c.name) || c.name.contains(query)) return c;
  }
  return null;
}

/// 解析 "lat,lon" 或 "lat,lon,tz" 格式. 失败返回 null.
City? parseLatLon(String input) {
  final parts = input.split(',').map((s) => s.trim()).toList();
  if (parts.length < 2 || parts.length > 3) return null;
  final lat = double.tryParse(parts[0]);
  final lon = double.tryParse(parts[1]);
  if (lat == null || lon == null) return null;
  final tz = parts.length == 3 ? (double.tryParse(parts[2]) ?? 8.0) : 8.0;
  return City('坐标 ${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}',
      const [], lat, lon, tz);
}
