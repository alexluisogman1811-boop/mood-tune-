import 'package:material_ui/material_ui.dart';

/// Album art with a tasteful generated placeholder when none is available
/// or loading fails.
class Artwork extends StatelessWidget {
  const Artwork({
    required this.seed,
    this.url,
    this.size = 64,
    this.radius = 12,
    super.key,
  });

  final Uri? url;

  /// Stable string (e.g. track id) used to pick placeholder colours.
  final String seed;
  final double size;
  final double radius;

  static const _palettes = [
    [Color(0xFF5B4B8A), Color(0xFF2A1F3D)],
    [Color(0xFF3E6D8E), Color(0xFF1B2A3A)],
    [Color(0xFF8E5B6D), Color(0xFF2D1B26)],
    [Color(0xFF4F7F6A), Color(0xFF17261F)],
    [Color(0xFF9A7B4F), Color(0xFF2B2117)],
  ];

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(
      colors: _palettes[seed.hashCode.abs() % _palettes.length],
      size: size,
    );
    final src = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: src == null
            ? placeholder
            : Image.network(
                src.toString(),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : placeholder,
              ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.colors, required this.size});
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
    ),
    child: Icon(Icons.music_note, color: Colors.white54, size: size * 0.4),
  );
}
