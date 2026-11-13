import 'package:flutter/widgets.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// Shared lens look for the shell chrome
const shellGlass = LiquidGlassStyle(
  specular: LiquidGlassLight.specular(),
  color: Color(0x8A101010),
  blur: 8,
  saturation: 1.04,
);

LiquidGlassShape shellShape(double radius) {
  return LiquidGlassShape.continuousRoundedRectangle(cornerRadius: radius);
}

class ShellLens extends StatelessWidget {
  final double radius;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const ShellLens({
    super.key,
    required this.radius,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassLens(
      style: shellGlass.copyWith(shape: shellShape(radius)),
      child: Padding(padding: padding, child: child),
    );
  }
}

class ShellCapture extends InheritedWidget {
  final LiquidGlassViewController controller;

  const ShellCapture({
    super.key,
    required this.controller,
    required super.child,
  });

  static LiquidGlassViewController? read(BuildContext context) {
    return context.getInheritedWidgetOfExactType<ShellCapture>()?.controller;
  }

  @override
  bool updateShouldNotify(ShellCapture oldWidget) {
    return controller != oldWidget.controller;
  }
}
