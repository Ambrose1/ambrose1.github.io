---
title: Swift Runtime的核心能力与实践
abstract: 介绍swift的runtime使用方式、以及与OC的Runtime的关系。
date: 2025-02-13 16:20:38
tags: swift
categories:
- swift
- runtime
---

# 一. 概述

对比OC（Objective-C）Swift 在设计上更强调安全性和性能，因此在动态特性上做了一些限制。同时为了兼容OC、支持自身的一些高级功能，保留了部分Runtime能力。

当Swift类继承自NSObject、或者使用@objc修饰时，这些类和成员会暴露给OC的runtime, 从而获取动态派发的能力。

# 二 . Runtime

## 2.1 swift 部分兼容OC

1. 继承NSObject

2. 使用@objc or dynamic修饰的成员强制启用动态派发。

3. 与OC代码交互通过桥接机制实现互通。

## 2.2 swift runtime的核心能力

### 2.2.1 方法派发机制

1. 静态派发
   
   1. 编译时确定方法地址（struct/final class/private方法)

2. 虚表派发
   
   1. 通过类虚函数表查找（常规class 的实例方法）

3. 动态派发
   
   1. 通过OC Runtime的消息机制（@objc和dynamic修饰）
   
   ```swift
   class MyClass: NSObject {
       @objc dynamic dynamicMethod() {} 动态派发 支持KVO/SWizzling
       func staticMethod() {}  虚表派发
   }
   ```

### 2.2.2 动态成员访问

通过`@dynamicMemeberLookup`和`@dynamicCallable`实现类似脚本语言的动态特性。

```swift
@dynamicMemberLookup
struct DynamicStruct {
    subscript(dynamicMember member: String) -> String {
        return "Accessed property: \(member)"
    }
}

let obj = DynamicStruct()
print(obj.hello) // 输出 "Accessed property: hello"
```

### 2.2.3 反射

通过Mirror实现有限的运行时类型检查：

```swift
let mirror = Mirror(reflecting: someInstance)
for child in mirror.children {
    print("Property: \(child.label ?? ""), Value: \(child.value)")
}
```

应用场景： 调试日志、JSON序列化工具。

### 2.2.4 协议扩展与动态类型检查

1. 协议扩展， 在运行时根据类型动态分发方法实现。

2. 类型检查（is/as?) 基于Runtime的类型信息判断。

```swift
protocol Drawable {
    func draw()
}
extension Circle: Drawable {
    func draw() { print("Drawing a circle") }
}

let shape: Any = Circle()
if let drawable = shape as? Drawable {
    drawable.draw() // 运行时动态调用具体实现
}
```

### 2.2.5 泛型特化 Generic Specialization

swift 编译器在编译时生成特定的泛型实现，避免Runtime开销。

```swift
func genericFunc<T>(_ value: T) -> T { ... }
// 编译后生成 Int、String 等特定版本的函数
```

### 2.2.6 内存管理优化

Swift 的ARC :

1. 结构体在栈上分配，无引用计数开销。

2. 写时复制 优化Array/Dictionary等集合类型的性能

3. 弱引用优化 weak和unowned编译时检查。

### 2.2.7 objc_msgSend 执行流程

分为3步，消息发送、动态方法解析、消息转发。

**消息发送**

消息接收者为空直接返回，不处理。

通过消息接收者的isa指针从类对象开始查找。（类方法从元类查找）

从类的方法缓存列表找最近使用过的方法。快速查找。

快速查找没找到就走慢速查找，找类的方法列表。

没找到，就向父类找，重复上述过程，直到NSObject

**动态方法解析**

允许运行时动态增加方法。resolveInstanceMethod.

**消息转发阶段**

快速转发、forwardingTargetForSelector

完整转发 forwardInvocation

崩溃。





# 关于动态派发和静态派发边界的选择原因

Swift 中静态派发与动态派发的划分基于类型安全、继承机制和可见性控制，旨在平衡性能与灵活性。以下是具体原因：

---

### **一、静态派发的适用场景**

#### 1. **结构体（`struct`）**

- **不可继承性**：结构体是值类型，不支持继承，所有方法在编译时即可确定唯一实现，无需运行时查找。
- **值语义优化**：直接操作栈内存，无引用计数开销，静态派发进一步提升效率。

#### 2. **`final` 类**

- **禁止子类化**：`final` 修饰的类无法被继承，其方法无法被重写（`override`）。
- **编译时确定性**：方法实现唯一，编译器可直接内联或硬编码调用地址。

#### 3. **`private` 方法**

- **作用域限制**：仅在当前文件或类型内可见，外部无法覆盖或动态修改。
- **唯一性保证**：编译器能确认方法不会被重写，可直接静态绑定。

---

### **二、动态派发的必要场景**

#### 1. **类实例方法**

- **支持多态**：普通类允许继承，子类可能重写父类方法（`override`），需运行时根据对象实际类型动态派发。
- **虚函数表（V-Table）**：每个类维护一个方法表，运行时通过对象类型查找正确的方法实现。

#### 2. **普通类方法（非 `final`）**

- **类继承与重写**：类方法（`class func`）可能被派生类重写，需动态派发。

- **示例**：
  
  ```swift
  class Animal {
      class func sound() { print("Animal sound") }
  }
  class Dog: Animal {
      override class func sound() { print("Bark") } // 需动态派发
  }
  ```

#### 3. **`public` 方法**

- **跨模块继承风险**：`public` 方法可能被其他模块的类继承并重写，编译器无法预知所有实现。
- **动态绑定保障**：确保跨模块调用时执行正确的方法版本。

---

### **三、设计哲学与性能权衡**

#### 1. **性能优先**

- **静态派发高效**：直接调用函数地址，无运行时开销，适合高频调用场景。
- **动态派发灵活**：以轻微性能损失（查表或消息传递）换取多态支持。

#### 2. **安全性约束**

- **显式控制继承**：通过 `final` 和访问控制符（如 `private`）限制动态派发范围，避免意外重写。
- **编译时优化**：尽可能静态化已知不可变的方法，减少运行时不确定性。

#### 3. **与 Objective-C 的兼容性**

- **动态派发兼容性**：`@objc` 或 `dynamic` 修饰的方法使用 Objective-C Runtime 的消息传递机制，支持 KVO、Swizzling 等特性。

---

### **四、示例对比**

#### 1. **静态派发示例**

```swift
struct Point {
    var x, y: Double
    func distance() -> Double { // 静态派发
        return sqrt(x*x + y*y)
    }
}

final class Logger {
    private func log(_ message: String) { // 静态派发
        print("[LOG] \(message)")
    }
}
```

#### 2. **动态派发示例**

```swift
class Shape {
    func draw() { print("Drawing a shape") } // 动态派发（虚表）
}

class Circle: Shape {
    override func draw() { print("Drawing a circle") } // 运行时确定实现
}

public class NetworkManager {
    public func request() { // 动态派发（可能被其他模块重写）
        // 网络请求逻辑
    }
}
```

---

### **五、总结**

- **静态派发**：用于**不可变场景**（如值类型、不可继承类、私有方法），通过编译时优化提升性能。
- **动态派发**：用于**需支持多态的场景**（如类继承、公开方法），确保运行时灵活性。

高级工程师需根据代码的扩展性和性能需求，合理选择类型（值类型 vs 引用类型）和方法修饰符（`final`、`private`），在灵活性与效率间找到最佳平衡。
