/// Available visual arrow head skins for threads.
enum ArrowSkin {
  chevron('Classic Chevron', 'Aerodynamic precision arrows', '🏹'),
  rounded('Rounded Neon', 'Soft futuristic pointers', '🔺'),
  diamond('Diamond Gem', 'Sharp crystal facets', '💎'),
  rockets('Space Rockets', 'Blazing interstellar rockets', '🚀'),
  animals('Wildlife Creatures', 'Playful creature pack (🦊 🐱 🐶 🐰)', '🦊'),
  emojis('Emoji Fun', 'Vibrant emoji mix (🚀 ⚡ ⭐ 🎯 🔥 💎)', '⚡'),
  random('Random Surprise', 'Unique random emoji on every arrow', '🎲');

  const ArrowSkin(this.displayName, this.description, this.previewIcon);

  final String displayName;
  final String description;
  final String previewIcon;

  static ArrowSkin fromId(String? id) {
    if (id == null) return ArrowSkin.chevron;
    return ArrowSkin.values.firstWhere(
      (s) => s.name == id,
      orElse: () => ArrowSkin.chevron,
    );
  }
}
