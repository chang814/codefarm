# 0.2.11 GitHub 试玩发布复核

日期：2026-11-14。基于桌面 0.2.10，保留 Claude 对自动存档、欢迎页、音效、场景、图标和代码框架的改进。

## 发布前检查

- 从当前源码在独立 build-public 目录用 CMake + MinGW 15.2.0 重新构建模拟器和测试。
- C++ 1844 项检查通过；真实玩家路线完成 45 次购买，总游戏时间 3124.48 秒。
- 存档专项：SAVE_OK（独立测试存档，不修改玩家存档）。
- 真实 Vulkan 界面专项：REFINE_0210_OK。该专项检查 MultiMesh 装饰位置，不能用无头 dummy 渲染器的几何读取结果代替；无头模式的装饰距离断言不作为产品故障。
- 字体修复后的真实 Vulkan 冒烟：SMOKE_OK。
- 从独立的 Codefarm.exe + Codefarm.pck 运行：PACKAGE_OK version=0.2.11 hay=1；核对系统/代码字体非空、循环范本可读、欢迎页进入农场、完成一次真实收割，无错误日志。
- 源码敏感内容检查未发现私钥、GitHub token、API token 或已知学号；构建目录、个人存档和二进制均被 Git 忽略。

## 发现并修复

直接 load_dynamic_font 读取原始 TTF/OTF，在工程目录有效，导出 PCK 时字体被导入为 fontdata，原始字体路径不能直接按字节读取。现在优先通过 ResourceLoader 加载导入字体，复制实例后应用抗锯齿和 hinting 设置，并保留源文件回退。没有修改游戏模拟规则、经济或范本。

## 发布内容

- 公开源码：https://github.com/chang814/codefarm
- Windows 下载：https://github.com/chang814/codefarm/releases/latest
- Codefarm-v0.2.11-Windows-x64.zip：完整解压后双击 Codefarm.exe，也可使用开始游戏.cmd。
- SHA256SUMS.txt：下载校验。
- 第三方许可：licenses/。

试玩包使用官方 Godot 4.7.2 编辑器运行程序自动加载同名 PCK，包含本地已验证的 GDExtension 和 MinGW 运行库；无需另外安装 Godot。该方式体积偏大，后续可改为专用导出模板。Windows x64 原生试玩，无网页或手机版本。未签名，其他显卡与干净 Windows 虚拟机尚未实测。

编译中仍有未使用变量、初始化顺序等告警；本轮未改动这些不影响当前构建的代码。完整试玩时长与长期运行边界仍以既有检查文档为准。
