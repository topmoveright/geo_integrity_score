import 'package:flutter/material.dart';

ButtonStyle compactButtonStyle() {
  return TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}
