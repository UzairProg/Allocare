import 'package:flutter/material.dart';
import '../../../map/presentation/map_screen.dart';

class VolunteerMapScreen extends StatelessWidget {
  const VolunteerMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MapScreen(
      isVolunteer: true,
    );
  }
}
