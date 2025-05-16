---
title: rust 常规语法
abstract: 补充rust 刷leetcode 过程中的一些常用语法
date: 2025-01-11 11:58:27
tags:
categories:
---

# 字符串

## 数字转字符串
```rust
let num = 42;
let format_num = format!("{:04}", num);  /// 不足4位增加前导0
```

## 遍历字符串
```rust
let s = "hello world";
for c in s.chars() {
    println!("{}",c);
}
```
在 Rust 中，字符串是以 UTF-8 编码的，因此遍历字符串时需要注意字符的 Unicode 编码。以下是几种常见的遍历字符串的方法：

---

### 1. **遍历字符（Unicode 标量值）**
使用 `.chars()` 方法可以按字符遍历字符串：

```rust
fn main() {
    let s = "你好, Rust!";
    for c in s.chars() {
        println!("{}", c);
    }
}
```

输出：
```
你
好
,
 
R
u
s
t
!
```

---

### 2. **遍历字节**
使用 `.bytes()` 方法可以按字节遍历字符串（UTF-8 编码的字节序列）：

```rust
fn main() {
    let s = "你好, Rust!";
    for b in s.bytes() {
        println!("{}", b);
    }
}
```

输出：
```
228
189
160
229
165
189
44
32
82
117
115
116
33
```

---

### 3. **遍历字符及其索引**
使用 `.char_indices()` 方法可以同时获取字符及其在字符串中的字节索引：

```rust
fn main() {
    let s = "你好, Rust!";
    for (i, c) in s.char_indices() {
        println!("Index: {}, Char: {}", i, c);
    }
}
```

输出：
```
Index: 0, Char: 你
Index: 3, Char: 好
Index: 6, Char: ,
Index: 7, Char:  
Index: 8, Char: R
Index: 9, Char: u
Index: 10, Char: s
Index: 11, Char: t
Index: 12, Char: !
```

---

### 4. **遍历字形簇（Grapheme Clusters）**
对于某些复杂的 Unicode 字符（如表情符号或组合字符），可能需要使用字形簇来正确遍历。可以使用 `unicode-segmentation` 库：

首先，在 `Cargo.toml` 中添加依赖：
```toml
[dependencies]
unicode-segmentation = "1.10"
```

然后使用 `unicode_segmentation::UnicodeSegmentation` 遍历字形簇：

```rust
use unicode_segmentation::UnicodeSegmentation;

fn main() {
    let s = "नमस्ते"; // 印地语的“你好”
    for g in s.graphemes(true) {
        println!("{}", g);
    }
}
```

输出：
```
न
म
स्
ते
```

---

### 总结
- 使用 `.chars()` 遍历字符。
- 使用 `.bytes()` 遍历字节。
- 使用 `.char_indices()` 遍历字符及其索引。
- 对于复杂的 Unicode 字符，使用 `unicode-segmentation` 库遍历字形簇。

根据你的需求选择合适的方法！在 Rust 中，字符串是以 UTF-8 编码的，因此遍历字符串时需要注意字符的 Unicode 编码。以下是几种常见的遍历字符串的方法：

---

## 字符串按下标取值
```rust
fn main() {
    let s = "你好, Rust!";
    let index = 2; // 想要获取的字符索引

    if let Some(c) = s.chars().nth(index) {
        println!("Character at index {}: {}", index, c);
    } else {
        println!("Index {} is out of bounds.", index);
    }
}
```