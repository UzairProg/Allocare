class VolunteerModel {
  const VolunteerModel({
    required this.id,
    required this.name,
    required this.skills,
    required this.reliabilityScore,
  });

  final String id;
  final String name;
  final List<String> skills;
  final double reliabilityScore;
}
