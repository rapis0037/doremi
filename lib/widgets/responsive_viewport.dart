import 'package:flutter/material.dart';

class ResponsiveViewport extends StatelessWidget {
  const ResponsiveViewport({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final designSize = isLandscape ? const Size(915, 412) : const Size(412, 915);
        return Center(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: SizedBox.fromSize(
              size: designSize,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: designSize,
                  textScaler: TextScaler.noScaling,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
