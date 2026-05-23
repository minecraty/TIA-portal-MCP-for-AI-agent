---
name: "tia-portal-block-import"
description: "TIA Portal V20 PLC block import via MCP. Use when creating, importing, or compiling SCL FCs, OBs, Global DBs, LAD blocks, PLC tags, or tag tables for TIA Portal V20 projects through MCP."
---

# TIA Portal V20 Block Import via MCP

Complete reference for building and importing PLC program blocks, tag tables, and types into TIA Portal V20 through the MCP Openness API.

---

## ⚠️ 实战必读（按重要性排序）

### 1. 导入后立即保存！

```
Import → Compile → GetBlocks(验证isConsistent) → SaveProject
                                              ↑
                                      MISS THIS = 数据丢失！
```

**TIA Portal 的 MCP 导入不会自动持久化。** 每次导入编译后必须执行 `SaveProject`。

### 2. MCP 重启 = 项目状态丢失

MCP 服务器（`TiaMcpServer.exe`）重启后，**必须重新执行**：
```
Connect → OpenProject(完整.apXX路径) → 导入 → SaveProject
```

忘记重连会导致 "Project is null" 错误。所有未保存更改也会丢失。

### 3. ImportExternalSource 文件名必须唯一

`ImportExternalSource` 使用文件名（不含扩展名）作为外部源名称。**每次必须使用新文件名**，否则 `CreateFromFile` 会因同名源已存在而失败。

```
✅ test_v1.scl → test_v2.scl → test_v3.scl    （唯一文件名）
❌ test.scl → 修改 → test.scl                   （同名冲突）
```

### 4. .scl 文件必须有 UTF-8 BOM

`ImportExternalSource` 要求 `.scl` 文件编码为 **UTF-8 with BOM**。不加 BOM 会导致导入失败。

```powershell
# 验证 BOM：239,187,191 开头的字节序列
(Get-Content file.scl -Encoding Byte -TotalCount 3) -join ','
```

### 5. OB 名称冲突无法覆盖

**MCP 无法删除已存在的 OB 块。** 若项目已有 `Main` (OB1)，则无法用同名 OB 覆盖。解决方案：使用新名称（如 `MainCycle`），PLC 会按编号顺序执行所有 ProgramCycle OB。

### 6. FC 编号冲突处理

每个块的 `<Number>` 必须全局唯一。若目标项目已有同编号块，修改 `<Name>` 和 `<Number>`。

### 7. s7dcl 文件不支持中文字符

DB 和 LAD 的 s7dcl 格式必须使用英文/拼音变量名。

### 8. PowerShell 生成 XML 时的函数命名陷阱

**绝对不能**使用以下短名称作为函数名，它们与 PowerShell 内置别名冲突：

| 禁用名 | 冲突别名 |
|--------|---------|
| `sc` / `cp` / `mv` / `rm` / `cat` | Set-Content / Copy-Item / Move-Item / Remove-Item / Get-Content |
| `if` | PowerShell 关键字 |

推荐使用长度 ≥ 4 字符且不含关键字的函数名。

### 9. 在线模式限制编译和保存

**TIA Portal 在线模式（Go online）下无法编译和保存项目。** `CompileSoftware` 返回 "No result returned"，`SaveProject` 返回 "The operation is not permitted in online mode"。

```
修改程序前必须先 Go offline！
在线模式 → CompileSoftware 失败 → SaveProject 失败
离线模式 → CompileSoftware 成功 → SaveProject 成功
```

### 10. 多个 ProgramCycle OB 的冲突风险

PLC 会**同时执行**所有 `SecondaryType=ProgramCycle` 的 OB（如 OB1、OB123、OB128），按编号顺序循环调用。若存在多个功能重叠的 OB：

- 两个 OB 对同一 DB 变量写入不同值 → 数据竞争、输出闪烁
- 旧 OB 调用已修改接口的 FC → 编译错误、isConsistent=false
- **最佳实践：** 只保留一个主 OB 调用所有 FC，删除冗余 OB

```
✅ Main (OB1) 或 SortCycle (OB123) — 只保留一个
❌ Main (OB1) + MainCycle (OB128) — 冲突！
```

### 11. 不一致块无法导出

`isConsistent=false` 的块**无法通过 ExportBlocks / ExportBlock 导出**（返回 0 blocks exported）。必须先修复编译错误使块一致后才能导出。排查不一致块的方法：

```
GetBlocks(regexName="BlockName") → 检查 isConsistent 字段
GetBlockInfo(blockPath="BlockName") → 查看 CompileDate 是否为 0001-01-01（从未编译）
```

---

## Standard MCP Workflow

### 推荐流程（OB 含 FC 参数调用）
```
1. Connect → 2. OpenProject(完整.apXX路径) → 3. GetSoftwareTree (确认项目状态)
4. ImportFromDocuments (DB first!) → 5. ImportBlock (FCs, 无CallInfo的FC)
6. ImportExternalSource (OB .scl, 推荐!)  → 7. ImportTagTable / ExportTagTable (可选)
8. CompileSoftware(softwarePath) → 9. GetBlocks → verify isConsistent:true
10. SaveProject  ← 绝对不要跳过！
```

### MCP 重启恢复流程
```
1. Connect
2. OpenProject("C:\path\to\Project.ap20")  ← 注意完整扩展名！
3. 检查项目状态，必要时 SaveProject
```
`OpenProject` 需要 `.apXX` 扩展名（XX=18,19,20），而非项目文件夹路径。

PLC software path is typically `"PLC_1"`.

---

## PLC 程序验证方法论 ⭐ 核心参考

构建PLC程序后，按以下框架系统性验证，可在下载到PLC前发现绝大多数逻辑缺陷。

---

### 第一步：编译一致性检查

**目标：** 确认所有块可编译且一致，排除"程序根本没运行"的低级问题。

```
GetBlocks(softwarePath="PLC_1") → 逐个检查 isConsistent 和 CompileDate
```

| 检查项 | 正常值 | 异常值含义 |
|--------|--------|-----------|
| `isConsistent` | `true` | `false` = 块未编译或接口与代码不匹配 |
| `CompileDate` | 有效日期时间 | `0001-01-01` = 从未编译成功 |
| `PLCSimAdvancedSupport` | `true` | `false` = 可能是旧版本导入的块 |

**异常处理：**
- isConsistent=false → 重新 `ImportExternalSource` 或 `GenerateBlocksFromSource` → `CompileSoftware`
- CompileDate=0001-01-01 → 块刚创建未编译，执行 `CompileSoftware`
- 编译报 "No result returned" → 项目可能处于在线模式，需 Go offline

---

### 第二步：数据流完整性验证

**目标：** 追踪每个状态标志从置位到清除的完整生命周期，确保无断裂或冲突。

#### 2.1 标志生命周期追踪法

对每个关键状态标志，画出完整生命周期：

```
标志: bXxxDetected
  置位: FC_A 中，条件 = SensorX OR bXxxDetected（自保持）
  使用: FC_B 判断是否启动执行器
  使用: FC_C 判断是否执行动作
  清除: FC_D 中，条件 = 完成信号触发
  验证: 置位条件与清除条件是否可能同一周期满足？
```

**核心验证规则：**

| 规则 | 描述 | 违反后果 |
|------|------|---------|
| **末端清除** | 标志只在处理链最后一个使用者中清除 | 提前清除 → 后续FC读到false → 逻辑链断裂 |
| **置位/清除互斥** | 同一扫描周期内不能同时满足置位和清除条件 | 标志闪烁 → 输出瞬间动作又停止 |
| **自保持完整** | 自保持标志（`X := Sensor OR X`）的清除必须显式 | 隐式清除 → 标志永远为true |

#### 2.2 同周期置位-清除检测模板

对每个标志，用以下模板检查：

```
1. 列出所有 "flag := ... OR flag" 的自保持语句 → 置位点
2. 列出所有 "flag := false" 的赋值语句 → 清除点
3. 对每个清除点，问：此清除条件是否可能在置位后的同一扫描周期内满足？
   - 如果可能 → 是否有"后续步骤已完成"的信号作为清除前提？
   - 如果没有 → 这是Bug
```

**典型Bug模式：**
```scl
// ❌ 标志在检测FC中置位，又在同一FC中清除
flag := Sensor OR flag;           // 置位
IF flag AND noOtherCondition THEN // 此时其他FC还没执行
    flag := false;                // 同周期清除！
END_IF;
```

**正确模式：**
```scl
// ✅ 检测FC只置位，执行FC在完成后清除
// FC_Detect:
flag := Sensor OR flag;

// FC_Execute (处理链末端):
IF completionSignal THEN
    flag := false;  // 确认完成后才清除
END_IF;
```

---

### 第三步：传感器-执行器时序验证

**目标：** 确认程序逻辑与物理设备的时序约束一致。

#### 3.1 传感器位置差异分析

当系统包含传送带、流水线等移动机构时，传感器分布在不同物理位置：

```
[传感器A] ----移动机构----> [传感器B] ----移动机构----> [执行器位置]

关键约束：传感器A检测到目标 ≠ 目标已到达传感器B位置
```

**验证清单：**

| 检查项 | 验证方法 |
|--------|---------|
| 标志清除是否依赖传感器A的消失？ | 如果是，目标离开A后还在移动中 → 不应清除运行标志 |
| 运行标志是否在目标到达终点后才清除？ | 清除条件应包含终点传感器信号 |
| 传感器A触发后，目标到达传感器B需要几个周期？ | 期间运行标志必须保持为true |

**通用规则：**
- **移动机构运行标志**应在目标到达终点（而非离开起点）后才清除
- **检测标志**与**运行标志**应分离：检测标志表示"有目标存在"，运行标志表示"机构应运行"

#### 3.2 执行器互斥验证

多个执行器不能同时冲突动作：

```
对每对执行器 (Actuator_X, Actuator_Y)，验证：
  两者是否可能同时激活？
  如果同时激活是否安全？
  如果不安全，是否有互锁逻辑？
```

**互锁模板：**
```scl
// 执行器互斥：气缸伸出时传送带停止
IF ActuatorX_Extended OR ActuatorY_Extended THEN
    Conveyor := false;
ELSIF RunFlag THEN
    Conveyor := true;
END_IF;
```

---

### 第四步：状态互斥与覆盖验证

**目标：** 确认互斥状态不会同时为true，已确定的状态不会被意外覆盖。

#### 4.1 互斥状态检查

当系统有多个互斥状态（如颜色、位置、模式），验证：

```scl
// ❌ 多个独立IF可能导致多状态同时为true
IF ConditionA THEN stateA := true; END_IF;
IF ConditionB THEN stateB := true; END_IF;
// 如果ConditionA和ConditionB同时满足 → 两个状态都为true

// ✅ 使用ELSIF确保互斥
IF ConditionA THEN
    stateA := true;
ELSIF ConditionB THEN
    stateB := true;
END_IF;
```

#### 4.2 状态覆盖防护

已确定的状态不应被后续扫描周期覆盖：

```scl
// ❌ 每周期都执行检测，可能覆盖已确定的状态
IF flag THEN
    IF SensorA THEN stateA := true; END_IF;
    // 下一个周期SensorB误触发 → stateA被覆盖
END_IF;

// ✅ 增加"无已有状态"前置条件
IF flag AND NOT stateA AND NOT stateB AND NOT stateC THEN
    IF SensorA THEN stateA := true;
    ELSIF SensorB THEN stateB := true;
    ELSIF SensorC THEN stateC := true;
    END_IF;
END_IF;
```

**验证规则：**
- 互斥状态用 `ELSIF` 而非独立 `IF`
- 状态检测增加"无已有状态"前置条件
- 状态标志是"一次性"的：设置后不再修改，直到处理完成才清除

---

### 第五步：初始化与守卫条件验证

**目标：** 确认初始化逻辑只执行一次，不会每周期重置变量。

#### 5.1 FirstScan 守卫验证

```scl
IF NOT bFirstScan THEN
    // 初始化代码
    bFirstScan := true;  // ← 关键：执行后立即置true
END_IF;
```

| 检查项 | 正确 | Bug |
|--------|------|-----|
| bFirstScan 存储位置 | DB 的 InOut 参数（跨周期保持） | VAR_TEMP（每周期重置为false） |
| bFirstScan DB初始值 | false（首次进入IF） | true（永远不会执行初始化） |
| bFirstScan 赋值位置 | IF块内部最后一行 | IF块外部或遗漏 |

#### 5.2 守卫条件通用验证模板

对任何"只执行一次"的逻辑，验证：

```
1. 守卫变量存储在哪里？ → 必须跨周期保持（DB InOut / Static / Retain）
2. 守卫变量初始值是什么？ → 必须允许首次进入
3. 守卫变量何时被置位？ → 必须在受保护逻辑内部，且是最后一条语句
4. 守卫变量是否可能被其他FC重置？ → 检查所有对该变量的赋值
```

---

### 第六步：OB架构验证

**目标：** 确认OB调用结构正确，无冲突或遗漏。

#### 6.1 单一主OB原则

```
GetBlocks(softwarePath="PLC_1") → 筛选 EventClass="Program cycle" 的OB
```

| 检查项 | 问题 | 后果 |
|--------|------|------|
| 多个ProgramCycle OB | 两个OB对同一DB变量写入 | 数据竞争、输出闪烁 |
| OB未调用关键FC | FC存在但OB中无调用 | FC逻辑不执行 |
| OB调用顺序错误 | 如：Sort在Detect之前 | 读取到上一周期的旧数据 |

**验证方法：**
- 导出OB源码，检查每个FC调用是否完整
- 确认调用顺序：Init → Detect → Control → Execute → Output
- 确认Q输出映射在OB末尾：`Q_xxx := DB.xxx`

#### 6.2 FC参数传递完整性

当修改FC接口（增加/删除参数）后：

```
1. 修改FC接口 → FC的isConsistent变为false
2. 调用该FC的OB → OB的isConsistent也变为false（参数不匹配）
3. 必须同步更新OB中的FC调用，添加/删除对应参数
4. 重新编译 → 两者isConsistent恢复true
```

---

### 验证流程速查表

```
构建程序后，按顺序执行：

□ Step 1: GetBlocks → 所有块 isConsistent=true?
  └─ No → CompileSoftware → 仍false? → 重新导入块源码

□ Step 2: 追踪每个状态标志的置位→使用→清除生命周期
  └─ 置位和清除可能同周期? → 改为末端清除模式

□ Step 3: 传感器-执行器时序 → 移动机构标志是否在终点清除?
  └─ 在起点清除? → 改为终点传感器触发后才清除

□ Step 4: 互斥状态 → ELSIF? 无已有状态前置条件?
  └─ 独立IF? → 改为ELSIF + 前置条件

□ Step 5: 初始化守卫 → bFirstScan在DB InOut? 初始值false?
  └─ 在VAR_TEMP? → 改为DB InOut参数

□ Step 6: OB架构 → 单一主OB? FC调用完整? Q映射在末尾?
  └─ 多个ProgramCycle OB? → 合并为一个，删除冗余

□ 最终: CompileSoftware → GetBlocks(全consistent) → SaveProject
```

---

### 常见症状→验证步骤映射

| 症状 | 首先验证 | 根因概率 |
|------|---------|---------|
| I变量正常，Q变量全不响应 | Step 1 (编译一致性) + Step 6 (OB是否调用FC) | 高：FC未编译或OB未调用 |
| 输出瞬间动作又停止 | Step 2 (标志同周期置位-清除) | 高：标志被提前清除 |
| 传送带/机构启动后立即停止 | Step 3 (传感器位置差异) | 高：离开起点就清除标志 |
| 状态被错误切换 | Step 4 (互斥与覆盖) | 高：缺少前置条件 |
| 变量每周期被重置 | Step 5 (初始化守卫) | 中：bFirstScan可能在VAR_TEMP |
| 输出闪烁/不稳定 | Step 6 (多个OB冲突) | 中：多个ProgramCycle OB |

---

## Quick Reference: File Format Matrix

### OB 块导入 — 能力矩阵 ⭐ 核心参考

| 调用需求 | 推荐方式 | 工具 | 状态 |
|----------|---------|------|:--:|
| **OB 带参数调用 FC/FB** | **SCL .scl 源文件** ⭐ | `ImportExternalSource` | ✅ |
| OB 无参数调用 FC/FB | FBD XML (FlgNet/v5) | `ImportBlock` | ✅ |
| OB 无参数调用 FC/FB | SCL XML (StructuredText/v4) | `ImportBlock` | ✅ |
| OB 带 Parameter 的 XML | FBD/SCL XML + CallInfo/Parameter | `ImportBlock` | ❌ **硬限制** |
| LAD OB (s7dcl) | s7dcl 文档格式 | `ImportFromDocuments` | ❌ **不支持** |

### 所有块类型速查

| Block Type | Format | Import Tool | Key Notes |
|------------|--------|-------------|-----------|
| **OB 带参数** ⭐ | .scl 文本源文件 (UTF-8 BOM) | `ImportExternalSource` | **唯一可行方案**；自动生成块；编号自动分配 |
| **OB 无参数** | XML Tokenized (FlgNet/v5 或 StructuredText/v4) | `ImportBlock` | FBD 可切换 LAD↔STL |
| **SCL FC** | XML Tokenized (StructuredText/v4) | `ImportBlock` | 仅 InOut 接口；不可直接访问 Global DB |
| **SCL FB** | XML Tokenized (StructuredText/v4) | `ImportBlock` | 可直接访问 DB（与 FC 不同） |
| **SCL FC/FB/DB** | .scl 文本源文件 | `ImportExternalSource` | V20+；无需 Token 化；自动生成块 |
| **LAD FC/FB** | s7dcl + s7res | `ImportFromDocuments` | 可用 CALL 指令 |
| **Global DB** | s7dcl + s7res | `ImportFromDocuments` | VAR/END_VAR；变量名仅 ASCII |
| **PLC Tag Table** | XML | `ImportTagTable` / `ExportTagTable` | 支持批量 I/O/M 标签导入 |

---

## OB 块导入：核心决策指南

### ⚠️ 关键发现：ImportBlock 的 CallInfo/Parameter 硬限制

经过实战验证，`ImportBlock` XML 方式存在以下**硬限制**：

| 测试场景 | 结果 |
|----------|:--:|
| FBD OB XML + `<CallInfo>` 无 `<Parameter>` → `FC_Init()` | ✅ 成功 |
| SCL OB XML + `<CallInfo>` 无 `<Parameter>` → `FC_Init()` | ✅ 成功 |
| FBD OB XML + `<CallInfo>` 含 `<Parameter>` | ❌ 失败 |
| SCL OB XML + `<CallInfo>` 含 `<Parameter>` | ❌ 失败 |
| FC XML + `<CallInfo>` 含 `<Parameter>` | ❌ 失败 |
| ImportExternalSource .scl + 完整参数传递 | ✅ 成功 |
| ImportFromDocuments s7dcl → OB | ❌ 失败（任何 OB） |

**结论：** `ImportBlock` 不支持任何带 `<Parameter>` 子元素的 `<CallInfo>`（无论 OB 还是 FC）。带参数的 FC/FB 调用**必须**使用 `ImportExternalSource` (.scl 文件) 方式。

### 决策流程

```
需要 OB 调用 FC/FB？
├── 需要传参数？
│   └── YES → ImportExternalSource (.scl 文件) ⭐ 唯一方案
└── 不需要传参数？
    ├── 需要可视化编辑？ → ImportBlock (FBD XML)
    └── 纯文本可接受？   → ImportBlock (SCL XML) 或 ImportExternalSource
```

---

## ImportExternalSource：OB 带参数调用方案 ⭐ 推荐

### .scl 文件格式

```scl
ORGANIZATION_BLOCK "OB_Name"
TITLE = 'Description'
BEGIN
    "FC_Target"(
        Param1 := "DB_Name".Field1,
        Param2 := "Tag_Name",
        Param3 := "DB_Name".Field3
    );

    "Output_Tag" := "DB_Name".Field1;
END_ORGANIZATION_BLOCK
```

### 完整实战示例（5 个 FC 调用 + 输出映射）

```scl
ORGANIZATION_BLOCK "MainCycle"
TITLE = 'Main Program Cycle'
BEGIN
    "FC_Init"(
        bFirstScan := "DB_SortingData".bFirstScan,
        bConveyorRunning := "DB_SortingData".bConveyorRunning,
        bMaterialDetected := "DB_SortingData".bMaterialDetected,
        bRedObject := "DB_SortingData".bRedObject,
        bBlueObject := "DB_SortingData".bBlueObject,
        bGreenObject := "DB_SortingData".bGreenObject,
        bCylRedExtended := "DB_SortingData".bCylRedExtended,
        bCylBlueExtended := "DB_SortingData".bCylBlueExtended,
        bCylGreenExtended := "DB_SortingData".bCylGreenExtended,
        iRedCount := "DB_SortingData".iRedCount,
        iBlueCount := "DB_SortingData".iBlueCount,
        iGreenCount := "DB_SortingData".iGreenCount,
        bSystemError := "DB_SortingData".bSystemError
    );

    "FC_ColorDetect"(
        ColorRed := "I_ColorRed",
        ColorBlue := "I_ColorBlue",
        ColorGreen := "I_ColorGreen",
        MaterialSensor := "I_MaterialSense",
        bMaterialDetected := "DB_SortingData".bMaterialDetected,
        bRedObject := "DB_SortingData".bRedObject,
        bBlueObject := "DB_SortingData".bBlueObject,
        bGreenObject := "DB_SortingData".bGreenObject
    );

    "FC_ConveyorControl"(
        bMaterialDetected := "DB_SortingData".bMaterialDetected,
        bConveyorRunning := "DB_SortingData".bConveyorRunning,
        bCylRedExtended := "DB_SortingData".bCylRedExtended,
        bCylBlueExtended := "DB_SortingData".bCylBlueExtended,
        bCylGreenExtended := "DB_SortingData".bCylGreenExtended
    );

    "FC_SortLogic"(
        PosRed := "I_RedPos",
        PosBlue := "I_BluePos",
        PosGreen := "I_GreenPos",
        BinRed := "I_RedBin",
        BinBlue := "I_BlueBin",
        BinGreen := "I_GreenBin",
        bRedObject := "DB_SortingData".bRedObject,
        bBlueObject := "DB_SortingData".bBlueObject,
        bGreenObject := "DB_SortingData".bGreenObject,
        bCylRedExtended := "DB_SortingData".bCylRedExtended,
        bCylBlueExtended := "DB_SortingData".bCylBlueExtended,
        bCylGreenExtended := "DB_SortingData".bCylGreenExtended,
        iRedCount := "DB_SortingData".iRedCount,
        iBlueCount := "DB_SortingData".iBlueCount,
        iGreenCount := "DB_SortingData".iGreenCount,
        bMaterialDetected := "DB_SortingData".bMaterialDetected
    );

    "FC_CylinderControl"(
        bCylRedExtended := "DB_SortingData".bCylRedExtended,
        bCylBlueExtended := "DB_SortingData".bCylBlueExtended,
        bCylGreenExtended := "DB_SortingData".bCylGreenExtended,
        bSystemError := "DB_SortingData".bSystemError
    );

    "Q_Conveyor" := "DB_SortingData".bConveyorRunning;
    "Q_CylRed" := "DB_SortingData".bCylRedExtended;
    "Q_CylBlue" := "DB_SortingData".bCylBlueExtended;
    "Q_CylGreen" := "DB_SortingData".bCylGreenExtended;
END_ORGANIZATION_BLOCK
```

### 导入命令

```
ImportExternalSource(softwarePath="PLC_1", importPath="C:\path\to\MainCycle.scl")
```

### 关键注意事项

| 注意事项 | 说明 |
|----------|------|
| **UTF-8 BOM 必须** | 文件必须以 BOM (239,187,191) 开头 |
| **文件名必须唯一** | 每次用不同文件名（如 `Main_v1.scl`, `Main_v2.scl`） |
| **OB 名称避免冲突** | OB 名不能与已有块同名（无法覆盖） |
| **可添加 `{ S7_Optimized_Access := 'TRUE' }`** | 在 `TITLE` 之前可添加，但非必须 |
| **VAR_TEMP 可省略** | 无临时变量时可省略 |
| **ImportExternalSource 自动生成块** | 导入即生成，无需额外调用 `GenerateBlocksFromSource` |

---

## FBD OB XML Template（仅无参数调用）

> ⚠️ 此方案**仅支持无参数 FC/FB 调用**。需要传参数请使用上方的 `ImportExternalSource` 方案。

```xml
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <Engineering version="V20" />
  <DocumentInfo>
    <Created>2026-05-21T12:00:00Z</Created>
    <ExportSetting>None</ExportSetting>
    <InstalledProducts>
      <Product><DisplayName>Totally Integrated Automation Portal</DisplayName><DisplayVersion>V20</DisplayVersion></Product>
      <OptionPackage><DisplayName>TIA Portal Openness</DisplayName><DisplayVersion>V20</DisplayVersion></OptionPackage>
      <OptionPackage><DisplayName>TIA Portal Version Control Interface</DisplayName><DisplayVersion>V20</DisplayVersion></OptionPackage>
      <Product><DisplayName>SINAMICS Startdrive Advanced</DisplayName><DisplayVersion>V20</DisplayVersion></Product>
      <OptionPackage><DisplayName>SINAMICS Startdrive G130, G150, S120, S150, SINAMICS MV, G220, S200, S210</DisplayName><DisplayVersion>V20</DisplayVersion></OptionPackage>
      <OptionPackage><DisplayName>SINAMICS Startdrive G110M, G120, G120C, G120D, G120P, G115D</DisplayName><DisplayVersion>V20</DisplayVersion></OptionPackage>
      <Product><DisplayName>STEP 7 Professional</DisplayName><DisplayVersion>V20</DisplayVersion></Product>
      <OptionPackage><DisplayName>STEP 7 Safety</DisplayName><DisplayVersion>V20</DisplayVersion></OptionPackage>
      <Product><DisplayName>WinCC Basic/Comfort/Advanced</DisplayName><DisplayVersion>V20</DisplayVersion></Product>
      <OptionPackage><DisplayName>SIMATIC Visualization Architect</DisplayName><DisplayVersion>V20</DisplayVersion></OptionPackage>
      <Product><DisplayName>WinCC Unified</DisplayName><DisplayVersion>V20</DisplayVersion></Product>
      <OptionPackage><DisplayName>SIMATIC Visualization Architect</DisplayName><DisplayVersion>V20</DisplayVersion></OptionPackage>
    </InstalledProducts>
  </DocumentInfo>
  <SW.Blocks.OB ID="0">
    <AttributeList>
      <Interface><Sections xmlns="http://www.siemens.com/automation/Openness/SW/Interface/v5">
        <Section Name="Input">
          <Member Name="Initial_Call" Datatype="Bool" Informative="true" />
          <Member Name="Remanence" Datatype="Bool" Informative="true" />
        </Section>
        <Section Name="Temp" />
        <Section Name="Constant" />
      </Sections></Interface>
      <MemoryLayout>Optimized</MemoryLayout>
      <Name>OB_Name</Name>
      <Namespace />
      <Number>200</Number>
      <ProgrammingLanguage>FBD</ProgrammingLanguage>
      <SecondaryType>ProgramCycle</SecondaryType>
      <SetENOAutomatically>false</SetENOAutomatically>
    </AttributeList>
    <ObjectList>
      <MultilingualText ID="1" CompositionName="Comment">
        <ObjectList><MultilingualTextItem ID="2" CompositionName="Items"><AttributeList><Culture>de-DE</Culture><Text /></AttributeList></MultilingualTextItem></ObjectList>
      </MultilingualText>
      <SW.Blocks.CompileUnit ID="3" CompositionName="CompileUnits">
        <AttributeList>
          <NetworkSource><FlgNet xmlns="http://www.siemens.com/automation/Openness/SW/NetworkSource/FlgNet/v5">
  <Parts>
    <Call UId="21">
      <CallInfo Name="FC_Init" BlockType="FC" />
    </Call>
  </Parts>
  <Wires>
    <Wire UId="23">
      <OpenCon UId="22" />
      <NameCon UId="21" Name="en" />
    </Wire>
  </Wires>
</FlgNet></NetworkSource>
          <ProgrammingLanguage>FBD</ProgrammingLanguage>
        </AttributeList>
        <ObjectList>
          <MultilingualText ID="4" CompositionName="Comment"><ObjectList><MultilingualTextItem ID="5" CompositionName="Items"><AttributeList><Culture>de-DE</Culture><Text /></AttributeList></MultilingualTextItem></ObjectList></MultilingualText>
          <MultilingualText ID="6" CompositionName="Title"><ObjectList><MultilingualTextItem ID="7" CompositionName="Items"><AttributeList><Culture>de-DE</Culture><Text /></AttributeList></MultilingualTextItem></ObjectList></MultilingualText>
        </ObjectList>
      </SW.Blocks.CompileUnit>
      <MultilingualText ID="8" CompositionName="Title"><ObjectList><MultilingualTextItem ID="9" CompositionName="Items"><AttributeList><Culture>de-DE</Culture><Text /></AttributeList></MultilingualTextItem></ObjectList></MultilingualText>
    </ObjectList>
  </SW.Blocks.OB>
</Document>
```

**FBD OB 关键要素：**
- `ProgrammingLanguage>FBD` + `NetworkSource><FlgNet .../FlgNet/v5>`
- `<Parts>` 中每个 `<Call>` 对应一个 FC/FB 调用（**不含 `<Parameter>` 子元素**）
- `<Wires>` 中必须连接 EN/ENO（`NameCon Name="en"`）
- FBD 导入需要**完整的 12 项** `InstalledProducts`（3 项精简版会失败！）
- FBD OB **不要**加 `<AutoNumber>` 元素
- ⚠️ **`<CallInfo>` 中绝对不能包含 `<Parameter>` 元素** — 会导致导入失败

---

## SCL OB XML Template（仅无参数调用）

> ⚠️ 此方案**仅支持无参数 FC/FB 调用**。需要传参数请使用 `ImportExternalSource` 方案。

```xml
<!-- AttributeList 中 -->
<ProgrammingLanguage>SCL</ProgrammingLanguage>
<!-- CompileUnit 中 -->
<NetworkSource><StructuredText xmlns="http://www.siemens.com/automation/Openness/SW/NetworkSource/StructuredText/v4">
  <NewLine UId="21" />
  <!-- ⚠️ CallInfo 不含 Parameter：FC_Init(); -->
  <Access Scope="Call" UId="22">
    <CallInfo Name="FC_Init" BlockType="FC" UId="23" />
  </Access>
  <Token Text=";" UId="24" />
</StructuredText></NetworkSource>
```

**OB 接口说明（FBD 和 SCL 通用）：**
- OB **没有** `Output`、`InOut`、`Return` 节
- `Input` 节包含 `Initial_Call` 和 `Remanence`（`Informative="true"`）
- `Temp` 节用于临时变量
- `SecondaryType` 取值：`ProgramCycle`、`TimeOfDay`、`TimeDelayInterrupt` 等

---

## SCL FC XML Template (V20 Verified)

```xml
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <Engineering version="V20" />
  <DocumentInfo>
    <Created>2026-05-20T12:00:00Z</Created>
    <ExportSetting>None</ExportSetting>
    <InstalledProducts>
      <Product><DisplayName>Totally Integrated Automation Portal</DisplayName><DisplayVersion>V20</DisplayVersion></Product>
      <OptionPackage><DisplayName>TIA Portal Openness</DisplayName><DisplayVersion>V20</DisplayVersion></OptionPackage>
      <Product><DisplayName>STEP 7 Professional</DisplayName><DisplayVersion>V20</DisplayVersion></Product>
    </InstalledProducts>
  </DocumentInfo>
  <SW.Blocks.FC ID="0">
    <AttributeList>
      <AutoNumber>false</AutoNumber>
      <Interface><Sections xmlns="http://www.siemens.com/automation/Openness/SW/Interface/v5">
        <Section Name="Input"><Member Name="inVal" Datatype="Bool" /></Section>
        <Section Name="Output" />
        <Section Name="InOut"><Member Name="outVal" Datatype="Bool" /></Section>
        <Section Name="Temp" />
        <Section Name="Constant" />
        <Section Name="Return"><Member Name="Ret_Val" Datatype="Void" /></Section>
      </Sections></Interface>
      <MemoryLayout>Optimized</MemoryLayout>
      <Name>FC_BlockName</Name>
      <Namespace />
      <Number>99</Number>
      <ProgrammingLanguage>SCL</ProgrammingLanguage>
      <SetENOAutomatically>false</SetENOAutomatically>
    </AttributeList>
    <ObjectList>
      <MultilingualText ID="1" CompositionName="Comment">
        <ObjectList><MultilingualTextItem ID="2" CompositionName="Items"><AttributeList><Culture>de-DE</Culture><Text /></AttributeList></MultilingualTextItem></ObjectList>
      </MultilingualText>
      <SW.Blocks.CompileUnit ID="3" CompositionName="CompileUnits">
        <AttributeList>
          <NetworkSource><StructuredText xmlns="http://www.siemens.com/automation/Openness/SW/NetworkSource/StructuredText/v4">
<NewLine UId="21" />
<Access Scope="LocalVariable" UId="22"><Symbol UId="23"><Component Name="outVal" UId="24" /></Symbol></Access>
<Blank UId="25" /><Token Text=":=" UId="26" /><Blank UId="27" />
<Access Scope="LocalVariable" UId="28"><Symbol UId="29"><Component Name="inVal" UId="30" /></Symbol></Access>
<Token Text=";" UId="31" />
<NewLine UId="32" />
</StructuredText></NetworkSource>
          <ProgrammingLanguage>SCL</ProgrammingLanguage>
        </AttributeList>
        <ObjectList>
          <MultilingualText ID="4" CompositionName="Comment"><ObjectList><MultilingualTextItem ID="5" CompositionName="Items"><AttributeList><Culture>de-DE</Culture><Text /></AttributeList></MultilingualTextItem></ObjectList></MultilingualText>
          <MultilingualText ID="6" CompositionName="Title"><ObjectList><MultilingualTextItem ID="7" CompositionName="Items"><AttributeList><Culture>de-DE</Culture><Text /></AttributeList></MultilingualTextItem></ObjectList></MultilingualText>
        </ObjectList>
      </SW.Blocks.CompileUnit>
      <MultilingualText ID="8" CompositionName="Title"><ObjectList><MultilingualTextItem ID="9" CompositionName="Items"><AttributeList><Culture>de-DE</Culture><Text /></AttributeList></MultilingualTextItem></ObjectList></MultilingualText>
    </ObjectList>
  </SW.Blocks.FC>
</Document>
```

---

## Tokenized SCL Element Reference

### Variable Access

```xml
<!-- LocalVariable (interface params) -->
<Access Scope="LocalVariable" UId="N">
  <Symbol UId="N+1"><Component Name="varName" UId="N+2" /></Symbol>
</Access>

<!-- GlobalVariable — DB fields -->
<Access Scope="GlobalVariable" UId="N">
  <Symbol UId="N+1"><Component Name="DB_Name" UId="N+2"><Component Name="Field" UId="N+3" /></Component></Symbol>
</Access>

<!-- GlobalVariable — PLC tag -->
<Access Scope="GlobalVariable" UId="N">
  <Symbol UId="N+1"><Component Name="TagName" UId="N+2" /></Symbol>
</Access>
```

⛔ **FC 中绝对不能使用 GlobalVariable 访问 DB 变量** — 仅 InOut 参数。

### Literal Constants

```xml
<Access Scope="LiteralConstant" UId="N">
  <Constant UId="N+1"><ConstantValue UId="N+2">true</ConstantValue></Constant>
</Access>
```

### Operators & Control Flow

| SCL | XML |
|-----|-----|
| `:=` `;` `AND` `OR` `NOT` `+` `(` `)` | `<Token Text="..." UId="N" />` |
| `IF` `THEN` `ELSE` `ELSIF` `END_IF` | `<Token Text="..." UId="N" />` |

### Whitespace

```xml
<Blank UId="N" />     <!-- 单空格 -->
<NewLine UId="N" />   <!-- 换行 -->
```

### CallInfo (FC/FB 调用)

> ⚠️ **ImportBlock 硬限制：** 通过 `ImportBlock` XML 导入时，`<CallInfo>` **不能包含 `<Parameter>` 子元素**（无论 OB 还是 FC 都会失败）。需要参数传递请使用 `ImportExternalSource` 的 .scl 文件方式。

```xml
<!-- ✅ ImportBlock 中允许的形式：无参数调用 -->
<Access Scope="Call" UId="N">
  <CallInfo Name="FC_TargetName" BlockType="FC" UId="N+1" />
</Access>
<Token Text=";" UId="N+2" />
```

```xml
<!-- ❌ ImportBlock 中禁止的形式：含 Parameter 子元素，会导致导入失败 -->
<!-- 此模式仅在 ImportExternalSource (.scl) 方式中可用 -->
<Access Scope="Call" UId="N">
  <CallInfo Name="FC_TargetName" BlockType="FC" UId="N+1">
    <Parameter Name="Param1" Section="Input" Type="Bool" UId="N+2">
      <Access Scope="LocalVariable" UId="N+3">
        <Symbol UId="N+4"><Component Name="sourceVar" UId="N+5" /></Symbol>
      </Access>
    </Parameter>
  </CallInfo>
</Access>
```

---

## UId Numbering

| Range | Reserved For |
|-------|-------------|
| 1-20 | DocumentInfo, AttributeList 结构元素 |
| 21+ | StructuredText 内容 |
| All | 全局唯一（FBD 的 FlgNet 也从 21 开始） |

---

## Global DB: s7dcl Format

```s7dcl
{
    S7_Optimized := "TRUE";
    S7_StandardRetain := "FALSE"
}
DATA_BLOCK DB_Name
    VAR
        bFlag : Bool;
        iCounter : Int;
        rValue : Real;
    END_VAR
END_DATA_BLOCK
```

Import: `ImportFromDocuments(softwarePath="PLC_1", groupPath="", importPath="C:\\path\\to\\docs", fileNameWithoutExtension="DB_Name")`

---

## PLC Tag Table

支持通过 MCP 导入/导出 PLC 变量表，替代了之前「标签必须手动创建」的限制。

### 导出变量表（获取模板/备份）

```
ExportTagTable(softwarePath="PLC_1", exportPath="C:\\export.xml", tagTableName="")
```

- `tagTableName` 留空则导出第一个变量表
- 注意：德文/中文项目的默认变量表名可能是 `Standard-Variablentabelle` 而非 `Default tag table`

### 导入变量表

```
ImportTagTable(softwarePath="PLC_1", importPath="C:\\tags.xml")
```

### XML 模板

```xml
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <Engineering version="V20" />
  <DocumentInfo>
    <Created>2026-05-21T12:00:00Z</Created>
    <ExportSetting>WithDefaults</ExportSetting>
    <InstalledProducts>
      <Product><DisplayName>Totally Integrated Automation Portal</DisplayName><DisplayVersion>V20</DisplayVersion></Product>
      <OptionPackage><DisplayName>TIA Portal Openness</DisplayName><DisplayVersion>V20</DisplayVersion></OptionPackage>
      <Product><DisplayName>STEP 7 Professional</DisplayName><DisplayVersion>V20</DisplayVersion></Product>
    </InstalledProducts>
  </DocumentInfo>
  <SW.Tags.PlcTagTable ID="0">
    <AttributeList>
      <Name>MyTagTable</Name>
    </AttributeList>
    <ObjectList>
      <SW.Tags.PlcTag ID="1" CompositionName="Tags">
        <AttributeList>
          <DataTypeName>Bool</DataTypeName>
          <ExternalAccessible>true</ExternalAccessible>
          <ExternalVisible>true</ExternalVisible>
          <ExternalWritable>true</ExternalWritable>
          <LogicalAddress>%M0.0</LogicalAddress>
          <Name>bFlag</Name>
        </AttributeList>
        <ObjectList>
          <MultilingualText ID="2" CompositionName="Comment">
            <ObjectList><MultilingualTextItem ID="3" CompositionName="Items"><AttributeList><Culture>de-DE</Culture><Text>Description</Text></AttributeList></MultilingualTextItem></ObjectList>
          </MultilingualText>
        </ObjectList>
      </SW.Tags.PlcTag>
    </ObjectList>
  </SW.Tags.PlcTagTable>
</Document>
```

### 标签属性参考

| 属性 | 说明 | 示例 |
|------|------|------|
| `Name` | 标签名称 | `bSensor` |
| `DataTypeName` | 数据类型 | `Bool`, `Int`, `Real`, `Word` |
| `LogicalAddress` | PLC 地址 | `%M0.0`, `%I0.2`, `%Q0.0`, `%MW2` |
| `ExternalAccessible` | HMI 可访问 | `true` / `false` |
| `ExternalVisible` | HMI 可见 | `true` / `false` |
| `ExternalWritable` | HMI 可写 | `true` / `false` |

### 地址格式

| 格式 | 含义 |
|------|------|
| `%I0.0` | Input bit |
| `%Q0.0` | Output bit |
| `%M0.0` | Memory bit |
| `%MW2` | Memory word (16-bit) |
| `%MD4` | Memory double word (32-bit) |

---

## Common Failure Patterns

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| "Project is null" | MCP 重启后未重连项目 | `Connect → OpenProject` |
| ImportBlock fails, no error | CallInfo 含 Parameter 子元素 | 改用 `ImportExternalSource` (.scl) |
| ImportBlock fails, no error | Missing `<AutoNumber>false</AutoNumber>` (SCL blocks) | Add to AttributeList |
| ImportExternalSource fails | .scl 文件无 BOM | 添加 UTF-8 BOM (239,187,191) |
| ImportExternalSource fails | 外部源名称已存在 | 使用新文件名 |
| ImportExternalSource fails | OB 名称与已有块冲突 | 使用唯一 OB 名称 |
| ImportExternalSource fails | .scl 语法错误 | 增量测试（先 1 个 FC 调用，逐步增加） |
| FBD OB import fails | InstalledProducts 不足 12 项 | 使用完整 12 项列表 |
| FBD OB import fails | 多余 `<AutoNumber>` 元素 | 删除（FBD OB 不要此元素） |
| Import fails, no error | `Culture` is `zh-CN` | Use `de-DE` in ALL MultilingualTextItem |
| Import fails, no error | StructuredText uses `v3` | Use `...StructuredText/v4` |
| Import fails, no error | StructuredText doesn't start with `<NewLine>` | Add `<NewLine UId="21" />` first |
| Import fails, no error | OB missing `SecondaryType` | Add `<SecondaryType>ProgramCycle</SecondaryType>` |
| Import fails, no error | OB missing `Initial_Call`/`Remanence` | Add informative members in Input |
| Import fails, no error | FC has GlobalVariable to DB | Redesign to InOut only |
| Import fails, no error | FC `<Number>` already exists | Change to unused number |
| ImportFromDocuments fails | Trying to import OB (LAD/FBD) | ❌ 不支持 OB 的 s7dcl 导入 |
| isConsistent:false after compile | Interface/Code mismatch | Check all Members used in StructuredText |
| Blocks gone after reopen | Did not call `SaveProject` | ALWAYS call `SaveProject` after `CompileSoftware` |
| ImportTagTable fails | Tag table name mismatch | Export first to check actual name |
| Compile fails with OB isConsistent:false | 旧的 OB 破坏且无法覆盖 | 创建新 OB（不同名称），手动在 TIA Portal 中删除旧 OB |
| CompileSoftware "No result returned" | 项目处于在线模式 | 先在 TIA Portal 中 Go offline |
| SaveProject "not permitted in online mode" | 项目处于在线模式 | 先在 TIA Portal 中 Go offline |
| ExportBlocks 返回 0 blocks | 块 isConsistent=false | 先修复编译错误使块一致 |
| Q变量全部无响应 | FC编译失败(isConsistent=false)导致OB不执行 | 修复FC编译错误，重新编译所有块 |
| 传送带启动后瞬间停止 | bMaterialDetected在同一周期被置位又清除 | 移除检测FC中的清除逻辑，改在处理链末端清除 |
| I变量正常但Q变量全不响应 | 程序逻辑链断裂（关键FC未编译/OB未调用） | 检查GetBlocks中所有块的isConsistent和CompileDate |
| 多个ProgramCycle OB冲突 | 两个OB对同一DB变量写入 | 只保留一个主OB，删除冗余OB |

---

## MCP Tool Summary

| Tool | Use For | Key Params |
|------|---------|-----------|
| `Connect` | 连接 TIA Portal | — |
| `OpenProject` | 打开本地项目 | `path`（需含 .apXX 扩展名，如 `C:\...\Project.ap20`） |
| `GetSoftwareTree` | 软件结构树 | `softwarePath` |
| `GetBlocks` | 列出块 / 检查一致性 | `softwarePath`, `regexName` |
| `GetBlockInfo` | 查看块属性详情 | `softwarePath`, `blockPath` |
| `ImportBlock` | 导入 SCL FC/FB XML；OB XML（仅无参数调用） | `softwarePath`, `groupPath`, `importPath` |
| `ImportExternalSource` ⭐ | **导入 .scl 源文件 — OB 带参数方案** | `softwarePath`, `importPath` |
| `ImportFromDocuments` | 导入 DB s7dcl / LAD FC/FB s7dcl（⚠️不支持 OB） | `softwarePath`, `groupPath`, `importPath`, `fileNameWithoutExtension` |
| `GenerateBlocksFromSource` | 从已导入源文件生成块 (V20+) | `softwarePath`, `sourceName` |
| `ImportTagTable` | 导入 PLC 变量表 | `softwarePath`, `importPath` |
| `ExportTagTable` | 导出 PLC 变量表 | `softwarePath`, `exportPath`, `tagTableName` |
| `ExportBlock` | 导出单个块 | `softwarePath`, `blockPath`, `exportPath` |
| `ExportBlocks` | 导出所有块 | `softwarePath`, `exportPath` |
| `CompileSoftware` | 编译 PLC | `softwarePath` |
| `SaveProject` | **必须：保存项目** | — |
| `Disconnect` | 断开连接 | — |

---

## MCP Capability Gaps (Manual Steps Required)

以下操作无法通过 MCP 完成，需在 TIA Portal 中手动执行：

1. **删除块 / 删除变量表** — 无 MCP Delete 工具
2. **编辑 FBD/LAD 网络** — 可导入不可在线编辑（需在 TIA Portal 图形编辑器操作）
3. **覆盖已有 OB 块** — 无法删除/覆盖同名 OB，需创建新名称 OB 后手动清理

> 变量表（PLC Tags）现在可通过 `ImportTagTable` / `ExportTagTable` 批量管理，不再需要逐个手动创建。