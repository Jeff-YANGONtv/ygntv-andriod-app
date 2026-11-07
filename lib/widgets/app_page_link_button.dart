import 'package:flutter/material.dart';

class AppPageLinkButton extends StatelessWidget {
  const AppPageLinkButton({required this.uri, this.uriBuilder, super.key});

  final Uri uri;
  final Uri Function()? uriBuilder;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
