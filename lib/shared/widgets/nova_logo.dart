import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nova3d_frontend/core/theme.dart';

class NovaLogo extends StatelessWidget {
  const NovaLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: kAccentBlue,
              borderRadius: BorderRadius.circular(size * 0.25),
            ),
            child: Center(
              child: Text(
                'N',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.55,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Nova3D',
            style: GoogleFonts.inter(
              color: kTextPrimary,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.6,
            ),
          ),
        ],
      );
}
