# 四级背单词 (memimo)

一个本地优先的四级背单词 Android App，内置 **艾宾浩斯遗忘曲线**（默认）与 **SM-2** 两套记忆算法，可随时切换。

## 安装

APK 位置：`D:\Minecraft\输出\四级背单词-v1.6.0.apk`（约 76MB，含发音）

安装方法（任选）：

**A. 数据线传到手机**
1. 手机连电脑，选择"传输文件"
2. 把 APK 复制到手机任意目录
3. 手机上用文件管理器打开 APK → 允许"安装未知应用" → 安装

**B. 微信/QQ 传**
1. 把 APK 发到"文件传输助手"或自己的 QQ
2. 手机上下载 → 点击安装

**C. adb 安装（手机开启 USB 调试）**
```
D:\Minecraft\dev-tools\android-sdk\platform-tools\adb.exe install -r "D:\Minecraft\输出\四级背单词-v1.2.apk"
```

> 系统要求：Android 7.0 (API 24) 及以上

## 版本历史

| 版本 | 变化 |
|---|---|
| v1.0 | 基础版：词库 + SM-2 记忆算法 + 学习/词库/统计/设置 |
| v1.1 | 新增单词发音（3739 词，SAPI 离线合成） |
| v1.2 | 新增「检查更新」功能；音频压缩优化（300MB→75.8MB） |
| v1.3 | 新增「随机抽取」：每日新词伪随机打乱抽取，首页可直接重抽 |
| v1.3.1 | 更新检查增加诊断信息；修复网络失败误报「已是最新」 |
| v1.3.2 | 修复 release 包缺少 INTERNET 权限导致无法联网 |
| v1.3.3 | 更新源切换为 GitHub Releases + jsDelivr 双源 |
| v1.4.0 | 大量 UI 细节优化，单词详情页增强 |
| v1.4.1 | 修复更新下载链接，默认走 ghproxy 镜像 |
| v1.4.2 | 稳定性修复 |
| v1.5.0 | 新增主题色切换：松绿/海蓝/墨紫/暖橙/玫红/石墨 六套配色 |
| v1.6.0 | 新增艾宾浩斯遗忘曲线（默认），12 级固定复习时间表；设置页可切换算法；统计页加遗忘曲线分布 |

## 记忆算法

### 艾宾浩斯遗忘曲线（默认）

每个词有一个「阶段」，阶段决定下次何时复习。间隔表由密到疏：

| 阶段 | 间隔 | 说明 |
|---|---|---|
| 1 | 10 分钟 | 刚学完，马上巩固 |
| 2 | 12 小时 | 当天回看或睡前过一遍 |
| 3 | 1 天 | 隔天复习 |
| 4 | 2 天 | 短间隔巩固 |
| 5 | 4 天 | 一周内最后一轮 |
| 6 | 7 天 | 满一周 |
| 7 | 15 天 | 半个月 |
| 8 | 30 天 | 满一个月，进入中期记忆 |
| 9 | 60 天 | 两个月 |
| 10 | 120 天 | 四个月 |
| 11 | 180 天 | 半年 |
| 12 | 1 年 | 已转为长期记忆 |

评分如何影响阶段：

| 选择 | 变化 |
|---|---|
| 忘记 | 回到第 1 级，整条曲线重走 |
| 模糊 | 退一级，下次来得更早 |
| 一般 | 原地不动，同一间隔再巩固一次 |
| 熟悉 | 前进一级 |
| 秒杀 | 前进两级（很熟的词不用陪跑） |

新词第一次评价时，除「忘记 / 模糊」外统一进入第 2 级（12 小时），
保证当天至少回看一次，不会被一上来就推到两天后。

「已掌握」= 走到第 8 级（30 天）及以后。

### SM-2 自适应

按每个词的难度因子（EF）动态计算间隔，背得快的词间隔拉得更开。
「已掌握」= 连续答对 3 次且间隔 ≥ 21 天。

> 两套算法写入不同的字段（艾宾浩斯用 `stage`，SM-2 用 `repetitions`/`easeFactor`），
> 互相不覆盖，随时切换都不会丢进度。老数据切到艾宾浩斯时，会按 SM-2 的历史
> 自动换算成等效阶段，且**不改动已有的到期时间**，不会突然冒出一堆待复习词。

## 更新功能（GitHub API + jsDelivr 双源）

App 依次尝试两个更新源，第一个成功的生效（已彻底移除 Netlify）：

1. **GitHub Releases API**（主源，带备用 IP 兜底 DNS 故障）
   `https://api.github.com/repos/acory0212/memimo-android/releases/latest`
2. **jsDelivr CDN**（备源，国内可直连，读取仓库里的 `version.json`）
   `https://cdn.jsdelivr.net/gh/acory0212/memimo-android@main/version.json`

设置页「检查更新」会显示诊断信息（当前版本、各源结果、线上版本），
另有「网络诊断」可单独查看 DNS 解析和 IP 可达性。

> **重要**：release 包必须在 `android/app/src/main/AndroidManifest.xml` 里显式声明
> `<uses-permission android:name="android.permission.INTERNET"/>`。
> Flutter 只在 debug/profile 包里自动加这个权限，正式包不加就会导致所有联网失败
> （表现为 `Failed host lookup ... errno = 7`，连直连 IP 也失败）。

### 发布新版本流程

```powershell
# 环境
$env:Path = "D:\Minecraft\dev-tools\gh\bin;D:\Minecraft\dev-tools\git\cmd;$env:Path"
$env:GH_CONFIG_DIR = "D:\Minecraft\dev-tools\gh\config"
$env:HTTPS_PROXY = ""
$env:HTTP_PROXY = ""

# 1. 改版本号（三处）
#    pubspec.yaml:              version: 1.5.0+7
#    android/local.properties:  flutter.versionName=1.5.0 / flutter.versionCode=7
#    version.json:              version / download_url / release_notes
# 2. 构建
cd D:\Minecraft\meme-app\android; .\gradlew.bat assembleRelease
# 3. 发布到 GitHub Release
cd D:\Minecraft\meme-app
gh release create v1.5.0 "D:\Minecraft\输出\四级背单词-v1.5.apk" --title "v1.5.0" --notes "更新说明"
# 4. 提交 version.json（jsDelivr 备源从仓库读取，push 后约 10 分钟生效）
git add version.json README.md
git commit -m "chore: version.json 更新到 1.5.0"
git push
```

> 大文件上传别走代理，直连 uploads.github.com 最快：
> ```
> curl --noproxy "*" -X POST -H "Authorization: Bearer <token>" `
>   -H "Content-Type: application/octet-stream" --data-binary @apk `
>   "https://uploads.github.com/repos/acory0212/memimo-android/releases/<id>/assets?name=xxx.apk"
> ```

## 功能

- **3739 个四级词**（有道 CET4 正序词书）：音标、中英释义、例句、真题例句、短语、近反义词、词根助记
- **随机抽取新词**：每日新词从全词库伪随机打乱后抽取，避免从 A 背到 Z 的枯燥；同一天结果稳定，可随时重抽
- **单词发音**：3739 词全覆盖，离线播放（Microsoft Zira 美式女声合成）
- **SM-2 间隔重复算法**：5 档评分（忘记/模糊/一般/熟悉/秒杀），自动计算下次复习时间
- **每日计划**：可设每日新词上限（5-100）和学习目标时长（0.5-4 小时）
- **词库管理**：搜索、已学/未学/收藏/错题筛选
- **学习统计**：累计已学、已掌握、连续打卡、14 天柱状图
- **错题本 + 收藏**
- **完全离线**：数据存本机，不联网、不上传

## 代码结构

```
lib/
├── main.dart                    入口 + 主题
├── models/word.dart             单词数据模型
├── services/
│   ├── sm2.dart                 SM-2 记忆算法
│   └── store.dart               本地存储 / 学习队列 / 统计
└── screens/
    ├── home_screen.dart         今日（首页）
    ├── learn_screen.dart        学习卡片（核心界面）
    ├── wordbook_screen.dart     词库列表
    ├── word_detail_screen.dart  单词详情
    ├── stats_screen.dart        统计
    └── settings_screen.dart     设置
assets/data/words_cet4.json      3739 词词库（2.15MB）
```

## 记忆算法说明

采用 SM-2 变体，评分映射到 SM-2 的 q 值：

| 按钮 | q 值 | 行为 |
|---|---|---|
| 忘记 | 0 | 重置，10 分钟后再次出现 |
| 模糊 | 2 | 不推进，约 1 小时后出现 |
| 一般 | 3 | 首次 12 小时，之后间隔 × 难度因子 |
| 熟悉 | 4 | 首次 1 天，之后间隔 × 难度因子 |
| 秒杀 | 5 | 同上，但难度因子提升更多 |

难度因子（EF）初始 2.5，最小 1.3。间隔上限 365 天。
"已掌握"定义：复习 ≥ 3 次且间隔 ≥ 21 天。

## 重新构建

```powershell
$env:JAVA_HOME = "D:\Minecraft\dev-tools\jdk17"
$env:ANDROID_HOME = "D:\Minecraft\dev-tools\android-sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_USER_HOME = "D:\Minecraft\dev-tools\android-home"
$env:GRADLE_USER_HOME = "D:\Minecraft\dev-tools\gradle-home"
$env:FLUTTER_ROOT = "D:\Minecraft\dev-tools\flutter"
$env:TEMP = "D:\Minecraft\dev-tools\temp"; $env:TMP = $env:TEMP
$env:APPDATA = "D:\Minecraft\dev-tools\appdata\Roaming"
$env:LOCALAPPDATA = "D:\Minecraft\dev-tools\appdata\Local"
$env:Path = "D:\Minecraft\dev-tools\flutter\bin;D:\Minecraft\dev-tools\git\cmd;" +
            "D:\Minecraft\dev-tools\jdk17\bin;" + $env:Path

cd D:\Minecraft\meme-app\android
.\gradlew.bat assembleRelease
```

产物：`D:\Minecraft\meme-app\build\app\outputs\flutter-apk\app-release.apk`

## 已知限制

- 只有四级一本书，暂不支持导入其他词书
- 没有发音播放（需要音频资源，涉及版权）
- 没有云同步（纯本地）
- APK 使用 debug 签名，仅供自用；如需上架需配置正式签名
