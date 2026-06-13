import 'dart:io';

void main() {
  final Map<String, String> replacements = {
    'Priority-Based Allocation': 'Resource Priorities',
    'Live Feed': 'Live Updates',
    'LIVE FEED': 'LIVE UPDATES',
    'Report Entry Hub': 'Submit Report',
    'Structured Report Entry': 'Manual Entry',
    'Sentinel Intelligence Scan': 'Document Analysis',
    'Strategically Positioned': 'Available for Deployment',
    'Optimizing Humanity Force Response': 'Priority Response Activated',
    'OPTIMIZING HUMANITY FORCE RESPONSE': 'PRIORITY RESPONSE ACTIVATED',
    'Mission Workspace': 'Active Mission',
    'Ground Intelligence': 'Reports',
    'GROUND INTELLIGENCE': 'REPORTS',
    'ground intelligence': 'reports',
    'Intelligence Reports': 'Field Reports',
    'Intelligence Report': 'Field Report',
    'Intelligence report': 'Field report',
    'AI Generated Intelligence': 'AI Generated Report',
    'Mission Intel': 'Mission Details',
    'Mission intel': 'Mission details',
    'AI Insight': 'AI Recommendation',
    'AI Insights': 'AI Recommendations',
    'Tactical Overview': 'Situation Overview',
    'TACTICAL OVERVIEW': 'SITUATION OVERVIEW',
    'Mission Parameters': 'Mission Details',
    'MISSION PARAMETERS': 'MISSION DETAILS',
    'Resource Allocation Matrix': 'Resource Allocation',
    'Volunteer Deployment Status': 'Volunteer Status',
    'Strategic Response Status': 'Response Status',
    'Operational Readiness': 'Readiness Status',
    'Humanitarian Intelligence Network': 'Response Network',
    'Response Coordination Engine': 'Response Coordination',
    'Mission Completion Analytics': 'Mission Summary',
    'Deployment History': 'Mission History',
    'Community Impact Metrics': 'Community Impact',
    'Field Intelligence Center': 'Report Center',
    'Intelligence Confidence': 'Confidence Score',
    'Intelligence Processing': 'Processing Report',
    'AI Situation Assessment': 'Situation Assessment',
    'Critical Resource Forecast': 'Resource Forecast',
    'Voice Observation': 'Voice Report',
    'Voice observation': 'Voice report',
    'Photo Evidence': 'Photo Report',
    'Photo evidence': 'Photo report',
    'Structured Report': 'Manual Report',
    'Structured report': 'Manual report',
    'Finding Nearby Missions': 'Scanning Nearby Incidents',
  };

  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  int modifiedFiles = 0;

  for (var file in files) {
    String content = file.readAsStringSync();
    bool modified = false;

    for (var entry in replacements.entries) {
      if (content.contains(entry.key)) {
        content = content.replaceAll(entry.key, entry.value);
        modified = true;
      }
    }

    if (modified) {
      file.writeAsStringSync(content);
      modifiedFiles++;
      print('Updated ${file.path}');
    }
  }

  print('Modified $modifiedFiles files.');
}
