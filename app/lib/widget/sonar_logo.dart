import 'package:flutter/material.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/assets.gen.dart';

class SonarLogo extends StatelessWidget {
  final bool withText;

  const SonarLogo({required this.withText});

  @override
  Widget build(BuildContext context) {
    final logo = ColorFiltered(
      colorFilter: ColorFilter.mode(
        Theme.of(context).colorScheme.primary,
        BlendMode.srcATop,
      ),
      child: Assets.img.logo512.image(
        width: 200,
        height: 200,
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
