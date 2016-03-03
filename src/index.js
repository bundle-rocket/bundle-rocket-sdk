/**
 * @file bundle-rocket main
 * @author leon(ludafa@outlook.com)
 */

import {
    NativeModules,
    NativeAppEventEmitter
} from 'react-native';

import {
    guid,
    querystring,
    pick
} from './common/util.js';

const {BundleRocket} = NativeModules;

const {rootFolderPath} = BundleRocket;

/**
 * 获取应用状态
 *
 * @param {...*} args 任意参数
 * @return {Object}
 */
export async function getAppStatusInfo(...args) {
    return BundleRocket.getAppStatusInfo(...args);
}

/**
 * 检测是否有可用的更新包
 *
 * @return {Object}
 */
export async function checkForUpdate() {

    // 获取本地的应用状态
    const {
        appVersion,
        bundleVersion = '0.1.0',
        deploymentKey,
        registry
    } = await getAppStatusInfo();

    const query = {
        appVersion,
        bundleVersion,
        deploymentKey
    };

    const url = `${registry}/bundles?${querystring.stringify(query)}`;

    const resoponse = await fetch(url, {
        method: 'GET'
    });

    const {bundle} = await resoponse.json();

    if (!bundle) {
        return null;
    }

    const {version} = bundle;

    const errorBundles = await BundleRocket.getErrorBundles();

    // 这里做错误版本检测，如果一个更新包在本地被标识为错误版本，那么我们将它过滤掉
    return bundle && errorBundles && errorBundles.indexOf(version) !== -1 ? null : bundle;

}

/**
 * 下载更新包
 *
 * @param  {Object} bundle             更新包数据
 * @param  {string} bundle.version     更新包版本号
 * @param  {string} bundle.shasum      更新包 md5 校验码
 * @param  {Function} progressCallback 更新进度回调函数
 * @return {Promise}
 */
export async function download({location, version, shasum}, progressCallback) {

    const {deploymentKey} = await getAppStatusInfo();

    const taskId = guid();

    const subscription = NativeAppEventEmitter
        .addListener(`BundleRocketDownloadProgress/${taskId}`, progress => {
            const {totalBytesExpected, totalBytesWritten} = progress;
            progressCallback(totalBytesExpected, totalBytesWritten);
        });

    try {
        await BundleRocket.download({
            outputFolderPath: `${rootFolderPath}/${version}`,
            location,
            shasum,
            taskId,
            deploymentKey
        });
        subscription.remove();
    }
    catch (error) {
        subscription.remove();
        throw error;
    }

}

/**
 * 安装模式
 *
 * @type {Object}
 */
export const InstallMode = {

    /**
     * 立即安装
     * @type {Number}
     */
    NOW: 0,

    /**
     * 下次重新启动时安装
     * @type {Number}
     */
    ON_NEXT_RESTART: 1,

    /**
     * 下次进入 active 状态时安装
     * @type {Number}
     */
    ON_NEXT_RESUME: 2
};

/**
 * 安装更新包
 *
 * @param  {Object} bundle      更新包数据
 * @param  {number} installMode 安装模式
 * @return {Promise}
 */
export async function install(bundle, installMode = InstallMode.ON_NEXT_RESUME) {

    const {
        version,
        main
    } = bundle;

    const appStatusInfo = await getAppStatusInfo();

    const nextAppStatusInfo = pick({
        ...appStatusInfo,
        main,
        bundleVersion: version,
        previousBundleVersion: appStatusInfo.bundleVersion || null
    }, function (value) {
        return value != null && value !== '';
    });

    return await BundleRocket.install(nextAppStatusInfo, installMode);

}

export async function notifyApplicationReady() {
    await BundleRocket.notifyApplicationReady();
}

export default {
    rootFolderPath,
    download,
    getAppStatusInfo,
    checkForUpdate,
    notifyApplicationReady,
    install
};
