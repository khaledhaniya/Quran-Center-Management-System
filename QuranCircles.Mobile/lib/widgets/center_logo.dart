import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class CenterLogo extends StatelessWidget {
  const CenterLogo({super.key, required this.logoUrl, this.size = 48});

  final String logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Image.asset('assets/logo.png', width: size, height: size, fit: BoxFit.contain);
    Widget image;
    if (logoUrl.startsWith('data:image/') && logoUrl.contains(';base64,')) {
      try {
        final Uint8List bytes = base64Decode(logoUrl.substring(logoUrl.indexOf(',') + 1));
        image = Image.memory(bytes, width: size, height: size, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallback());
      } catch (_) {
        image = fallback();
      }
    } else if (logoUrl.startsWith('https://')) {
      image = Image.network(logoUrl, width: size, height: size, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback());
    } else {
      image = fallback();
    }
    return SizedBox(width: size, height: size, child: image);
  }
}
