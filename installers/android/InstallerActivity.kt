package installers.android;

import android.app.ProgressDialog;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.view.View;
import android.widget.Button;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.FileProvider;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;

public class InstallerActivity extends AppCompatActivity {

    private Button installButton;
    private Button checkUpdatesButton;
    private ProgressDialog progressDialog;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_installer);

        installButton = findViewById(R.id.installButton);
        checkUpdatesButton = findViewById(R.id.checkUpdatesButton);

        installButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                downloadApk("http://example.com/app.apk");
            }
        });

        checkUpdatesButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                // Check for updates logic
                Toast.makeText(InstallerActivity.this, "Checking for updates...", Toast.LENGTH_SHORT).show();
            }
        });
    }

    private void downloadApk(String apkUrl) {
        progressDialog = new ProgressDialog(this);
        progressDialog.setMessage("Downloading APK...");
        progressDialog.setCancelable(false);
        progressDialog.show();

        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    URL url = new URL(apkUrl);
                    HttpURLConnection connection = (HttpURLConnection) url.openConnection();
                    connection.setRequestMethod("GET");
                    connection.setDoOutput(true);
                    connection.connect();

                    File apkFile = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "app.apk");
                    FileOutputStream fos = new FileOutputStream(apkFile);
                    InputStream is = connection.getInputStream();

                    byte[] buffer = new byte[1024];
                    int length;
                    while ((length = is.read(buffer)) != -1) {
                        fos.write(buffer, 0, length);
                    }
                    fos.close();
                    is.close();

                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            progressDialog.dismiss();
                            installApk(apkFile);
                        }
                    });
                } catch (Exception e) {
                    e.printStackTrace();
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            progressDialog.dismiss();
                            Toast.makeText(InstallerActivity.this, "Download failed!", Toast.LENGTH_SHORT).show();
                        }
                    });
                }
            }
        }).start();
    }

    private void installApk(File apkFile) {
        Intent intent = new Intent(Intent.ACTION_VIEW);
        intent.setDataAndType(FileProvider.getUriForFile(this, "your.package.name.fileprovider", apkFile), "application/vnd.android.package-archive");
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(intent);
    }
}
