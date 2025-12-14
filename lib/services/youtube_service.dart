import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/youtube_video_model.dart';

class YouTubeService {
  static const String _cacheKey = 'youtube_videos_cache';
  static const String _cacheTimeKey = 'youtube_cache_time';
  static const Duration _cacheDuration = Duration(hours: 1);

  Future<String> _getApiKey() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.fetchAndActivate();
    return remoteConfig.getString('youtube_api_key');
  }

  Future<String?> _getChannelId(String channelUrl) async {
    try {
      // Clean the URL
      final url = channelUrl.trim();
      
      // Direct channel ID in URL: /channel/UC...
      if (url.contains('/channel/')) {
        final channelId = url.split('/channel/').last.split('/').first.split('?').first;
        return channelId;
      }
      
      // Handle format: @username
      if (url.contains('@')) {
        final handle = url.split('@').last.split('/').first.split('?').first;
        return await _fetchChannelIdByHandle(handle);
      }
      
      // Custom URL format: /c/customname or /user/username
      if (url.contains('/c/') || url.contains('/user/')) {
        final parts = url.contains('/c/') ? url.split('/c/') : url.split('/user/');
        final customName = parts.last.split('/').first.split('?').first;
        return await _fetchChannelIdByCustomUrl(customName);
      }
      
      // If just a handle without @ symbol
      if (!url.contains('/') && !url.contains('http')) {
        return await _fetchChannelIdByHandle(url);
      }
      
    } catch (e) {
      print('Error parsing channel URL: $e');
    }
    return null;
  }

  Future<String?> _fetchChannelIdByHandle(String handle) async {
    try {
      final apiKey = await _getApiKey();
      final url = 'https://www.googleapis.com/youtube/v3/channels?part=id&forHandle=$handle&key=$apiKey';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['items'] != null && data['items'].isNotEmpty) {
          return data['items'][0]['id'];
        }
      }
    } catch (e) {
      print('Error fetching channel ID by username: $e');
    }
    return null;
  }

  Future<String?> _fetchChannelIdByCustomUrl(String customUrl) async {
    try {
      final apiKey = await _getApiKey();
      final url = 'https://www.googleapis.com/youtube/v3/search?part=id&q=$customUrl&type=channel&key=$apiKey';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['items'] != null && data['items'].isNotEmpty) {
          return data['items'][0]['id']['channelId'];
        }
      }
    } catch (e) {
      print('Error fetching channel ID by custom URL: $e');
    }
    return null;
  }

  Future<List<YouTubeVideo>> fetchLatestVideos(String channelUrl) async {
    try {
      final channelId = await _getChannelId(channelUrl);
      if (channelId == null) {
        throw 'Could not extract channel ID from URL';
      }

      // Check cache first (using channelId)
      final cachedVideos = await _getCachedVideos(channelId);
      if (cachedVideos != null) {
        return cachedVideos;
      }

      final apiKey = await _getApiKey();
      
      // Fetch latest 4 videos
      final searchUrl = 'https://www.googleapis.com/youtube/v3/search'
          '?part=snippet'
          '&channelId=$channelId'
          '&maxResults=4'
          '&order=date'
          '&type=video'
          '&key=$apiKey';

      final searchResponse = await http.get(Uri.parse(searchUrl));
      if (searchResponse.statusCode != 200) {
        throw 'Failed to fetch videos: ${searchResponse.statusCode}';
      }

      final searchData = json.decode(searchResponse.body);
      final items = searchData['items'] as List;

      if (items.isEmpty) {
        return [];
      }

      // Get video IDs
      final videoIds = items.map((item) => item['id']['videoId']).join(',');

      // Fetch video statistics
      final statsUrl = 'https://www.googleapis.com/youtube/v3/videos'
          '?part=statistics,contentDetails'
          '&id=$videoIds'
          '&key=$apiKey';

      final statsResponse = await http.get(Uri.parse(statsUrl));
      final statsData = json.decode(statsResponse.body);
      final statsItems = statsData['items'] as List;

      // Create map of video ID to statistics
      final statsMap = <String, Map<String, dynamic>>{};
      for (var stat in statsItems) {
        statsMap[stat['id']] = {
          ...stat['statistics'],
          'contentDetails': stat['contentDetails'],
        };
      }

      // Combine search results with statistics
      final videos = items.map((item) {
        final videoId = item['id']['videoId'];
        final stats = statsMap[videoId];
        return YouTubeVideo.fromJson(item, stats);
      }).toList();

      // Cache the results
      await _cacheVideos(channelId, videos);

      return videos;
    } catch (e) {
      print('Error fetching YouTube videos: $e');
      return [];
    }
  }

  Future<Map<String, String>?> fetchChannelInfo(String channelUrl) async {
    try {
      final channelId = await _getChannelId(channelUrl);
      if (channelId == null) return null;

      final apiKey = await _getApiKey();
      final url = 'https://www.googleapis.com/youtube/v3/channels'
          '?part=snippet,brandingSettings'
          '&id=$channelId'
          '&key=$apiKey';

      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['items'] != null && data['items'].isNotEmpty) {
          final channel = data['items'][0];
          final snippet = channel['snippet'];
          final branding = channel['brandingSettings'];
          
          final bannerUrl = branding?['image']?['bannerExternalUrl'] ?? '';
          // Prefer medium thumbnail (240x240) as it's sufficient and lighter than high (800x800)
          final thumbUrl = snippet?['thumbnails']?['medium']?['url'] ?? snippet?['thumbnails']?['high']?['url'] ?? '';
          
          return {
            'title': snippet['title'] ?? '',
            'thumbnail': thumbUrl,
            'banner': bannerUrl,
          };
        }
      }
    } catch (e) {
      print('Error fetching channel info: $e');
    }
    return null;
  }

  Future<List<YouTubeVideo>?> _getCachedVideos(String channelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_cacheKey}_$channelId';
      final cacheTimeKey = '${_cacheTimeKey}_$channelId';
      
      final cacheTime = prefs.getInt(cacheTimeKey);
      
      if (cacheTime != null) {
        final cachedDate = DateTime.fromMillisecondsSinceEpoch(cacheTime);
        if (DateTime.now().difference(cachedDate) < _cacheDuration) {
          final cachedData = prefs.getString(cacheKey);
          if (cachedData != null) {
            final List<dynamic> jsonList = json.decode(cachedData);
            return jsonList.map((json) => YouTubeVideo.fromJson(json, json['statistics'])).toList();
          }
        }
      }
    } catch (e) {
      print('Error reading cache: $e');
    }
    return null;
  }

  Future<void> _cacheVideos(String channelId, List<YouTubeVideo> videos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_cacheKey}_$channelId';
      final cacheTimeKey = '${_cacheTimeKey}_$channelId';
      
      final jsonList = videos.map((v) => {
          'id': {'videoId': v.videoId},
          'snippet': {
            'title': v.title,
            'thumbnails': {'high': {'url': v.thumbnailUrl}},
            'channelTitle': v.channelTitle,
            'publishedAt': v.publishedAt.toIso8601String(),
          },
          'statistics': {
            'viewCount': v.viewCount.toString(),
            'likeCount': v.likeCount.toString(),
            'commentCount': v.commentCount.toString(),
          },
          'contentDetails': {
            'duration': v.duration,
          },
        }).toList();
      
      await prefs.setString(cacheKey, json.encode(jsonList));
      await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error caching videos: $e');
    }
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Clear all keys starting with our prefix
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_cacheKey) || key.startsWith(_cacheTimeKey)) {
          await prefs.remove(key);
        }
      }
      print('YouTube cache cleared');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
}
