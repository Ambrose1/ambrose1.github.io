---
title: iOS 系统知识点整理
abstract: 补充简介
date: 2025-02-12 11:22:56
tags:
categories:
---

# 语言

## swift

+ 值类型与引用类型（结构体/类）

+ Protocol-Oriented Design

+ Generic & Associated

+ 内存管理

+ 闭包捕获语义

+ 循环引用

+ 错误处理

+ swift runtime
  
  + 方法派发机制，Mirror反射

### iOS 高级工程师知识点清单（侧重性能与基础）

#### 一、编程语言与底层机制

1. **Swift 高级特性**
   
   - 值类型与引用类型（结构体/类的内存管理）
   - 协议导向编程（Protocol-Oriented Design）
   - 泛型与关联类型（Generic & AssociatedType）
   - 内存管理（ARC、`weak`/`unowned` 使用场景）
   - 闭包捕获语义与循环引用
   - 错误处理（`Result` 类型、`throws`/`try`）
   - Swift Runtime（方法派发机制、Mirror 反射）

2. **Objective-C 核心机制**
   
   - Runtime 运行时（方法交换、动态消息解析）
   - KVO/KVC 实现原理与自定义监听
   - Category 与关联对象（Associated Object）
   - Block 的内存管理与循环引用
   - `@synthesize` 与 `@dynamic` 区别
   - 消息转发流程（`resolveInstanceMethod`、`forwardingTargetForSelector` 等）

---

#### 二、iOS 系统原理

1. **应用生命周期与组件**
   
   - App 启动流程（`dyld` 加载、`main()` 前阶段优化）
   - `UIViewController` 生命周期（`viewDidLoad`、`viewWillAppear` 等）
   - `UIApplication` 事件传递与响应链（Responder Chain）

2. **RunLoop 与事件处理**
   
   - RunLoop 工作原理（`NSRunLoop` 与 `CFRunLoop`）
   - 事件处理模式（`Default`/`Tracking` Mode）
   - 利用 RunLoop 优化滑动性能（空闲任务调度）

3. **多线程与并发**
   
   - GCD 高级用法（`dispatch_group`、信号量、栅栏函数）
   - `NSOperation` 依赖管理与优先级
   - 线程安全（锁机制：`os_unfair_lock`、`@synchronized`）
   - 异步绘制（`CATiledLayer`、`CGBitmapContext`）

4. **内存管理**
   
   - ARC 实现原理（引用计数表、SideTable）
   - 循环引用场景（Block、Delegate、Timer）
   - `AutoreleasePool` 机制与性能影响
   - 内存泄漏检测工具（Instruments Leaks、FBRetainCycleDetector）

5. **渲染与动画**
   
   - Core Animation 渲染管线（Commit -> Render Server -> GPU）
   - 离屏渲染优化（`cornerRadius` + `masksToBounds` 替代方案）
   - 图层混合（`opaque` 属性与 `shouldRasterize`）
   - 卡顿检测（CADisplayLink 帧率监控）

---

#### 三、性能优化专项

1. **启动优化**
   
   - 冷启动阶段拆分（`dyld`、Runtime 初始化、`main()` 后）
   - 减少动态库数量与二进制重排（`clang` Order File）
   - 延迟初始化非必要组件（按需加载）

2. **内存优化**
   
   - 检测 OOM（内存警告处理、`XNU` 内存阈值）
   - 图片加载优化（`UIImage` 解码、`downsampling` 技术）
   - 大内存对象管理（缓存策略、`NSCache` 使用）

3. **CPU/GPU 优化**
   
   - 主线程耗时任务排查（Time Profiler 火焰图分析）
   - 离屏渲染检测与避免（Instruments Core Animation）
   - 列表滚动性能优化（Cell 复用、高度缓存）

4. **网络优化**
   
   - 请求合并与减少 DNS 查询（HTTPDNS 方案）
   - 连接复用（HTTP/2、`NSURLSession` 配置）
   - 数据压缩（Protocol Buffer、压缩算法选择）

5. **耗电优化**
   
   - 后台任务管理（`BGTaskScheduler`）
   - 减少 `CPU` 唤醒次数（合并定位、网络请求）

6. **包体积优化**
   
   - 资源压缩（WebP、音频转码）
   - 无用代码检测（`LinkMap` 分析、`Swift` 死代码剔除）
   - 编译选项优化（Bitcode、Strip 符号表）

---

#### 四、架构设计与模式

1. **主流架构模式**
   
   - MVC 缺陷与改进方案（瘦 Controller）
   - MVVM 双向绑定（RxSwift/Combine 响应式实践）
   - 协调器模式（Coordinator 路由解耦）

2. **组件化与模块化**
   
   - 私有 Pod 库管理（版本号语义化、依赖冲突解决）
   - 路由设计（URL Scheme、`CTMediator` 解耦）
   - 依赖注入（Swinject 容器管理）

3. **设计模式**
   
   - 单例模式线程安全
   - 观察者模式（`Notification` vs `KVO`）
   - 工厂模式与抽象工厂

---

#### 五、工具链与调试

1. **Xcode 高级调试**
   
   - LLDB 命令（`po`、`image lookup`、内存断点）
   - 符号断点与条件断点
   - Address Sanitizer 内存检测

2. **性能分析工具**
   
   - Instruments 深度使用：
     - Time Profiler（CPU 耗时）
     - Allocations（内存分配）
     - Core Animation（GPU 性能）
   - 第三方工具：Reveal（UI 层级分析）、Netfox（网络监控）

3. **自动化与脚本**
   
   - Fastlane 自动化打包与上传
   - Shell 脚本优化编译流程
   - Xcode Build System 原理（`.xcconfig` 配置）

---

#### 六、网络与安全

1. **网络层优化**
   
   - `URLSession` 定制（`URLProtocol` 拦截）
   - 缓存策略（`ETag`、`Last-Modified`）
   - 弱网适配（超时重试、增量更新）

2. **安全实践**
   
   - HTTPS 证书固定（SSL Pinning）
   - 敏感数据加密（AES、RSA）
   - 反调试与代码混淆（`ptrace` 防护、LLVM 混淆）

---

#### 七、进阶技术

1. **底层机制探索**
   
   - `dyld` 动态链接过程
   - `libobjc` 源码分析（对象分配、消息发送）
   - `malloc` 内存分配栈回溯

2. **新技术趋势**
   
   - Swift Concurrency（`async`/`await` 替代 GCD）
   - SwiftUI 性能优化（`@StateObject` 使用场景）
   - Combine 响应式框架与内存管理

---

#### 八、质量保障

1. **测试体系**
   
   - 单元测试覆盖率（XCTest）
   - UI 自动化测试（XCUITest）
   - 性能基线测试（Metrics API）

2. **持续集成**
   
   - Jenkins Pipeline 配置
   - 自动化 Code Review（SwiftLint）
   - 崩溃监控（CrashSymbolicator 符号化解析）

---

### 学习建议

- **深度优先**：从 Instruments 工具链入手，分析性能瓶颈。
- **源码学习**：阅读 `UIKit`/`Foundation` 关键类的逆向实现。
- **实践驱动**：通过重构旧项目模块，应用组件化与性能优化方案。
