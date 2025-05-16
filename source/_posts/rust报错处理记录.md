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

## `rustc --explain E0605`.
Line 12: Char 20: error: non-primitive cast: `Option<char>` as `i32` (solution.rs)
   |
12 |             res += tmp as i32 * f;
   |                    ^^^^^^^^^^ an `as` expression can be used to convert enum types to numeric types only if the enum type is unit-only or field-less
   |
   = note: see https://doc.rust-lang.org/reference/items/enumerations.html#casting for more information

For more information about this error, try `rustc --explain E0605`.
error: could not compile `prog` (bin "prog") due to 1 previous error