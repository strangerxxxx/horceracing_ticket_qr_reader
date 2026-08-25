package jp.strangerxxxx.horceracing_ticket_qr_reader;

import android.content.Intent;
import android.net.Uri;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String STORAGE_CHANNEL = "horceracing_ticket_qr_reader/storage";
    private static final String URL_CHANNEL = "horceracing_ticket_qr_reader/url";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), STORAGE_CHANNEL)
                .setMethodCallHandler(
                        (MethodCall call, MethodChannel.Result result) -> {
                            if ("getStorageDirectory".equals(call.method)) {
                                result.success(getFilesDir().getAbsolutePath());
                            } else {
                                result.notImplemented();
                            }
                        });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), URL_CHANNEL)
                .setMethodCallHandler(
                        (MethodCall call, MethodChannel.Result result) -> {
                            if ("launchUrl".equals(call.method)) {
                                final Object urlArg = call.argument("url");
                                if (!(urlArg instanceof String) || ((String) urlArg).isEmpty()) {
                                    result.error("INVALID_URL", "url is required", null);
                                    return;
                                }
                                try {
                                    final Intent intent =
                                            new Intent(Intent.ACTION_VIEW, Uri.parse((String) urlArg));
                                    startActivity(intent);
                                    result.success(true);
                                } catch (Exception e) {
                                    result.error("LAUNCH_FAILED", e.getMessage(), null);
                                }
                            } else {
                                result.notImplemented();
                            }
                        });
    }
}
