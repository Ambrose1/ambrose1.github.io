---
title: leetcode常用方法推荐
abstract: 做算法题时一些常用的语法api记录。
date: 2025-01-01 11:44:07
tags: 算法题目
categories:
 - 语法
---

# python

## 进制转换
1. **使用内置函数`bin()`**
   - `bin()`函数是Python 3中用于将十进制整数转换为二进制字符串的内置方法。
   - 示例：
   ```python
   decimal_num = 10
   binary_num = bin(decimal_num)
   print(binary_num)  
   ```
   - 输出结果是`0b1010`。这里的`0b`是二进制数的前缀，用于标识这是一个二进制表示。如果只想获取纯粹的二进制数字部分，可以使用`[2:]`切片操作来去除前缀，例如`binary_num = bin(decimal_num)[2:]`，这样输出的就是`1010`。
2. **除2取余法（手动实现）**
   - 原理：将十进制数不断除以2，记录每次的余数，直到商为0。然后将余数从右到左排列，就得到了对应的二进制数。
   - 示例代码：
   ```python
   decimal_num = 10
   binary_str = ""
   while decimal_num > 0:
       remainder = decimal_num % 2
       binary_str = str(remainder)+binary_str
       decimal_num = decimal_num // 2
   print(binary_str)
   ```
   - 首先，通过`decimal_num % 2`获取余数，将余数转换为字符串后添加到`binary_str`的左边（这样才能保证最后得到的二进制数顺序正确）。然后，通过`decimal_num = decimal_num // 2`更新十进制数，用于下一轮计算。当`decimal_num`为0时，循环结束，此时`binary_str`中存储的就是转换后的二进制数。
         
# Rust

## 进制转换
1. **十进制转二进制**
   - **方法一：使用`format!`宏与二进制格式说明符`b`**
     - Rust有强大的格式化宏`format!`，它类似于`println!`，但它是将格式化后的内容作为字符串返回，而不是打印出来。可以使用`b`格式说明符将十进制数转换为二进制字符串。
     - 示例：
     ```rust
     let decimal_num = 10;
     let binary_num = format!("{:b}", decimal_num);
     println!("{} in decimal is {} in binary", decimal_num, binary_num);
     ```
     - 在这个示例中，`{:b}`是格式说明符，它告诉`format!`宏将`decimal_num`转换为二进制格式。变量`binary_num`将存储转换后的二进制字符串，然后通过`println!`打印出十进制数和对应的二进制表示。
   - **方法二：手动实现除2取余法**
     - 这种方法类似于在其他编程语言中手动实现十进制到二进制的转换。不断地将十进制数除以2，记录余数，直到商为0。然后将余数从右到左组合起来，就得到了二进制表示。
     - 示例：
     ```rust
     fn decimal_to_binary(decimal_num: u32) -> String {
         let mut binary_str = String::new();
         let mut num = decimal_num;
         while num > 0 {
             let remainder = num % 2;
             binary_str = remainder.to_string() + &binary_str;
             num = num / 2;
         }
         binary_str
     }
     let decimal_num = 10;
     let binary_num = decimal_to_binary(decimal_num);
     println!("{} in decimal is {} in binary", decimal_num, binary_num);
     ```
     - 在`decimal_to_binary`函数中，首先创建一个空字符串`binary_str`用于存储二进制数字。然后进入循环，每次计算`num`除以2的余数`remainder`，将余数转换为字符串后与`binary_str`拼接（注意是余数在前，因为是从低位到高位构建二进制字符串）。接着更新`num`为商的值。当`num`为0时，循环结束，函数返回`binary_str`作为二进制表示。

2. **二进制转十进制**
   - **方法一：使用`parse`方法与二进制基数说明符`_2`**
     - Rust的字符串类型`String`和`&str`提供了`parse`方法，可以用于将字符串解析为其他类型。对于二进制转十进制，可以使用`_2`基数说明符来指定字符串是二进制表示，然后将其解析为十进制数。
     - 示例：
     ```rust
     let binary_num = "1010";
     if let Ok(decimal_num) = u32::from_str_radix(binary_num, 2) {
         println!("{} in binary is {} in decimal", binary_num, decimal_num);
     } else {
         println!("Invalid binary number");
     }
     ```
     - 在这个示例中，`u32::from_str_radix(binary_num, 2)`尝试将`binary_num`作为二进制字符串解析为`u32`类型的十进制数。如果解析成功，`Ok(decimal_num)`模式匹配成功，就可以打印出二进制数和对应的十进制表示；如果解析失败（例如`binary_num`包含非0或1的字符），则会执行`else`分支。
   - **方法二：手动实现位权展开法**
     - 根据二进制数的位权展开式来计算对应的十进制数。对于二进制数`b_n b_{n - 1}...b_1 b_0`，其十进制值为`b_n×2^n + b_{n - 1}×2^{n - 1}+...+b_1×2^1 + b_0×2^0`。
     - 示例：
     ```rust
     fn binary_to_decimal(binary_num: &str) -> u32 {
         let mut decimal_num = 0;
         let mut power = 1;
         for digit in binary_num.chars().rev() {
             if digit == '1' {
                 decimal_num += power;
             }
             power *= 2;
         }
         decimal_num
     }
     let binary_num = "1010";
     let decimal_num = binary_to_decimal(binary_num);
     println!("{} in binary is {} in decimal", binary_num, decimal_num);
     ```
     - 在`binary_to_decimal`函数中，首先初始化`decimal_num`为0（用于存储十进制结果）和`power`为1（用于表示当前位的位权，从最低位开始为1，然后每次乘以2）。然后通过`for digit in binary_num.chars().rev()`反向遍历二进制字符串中的每个字符。如果字符是`1`，就将`power`的值累加到`decimal_num`中。接着更新`power`的值，使其表示下一位的位权。最后返回`decimal_num`作为十进制结果。

3. **其他进制转换（以十六进制为例）**
   - **十进制转十六进制**
     - **使用`format!`宏与十六进制格式说明符`x`或`X`**：
       - `x`会将数字转换为小写字母的十六进制表示，`X`会转换为大写字母的十六进制表示。
       - 示例：
       ```rust
       let decimal_num = 255;
       let hexadecimal_num_lower = format!("{:x}", decimal_num);
       let hexadecimal_num_upper = format!("{:X}", decimal_num);
       println!("{} in decimal is {} in hexadecimal (lowercase) and {} in hexadecimal (uppercase)",
                decimal_num, hexadecimal_num_lower, hexadecimal_num_upper);
       ```
       - 输出结果为`255 in decimal is ff in hexadecimal (lowercase) and FF in hexadecimal (uppercase)`。
     - **手动实现除16取余法（类似十进制转二进制）**：
       - 不断地将十进制数除以16，记录余数，直到商为0。余数范围是0 - 15，对于大于9的余数，用字母`A - F`（或`a - f`）表示。
       - 示例：
       ```rust
       fn decimal_to_hexadecimal(decimal_num: u32) -> String {
           let mut hexadecimal_str = String::new();
           let mut num = decimal_num;
           let hex_chars = ['0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'];
           while num > 0 {
               let remainder = num % 16;
               hexadecimal_str = hex_chars[remainder as usize].to_string() + &hexadecimal_str;
               num = num / 16;
           }
           hexadecimal_str
       }
       let decimal_num = 255;
       let hexadecimal_num = decimal_to_hexadecimal(decimal_num);
       println!("{} in decimal is {} in hexadecimal", decimal_num, hexadecimal_num);
       ```
   - **十六进制转十进制**
     - **使用`parse`方法与十六进制基数说明符`_16`**：
       - 示例：
       ```rust
       let hexadecimal_num = "FF";
       if let Ok(decimal_num) = u32::from_str_radix(hexadecimal_num, 16) {
           println!("{} in hexadecimal is {} in decimal", hexadecimal_num, decimal_num);
       } else {
           println!("Invalid hexadecimal number");
       }
       ```
     - **手动实现位权展开法（类似二进制转十进制）**：
       - 对于十六进制数`h_n h_{n - 1}...h_1 h_0`，其十进制值为`h_n×16^n + h_{n - 1}×16^{n - 1}+...+h_1×16^1 + h_0×16^0`。
       - 示例：
       ```rust
       fn hexadecimal_to_decimal(hexadecimal_num: &str) -> u32 {
           let mut decimal_num = 0;
           let mut power = 1;
           for digit in hexadecimal_num.chars().rev() {
               let value: u32;
               match digit {
                   '0'..='9' => value = digit.to_digit(10).unwrap(),
                   'a'..='f' => value = 10 + (digit as u8 - 'a' as u8) as u32,
                   'A'..='F' => value = 10 + (digit as u8 - 'A' as u8) as u32,
                   _ => return 0,
               }
               decimal_num += value * power;
               power *= 16;
           }
           decimal_num
       }
       let hexadecimal_num = "FF";
       let decimal_num = hexadecimal_to_decimal(hexadecimal_num);
       println!("{} in hexadecimal is {} in decimal", hexadecimal_num, decimal_num);
       ```