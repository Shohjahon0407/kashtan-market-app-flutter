package uz.beshkashtan.customer

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Base64
import android.util.Log
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Status
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

private const val CHANNEL = "uz.beshkashtan.customer/sms_autofill"
private const val EVENTS = "uz.beshkashtan.customer/sms_autofill_events"

/**
 * Boshqa plaginlar bilan to'qnashmasligi kerak (image_picker, geolocator...).
 * Yangi plagin qo'shilganda qiymatni tekshiring.
 */
private const val CONSENT_REQUEST = 0x5347

/**
 * SMS OTP autofill: SMS Retriever (0 tap, SMS'da app hash bo'lsa) va
 * SMS User Consent (1 tap, hash shart emas).
 *
 * Receiver MANIFESTDA emas, dinamik ro'yxatdan o'tadi: manifest receiver'i
 * jarayonni broadcast bilan uyg'otardi (Dart isolate hali yo'q) va backup
 * qoidalariga tegishga majbur qilardi. Dinamik ro'yxat esa aynan "OTP ekrani
 * ochiq" muddatiga bog'lanadi.
 *
 * Hech qanday SMS ruxsati talab qilinmaydi — xabarni Google Play Services
 * yetkazadi.
 */
class MainActivity : FlutterActivity() {

    private var events: EventChannel.EventSink? = null
    private val pending = mutableListOf<Map<String, String?>>()
    private var receiver: BroadcastReceiver? = null
    private var consentInFlight = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    startSession(call.argument<String>("mode") ?: "consent")
                    result.success(true)
                }
                "stop" -> {
                    stopSession()
                    result.success(null)
                }
                "debugAppHash" -> result.success(debugAppHash())
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    events = sink
                    // Dart obuna bo'lgunicha kelgan xabar yo'qolmasin
                    // (sekin engine start yoki hot restart).
                    pending.forEach { sink?.success(it) }
                    pending.clear()
                }

                override fun onCancel(arguments: Any?) {
                    events = null
                }
            },
        )
    }

    private fun startSession(mode: String) {
        // Idempotent: ilova fondan qaytganda qayta yoqilmaydi, aks holda
        // uchayotgan consent natijasi yo'qolardi.
        if (receiver != null) return

        val broadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != SmsRetriever.SMS_RETRIEVED_ACTION) return
                val extras = intent.extras ?: return
                val status = smsStatus(extras) ?: return
                when (status.statusCode) {
                    CommonStatusCodes.SUCCESS -> {
                        // (a) SMS Retriever: matn darhol keladi — 0 tap.
                        val message = extras.getString(SmsRetriever.EXTRA_SMS_MESSAGE)
                        if (message != null) {
                            stopSession()
                            emit("message", message)
                            return
                        }
                        // (b) SMS User Consent: tizim oynasi uchun Intent.
                        val consent = consentIntent(extras) ?: return
                        if (consentInFlight) return
                        consentInFlight = true
                        runCatching {
                            startActivityForResult(consent, CONSENT_REQUEST)
                        }.onFailure {
                            consentInFlight = false
                            emit("error", "consent_intent_failed")
                        }
                    }

                    CommonStatusCodes.TIMEOUT -> {
                        // GMS listener'i 5 daqiqadan keyin o'zi to'xtaydi.
                        stopSession()
                        emit("timeout", null)
                    }
                }
            }
        }

        val filter = IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION)
        // Broadcast BOSHQA ilovadan (Play Services) keladi, shuning uchun
        // RECEIVER_EXPORTED shart. NOT_EXPORTED quriladi-yu hech qachon
        // xabar olmaydi — jim nosozlik. Xavfsizlikni SEND_PERMISSION beradi:
        // bu intent'ni faqat Play Services yubora oladi.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                broadcastReceiver,
                filter,
                SmsRetriever.SEND_PERMISSION,
                null,
                Context.RECEIVER_EXPORTED,
            )
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(broadcastReceiver, filter, SmsRetriever.SEND_PERMISSION, null)
        }
        receiver = broadcastReceiver

        val client = SmsRetriever.getClient(this)
        if (mode == "retriever" || mode == "both") {
            client.startSmsRetriever()
        }
        if (mode == "consent" || mode == "both") {
            client.startSmsUserConsent(null)
        }
    }

    private fun stopSession() {
        receiver?.let { runCatching { unregisterReceiver(it) } }
        receiver = null
    }

    private fun smsStatus(extras: Bundle): Status? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            extras.getParcelable(SmsRetriever.EXTRA_STATUS, Status::class.java)
        } else {
            @Suppress("DEPRECATION")
            extras.getParcelable(SmsRetriever.EXTRA_STATUS)
        }

    private fun consentIntent(extras: Bundle): Intent? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            extras.getParcelable(SmsRetriever.EXTRA_CONSENT_INTENT, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            extras.getParcelable(SmsRetriever.EXTRA_CONSENT_INTENT)
        }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == CONSENT_REQUEST) {
            consentInFlight = false
            stopSession()
            if (resultCode == Activity.RESULT_OK) {
                val message = data?.getStringExtra(SmsRetriever.EXTRA_SMS_MESSAGE)
                if (message != null) emit("message", message)
                else emit("error", "empty_consent_result")
            } else {
                emit("denied", null)
            }
            return
        }
        // MAJBURIY: image_picker (rasm/ovoz), geolocator ruxsat oynasi va
        // url_launcher natijalari SHU YERDAN o'tadi — super chaqirilmasa
        // ular jimgina ishlamay qo'yadi.
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        stopSession()
        super.onDestroy()
    }

    private fun emit(type: String, value: String?) {
        val payload = mapOf("type" to type, "message" to value)
        val sink = events
        if (sink == null) pending.add(payload) else sink.success(payload)
    }

    /**
     * Faqat debug build: ishlayotgan ilovaning 11 belgilik app hash'i.
     *
     * Release'da `null` qaytaradi — hash imzo kalitiga bog'liq va uni
     * production uchun Play Console'dagi sertifikatdan (tool/app_hash.py)
     * olish kerak. `BuildConfig.DEBUG` bu loyihada mavjud emas (AGP 8+ da
     * buildConfig o'chirilgan), shuning uchun FLAG_DEBUGGABLE ishlatiladi.
     */
    private fun debugAppHash(): String? {
        val debuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!debuggable || Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return null
        return runCatching {
            val info = packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNING_CERTIFICATES,
            )
            val signature = info.signingInfo!!.apkContentsSigners[0].toCharsString()
            val digest = MessageDigest.getInstance("SHA-256")
                .digest("$packageName $signature".toByteArray(Charsets.UTF_8))
            // DIQQAT: birinchi 9 BAYT (9 ta belgi emas), standart base64
            // alifbosi (URL-safe emas) — keyin 11 ta belgi.
            Base64.encodeToString(
                digest.copyOf(9),
                Base64.NO_PADDING or Base64.NO_WRAP,
            ).substring(0, 11).also { Log.d("SmsAutofill", "app hash = $it") }
        }.getOrNull()
    }
}
