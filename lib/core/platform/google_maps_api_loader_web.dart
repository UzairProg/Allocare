import 'dart:async';
import 'dart:html' as html;

Future<void> ensureGoogleMapsApiLoaded({required String apiKey}) async {
  final trimmedApiKey = apiKey.trim();
  
  if (trimmedApiKey.isEmpty) {
    throw StateError(
      'Missing MAPS_API_KEY. Please provide it using --dart-define=MAPS_API_KEY=your_key when building or running the web application.',
    );
  }

  // Check if script is already present
  if (html.document.querySelector('script[data-allocare-google-maps="true"]') !=
      null) {
    return;
  }

  final completer = Completer<void>();
  final script = html.ScriptElement()
    ..async = true
    ..defer = true
    ..src =
        'https://maps.googleapis.com/maps/api/js?key=$trimmedApiKey&libraries=places,visualization';
  script.setAttribute('data-allocare-google-maps', 'true');

  script.onLoad.first.then((_) => completer.complete());
  script.onError.first.then((_) {
    completer.completeError(
      StateError('Failed to load the Google Maps JavaScript API. Verify that the MAPS_API_KEY is correct and has the required permissions.'),
    );
  });

  html.document.head?.append(script);

  await completer.future;
}
