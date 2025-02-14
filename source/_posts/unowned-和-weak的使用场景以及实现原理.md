---
title: unowned 和 weak的使用场景以及实现原理
abstract: 补充简介
date: 2025-02-14 18:00:02
tags:
categories:
---

在 Swift 中，`unowned` 和 `weak` 都用于打破循环引用，但它们的适用场景不同。**存在一些场景必须使用 `unowned`，而无法用 `weak` 替代**，这些场景通常与对象的生命周期严格绑定有关。

---

### **1. 必须使用 `unowned` 的核心场景**

#### **场景：被引用对象的生命周期严格长于引用持有者**

- **条件**：  
  
  - 对象 A 的存活时间 **严格覆盖** 对象 B 的存活时间。
  - 对象 B 持有对 A 的引用，且 A 的销毁必然导致 B 的销毁。

- **示例**：父子关系模型  
  
  ```swift
  class Parent {
      var child: Child?
  }
  
  class Child {
      // 父对象 Parent 的生命周期一定长于 Child
      unowned let parent: Parent
  
      init(parent: Parent) {
          self.parent = parent
      }
  }
  ```
  
  - 如果 `child.parent` 使用 `weak`，则 `parent` 需要是可选类型（`Parent?`），但根据业务逻辑，`Child` 实例不可能脱离 `Parent` 存在。
  - 使用 `unowned` 可避免强制解包或冗余的可选性检查，同时保证安全性。

---

#### **场景：闭包与捕获对象的同步生命周期**

- **条件**：  
  
  - 闭包的执行逻辑 **严格限定** 在捕获对象（如 `self`）的生命周期内。
  - 闭包不会在对象释放后执行（如立即执行的同步操作）。

- **示例**：同步闭包  
  
  ```swift
  class DataLoader {
      func loadData(completion: () -> Void) {
          completion()
      }
  
      func start() {
          loadData { [unowned self] in
              self.handleData() // 闭包立即执行，self 一定存活
          }
      }
  
      func handleData() { ... }
  }
  ```
  
  - 如果闭包在 `loadData` 中立即执行，`self` 的存活是确定的。
  - 使用 `unowned` 避免 `weak` 的冗余可选解包（`self?.handleData()`）。

---

### **2. `unowned` vs `weak` 的关键区别**

| **特性**     | **`unowned`**    | **`weak`**          |
| ---------- | ---------------- | ------------------- |
| **可选性**    | 非可选类型            | 必须声明为可选类型（`T?`）     |
| **安全性**    | 对象释放后访问会崩溃       | 对象释放后自动置 `nil`，安全访问 |
| **生命周期假设** | 假定对象存活时间 ≥ 引用持有者 | 不假设对象存活时间           |
| **性能**     | 无额外开销（直接指针）      | 有可选值检查开销            |

---

### **3. 为什么某些场景只能用 `unowned`？**

#### **原因 1：避免不必要的可选性**

- 如果业务逻辑确保被引用对象一定存活，使用 `weak` 会导致代码中充斥冗余的 `guard let` 或 `if let`。

- **示例**：  
  
  ```swift
  // 错误：weak 导致不必要的可选解包
  class Child {
      weak var parent: Parent? // 需要解包
      func callParent() {
          parent?.doSomething() // 每次调用都需解包
      }
  }
  
  // 正确：unowned 避免冗余解包
  class Child {
      unowned let parent: Parent // 非可选
      func callParent() {
          parent.doSomething() // 直接访问
      }
  }
  ```

#### **原因 2：性能优化**

- `unowned` 是直接指针访问，无运行时检查；`weak` 需要额外的安全机制（如 `SideTable` 管理），存在性能开销。
- 在性能敏感场景（高频调用的闭包或紧密循环），`unowned` 更高效。

---

### **4. 注意事项**

1. **必须确保生命周期假设成立**  
   
   - 若 `unowned` 引用的对象提前释放，访问会导致 **崩溃**。
   - 仅在 **逻辑上严格保证对象存活** 时使用 `unowned`。

2. **典型错误场景**  
   
   ```swift
   class NetworkManager {
       func fetchData(completion: @escaping () -> Void) {
           DispatchQueue.global().async {
               // 错误：异步闭包可能延迟执行，self 可能已释放
               [unowned self] in
               self.handleData()
           }
       }
   }
   ```
   
   - 此处应使用 `weak`，因为异步闭包可能在 `self` 释放后执行。

---

### **5. 面试回答示例**

**问题**：“什么场景只能使用 `unowned` 不能使用 `weak`？”

**回答**：  

> “在两种场景下必须使用 `unowned`：  
> 
> 1. **被引用对象的生命周期严格长于当前对象**，例如父子模型中的子对象引用父对象。此时使用 `unowned` 可避免不必要的可选解包，同时保证安全性。  
> 2. **闭包立即执行且捕获对象生命周期同步**，例如同步闭包中引用 `self`。此时 `self` 的存活是确定的，`unowned` 比 `weak` 更高效。  
>    需要注意的是，滥用 `unowned` 会导致崩溃，必须确保生命周期假设严格成立。”

---

### **总结**

- **必须使用 `unowned`**：当对象的生命周期严格绑定且无需可选性时。
- **优先使用 `weak`**：在不确定对象存活时间或异步场景中。  
- **核心原则**：根据对象生命周期的确定性选择 `unowned` 或 `weak`，避免潜在崩溃。
