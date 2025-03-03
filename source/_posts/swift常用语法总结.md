---
title: swift常用语法总结
abstract: 总结一些常用的语法、计算方法、高级语法糖
date: 2025-02-07 10:46:02
tags: swift
categories: swift
---

## 求和

## 异或

在 Swift 中，**异或运算（XOR）** 使用 `^` 运算符实现，**专门用于整数类型的二进制位运算**。以下是详细说明和示例：

---

### 一、基本语法

```swift
let result = a ^ b
```

- `a` 和 `b` 必须是**整数类型**（如 `Int`, `UInt`, `Int8` 等）。
- 对每一位进行异或操作：**相同为 0，不同为 1**。

---

### 二、示例代码

#### 1. 基础异或运算

```swift
let a: Int = 5  // 二进制 0101
let b: Int = 3  // 二进制 0011
let xorResult = a ^ b
print(xorResult) // 输出 6（二进制 0110）
```

#### 2. 交换两个变量的值（无需临时变量）

```swift
var x = 10
var y = 20

x = x ^ y
y = x ^ y // 此时 y = 原始 x 的值
x = x ^ y // 此时 x = 原始 y 的值

print("x = \(x), y = \(y)") // 输出 x = 20, y = 10
```

#### 3. 简单数据加密/解密

```swift
let plainText: UInt8 = 0b10101010  // 原始数据
let key: UInt8 = 0b11110000        // 密钥

// 加密
let encrypted = plainText ^ key    // 结果 0b01011010

// 解密（再次异或密钥）
let decrypted = encrypted ^ key    // 结果 0b10101010（恢复原始数据）
```

---

### 三、注意事项

1. **仅限整数类型**：
   
   - 若操作数为非整数类型（如 `Double` 或 `Bool`），编译器会报错。
     
     ```swift
     let invalid = true ^ false // 错误：二进制运算符 '^' 不能用于两个 Bool 操作数
     ```

2. **逻辑异或需手动实现**：
   
   - 对布尔值（`Bool`）的逻辑异或，需组合逻辑运算符：
     
     ```swift
     func logicalXOR(_ a: Bool, _ b: Bool) -> Bool {
       return (a && !b) || (!a && b)
     }
     print(logicalXOR(true, false)) // 输出 true
     ```

3. **运算符优先级**：
   
   - `^` 的优先级低于算术运算符（如 `+`, `-`），但高于比较运算符（如 `==`）。
   
   - 建议使用括号明确运算顺序：
     
     ```swift
     let result = (a + b) ^ (c * d)
     ```

---

### 四、常见应用场景

- **数据加密**：通过异或密钥对数据进行简单加密。
- **交换变量值**：无需临时变量（但需注意整数溢出风险）。
- **错误检测**：如奇偶校验位的生成。
- **图形处理**：快速切换像素状态（例如掩码操作）。

---

通过 `^` 运算符，Swift 提供了高效的位级异或操作，适用于需要直接操作二进制位的场景。
