package com.example.allocare_app

import com.google.firebase.pnv.FirebasePhoneNumberVerification
import com.google.firebase.pnv.VerificationSupportResult
import com.google.firebase.pnv.VerifiedPhoneNumberTokenResult
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private lateinit var fpnv: FirebasePhoneNumberVerification

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		fpnv = FirebasePhoneNumberVerification.getInstance(this)
		fpnv.enableTestSession("AdrTqXH0O1vu-SdRw14RN8A8RBdZmrj5kDls6cMtkzoY0Ud4-klpTzNy5obrqFcEsO19Pz5nu6M3BFLhczRXeOn2iyr4QRHqXz4Bzk3knjQwgFw-MQSmLXGSDGDV0kM7Fe3jORGmIt4zQPJqAR413WZEOw")

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"com.example.allocare_app/pnv"
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"getVerifiedPhone" -> {
					fpnv.getVerificationSupportInfo()
						.addOnSuccessListener { supportResults ->
							if (!isPnvSupported(supportResults)) {
								result.error(
									"PNV_UNSUPPORTED",
									buildSupportMessage(supportResults),
									null
								)
								return@addOnSuccessListener
							}

							fpnv.getVerifiedPhoneNumber()
								.addOnSuccessListener { verified: VerifiedPhoneNumberTokenResult ->
									val payload = hashMapOf<String, String?>(
										"phoneNumber" to verified.getPhoneNumber(),
										"token" to verified.getToken()
									)
									result.success(payload)
								}
								.addOnFailureListener { error ->
									result.error(
										"PNV_FAILED",
										friendlyPnvError(error.message),
										null
									)
								}
						}
						.addOnFailureListener { error ->
							result.error(
								"PNV_FAILED",
								friendlyPnvError(error.message),
								null
							)
						}
				}

				else -> result.notImplemented()
			}
		}
	}

	private fun isPnvSupported(results: List<VerificationSupportResult>): Boolean {
		return results.isNotEmpty() && results.all { it.isSupported() }
	}

	private fun buildSupportMessage(results: List<VerificationSupportResult>): String {
		if (results.isEmpty()) {
			return "PNV is not supported on this device or no eligible SIM slot was found. Use a GMS Beta-enabled physical device."
		}

		val details = results.joinToString(separator = "; ") { support ->
			"slot=${support.getSimSlot()}, carrier=${support.getCarrierId()}, reason=${support.getReason()}, supported=${support.isSupported()}"
		}

		return "PNV is not supported on this device. Details: $details"
	}

	private fun friendlyPnvError(message: String?): String {
		if (message.isNullOrBlank()) {
			return "Phone verification failed."
		}

		return when {
			message.contains("DigitalCredentials", ignoreCase = true) ->
				"The device couldn't fetch the Digital Credentials payload. Use a physical GMS Beta device with a supported SIM, then try again."
			message.contains("carrier", ignoreCase = true) ->
				"The SIM carrier is not supported for PNV on this device."
			message.contains("SIM", ignoreCase = true) ->
				"No eligible SIM state was found for PNV. Check the SIM and mobile network."
			else -> message
		}
	}
}
