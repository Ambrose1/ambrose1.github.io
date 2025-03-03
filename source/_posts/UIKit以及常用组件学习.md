---
title: UIKit以及常用组件学习
abstract: 学习总结UIKit的使用、特性、优势、局限以及常用组件的特性。
date: 2024-12-26 11:42:08
tags:
   - UIKit
categories:
 - iOS
---

# 序

UIKit 为App提供了一些核心功能对象：与系统互动、运行App的主事件循环以及在屏幕上显示的内容。

UIKit 结构基于 MVC 的设计模式。 模型对象管理App的数据和业务逻辑。 视图对象提供数据的直观展示。 控制器对象充当模型和视图对象之间的桥梁。

![image](https://developer.apple.com/cn/documentation/uikit/about_app_development_with_uikit/images/ff7aa08f-4857-44ce-88d5-7dacbef84509.png)

UIKit 提供了一个UIDocument 对象，用于管理属于磁盘文件的数据结构。UIKit定义了UIView类，通常用于在屏幕上显示内容。UIApplication 对象负责运行App的主时间循环和管理App的整个生命周期。

> 上述内容参考官方文档： [关于使用 UIKit 开发 App - 简体中文文档 - Apple Developer](https://developer.apple.com/cn/documentation/uikit/about_app_development_with_uikit/#:~:text=UIKit%20%E6%A1%86%E6%9E%B6%E6%8F%90%E4%BE%9B%E4%BA%86%E4%B8%BA%20iOS%20%E5%92%8C%20Apple%20tvOS%20%E6%9E%84%E5%BB%BA%20App,%E5%A6%82%E6%9E%9C%E6%B2%A1%E6%9C%89%20Xcode%EF%BC%8C%E4%BD%A0%E5%8F%AF%E4%BB%A5%E4%BB%8E%20App%20Store%20%E4%B8%8B%E8%BD%BD%E3%80%82%20%E4%BD%A0%E4%B9%9F%E5%8F%AF%E4%BB%A5%E4%BB%8E%20developer.apple.com%2Fcn%2F%20%E4%B8%8B%E8%BD%BD%E6%9C%80%E6%96%B0%E7%89%88%E6%9C%AC%E3%80%82)

# 一. UIKit 框架

> 参考文献： [UIKit - 简体中文文档 - Apple Developer](https://developer.apple.com/cn/documentation/uikit/)

## 1.1 管理App's 生命周期

The following figure shows the state transitions for scenes. When the user or system requests a new scene for your app, UIKit creates it and puts it in the unattached state. User-requested scenes move quickly to the foreground, where they appear onscreen. A system-requested scene typically moves to the background so that it can process an event. For example, the system might launch the scene in the background to process a location event. When the user dismisses your app’s UI, UIKit moves the associated scene to the background state and eventually to the suspended state. UIKit can disconnect a background or suspended scene at any time to reclaim its resources, returning that scene to the unattached state.

![](https://docs-assets.developer.apple.com/published/bb875ff5b6507138789b710fc57afaf1/media-3233330@2x.png)

App 在进入前后台、active 和 inactive的时机，都会有对应的回调delegate方法给到应用程序，开发者需要根据App的自身定位，处理UI的展示和事件。

## 1.2 用户界面

在屏幕上显示你的内容，并定义配合内容的互动。

### 1.2.1 视图和控件

视图和控件是App用户界面的视觉组成要素。

![](https://developer.apple.com/cn/documentation/uikit/views_and_controls/images/75c071dc-3a79-466b-99d1-f8ef216a94aa.png)

UIView 是所有视图的根类，并定义视图的通用行为。

UIControl 定义特定的按钮、开关以及类似专门为用户互动设计的其他视图行为。

#### 容器视图

UITableView

UICollectionView

UIStackView

UIScrollView

#### 内容视图

UIActivityIndicatorView

UIImageView

UIPickerView

UIProgressView

WKWebView

#### 控件

UIControl

UIButton

UIDatePicker

UIPageControl

UISegmentedControl

UIStepper

UISwitch

#### 文本视图

UILabel

UITextField

UITextView

UISearchTextField

UISearchToken

#### 视觉效果

UIVisualEffect

UIVisualEffectView

UIVibrancyEffect

UIBlurEffect

#### 栏

UIBarItem

UIBarButtonItem

UIBarButtonItemGroup

UINavigationBar

UISearchBar

UIToolbar

UITabBarItem

# 思考

## UIView 的frame 和bounds的区别？

The frame rectangle, which describes the view’s location and size in its superview’s coordinate system.

The bounds rectangle, which describes the view’s location and size in its own coordinate system.

持续更新ing...
