class LatLng { final double lat, lon; LatLng(this.lat, this.lon); }

List<LatLng> parsePolygon(String s) => s.split(';').map((p){
  final parts = p.split(',');
  return LatLng(double.parse(parts[0]), double.parse(parts[1]));
}).toList();

bool containsPoint(LatLng pt, List<LatLng> poly) {
  bool inside = false; int j = poly.length - 1;
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i], b = poly[j];
    final intersect = ((a.lon > pt.lon) != (b.lon > pt.lon)) &&
      (pt.lat < (b.lat - a.lat) * (pt.lon - a.lon) / ((b.lon - a.lon) + 1e-12) + a.lat);
    if (intersect) inside = !inside;
    j = i;
  }
  return inside;
}
