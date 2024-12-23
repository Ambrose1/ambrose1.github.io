---
layout: masonry
title: 源码阅读
date: 2024-12-23 15:02:06
tags: masonry iOS
---

# Masonry 源码阅读笔记

## 一. 概要

业务开发使用的Masonry布局，阅读并了解自动布局库的底层实现原理有助于写出更好的UI和布局代码。

... 

## 二. Masonry 类介绍

- **Masonry** 对外导出api的头文件。无代码实现

- **MASUtilities** 定义宏和常量，数值解析方法。

- **View+MASShorthandAdditions** 提供一个简化的写法，需要生命条件，不推荐使用。

- **View+MASAdditions** 提供视图的mas_xx 属性
  
  提供 mas_makeConstraints/mas_updateConstraints/mas_remakeConstraints
  
  1. 关闭translatesAutoresizingMaskIntoConstraints 自动调整布局约束
  
  2. 创建MASConstraintMaker 对象
  
  3. 根据业务侧回调block 给MASConstraintMaker 设置约束
  
  4. 执行install动作，使约束生效。

- **ViewController+MASAdditions** 提供VC的一些 mas_xx方法

- **NSArray+MASAdditions** 为视图列表提供约束
  
  1. 提供 make/update/remake 三种约束方式
     
     1. 遍历当前数组内所有视图，分别执行make/update/remake
  
  2. 列表内视图提供固定间距/固定宽度两种方案。
     
     1. 遍历数组，对每个视图逐个进行masonry约束。

- **NSLayoutConstraint+MASDebugAdditions** 打印约束属性

- **MASConstraint**
  
  1. 提供比较方法（equalTo/mas_equalTo/greaterThanOrEqualTo/lessThanOrEqualTo)
  
  2. 提供设置优先级的方法。
  
  3. 提供设置偏移量的方法 insets、sizeOffset/centerOffset
  
  4. 作为父类，被MASViewConstraint 继承。

- **MASViewConstraint**
  
  1. 提供当前视图属性和对比视图属性。 view1.equalto(view2)
  
  2. 提供约束设置能力的设置。 优先级、equalTo属性、激活属性、偏移属性
  
  3. 提供install 和 uninstall方法，控制约束布局生效。

- **MASLayoutConstraint**
  
  1. 继承NSLayoutConstraint
  
  2. 无实现，提供一个mas_key
