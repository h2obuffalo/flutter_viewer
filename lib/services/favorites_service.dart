import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const String _favoritesKey = 'favorite_artists';
  
  static Future<List<int>> getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey)?.map(int.parse).toList() ?? [];
  }
  
  static Future<void> toggleFavorite(int artistId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavoriteIds();
    
    if (favorites.contains(artistId)) {
      favorites.remove(artistId);
    } else {
      favorites.add(artistId);
    }
    
    await prefs.setStringList(_favoritesKey, favorites.map((id) => id.toString()).toList());
  }
  
  static Future<bool> isFavorite(int artistId) async {
    final favorites = await getFavoriteIds();
    return favorites.contains(artistId);
  }
}

