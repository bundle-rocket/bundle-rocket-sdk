# BundleRocket SDK

## 起步

通过下边这条命令安装 bundle-rocket-sdk

```sh
npm install --save bundle-rocket-sdk
```

## iOS

### 安装

1. 打开你的 XCode Project；
2. 找到 node_modules/bundle-rocket/ios 目录中的 BundleRocket.xcodeproj，然后把它拖进XCode 中的 Libraries 目录中；
3. 选中 XCode 项目，在你的项目配置中再选中 `Build Prases` 标签；把 `libBundleRocket.a` 拖到 `Link Binary With Libraries` 区块中；
4. 由于我们使用到 `libz` 库，所以还需要在 `Link Binary With Libraries` 中添加它；点击 `+`，输入 `libz` 添加 `libz.tbd` 最后点击 `Add` 按钮；
5. 在 `Build Settings` 标签下，找到 `Header Search Paths` 区块，编辑它的值；添加一个新的值 `$(SRCROOT)/../node_modules/bundle-rocket-sdk` 并在后边的下拉选项中选择 `recursive`；

### 在代码中引入

1. 打开 `AppDelegate.m` 文件，添加 `BundleRocket` 的头文件

    ```Objective-C
    #import "BundleRocket.h"
    ```
2. 找到这段在生产环境下加载 JS Bundle 文件的代码

    ```Objective-C
    jsCodeLocation = [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
    ```

3. 替换成下边这行：

    ```Objective-C
    jsCodeLocation = [BundleRocket getBundleURL];
    ```

### 配置

我们在运行中需要使用到 bundle-rocket 应用的 `registry` 和 `deploymentKey`；因此，我们需要在 XCode 项目中的 Info.plist 进行设置；

+ BundleRocketRegistry: 请填写你的 `BundleRocket` 服务器地址
+ BundleRocketDeploymentKey：你可以通过 `bundle-rocket-cli` 提供的 `br view your-app-name` 来查询 `deploymentKey`；

> 我们建议使用 SemVer 版本号来管理你的应用
