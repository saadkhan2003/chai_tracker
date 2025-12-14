import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/youtube_video_model.dart';
import '../theme/app_theme.dart';

class YouTubeVideoCard extends StatelessWidget {
  final YouTubeVideo video;

  const YouTubeVideoCard({super.key, required this.video});

  Future<void> _openVideo() async {
    final Uri url = Uri.parse(video.videoUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openVideo,
      child: Container(
        width: 260, // Compact width
        height: 240, // Compact height
        margin: const EdgeInsets.only(right: 12, bottom: 8), // Tighter spacing
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Section
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    height: 150, // Reduced thumbnail height
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 150,
                      color: AppTheme.surface,
                      child: const Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryGold),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 150,
                      color: AppTheme.surface,
                      child: const Icon(Icons.error, color: AppTheme.error),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content Section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13, // Smaller font
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStat(Icons.visibility, video.formattedViews),
                        _buildStat(Icons.favorite, video.formattedLikes),
                        _buildStat(Icons.comment, video.formattedComments),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textSecondary), // Smaller icons
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11, // Smaller text
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
