import 'package:flutter/material.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/assets.gen.dart';

class SonarLogo extends StatelessWidget {
  final bool withText;

  /// Width and height of the mark (the text keeps its own type-scale size).
  final double size;

  const SonarLogo({required this.withText, this.size = 200});

  @override
  Widget build(BuildContext context) {
    final logo = ColorFiltered(
      colorFilter: ColorFilter.mode(
        Theme.of(context).colorScheme.primary,
        BlendMode.srcATop,
      ),
      child: Assets.img.logo512.image(
        width: size,
        height: size,
      ),
    );

    if (withText) {
      return Column(
        children: [
          logo,
          Text(
            'Sonar',
            style: context.ls.display,
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      return logo;
    }
  }
}
