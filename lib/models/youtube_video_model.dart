class YouTubeVideo {
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final String channelTitle;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final DateTime publishedAt;
  final String duration;

  YouTubeVideo({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.channelTitle,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.publishedAt,
    required this.duration,
  });

  factory YouTubeVideo.fromJson(Map<String, dynamic> json, Map<String, dynamic>? statistics) {
    final snippet = json['snippet'] as Map<String, dynamic>;
    final stats = statistics ?? {};
    // Look for contentDetails in statistics (API) or root json (Cache)
    final contentDetails = (stats['contentDetails'] ?? json['contentDetails']) as Map<String, dynamic>?;
    
    return YouTubeVideo(
      videoId: json['id'] is String ? json['id'] : json['id']['videoId'],
      title: snippet['title'] ?? '',
      thumbnailUrl: snippet['thumbnails']?['high']?['url'] ?? 
                    snippet['thumbnails']?['medium']?['url'] ?? '',
      channelTitle: snippet['channelTitle'] ?? '',
      viewCount: int.tryParse(stats['viewCount']?.toString() ?? '0') ?? 0,
      likeCount: int.tryParse(stats['likeCount']?.toString() ?? '0') ?? 0,
      commentCount: int.tryParse(stats['commentCount']?.toString() ?? '0') ?? 0,
      publishedAt: DateTime.parse(snippet['publishedAt'] ?? DateTime.now().toIso8601String()),
      duration: _parseDuration(contentDetails?['duration'] ?? 'PT0S'),
    );
  }

  static String _parseDuration(String duration) {
    if (duration == 'PT0S' || duration == '0:00') return '0:00';
    
    // If it doesn't start with PT, assume it's already formatted (from cache)
    if (!duration.startsWith('PT')) {
      return duration;
    }

    try {
      // Parse ISO 8601 duration (e.g., PT4M13S -> 4:13)
      final regex = RegExp(r'PT(\d+H)?(\d+M)?(\d+S)?');
      final match = regex.firstMatch(duration);
      
      if (match == null) return '0:00';
      
      final hours = match.group(1)?.replaceAll('H', '') ?? '';
      final minutes = match.group(2)?.replaceAll('M', '') ?? '0';
      final seconds = match.group(3)?.replaceAll('S', '') ?? '0';
      
      if (hours.isNotEmpty) {
        return '$hours:${minutes.padLeft(2, '0')}:${seconds.padLeft(2, '0')}';
      }
      return '$minutes:${seconds.padLeft(2, '0')}';
    } catch (e) {
      return '0:00';
    }
  }

  String get videoUrl => 'https://www.youtube.com/watch?v=$videoId';
  
  String get formattedViews {
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K';
    }
    return viewCount.toString();
  }
  
  String get formattedLikes {
    if (likeCount >= 1000000) {
      return '${(likeCount / 1000000).toStringAsFixed(1)}M';
    } else if (likeCount >= 1000) {
      return '${(likeCount / 1000).toStringAsFixed(1)}K';
    }
    return likeCount.toString();
  }

  String get formattedComments {
    if (commentCount >= 1000000) {
      return '${(commentCount / 1000000).toStringAsFixed(1)}M';
    } else if (commentCount >= 1000) {
      return '${(commentCount / 1000).toStringAsFixed(1)}K';
    }
    return commentCount.toString();
  }
}
