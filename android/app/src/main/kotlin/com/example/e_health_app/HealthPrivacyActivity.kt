package com.example.e_health_app

import android.app.Activity
import android.app.AlertDialog
import android.os.Bundle

class HealthPrivacyActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AlertDialog.Builder(this)
            .setTitle("Beam health access")
            .setMessage("Beam requests read-only access to steps, heart rate and sleep for wellness insights. You choose which records to share. Beam does not change your Health Connect records. You can revoke access in Health Connect settings.")
            .setPositiveButton("Done") { _, _ -> finish() }
            .setOnCancelListener { finish() }
            .show()
    }
}
