// Copyright 2015-present 650 Industries. All rights reserved.

package host.exp.exponent.experience;

import android.content.Intent;
import android.os.Build;
import android.os.Bundle;

import org.json.JSONException;
import org.json.JSONObject;

import host.exp.exponent.AppLoader;
import host.exp.exponent.Constants;
import host.exp.exponent.kernel.ExponentUrls;
import host.exp.exponent.kernel.KernelConstants;
import host.exp.expoview.Exponent;

public class ShellAppActivity extends ExperienceActivity {

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    boolean forceCache = getIntent().getBooleanExtra(KernelConstants.LOAD_FROM_CACHE_KEY, false);

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      mKernel.handleIntent(this, getIntent());
    }

    new AppLoader(Constants.INITIAL_URL, forceCache) {
      @Override
      public void onOptimisticManifest(final JSONObject optimisticManifest) {
        Exponent.getInstance().runOnUiThread(new Runnable() {
          @Override
          public void run() {
            setLoadingScreenManifest(optimisticManifest);
          }
        });
      }

      @Override
      public void onManifestCompleted(final JSONObject manifest) {
        Exponent.getInstance().runOnUiThread(new Runnable() {
          @Override
          public void run() {
            try {
              String bundleUrl = ExponentUrls.toHttp(manifest.getString("bundleUrl"));
              JSONObject opts = new JSONObject();
              opts.put(KernelConstants.OPTION_LOAD_NUX_KEY, false);

              setManifest(Constants.INITIAL_URL, manifest, bundleUrl, opts);
            } catch (JSONException e) {
              mKernel.handleError(e);
            }
          }
        });
      }

      @Override
      public void onBundleCompleted(String localBundlePath) {
        setBundle(localBundlePath);
      }

      @Override
      public void emitEvent(JSONObject params) {
        emitUpdatesEvent(params);
      }

      @Override
      public void onError(Exception e) {
        mKernel.handleError(e);
      }

      @Override
      public void onError(String e) {
        mKernel.handleError(e);
      }
    }.start();
  }

  @Override
  public void onNewIntent(Intent intent) {
    super.onNewIntent(intent);
    mKernel.handleIntent(this, intent);
  }
}