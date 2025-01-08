---
title: rust报错处理记录
abstract: 补充简介
date: 2024-12-27 15:32:33
tags:
   - 语法
categories:
 - rust
---

## **error****: cannot find macro `lazy_static` in this scope**

> // 引入lazy_static宏  
> use lazy_static::lazy_static;

## Error code E0596

不可变对象不能作为可变指针被借用。
