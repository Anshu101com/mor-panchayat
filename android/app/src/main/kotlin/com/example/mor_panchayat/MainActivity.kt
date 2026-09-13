package com.example.mor_panchayat

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "mor_panchayat/apk_installer"
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                // =====================================================
                // INSTALL APK
                // =====================================================

                "installApk" -> {

                    val apkPath = call.argument<String>("path")

                    if (apkPath.isNullOrBlank()) {
                        result.error(
                            "INVALID_PATH",
                            "APK path is missing.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {

                        val apkFile = File(apkPath)

                        // Verify APK exists
                        if (!apkFile.exists()) {
                            result.error(
                                "FILE_NOT_FOUND",
                                "APK file does not exist.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        if (!apkFile.isFile) {
                            result.error(
                                "INVALID_FILE",
                                "APK path is not a file.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        if (apkFile.length() < 100 * 1024) {
                            result.error(
                                "INVALID_APK",
                                "APK file is too small.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        // Create FileProvider URI
                        val apkUri: Uri =
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {

                                val fileProviderAuthority =
                                    "${applicationContext.packageName}.fileprovider"

                                FileProvider.getUriForFile(
                                    this,
                                    fileProviderAuthority,
                                    apkFile
                                )

                            } else {

                                Uri.fromFile(apkFile)
                            }

                        // Open Android package installer
                        val installIntent = Intent(
                            Intent.ACTION_INSTALL_PACKAGE
                        ).apply {

                            setDataAndType(
                                apkUri,
                                "application/vnd.android.package-archive"
                            )

                            addFlags(
                                Intent.FLAG_ACTIVITY_NEW_TASK
                            )

                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION
                            )
                        }

                        startActivity(installIntent)

                        result.success(true)

                    } catch (e: Exception) {

                        result.error(
                            "INSTALL_ERROR",
                            e.message ?: "Unable to open installer.",
                            null
                        )
                    }
                }

                // =====================================================
                // CHECK UNKNOWN APP INSTALL PERMISSION
                // =====================================================

                "canInstallPackages" -> {

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

                        result.success(
                            packageManager.canRequestPackageInstalls()
                        )

                    } else {

                        result.success(true)
                    }
                }

                // =====================================================
                // OPEN UNKNOWN APP INSTALL SETTINGS
                // =====================================================

                "openInstallSettings" -> {

                    try {

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

                            val settingsIntent = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES
                            ).apply {

                                data = Uri.parse(
                                    "package:$packageName"
                                )
                            }

                            startActivity(settingsIntent)
                        }

                        result.success(true)

                    } catch (e: Exception) {

                        result.error(
                            "SETTINGS_ERROR",
                            e.message
                                ?: "Unable to open installation settings.",
                            null
                        )
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
