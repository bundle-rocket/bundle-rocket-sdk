/**
 * @file bundle-rocket main
 * @author leon(ludafa@outlook.com)
 */

import {NativeModules} from 'react-native';
import {guid} from './common/util.js';

const {BundleRocket} = NativeModules;

const {
    rootFolderPath
} = BundleRocket;

export async function download({deploymentKey, location, version, shasum}) {

    const toFilePath = `${rootFolderPath}/${version}/bundle.tar.gz`;
    const taskId = guid();

    return BundleRocket.download(location, toFilePath, taskId, shasum);

}

export default {
    rootFolderPath,
    download
};
