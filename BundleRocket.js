/**
 * @file BundleRocket.js
 * @author
 */

import {
    AcquisitionManager as Sdk
} from 'code-push/script/acquisition-sdk';

import {
    Alert
} from 'react-native';
import requestFetchAdapter from './request-fetch-adapter';
import semver from 'semver';

let NativeBundleRocket = require('react-native').NativeModules.BundleRocket;
const PackageMixins = require('./package-mixins')(NativeBundleRocket);

/* eslint-disable no-console */

let BundleRocket;

var testConfig;

const getConfiguration = (() => {
    let config;
    return async function getConfiguration() {
        if (config) {
            return config;
        }

        if (testConfig) {
            return testConfig;
        }

        config = await NativeBundleRocket.getConfiguration();
        return config;

    };
})();

async function checkForUpdate(deploymentKey = null) {
    /*
     * Before we ask the server if an update exists, we
     * need to retrieve three pieces of information from the
     * native side: deployment key, app version (e.g. 1.0.1)
     * and the hash of the currently running update (if there is one).
     * This allows the client to only receive updates which are targetted
     * for their specific deployment and version and which are actually
     * different from the BundleRocket update they have already installed.
     */
    const nativeConfig = await getConfiguration();

    /*
     * If a deployment key was explicitly provided,
     * then let's override the one we retrieved
     * from the native-side of the app. This allows
     * dynamically 'redirecting' end-users at different
     * deployments (e.g. an early access deployment for insiders).
     */
    const config = deploymentKey ? {
        ...nativeConfig,
        ... {
            deploymentKey
        }
    } : nativeConfig;
    const sdk = getPromisifiedSdk(requestFetchAdapter, config);

    // Use dynamically overridden getCurrentPackage() during tests.
    const localPackage = await module.exports.getCurrentPackage();

    /*
     * If the app has a previously installed update, and that update
     * was targetted at the same app version that is currently running,
     * then we want to use its package hash to determine whether a new
     * release has been made on the server. Otherwise, we only need
     * to send the app version to the server, since we are interested
     * in any updates for current app store version, regardless of hash.
     */
    const queryPackage = localPackage && localPackage.appVersion
        && semver.compare(localPackage.appVersion, config.appVersion) === 0
        ? localPackage
        : {
            appVersion: config.appVersion
        };
    const update = await sdk.queryUpdateWithCurrentPackage(queryPackage);

    /*
     * There are three cases where checkForUpdate will resolve to null:
     * ----------------------------------------------------------------
     * 1) The server said there isn't an update. This is the most common case.
     * 2) The server said there is an update but it requires a newer binary version.
     *    This would occur when end-users are running an older app store version than
     *    is available, and BundleRocket is making sure they don't get an update that
     *    potentially wouldn't be compatible with what they are running.
     * 3) The server said there is an update, but the update's hash is the same as
     *    the currently running update. This should _never_ happen, unless there is a
     *    bug in the server, but we're adding this check just to double-check that the
     *    client app is resilient to a potential issue with the update check.
     */
    if (!update || update.updateAppVersion || (update.packageHash === localPackage.packageHash)) {
        return null;
    }

    const remotePackage = {
        ...update,
        ...PackageMixins.remote
    };
    remotePackage.failedInstall = await NativeBundleRocket.isFailedUpdate(remotePackage.packageHash);
    return remotePackage;

}

async function getCurrentPackage() {
    const localPackage = await NativeBundleRocket.getCurrentPackage();
    localPackage.failedInstall = await NativeBundleRocket.isFailedUpdate(localPackage.packageHash);
    localPackage.isFirstRun = await NativeBundleRocket.isFirstRun(localPackage.packageHash);
    return localPackage;
}

function getPromisifiedSdk(requestFetchAdapter, config) {
    // Use dynamically overridden AcquisitionSdk during tests.
    const sdk = new module.exports.AcquisitionSdk(requestFetchAdapter, config);
    sdk.queryUpdateWithCurrentPackage = (queryPackage) => {
        return new Promise((resolve, reject) => {
            module.exports.AcquisitionSdk.prototype.queryUpdateWithCurrentPackage.call(
                sdk, queryPackage, (err, update) => {
                    if (err) {
                        reject(err);
                    }
                    else {
                        resolve(update);
                    }
                }
            );
        });
    };

    return sdk;
}

/* Logs messages to console with the [BundleRocket] prefix */
function log(message) {
    console.log(`[BundleRocket] ${message}`);
}

function restartApp(onlyIfUpdateIsPending = false) {
    NativeBundleRocket.restartApp(onlyIfUpdateIsPending);
}

// This function is only used for tests. Replaces the default SDK, configuration and native bridge
function setUpTestDependencies(testSdk, providedTestConfig, testNativeBridge) {
    if (testSdk) {
        module.exports.AcquisitionSdk = testSdk;
    }
    if (providedTestConfig) {
        testConfig = providedTestConfig;
    }
    if (testNativeBridge) {
        NativeBundleRocket = testNativeBridge;
    }
}

/*
 * The sync method provides a simple, one-line experience for
 * incorporating the check, download and application of an update.
 *
 * It simply composes the existing API methods together and adds additional
 * support for respecting mandatory updates, ignoring previously failed
 * releases, and displaying a standard confirmation UI to the end-user
 * when an update is available.
 */
async function sync(options = {}, syncStatusChangeCallback, downloadProgressCallback) {
    const syncOptions = {

        deploymentKey: null,
        ignoreFailedUpdates: true,
        installMode: BundleRocket.InstallMode.ON_NEXT_RESTART,
        updateDialog: null,

        ...options
    };

    syncStatusChangeCallback = typeof syncStatusChangeCallback === 'function'
        ? syncStatusChangeCallback
        : (syncStatus) => {
            switch (syncStatus) {
                case BundleRocket.SyncStatus.CHECKING_FOR_UPDATE:
                    log('Checking for update.');
                    break;
                case BundleRocket.SyncStatus.AWAITING_USER_ACTION:
                    log('Awaiting user action.');
                    break;
                case BundleRocket.SyncStatus.DOWNLOADING_PACKAGE:
                    log('Downloading package.');
                    break;
                case BundleRocket.SyncStatus.INSTALLING_UPDATE:
                    log('Installing update.');
                    break;
                case BundleRocket.SyncStatus.UP_TO_DATE:
                    log('App is up to date.');
                    break;
                case BundleRocket.SyncStatus.UPDATE_IGNORED:
                    log('User cancelled the update.');
                    break;
                case BundleRocket.SyncStatus.UPDATE_INSTALLED:
                    /*
                     * If the install mode is IMMEDIATE, this will not get returned as the
                     * app will be restarted to a new Javascript context.
                     */
                    if (syncOptions.installMode === BundleRocket.InstallMode.ON_NEXT_RESTART) {
                        log('Update is installed and will be run on the next app restart.');
                    }
                    else {
                        log('Update is installed and will be run when the app next resumes.');
                    }
                    break;
                case BundleRocket.SyncStatus.UNKNOWN_ERROR:
                    log('An unknown error occurred.');
                    break;
            }
        };

    downloadProgressCallback = typeof downloadProgressCallback === 'function'
        ? downloadProgressCallback : (downloadProgress) => {
            log(`Expecting ${downloadProgress.totalBytes} bytes, received ${downloadProgress.receivedBytes} bytes.`);
        };

    try {
        await BundleRocket.notifyApplicationReady();

        syncStatusChangeCallback(BundleRocket.SyncStatus.CHECKING_FOR_UPDATE);
        const remotePackage = await checkForUpdate(syncOptions.deploymentKey);

        const doDownloadAndInstall = async() => {
            syncStatusChangeCallback(BundleRocket.SyncStatus.DOWNLOADING_PACKAGE);
            const localPackage = await remotePackage.download(downloadProgressCallback);

            syncStatusChangeCallback(BundleRocket.SyncStatus.INSTALLING_UPDATE);
            await localPackage.install(syncOptions.installMode, () => {
                syncStatusChangeCallback(BundleRocket.SyncStatus.UPDATE_INSTALLED);
            });

            return BundleRocket.SyncStatus.UPDATE_INSTALLED;
        };

        if (!remotePackage || (remotePackage.failedInstall && syncOptions.ignoreFailedUpdates)) {
            syncStatusChangeCallback(BundleRocket.SyncStatus.UP_TO_DATE);
            return BundleRocket.SyncStatus.UP_TO_DATE;
        }

        if (syncOptions.updateDialog) {

            // updateDialog supports any truthy value (e.g. true, 'goo', 12),
            // but we should treat a non-object value as just the default dialog
            if (typeof syncOptions.updateDialog !== 'object') {
                syncOptions.updateDialog = BundleRocket.DEFAULT_UPDATE_DIALOG;
            }
            else {
                syncOptions.updateDialog = {
                    ...BundleRocket.DEFAULT_UPDATE_DIALOG,
                    ...syncOptions.updateDialog
                };
            }

            return await new Promise((resolve, reject) => {
                let message = null;
                const dialogButtons = [{
                    text: null,
                    onPress: async() => {
                        resolve(await doDownloadAndInstall());
                    }
                }];

                if (remotePackage.isMandatory) {
                    message = syncOptions.updateDialog.mandatoryUpdateMessage;
                    dialogButtons[0].text = syncOptions.updateDialog.mandatoryContinueButtonLabel;
                }
                else {
                    message = syncOptions.updateDialog.optionalUpdateMessage;
                    dialogButtons[0].text = syncOptions.updateDialog.optionalInstallButtonLabel;
                    // Since this is an optional update, add another button
                    // to allow the end-user to ignore it
                    dialogButtons.push({
                        text: syncOptions.updateDialog.optionalIgnoreButtonLabel,
                        onPress: () => {
                            syncStatusChangeCallback(BundleRocket.SyncStatus.UPDATE_IGNORED);
                            resolve(BundleRocket.SyncStatus.UPDATE_IGNORED);
                        }
                    });
                }

                // If the update has a description, and the developer
                // explicitly chose to display it, then set that as the message
                if (syncOptions.updateDialog.appendReleaseDescription && remotePackage.description) {
                    message += `${syncOptions.updateDialog.descriptionPrefix} ${remotePackage.description}`;
                }

                syncStatusChangeCallback(BundleRocket.SyncStatus.AWAITING_USER_ACTION);
                Alert.alert(syncOptions.updateDialog.title, message, dialogButtons);
            });
        }

        return await doDownloadAndInstall();

    }
    catch (error) {
        syncStatusChangeCallback(BundleRocket.SyncStatus.UNKNOWN_ERROR);
        log(error.message);
        throw error;
    }
}

BundleRocket = {
    AcquisitionSdk: Sdk,
    checkForUpdate,
    getConfiguration,
    getCurrentPackage,
    log,
    notifyApplicationReady: NativeBundleRocket.notifyApplicationReady,
    restartApp,
    setUpTestDependencies,
    sync,
    InstallMode: {
        IMMEDIATE: NativeBundleRocket.codePushInstallModeImmediate, // Restart the app immediately
        ON_NEXT_RESTART: NativeBundleRocket.codePushInstallModeOnNextRestart, // Don't artificially restart the app. Allow the update to be 'picked up' on the next app restart
        ON_NEXT_RESUME: NativeBundleRocket.codePushInstallModeOnNextResume // Restart the app the next time it is resumed from the background
    },
    SyncStatus: {
        CHECKING_FOR_UPDATE: 0,
        AWAITING_USER_ACTION: 1,
        DOWNLOADING_PACKAGE: 2,
        INSTALLING_UPDATE: 3,
        UP_TO_DATE: 4, // The running app is up-to-date
        UPDATE_IGNORED: 5, // The app had an optional update and the end-user chose to ignore it
        UPDATE_INSTALLED: 6, // The app had an optional/mandatory update that was successfully downloaded and is about to be installed.
        UNKNOWN_ERROR: -1
    },
    DEFAULT_UPDATE_DIALOG: {
        appendReleaseDescription: false,
        descriptionPrefix: ' Description: ',
        mandatoryContinueButtonLabel: 'Continue',
        mandatoryUpdateMessage: 'An update is available that must be installed.',
        optionalIgnoreButtonLabel: 'Ignore',
        optionalInstallButtonLabel: 'Install',
        optionalUpdateMessage: 'An update is available. Would you like to install it?',
        title: 'Update available'
    }
};

module.exports = BundleRocket;
