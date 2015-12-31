/**
 * @file package-mixins.js
 * @author
 */

import {
    DeviceEventEmitter
} from 'react-native';

// This function is used to augment remote and local
// package objects with additional functionality/properties
// beyond what is included in the metadata sent by the server.
module.exports = (NativeBundleRocket) => {
    const remote = {
        async download(downloadProgressCallback) {
            if (!this.downloadUrl) {
                throw new Error('Cannot download an update without a download url');
            }

            let downloadProgressSubscription;
            if (downloadProgressCallback) {
                // Use event subscription to obtain download progress.
                downloadProgressSubscription = DeviceEventEmitter.addListener(
                    'BundleRocketDownloadProgress',
                    downloadProgressCallback
                );
            }

            // Use the downloaded package info. Native code will save the package info
            // so that the client knows what the current package version is.
            try {
                const downloadedPackage = await NativeBundleRocket.downloadUpdate(this);
                return {
                    ...downloadedPackage,
                    ...local
                };
            }
            finally {
                downloadProgressSubscription && downloadProgressSubscription.remove();
            }
        },

        isPending: false // A remote package could never be in a pending state
    };

    const local = {
        async install(installMode = NativeBundleRocket.codePushInstallModeOnNextRestart, updateInstalledCallback) {
            const localPackage = this;
            await NativeBundleRocket.installUpdate(this, installMode);
            updateInstalledCallback && updateInstalledCallback();
            if (installMode === NativeBundleRocket.codePushInstallModeImmediate) {
                NativeBundleRocket.restartApp(false);
            }
            else {
                localPackage.isPending = true; // Mark the package as pending since it hasn't been applied yet
            }
        },

        isPending: false // A local package wouldn't be pending until it was installed
    };

    return {
        local,
        remote
    };
};