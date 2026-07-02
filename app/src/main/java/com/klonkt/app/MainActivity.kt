package com.klonkt.app

import android.app.Activity
import android.app.AlertDialog
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import android.widget.FrameLayout
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class MainActivity : Activity() {
    private lateinit var webView: WebView
    private lateinit var statusText: TextView
    private lateinit var statusLight: View
    private lateinit var statusLabel: TextView
    private lateinit var dashboardOverlay: LinearLayout
    private lateinit var progressBar: ProgressBar

    private val PREFS_NAME = "klonkt_prefs"
    private val KEY_PORT = "server_port"
    private val KEY_COMMAND = "termux_command"
    private val KEY_SAVED_VERSION_CODE = "saved_version_code"

    private val DEFAULT_COMMAND = "termux-wake-lock && cd ~/klonkt-node && npm run start & ssh -R 80:localhost:3020 a.pinggy.io"

    @Volatile
    private var pollingSessionId = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 1. Root Vertical Layout
        val rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.parseColor("#121212"))
        }

        // 2. Toolbar Layout
        val toolbar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(56)
            )
            setBackgroundColor(Color.parseColor("#1E1E1E"))
            setPadding(dpToPx(16), 0, dpToPx(16), 0)
            gravity = Gravity.CENTER_VERTICAL
        }

        val appTitle = TextView(this).apply {
            text = "Klonkt"
            setTextColor(Color.WHITE)
            textSize = 18f
            typeface = Typeface.DEFAULT_BOLD
        }
        toolbar.addView(appTitle)

        // Status Indicator Group
        val statusGroup = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                leftMargin = dpToPx(16)
            }
            gravity = Gravity.CENTER_VERTICAL
        }

        statusLight = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(dpToPx(10), dpToPx(10))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#FFC107")) // Yellow/Orange by default (loading)
            }
        }
        statusGroup.addView(statusLight)

        statusLabel = TextView(this).apply {
            text = "BOOTING"
            setTextColor(Color.parseColor("#B0BEC5"))
            textSize = 11f
            setPadding(dpToPx(6), 0, 0, 0)
        }
        statusGroup.addView(statusLabel)
        
        toolbar.addView(statusGroup)

        // Spacer to push buttons to the right
        val spacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, 0, 1f)
        }
        toolbar.addView(spacer)

        // Reload button
        val reloadBtn = TextView(this).apply {
            text = "RELOAD"
            setTextColor(Color.WHITE)
            textSize = 12f
            setPadding(dpToPx(12), dpToPx(6), dpToPx(12), dpToPx(6))
            background = GradientDrawable().apply {
                cornerRadius = dpToPx(4).toFloat()
                setColor(Color.parseColor("#2C2C2C"))
            }
            setOnClickListener {
                restartAppLogic()
            }
        }
        toolbar.addView(reloadBtn)

        // Spacer between buttons
        val buttonSpacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(dpToPx(8), ViewGroup.LayoutParams.MATCH_PARENT)
        }
        toolbar.addView(buttonSpacer)

        // Settings button
        val settingsBtn = TextView(this).apply {
            text = "SETTINGS"
            setTextColor(Color.WHITE)
            textSize = 12f
            setPadding(dpToPx(12), dpToPx(6), dpToPx(12), dpToPx(6))
            background = GradientDrawable().apply {
                cornerRadius = dpToPx(4).toFloat()
                setColor(Color.parseColor("#00ADB5"))
            }
            setOnClickListener {
                showSettingsDialog()
            }
        }
        toolbar.addView(settingsBtn)

        rootLayout.addView(toolbar)

        // 3. Content Frame Layout (WebView + Progress + Overlay)
        val contentFrame = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }

        // WebView
        webView = WebView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    progressBar.visibility = View.GONE
                }

                override fun onReceivedError(view: WebView?, errorCode: Int, description: String?, failingUrl: String?) {
                    val port = getSavedPort()
                    if (failingUrl?.contains("127.0.0.1:$port") == true || failingUrl?.contains("localhost:$port") == true) {
                        runOnUiThread {
                            dashboardOverlay.visibility = View.VISIBLE
                            statusText.text = "WebView laadfout: $description\n\nIs de server gestopt?"
                            statusLight.background = GradientDrawable().apply {
                                shape = GradientDrawable.OVAL
                                setColor(Color.parseColor("#F44336")) // Red
                            }
                            statusLabel.text = "OFFLINE"
                        }
                    }
                }
            }
            webChromeClient = object : WebChromeClient() {
                override fun onProgressChanged(view: WebView?, newProgress: Int) {
                    super.onProgressChanged(view, newProgress)
                    if (newProgress < 100) {
                        progressBar.visibility = View.VISIBLE
                        progressBar.progress = newProgress
                    } else {
                        progressBar.visibility = View.GONE
                    }
                }
            }
        }
        contentFrame.addView(webView)

        // ProgressBar (Horizontal)
        progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                dpToPx(4)
            ).apply {
                gravity = Gravity.TOP
            }
            max = 100
            visibility = View.GONE
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                progressTintList = android.content.res.ColorStateList.valueOf(Color.parseColor("#00ADB5"))
            }
        }
        contentFrame.addView(progressBar)

        // Dashboard Overlay
        dashboardOverlay = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.parseColor("#121212"))
            gravity = Gravity.CENTER
            setPadding(dpToPx(32), dpToPx(32), dpToPx(32), dpToPx(32))
        }

        val overlayTitle = TextView(this).apply {
            text = "Klonkt"
            setTextColor(Color.parseColor("#00ADB5"))
            textSize = 36f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dpToPx(24))
        }
        dashboardOverlay.addView(overlayTitle)

        val spinner = ProgressBar(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dpToPx(24)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                indeterminateTintList = android.content.res.ColorStateList.valueOf(Color.parseColor("#00ADB5"))
            }
        }
        dashboardOverlay.addView(spinner)

        statusText = TextView(this).apply {
            text = "Klonkt en Termux opstarten in de achtergrond..."
            setTextColor(Color.WHITE)
            textSize = 15f
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.2f)
            setPadding(0, 0, 0, dpToPx(32))
        }
        dashboardOverlay.addView(statusText)

        // Buttons in overlay
        val overlayButtons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            gravity = Gravity.CENTER
        }

        val startTermuxBtn = TextView(this).apply {
            text = "START TERMUX"
            setTextColor(Color.WHITE)
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dpToPx(16), dpToPx(12), dpToPx(16), dpToPx(12))
            background = GradientDrawable().apply {
                cornerRadius = dpToPx(6).toFloat()
                setColor(Color.parseColor("#1E1E1E"))
                setStroke(dpToPx(1), Color.parseColor("#33FFFFFF"))
            }
            setOnClickListener {
                startServerInTermux()
            }
        }
        overlayButtons.addView(startTermuxBtn)

        val overlaySpacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(dpToPx(16), ViewGroup.LayoutParams.MATCH_PARENT)
        }
        overlayButtons.addView(overlaySpacer)

        val configBtn = TextView(this).apply {
            text = "INSTELLINGEN"
            setTextColor(Color.BLACK)
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dpToPx(16), dpToPx(12), dpToPx(16), dpToPx(12))
            background = GradientDrawable().apply {
                cornerRadius = dpToPx(6).toFloat()
                setColor(Color.parseColor("#00ADB5"))
            }
            setOnClickListener {
                showSettingsDialog()
            }
        }
        overlayButtons.addView(configBtn)

        dashboardOverlay.addView(overlayButtons)
        contentFrame.addView(dashboardOverlay)

        rootLayout.addView(contentFrame)
        setContentView(rootLayout)

        // Trigger copying of offline installation ZIP and script using version code check
        thread {
            try {
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val currentVersionCode = try {
                    val pInfo = packageManager.getPackageInfo(packageName, 0)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        pInfo.longVersionCode
                    } else {
                        pInfo.versionCode.toLong()
                    }
                } catch (e: Exception) {
                    0L
                }
                
                val savedVersionCode = prefs.getLong(KEY_SAVED_VERSION_CODE, -1L)
                
                if (currentVersionCode != savedVersionCode) {
                    runOnUiThread {
                        statusText.text = "Klonkt installatiebestanden kopiëren naar Download map..."
                    }
                    val successZip = copyAssetToDownloads(this@MainActivity, "klonkt-node.zip", "application/zip")
                    val successScript = copyAssetToDownloads(this@MainActivity, "setup-termux-klonkt.sh", "application/x-sh")
                    
                    runOnUiThread {
                        if (successZip && successScript) {
                            prefs.edit().putLong(KEY_SAVED_VERSION_CODE, currentVersionCode).apply()
                            Toast.makeText(this@MainActivity, "Bestanden gekopieerd naar Download map!", Toast.LENGTH_LONG).show()
                            restartAppLogic()
                        } else {
                            Toast.makeText(this@MainActivity, "Kopiëren mislukt. Zorg voor opslagtoegang.", Toast.LENGTH_LONG).show()
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // Start polling and loading directly (auto-start is removed to prevent background start errors on Android 14+)
        startPollingThread()
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }

    private fun getSavedPort(): String {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString(KEY_PORT, "3020") ?: "3020"
    }

    private fun getSavedCommand(): String {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString(KEY_COMMAND, DEFAULT_COMMAND) ?: DEFAULT_COMMAND
    }

    private fun saveSettings(port: String, command: String) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        editor.putString(KEY_PORT, port)
        editor.putString(KEY_COMMAND, command)
        editor.apply()
    }

    private fun copyAssetToDownloads(context: Context, assetFileName: String, mimeType: String): Boolean {
        try {
            val resolver = context.contentResolver
            
            // Delete existing duplicate file to keep it clean
            val projection = arrayOf(android.provider.MediaStore.MediaColumns._ID)
            val selection = "${android.provider.MediaStore.MediaColumns.DISPLAY_NAME} = ?"
            val selectionArgs = arrayOf(assetFileName)
            val queryUri = android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI
            
            resolver.query(queryUri, projection, selection, selectionArgs, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(android.provider.MediaStore.MediaColumns._ID))
                    val deleteUri = android.content.ContentUris.withAppendedId(queryUri, id)
                    resolver.delete(deleteUri, null, null)
                }
            }

            val contentValues = android.content.ContentValues().apply {
                put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, assetFileName)
                put(android.provider.MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, android.os.Environment.DIRECTORY_DOWNLOADS)
            }

            val uri = resolver.insert(android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues) ?: return false
            resolver.openOutputStream(uri)?.use { outputStream ->
                context.assets.open(assetFileName).use { inputStream ->
                    inputStream.copyTo(outputStream)
                }
            }
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    private fun startServerInTermux() {
        val port = getSavedPort()
        var command = getSavedCommand()
        
        // Dynamically replace default port in command if changed in settings
        if (command.contains("localhost:3020") && port != "3020") {
            command = command.replace("localhost:3020", "localhost:$port")
        }

        val intent = Intent().apply {
            component = ComponentName("com.termux", "com.termux.app.RunCommandService")
            action = "com.termux.RUN_COMMAND"
            putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/bash")
            putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf("-c", command))
            putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
            putExtra("com.termux.RUN_COMMAND_SESSION_ACTION", "1")
        }
        try {
            startService(intent)
            Toast.makeText(this, "Termux-commando verzonden...", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            e.printStackTrace()
            
            val stackTrace = android.util.Log.getStackTraceString(e)
            val dialogBuilder = AlertDialog.Builder(this)
            dialogBuilder.setTitle("Opstartfout (Android Beveiliging)")
            
            val container = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dpToPx(16), dpToPx(16), dpToPx(16), dpToPx(16))
            }
            
            val errorMsg = TextView(this).apply {
                text = "Android blokkeert het opstarten van de Termux service.\nGeef Termux 'Weergeven over andere apps' permissie of bekijk de foutmelding hieronder:"
                setTextColor(Color.BLACK)
                setPadding(0, 0, 0, dpToPx(16))
            }
            container.addView(errorMsg)
            
            val scrollView = android.widget.ScrollView(this).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    dpToPx(200)
                )
            }
            
            val errorText = EditText(this).apply {
                setText(stackTrace)
                setTextColor(Color.RED)
                textSize = 10f
                typeface = Typeface.MONOSPACE
                isFocusable = false
                isClickable = true
                isLongClickable = true
                setTextIsSelectable(true)
                background = null
            }
            scrollView.addView(errorText)
            container.addView(scrollView)
            
            dialogBuilder.setView(container)
            
            dialogBuilder.setPositiveButton("Kopieer Log") { _, _ ->
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                val clip = android.content.ClipData.newPlainText("Klonkt Error", stackTrace)
                clipboard.setPrimaryClip(clip)
                Toast.makeText(this, "Log gekopieerd naar klembord!", Toast.LENGTH_LONG).show()
            }
            dialogBuilder.setNegativeButton("Sluiten", null)
            
            dialogBuilder.show()
        }
    }

    private fun restartAppLogic() {
        dashboardOverlay.visibility = View.VISIBLE
        statusText.text = "Klonkt en Termux opnieuw opstarten..."
        statusLight.background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.parseColor("#FFC107"))
        }
        statusLabel.text = "BOOTING"

        startPollingThread()
    }

    private fun startPollingThread() {
        val sessionId = ++pollingSessionId
        val port = getSavedPort()
        
        thread {
            var connected = false
            var attempts = 0
            
            try {
                val url = URL("http://127.0.0.1:$port")
                while (!connected && attempts < 35 && sessionId == pollingSessionId) {
                    var connection: HttpURLConnection? = null
                    try {
                        connection = url.openConnection() as HttpURLConnection
                        connection.connectTimeout = 1000
                        connection.readTimeout = 1000
                        connection.requestMethod = "GET"
                        val responseCode = connection.responseCode
                        connected = true
                    } catch (t: Throwable) {
                        // Offline
                    } finally {
                        connection?.disconnect()
                    }
                    
                    if (!connected && sessionId == pollingSessionId) {
                        attempts++
                        try {
                            Thread.sleep(1500)
                        } catch (ie: InterruptedException) {
                            break
                        }
                    }
                }
            } catch (t: Throwable) {
                t.printStackTrace()
            }
            
            if (sessionId == pollingSessionId) {
                runOnUiThread {
                    if (connected) {
                        dashboardOverlay.visibility = View.GONE
                        statusLight.background = GradientDrawable().apply {
                            shape = GradientDrawable.OVAL
                            setColor(Color.parseColor("#4CAF50"))
                        }
                        statusLabel.text = "ONLINE"
                        webView.loadUrl("http://127.0.0.1:$port")
                    } else {
                        statusLight.background = GradientDrawable().apply {
                            shape = GradientDrawable.OVAL
                            setColor(Color.parseColor("#F44336"))
                        }
                        statusLabel.text = "OFFLINE"
                        statusText.text = "Kan geen verbinding maken met de Klonkt server op poort $port.\n\n" +
                                "Zorg ervoor dat:\n" +
                                "1. Termux is geïnstalleerd en draait.\n" +
                                "2. Klonkt is geïnstalleerd in Termux (`~/klonkt-node`).\n" +
                                "3. De Node.js server draait via `npm start`."
                    }
                }
            }
        }
    }

    private fun showSettingsDialog() {
        val builder = AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog)
        builder.setTitle("Klonkt Instellingen")

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(24), dpToPx(16), dpToPx(24), dpToPx(16))
        }

        val portLabel = TextView(this).apply {
            text = "Server Poort"
            setTextColor(Color.WHITE)
            textSize = 14f
        }
        container.addView(portLabel)

        val portInput = EditText(this).apply {
            setText(getSavedPort())
            inputType = InputType.TYPE_CLASS_NUMBER
            setTextColor(Color.WHITE)
        }
        container.addView(portInput)

        val commandLabel = TextView(this).apply {
            text = "Termux Start Commando"
            setTextColor(Color.WHITE)
            textSize = 14f
            setPadding(0, dpToPx(12), 0, 0)
        }
        container.addView(commandLabel)

        val commandInput = EditText(this).apply {
            setText(getSavedCommand())
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
            setTextColor(Color.WHITE)
        }
        container.addView(commandInput)

        builder.setView(container)

        builder.setPositiveButton("Opslaan") { _, _ ->
            val newPort = portInput.text.toString().trim()
            val newCommand = commandInput.text.toString().trim()

            if (newPort.isEmpty() || newCommand.isEmpty()) {
                Toast.makeText(this, "Velden mogen niet leeg zijn", Toast.LENGTH_SHORT).show()
            } else {
                saveSettings(newPort, newCommand)
                Toast.makeText(this, "Instellingen opgeslagen", Toast.LENGTH_SHORT).show()
                restartAppLogic()
            }
        }

        builder.setNegativeButton("Annuleren") { dialog, _ ->
            dialog.cancel()
        }

        builder.show()
    }

    override fun onBackPressed() {
        if (::webView.isInitialized && webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }
}
