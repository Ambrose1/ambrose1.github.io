---
title: xcode适配
date: 2024-12-23 10:40:19
tags: iOS
donate: true # 在当前文章隐藏打赏按钮
---

# Xcode 16

## Darwin.POSIX.sys.types._sa_family_t

be imported from module 'Darwin.POSIX.sys.types._sa_family_t' before it is required

**解决方案：** 手动导入 #import <sys/_types/_sa_family_t.h>

## unsupported option '-G' for target 'arm64-apple-ios12.0'

/Users/didi/work/kf_p/one-workspace/Pods/BoringSSL/crypto/x509/x_x509a.c unsupported option '-G' for target 'arm64-apple-ios12.0'

**解决方案：** -GCC_WARN_INHIBIT_ALL_WARNINGS 删除

1. 可以在podfile里使用rb代码修改xcodeproj的配置

2. 可以直接在对应库的xcodeproj  -> 显示包内容 -> project.pbxproj -> 删除所有的 -GCC_WARN_INHIBIT_ALL_WARNINGS

## xcode 16.1 beta 中 __mh_execute_header 编译报错

![](./images/xcode-adapter-image.png)

## 汇编语言报错

修改对应汇编报错部分代码。

[案例待补充]

持续更新ing
