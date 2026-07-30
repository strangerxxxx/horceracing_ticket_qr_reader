package com.example.horceracing_ticket_qr_reader;

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "horceracing_ticket_qr_reader/storage";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (MethodCall call, MethodChannel.Result result) -> {
                            if ("getStorageDirectory".equals(call.method)) {
                                result.success(getFilesDir().getAbsolutePath());
                            } else {
                                result.notImplemented();
                            }
                        });
    }
}
