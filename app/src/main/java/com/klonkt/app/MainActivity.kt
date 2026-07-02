package com.klonkt.app

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.TextView
import android.widget.Toast
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class MainActivity : Activity() {
    private lateinit var webView: WebView
    private lateinit var statusText: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Dynamic layout creation
        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT
            )
        }

        statusText = TextView(this).apply {
            text = "Klonkt en Termux opstarten in de achtergrond..."
            textSize = 16f
            setPadding(30, 30, 30, 30)
        }
        layout.addView(statusText)

        webView = WebView(this).apply {
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    statusText.visibility = android.view.View.GONE
                }
            }
        }
        layout.addView(webView)

        setContentView(layout)

        // Start server in Termux (using external-apps permission)
        startServerInTermux()

        // Poll the local server and load WebView when ready
        thread {
            try {
                waitForServer()
                runOnUiThread {
                    webView.loadUrl("http://127.0.0.1:3020")
                }
            } catch (e: Exception) {
                runOnUiThread {
                    statusText.text = "Kan geen verbinding maken met de Klonkt server.\n\n" +
                            "Zorg ervoor dat:\n" +
                            "1. Termux is geïnstalleerd.\n" +
                            "2. Klonkt is geïnstalleerd in Termux (`~/klonkt-node`).\n" +
                            "3. 'Allow external apps' aan staat in `~/.termux/termux.properties`."
                }
            }
        }
    }

    private fun startServerInTermux() {
        val intent = Intent().apply {
            component = ComponentName("com.termux", "com.termux.app.RunCommandService")
            action = "com.termux.RUN_COMMAND"
            putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/bash")
            putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf("-c", "cd ~/klonkt-node && npm run start & ssh -R 80:localhost:3020 a.pinggy.io"))
            putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
            putExtra("com.termux.RUN_COMMAND_SESSION_ACTION", "1") // Run in background session
        }
        try {
            startService(intent)
        } catch (e: Exception) {
            e.printStackTrace()
            Toast.makeText(this, "Kon Termux-service niet starten.", Toast.LENGTH_LONG).show()
        }
    }

    private fun waitForServer() {
        val url = URL("http://127.0.0.1:3020")
        var connected = false
        var attempts = 0
        while (!connected && attempts < 35) {
            try {
                val connection = url.openConnection() as HttpURLConnection
                connection.connectTimeout = 1000
                connection.readTimeout = 1000
                connection.requestMethod = "GET"
                val responseCode = connection.responseCode
                if (responseCode == 200 || responseCode == 302 || responseCode == 404) {
                    connected = true
                }
            } catch (e: Exception) {
                attempts++
                Thread.sleep(1500)
            }
        }
        if (!connected) {
            throw RuntimeException("Klonkt server reageert niet.")
        }
    }
}
