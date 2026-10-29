# ATV-Bilibili 项目记录

最后更新：2026-10-29
仓库：`/Users/jiaweiding/Documents/ATV-Bilibili-demo`（分支 `feature/ui-customization`）
架构总览见根目录 `AGENTS.md`；本文记录这个 fork 当前的 UI 约定、Tab 栏模型、改动历史和踩过的坑。改 UI 之前先读第 3、4、7 节。

---

## 1. 工程速查

| 项 | 值 |
| --- | --- |
| 平台 | tvOS 16.0+，Swift 5，UIKit（没有 SwiftUI） |
| Bundle ID | `com.etan.tv.BilibiliLive` |
| 模拟器 | Apple TV 4K (3rd gen)，tvOS 27.0，UDID `02006554-B860-4680-AD5F-C97CD1BF8470` |
| 依赖 | Alamofire / SwiftyJSON / SwiftProtobuf / Kingfisher / SnapKit / CocoaLumberjack / CocoaAsyncSocket / Gzip / Swifter（SPM） |
| 发布 | `fastlane build_simulator` / `fastlane build_unsign_ipa`（见 AGENTS.md） |

### 构建、安装、运行

```bash
cd /Users/jiaweiding/Documents/ATV-Bilibili-demo

xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive \
  -destination 'platform=tvOS Simulator,id=02006554-B860-4680-AD5F-C97CD1BF8470' \
  -configuration Debug build

xcrun simctl install 02006554-B860-4680-AD5F-C97CD1BF8470 \
  /Users/jiaweiding/Library/Developer/Xcode/DerivedData/BilibiliLive-chrznfldbjccqihhpiqgodwbejaj/Build/Products/Debug-appletvsimulator/BilibiliLive.app

xcrun simctl launch 02006554-B860-4680-AD5F-C97CD1BF8470 com.etan.tv.BilibiliLive
xcrun simctl io 02006554-B860-4680-AD5F-C97CD1BF8470 screenshot /tmp/shot.png
```

- 截图原始分辨率 3840×2160（2x）。预览按 2000 宽显示时，×1.92 得到原图坐标，÷2 得到 pt。
- 临时调试页面的方式：在 `SceneDelegate.scene(_:willConnectTo:options:)` 里按环境变量 present 目标页，然后用
  `SIMCTL_CHILD_BL_DEBUG_PAGE=xxx xcrun simctl launch ...` 启动。**调试代码用完必须删除，并用 `rg` 确认无残留。**
- 模拟器**不能注入按键**：AppleScript `key code` 会被 tvOS 模拟器忽略；`click at` 不绑定进程会点到别的窗口（曾误点用户的 Chrome）。需要交互验证时，用调试钩子直接构造状态，或让用户手动点。
- SourceKit 偶尔报 `No such module 'UIKit' / 'SnapKit' / 'Kingfisher'`、`Cannot find type 'Settings'`，是索引误报，以 `xcodebuild` 结果为准。
- 本地 shell 的 `rm` 是交互式 alias；脚本里用 `command rm -f`。

### 工作区状态

工作区不是干净的：`git status` 里有大量未提交改动（Feed、播放器插件、Request、Assets 等），部分是本次及之前几轮的 UI 改造。**改任何文件前先 `git diff <file>` 确认当前内容，不要假设文件是干净的。**

---

## 2. 模块地图

```
BilibiliLive/
├── AppDelegate.swift / SceneDelegate.swift   启动、登录态分流、换根
├── Module/
│   ├── Tabbar/        BLTabBarViewController、TabBarPage、TabBarPageFactory、Settings+TabBar
│   ├── Personal/      PersonalViewController（左导航+右内容）、SettingsViewController、
│   │                  TabBarCustomizationViewController、AccountSwitcherViewController、
│   │                  FollowUpsViewController、History/ToView/FollowBangumi…
│   ├── Live/          直播播放、弹幕 WebSocket
│   ├── ViewController/ Feed、热门、排行榜、收藏、UP 空间
│   └── DLNA/          UPnP 投屏
├── Component/
│   ├── View/          BLButton、BLMotionCollectionViewCell、BLSettingLineCollectionViewCell、
│   │                  BLLoadingIndicator、ReplyRowView、UIFont+App
│   ├── Feed/          FeedCollectionViewController / Cell、StandardVideoCollectionViewController
│   ├── Video/         VideoDetailViewController、ReplyDetailViewController、播放器插件
│   └── Player/        CommonPlayerViewController 与插件体系
├── Request/           ApiRequest、WebRequest（MD5 + WBI 签名）、CookieManager
└── Vendor/            DanmakuKit、PocketSVG
```

### 导航关系

- `SceneDelegate`：已登录 → `BLTabBarViewController`；未登录 → `LoginViewController`。
- Tab 栏由 `Settings.tabBarPages` 动态生成，每个页面由 `TabBarPageVCFactory.createVC(for:)` 创建。
- 「我的」是固定 tab（`isFixedInTabBar`），内部是 `PersonalViewController`：左侧 `personalPages` 列表 + 右侧内容。
- 设置页、Tab 自定义页、账号管理都是 modal present。

### 新增一个 Tab 页面的步骤

1. `TabBarPage` 加 case，补 `title` 和 `systemImage`。
2. `TabBarPageFactory` 加对应的 VC。
3. 如果属于导航栏，加进 `TabBarPage.defaultTabBarPages`；否则自动归到「我的页面」（`homeSection` 由这个数组推导）。
4. 需要整页弹出（而不是嵌在右侧内容区）的「我的」页面，把它加进 `requirePresentInPersonalPage`。

Tab 自定义页会自动列出新页面，`Settings.normalize()` 会自动补齐，不需要改别的地方。

---

## 3. 设计系统（tvOS 26 Liquid Glass）

### 玻璃与圆角

- `UIVisualEffectView.makeGlassView(style:cornerRadius:)`（`Extensions/UIView+Layout.swift`）：tvOS 26+ 用 `UIGlassEffect`，低版本回退 `UIBlurEffect`。
- `UIView.setGlassEffectView(cornerRadius:)`：给已有视图加玻璃底。
- **`makeGlassView` 会设 `isUserInteractionEnabled = false`**，不能拿它当容器；需要交互的面板用普通 `UIView` + 玻璃子视图（账号管理页就是这么做的）。
- `BLCornerRadius`：`small 8` / `little 12` / `moreLittle 18` / `normal 25` / `lessBig 34` / `big 45`。面板和 Tab 卡片用 34，列表行胶囊按高度取半径。

### 焦点语言

- 玻璃底 + 聚焦时盖一层 `white 0.95` + 内容转黑；缩放由 `BLMotionCollectionViewCell`（默认 1.1）或自定义（账号卡片 1.06）负责。
- 侧栏、设置行、Tab 卡片、账号卡片、FollowUps 卡片、详情页按钮都是这一套。
- 纯图标按钮（UP 空间那一排）背后没有内容，玻璃在纯黑底上几乎没有边缘，用 `BLButton.restingWhiteAlpha = 0.12` 垫一层淡白。
- 侧栏的白色胶囊有两层含义：焦点在侧栏内时只跟焦点；焦点离开侧栏后交给选中项，作为「当前分区」的锁定标记（`blSetSidebarFocusActive`）。

### 字体（`UIFont.App`）

| 角色 | 样式 | tvOS 默认字号 | 用途 |
| --- | --- | --- | --- |
| `pageTitle` | `.title3` | 48 | 页面大标题 |
| `sectionTitle` | `.footnote` | 29 | 分区标题、提示文字 |
| `rowTitle` | `.callout` | 31 | 列表行、侧栏、Tab 卡片标题 |
| `cardTitle` | `.body` | 29 | Feed 卡片标题 |
| `button` | `.callout` | 31 | 按钮 |
| `body` | `.body` | 29 | 正文、Tab 栏标题 |
| `meta` | `.caption1` | 25 | UP 主、时间、播放量 |
| `badge` | `.caption2` | 23 | 角标 |

原则：选角色，不写 `systemFont(ofSize:)`；要调一档只动一步。固定字号只留给弹幕、播放器 HUD、回复富文本里的 10pt 间隔。

### 各页面关键指标

| 页面 | 指标 |
| --- | --- |
| 侧栏（排行榜/收藏/我的/直播） | 面板宽 300、圆角 34、行高 66、行距 10、内边距 16、文字 30 semibold、图标 26 |
| 设置列表 | 行高 66、行距 14、胶囊圆角 33、白 0.1 底；聚焦白胶囊长到 75、文字转黑、不缩放 |
| Feed 卡片 | 16:9 封面、时长黑胶囊右下、红角标左下、无头像；标题 29 / UP 主 25 + ✓ / `N万播放 · 日期` 25；聚焦不缩放、封面 4pt 白边 |
| Feed 网格 | 卡片对齐安全区（两侧 80）；列距 60、行距 60（用 `section.interGroupSpacing`，不要用 `edgeSpacing` 做行距） |
| Tab 自定义卡片 | 200×140、圆角 34、图标 44（52 方框）、标题 31、间距 10、卡片间距 30 |
| 账号管理 | 面板 1100×600、圆角 34；卡片 300×320、间距 30、左内边距 60；头像 160、缩放 1.06 |
| 视频详情 | 播放按钮宽 240、其余 200；UP 行玻璃高 80、头像 64；推荐/合集用 Feed cell（cardWidth 360） |
| FollowUps | UpCell 玻璃圆角 25、聚焦白 0.95、名字 Marquee |
| 刷新指示器 | 右下角 64pt 玻璃圆点（`BLLoadingIndicator` / `blSetLoading`） |

---

## 4. Tab 栏模型（2026-10-29 定稿）

### 4.1 数据模型

文件：`Module/Tabbar/Settings+TabBar.swift`、`Module/Tabbar/TabBarPage.swift`

```swift
struct TabBarPagePlacement: Codable, Hashable {
    var page: TabBarPage
    var isHidden: Bool = false
    var section: TabBarPageSection { page.homeSection }   // 计算属性，不存储
}
```

- **归属固定**：`TabBarPage.homeSection = defaultTabBarPages.contains(self) ? .tabBar : .personal`。
  - 导航栏 8 个：直播、推荐、热门、排行榜、动态、收藏、我的、搜索。
  - 我的页面 6 个：追番追剧、关注UP、稍后再看、历史记录、每周必看、TV推荐。
- **隐藏是独立开关**：`isHidden` 不影响归属和顺序，卡片留在自定义页原位。
- **消费方**：
  - 导航栏：`Settings.tabBarPages`（过滤 `.tabBar && !isHidden`）
  - 我的侧栏：`Settings.personalPages`（过滤 `.personal && !isHidden`）
- **`normalize()`**：去重、补齐缺失页面、强制「我的」不可隐藏、清掉旧数据里不合法的归属。
- **存档**：`UserDefaults` 键 `Settings.tabBarPagePlacements`，JSON Data，只写 `page` + `isHidden`。
- **旧数据迁移**：早期版本用 `section == "hidden"` 表示隐藏；自定义 `init(from:)` 会把它转成 `isHidden = true`，`section` 由页面推导。

### 4.2 自定义页交互（`TabBarCustomizationViewController`）

- 两行：导航栏、我的页面，横向连续滚动。
- **确认键**：进入 / 结束排序。排序中卡片轻微摇动。
- **播放键**：隐藏 / 恢复当前聚焦的页面（浏览态和排序态都生效）。
- 排序只在同一行内左右移动；上下移动被 `shouldUpdateFocusIn` 拒绝，焦点锁在当前行。跨区移动彻底禁止。
- 规则：
  - 「我的」不能隐藏（设置、账号切换、登出都挂在它下面）。
  - 导航栏可见页面降到 3 个后不能再隐藏（弹提示）。
  - 我的页面可以全部隐藏，侧栏仍保留设置/账号切换/登出。
  - 导航栏上限 8 的规则已删除：归属固定后天然不会超过 8 个。
- **提交时机**：浏览态按播放键只改本地数组，`viewWillDisappear` 统一 `commitIfNeeded()` 写 `Settings.setPlacements` 并发 `.tabBarPagesDidChange`；「恢复默认」立即提交。避免 modal 还开着时刷新 tab bar。
- 隐藏视觉：卡片压到 `contentView.alpha = 0.35`（未聚焦），右上角 40pt 圆形角标 + `eye.slash`。角标挂在 cell 上而不是 contentView 里，避免被一起压暗；角标底色反着来（聚焦白卡 black 0.6，未聚焦暗卡 white 0.18）。

### 4.3 系统 tab bar 行为

- 导航栏 8 个全可见时，tvOS 系统 tab bar 会压缩/滚动把当前聚焦的 tab 带出来；`tabBar.items.count` 仍是 8，不是丢数据。
- 系统会给选中项套约 1.048 的缩放，这是系统行为。**不要再尝试私有层级放大**（试过，已回退，见 7.6）。

---

## 5. 本次会话改动（2026-10-29）

按时间顺序。文件路径相对 `BilibiliLive/`。

### 5.1 详情页纯代码化 + 删除 storyboard（Batch B）

- `Supporting Files/Info.plist`：删除 `UIMainStoryboardFile`，保留 `UILaunchStoryboardName`。
- 删除 `Base.lproj/Main.storyboard`（备份在 `/tmp/Main.storyboard.bak`），删除空的 `Base.lproj/`。
- `Component/Video/VideoDetailViewController.swift`：纯代码布局；`create(aid:cid:epid:)` 保留但内部直接初始化；按钮/UP 行/元信息/推荐合集/回复页按第 3 节指标。
- 验证：bundle 里没有 `Main.storyboardc`，正常启动。

### 5.2 Tab 自定义页玻璃化

- `Module/Personal/TabBarCustomizationViewController.swift`：卡片 200×140，Liquid Glass 底（34），聚焦 white 0.95 overlay + 黑字，`systemImage` 44pt + 标题 31pt；排序时摇动。
- 尺寸唯一来源 `TabBarTileCell.tileSize`。

### 5.3 账号管理左右排布 + 玻璃

- `Module/Personal/AccountSwitcherViewController.swift`：
  - 账号卡片和「添加账号」一行排开、整体靠左；卡片 300×320、间距 30、左内边距 60。
  - 面板 1100×600，玻璃子视图（不是玻璃容器）；卡片玻璃 + white 0.95 + 1.06 缩放。
  - 内容用居中 `UIStackView`，避免单行名字时徽章贴底。
  - 关闭按钮去掉（Menu 键即可关闭）。
  - 「添加账号」改为 `present(LoginViewController.create())`，返回键回到账号管理；登录成功由 `didValidationSuccess` 换根。

### 5.4 FollowUps / UP 空间按钮

- `Module/Personal/FollowUpsViewController.swift`：`UpCell` 改玻璃底 + 聚焦白 overlay + 黑字；Marquee 仍按「先 `holdScrolling = false` 再 `restartLabel()`」。
- `Component/View/UpSpaceTitleSupplementaryView.swift`：关注/拉黑/排序三个按钮改成 80×80 正圆玻璃（之前宽度是高度的 20.5/18，渲染成椭圆），`restingWhiteAlpha = 0.12`。
- `Component/View/BLButton.swift`：新增 `restingWhiteAlpha`，并修复 `didSet` 里只改透明度不取消隐藏导致不生效的问题。

### 5.5 Tab 栏自定义：从「第三个分区」改为「固定分区 + 隐藏开关」

> 中间版本曾实现第三个「不显示」分区（`TabBarPageSection.hidden`、占位卡、`reloadSections`），用户确认方案后已整体替换，当前代码里没有 `.hidden`。

- `Module/Tabbar/Settings+TabBar.swift`：见第 4 节。
- `Module/Personal/TabBarCustomizationViewController.swift`：两行、确认键排序、播放键隐藏、压暗 + 眼睛角标、跨区禁止、提交时机。
- 迁移：旧 `section == "hidden"` → `isHidden = true`。

### 5.6 验证与清理

- 构建通过；隐藏「直播」后导航栏只剩 7 个；隐藏「追番追剧」后卡片压暗带角标（截图确认）。
- 存档格式确认：`{"page":"live","isHidden":true}`，不再写 `section`。
- 调试钩子已删除，`rg "BL_DEBUG|hiddenPlacements|拖到这里|case hidden"` 无残留。
- 模拟器状态已还原为全部可见、默认顺序。

### 5.7 App Icon 还原

- 工作区里曾有一套未提交的新图标（粉色 B 站 TV 标志，`Group 7-2.png` / `Group 1-2.png` / `Group 1-3.png`），已按用户要求还原到 git 提交版本（22 娘 chibi 图标，`App Icon.imagestack` 的 `3.jpg`）。
- 还原方式：新图标 PNG 移到 `/tmp/ATV-Bilibili-AppIcon-new-20261029/`（临时备份），再 `git checkout -- "BilibiliLive/Supporting Files/Assets.xcassets/App Icon & Top Shelf Image.brandassets"`。
- 重新构建安装后，模拟器主屏幕图标已恢复为旧版。

---

## 6. 更早的 UI 工作（按记忆归档）

- **Feed 卡片**：YouTube TV 风格，三行信息（标题 / UP 主 + ✓ / 播放量 · 日期），无头像；播放量压缩成 `N万播放`，日期中文格式；网格列距/行距 60，卡片对齐安全区；聚焦不缩放、4pt 白边。
- **侧栏**：玻璃面板 300 宽，白胶囊焦点/选中双层语义；`contentInsetsReference = .none` 和 `contentInsetAdjustmentBehavior = .never` 修过对齐。
- **设置列表**：Apple TV 系统设置胶囊行，66/14/33 指标，聚焦长到 75。
- **字体**：全部走 `UIFont.App`；Tab 栏图标 26、标题 `.body`。
- **刷新加载**：右下角玻璃圆点，`blSetLoading`，所有可刷新页面已接入。
- **Tab 栏放大**：试过私有层级，用户要求回退，已删除；不要再试（见 7.6）。
- **视频详情**：纯代码、按钮 240/200、UP 行整体聚焦、推荐/合集复用 Feed cell、回复页重设计。
- **账号管理**：左右排布、玻璃面板、关闭按钮移除、登录返回逻辑修正。

---

## 7. 已知坑 / 不要再试

1. **SourceKit 误报**：`No such module 'UIKit'/'SnapKit'/'Kingfisher'`、`Cannot find type 'Settings'` 是索引问题，构建成功即正常。
2. **模拟器不能注入按键**：AppleScript `key code` 无效；不要用未绑定进程的 `click at`（会点到其他 App）。
3. **`makeGlassView` 不能当容器**：它把 `isUserInteractionEnabled` 设为 false，里面的控件全部失效。
4. **Auto Layout 视图消失**：先查同一个约束链上是否漏了 `translatesAutoresizingMaskIntoConstraints = false`（账号页标题消失就是这个原因）。
5. **MarqueeLabel**：必须先 `holdScrolling = false` 再 `restartLabel()`，反过来永远不滚。
6. **Tab 栏选中放大**：系统绘制，公开 API 无效；私有层级方案已回退，不要再试。系统自带约 1.048 缩放。
7. **8 个 tab**：系统会压缩/滚动显示，不是丢数据。
8. **`group.edgeSpacing` 不能做行距**：estimated 高度下会被吸收再叠加，行距翻倍；行距用 `section.interGroupSpacing`。
9. **侧栏/面板内的 collection view**：`contentInsetsReference` 和 `contentInsetAdjustmentBehavior` 会额外加安全区，记得关掉。
10. **modal 期间刷新 tab bar**：`setPlacements` 会触发 `reloadTabs`，可能在弹窗还开着时重建整条 tab；提交放在 `viewWillDisappear`。
11. **本地 `rm` 是交互式 alias**：脚本里用 `command rm -f`。

---

## 8. 验证与清理约定

1. 改完先 `xcodebuild` 构建，忽略 SourceKit 误报。
2. 安装到模拟器，正常启动一次，截图确认没有回归。
3. 需要看特定页面/状态时，用 `SceneDelegate` 的临时环境变量钩子；**用完删除**。
4. 清理检查：`rg -n "BL_DEBUG|<临时变量名>" BilibiliLive` 必须无结果。
5. 如果测试改过 `Settings.tabBarPagePlacements`，把模拟器状态还原（全部可见、默认顺序）。
6. 最终回复里说明：改了哪些文件、验证了什么、还有什么没验证。

---

## 9. 当前待办 / 已知限制

- 请求 F 里提到的 Tab 自定义焦点问题，已由「固定分区」方案解决：
  - 排序时不再跨区移动，焦点不会跳几格；
  - 排序时焦点无法离开 collection view，不会误触「恢复默认」；
  - 收藏不能进「我的」，不会再出现整页弹出盖住导航栏；
  - 「我的」页面里的页面归属固定，不会出现没有导航栏的情况。
- 「我的」页面可以全部隐藏，侧栏仍有设置/账号切换/登出，属于预期行为。
- 个别用户头像加载不出（空圆），详情页评论里存在，改造前就有，未处理。
- Feed 推荐流里已关注 UP 的视频可能没有时间戳（B 站接口就不给），靠名字后的 ✓ 区分；要补只能逐条请求 `x/web-interface/view`。
