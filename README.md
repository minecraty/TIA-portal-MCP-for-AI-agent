# TIA Portal MCP Server

基于 Model Context Protocol (MCP) 的西门子 TIA Portal 服务端，使 AI 编码助手（如 Trae、Claude、VS Code Copilot）能够直接与 TIA Portal 交互，执行项目管理、程序块导入导出、编译等操作。

> 本项目基于 [J.Heilingbrunner](https://github.com/JHeilingbrunner) 的 TIA Portal MCP Server 开源项目构建，采用 MIT 许可证（详见 [LICENSE.txt](LICENSE.txt)）。

## 架构

```
AI 编码助手 (Trae / Claude / VS Code)
        │ MCP JSON-RPC (stdio)
        ▼
  TiaMcpServer.exe (.NET Framework 4.8)
        │ Siemens Openness API
        ▼
    TIA Portal V20
```

所有通信通过 MCP stdio 传输，无需网络配置。

## 环境要求

| 组件 | 说明 |
|------|------|
| Windows 10 / 11 | 操作系统 |
| .NET Framework 4.8 | 运行时 |
| .NET Framework 4.8 Developer Pack | 编译时需要 |
| TIA Portal V20 | 需安装并至少运行过一次 |
| Siemens TIA Openness 用户组 | 当前用户需在此 Windows 用户组中 |
| 环境变量 `TiaPortalLocation` | 设置为 `C:\Program Files\Siemens\Automation\Portal V20` |

## 快速开始
vm-setup文件中有具体说明
### 1. 编译

```powershell
dotnet build src/TiaMcpServer/TiaMcpServer.csproj -c Release
```

编译输出：`src/TiaMcpServer/bin/Release/net48/TiaMcpServer.exe`

### 2. 运行

```powershell
.\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe
```

### 3. 命令行参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `--tia-major-version` | TIA Portal 主版本号（默认 20） | `--tia-major-version 19` |
| `--logging` | 日志模式：1=stderr, 2=Debug输出, 3=Windows事件日志 | `--logging 1` |

## 配置 AI 助手

### Trae

在 Trae MCP 设置中添加：

```json
{
    "mcpServers": {
        "tiaportal-mcp": {
            "command": "C:\\path\\to\\TiaMcpServer.exe",
            "args": ["--tia-major-version", "20"],
            "env": {}
        }
    }
}
```

或使用 `vm-setup/generate-trae-config.ps1` 脚本自动生成配置。

### Claude Desktop

编辑 `%APPDATA%\Claude\claude_desktop_config.json`：

```json
{
    "mcpServers": {
        "tiaportal-mcp": {
            "command": "<path-to>\\TiaMcpServer.exe",
            "args": [],
            "env": {}
        }
    }
}
```

### VS Code

配置示例见 `samples/vscode/mcp.json`。

## MCP 工具列表

> 测试状态标记：✅ 已验证通过 | ⚠️ 部分场景异常 | ❌ 已知问题

### 连接管理

| 工具 | 功能 | 状态 |
|------|------|:----:|
| `Connect` | 连接到 TIA Portal（附加运行中实例或启动新实例） | ✅ |
| `Disconnect` | 断开与 TIA Portal 的连接 | ✅ |
| `GetState` | 获取当前连接状态和项目信息 | ✅ |

### 项目管理

| 工具 | 功能 | 状态 |
|------|------|:----:|
| `OpenProject` | 打开项目 (.apXX) 或会话 (.alsXX) | ✅ |
| `CloseProject` | 关闭当前项目/会话 | ✅ |
| `SaveProject` | 保存当前项目/会话 | ✅ |
| `SaveAsProject` | 将项目另存为新路径 | ✅ |
| `GetProjectTree` | 获取项目结构树状视图 | ✅ |
| `GetProject` | 获取已打开的项目/会话列表 | ❌ |

### 设备管理

| 工具 | 功能 | 状态 |
|------|------|:----:|
| `CreateDevice` | 创建新设备 | ✅ |
| `GetDevices` | 获取所有设备列表 | ❌ |
| `GetDeviceInfo` | 获取指定设备信息 | ❌ |
| `GetDeviceItemInfo` | 获取设备子项信息 | ❌ |

### PLC 软件

| 工具 | 功能 | 状态 |
|------|------|:----:|
| `GetSoftwareInfo` | 获取 PLC 软件信息 | ✅ |
| `GetSoftwareTree` | 获取 PLC 软件块和类型结构树 | ✅ |
| `CompileSoftware` | 编译 PLC 程序（支持安全程序密码） | ✅ |

### 程序块 (Blocks)

| 工具 | 功能 | 状态 |
|------|------|:----:|
| `GetBlocks` | 获取块列表（支持正则过滤） | ✅ |
| `GetBlocksWithHierarchy` | 获取带层级结构的块列表 | ✅ |
| `GetBlockInfo` | 获取单个块详细信息 | ✅ |
| `ExportBlock` | 导出单个块为 XML 文件 | ✅ |
| `ExportBlocks` | 批量导出块（含进度通知） | ✅ |
| `ImportBlock` | 从 XML 文件导入块 | ⚠️ |

### 数据类型 (Types / UDT)

| 工具 | 功能 | 状态 |
|------|------|:----:|
| `GetTypes` | 获取类型列表（支持正则过滤） | ✅ |
| `GetTypeInfo` | 获取单个类型信息 | ✅ |
| `ExportType` | 导出单个类型 | ✅ |
| `ExportTypes` | 批量导出类型（含进度通知） | ✅ |
| `ImportType` | 从 XML 文件导入类型 | ✅ |

### 文档格式导入导出 (V20+)

| 工具 | 功能 | 状态 |
|------|------|:----:|
| `ExportAsDocuments` | 导出块为 SIMATIC SD 文档 (.s7dcl/.s7res) | ✅ |
| `ExportBlocksAsDocuments` | 批量导出块为文档格式 | ✅ |
| `ImportFromDocuments` | 从文档导入单个块 | ✅ |
| `ImportBlocksFromDocuments` | 批量从文档导入块 | ✅ |

### 外部源文件 (V20+)

| 工具 | 功能 | 状态 |
|------|------|:----:|
| `ImportExternalSource` | 导入 SCL 源文件 (.scl) 并自动生成块 | ✅ |
| `GenerateBlocksFromSource` | 从已导入的外部源生成程序块 | ✅ |

### 变量表

| 工具 | 功能 | 状态 |
|------|------|:----:|
| `ExportTagTable` | 导出 PLC 变量表 | ✅ |
| `ImportTagTable` | 导入 PLC 变量表 | ✅ |

## softwarePath 参数说明

所有 PLC 软件相关工具（`GetBlocks`、`GetSoftwareInfo`、`CompileSoftware`、`ImportBlock` 等）都需要 `softwarePath` 参数来定位 PLC 软件。路径格式取决于设备类型：

### 硬件 PLC（S7-1200 / S7-1500 等）

使用设备名称作为路径，与 TIA Portal 项目树中显示的设备名一致：

```
softwarePath = "PLC_1"
softwarePath = "S7-1500_1"
```

> 系统会自动在设备及其子项中递归查找 `SoftwareContainer`，无需指定 CPU 名称。

### PC-based PLC

使用两段路径：`设备名/CPU名`：

```
softwarePath = "PC-System_1/CPU_1"
```

### 设备组内的设备

如果设备位于分组中，路径需包含组名：

```
softwarePath = "Group1/PLC_1"
```

### 获取正确的 softwarePath

最可靠的方式是通过 `GetProjectTree` 查看项目结构，找到标记为 `[PLC Program]` 的节点，其父级设备名即为 `softwarePath`。

## 导入格式与工具选择

### 块类型 → 推荐方式速查

| 块类型 | 推荐格式 | 导入工具 | 备注 |
|--------|----------|----------|------|
| **OB（带参数调用 FC/FB）** | `.scl` 源文件 (UTF-8 BOM) | `ImportExternalSource` | ⭐ **唯一可行方案**，自动生成块 |
| **OB（无参数调用 FC/FB）** | FBD/SCL XML | `ImportBlock` | `<CallInfo>` 不含 `<Parameter>` |
| **SCL FC / FB** | `.scl` 源文件 | `ImportExternalSource` | V20+，推荐方式，无需 Token 化 |
| **SCL FC / FB** | XML Tokenized | `ImportBlock` | FC 仅 InOut 接口；FB 可直接访问 DB |
| **LAD FC / FB** | s7dcl + s7res | `ImportFromDocuments` | 可用 CALL 指令 |
| **Global DB** | s7dcl + s7res | `ImportFromDocuments` | 变量名仅 ASCII |
| **PLC 变量表** | XML | `ImportTagTable` / `ExportTagTable` | 支持 I/Q/M 批量管理 |

### OB 导入决策流程

```
需要 OB 调用 FC/FB？
├── 需要传参数？
│   └── YES → ImportExternalSource (.scl) ⭐ 唯一方案
└── 不需要传参数？
    ├── 需要可视化编辑？ → ImportBlock (FBD XML)
    └── 纯文本可接受？   → ImportBlock (SCL XML) 或 ImportExternalSource
```

> ⚠️ **关键限制：** `ImportBlock` 的 `<CallInfo>` 不支持 `<Parameter>` 子元素（无论 OB 还是 FC）。需要参数传递时必须使用 `ImportExternalSource` (.scl) 方式。

### .scl 文件编码与命名要求

- `ImportExternalSource` 要求 `.scl` 文件必须使用 **UTF-8 with BOM** 编码（文件头 `EF BB BF`）
- 每次导入必须使用不同的文件名（如 `Main_v1.scl` → `Main_v2.scl`），否则同名外部源冲突

### ImportBlock XML 格式要求

- XML 必须由 TIA Portal 导出生成，手动编写的 XML 极易因格式不兼容而静默失败
- 所有 `MultilingualTextItem` 的 `Culture` 必须使用项目已安装的语言（通常为 `de-DE`），使用未安装的 culture（如 `zh-CN`）会导致导入失败
- `InstalledProducts` 列表应包含完整条目

### ExportTagTable / ImportTagTable 注意事项

- `ExportTagTable` 的 `exportPath` 需指定完整文件路径（如 `C:\exports\tags.xml`），不能是已存在的目录
- `ImportTagTable` 的 XML 中 `MultilingualTextItem` 的 `Culture` 必须与项目语言一致
- 推荐先用 `ExportTagTable` 导出获取正确格式，再基于该格式修改后导入

## 标准工作流程

### 推荐流程

```
1. Connect
2. OpenProject(C:\path\to\Project.ap20)   ← 注意完整扩展名！
3. GetProjectTree                           ← 确认项目结构和设备名
4. GetSoftwareTree(softwarePath)            ← 确认 PLC 软件状态
5. ImportFromDocuments (DB 优先)
6. ImportBlock (FC, 无参数调用的 OB)
7. ImportExternalSource (OB .scl, 带参数方案 ⭐)
8. ImportTagTable / ExportTagTable (变量表管理)
9. CompileSoftware(softwarePath)
10. GetBlocks → 验证 isConsistent:true
11. SaveProject  ← 绝对不要跳过！
```

### MCP 重启恢复流程

MCP 服务重启后必须重新连接项目：

```
1. Connect
2. OpenProject("C:\path\to\Project.ap20")
3. 重新导入 + 编译 + SaveProject
```

### 关键注意事项

| 注意事项 | 说明 |
|----------|------|
| **导入后立即保存** | TIA Portal MCP 导入不会自动持久化，必须 `SaveProject` |
| **在线模式限制** | Go online 状态下无法 `CompileSoftware` 和 `SaveProject`，修改前必须 Go offline |
| **OB 名称不可覆盖** | MCP 无法删除/覆盖已存在的 OB 块，需使用新名称 |
| **isConsistent=false 的块** | 不一致的块无法通过 `ExportBlocks` 导出，必须先修复 |
| **.scl 文件名必须唯一** | `ImportExternalSource` 使用文件名作为源名称，重复会失败 |
| **s7dcl 不支持中文** | DB 和 LAD 的 s7dcl 格式必须使用英文/拼音变量名 |
| **编译后 isConsistent 变为 true** | 新导入的块 isConsistent=false，编译成功后变为 true |

## PLC 程序验证框架

构建 PLC 程序后，建议按以下框架系统性验证：

### 验证速查表

```
□ Step 1: GetBlocks → 所有块 isConsistent=true?
  └─ No → CompileSoftware → 仍 false? → 重新导入块源码

□ Step 2: 追踪每个状态标志的置位→使用→清除生命周期
  └─ 置位和清除可能同周期? → 改为末端清除模式

□ Step 3: 传感器-执行器时序 → 标志是否在终点清除?
  └─ 在起点清除? → 改为终点传感器触发后才清除

□ Step 4: 互斥状态 → ELSIF? 无已有状态前置条件?
  └─ 独立 IF? → 改为 ELSIF + 前置条件

□ Step 5: 初始化守卫 → bFirstScan 在 DB InOut? 初始值 false?

□ Step 6: OB 架构 → 单一主 OB? FC 调用完整? Q 映射在末尾?
  └─ 多个 ProgramCycle OB? → 合并为一个

□ 最终: CompileSoftware → GetBlocks(全 consistent) → SaveProject
```

### 症状 → 验证映射

| 症状 | 首先验证 | 根因概率 |
|------|---------|---------|
| I 变量正常，Q 变量全不响应 | 编译一致性 + OB 是否调用 FC | 高 |
| 输出瞬间动作又停止 | 标志同周期置位-清除冲突 | 高 |
| 传送带/机构启动后立即停止 | 传感器位置差异（离开起点就清除标志） | 高 |
| 状态被错误切换 | 互斥与覆盖（缺少前置条件） | 高 |
| 变量每周期被重置 | 初始化守卫（bFirstScan 可能在 VAR_TEMP） | 中 |
| 输出闪烁/不稳定 | 多个 ProgramCycle OB 冲突 | 中 |

## 项目结构

```
├── .trae/skills/                 # Trae Agent 技能定义
│   └── tia-portal-block-import/  # TIA Portal 块导入技能
├── docs/
│   └── error-model.md            # 错误处理模型文档
├── samples/                      # 客户端配置示例
│   ├── claude/                   # Claude Desktop 配置
│   └── vscode/                   # VS Code 配置
├── src/TiaMcpServer/             # MCP 服务端源码
│   ├── ModelContextProtocol/     # MCP 协议实现层
│   │   ├── McpServer.cs          # MCP 工具定义
│   │   ├── McpPrompts.cs         # MCP 提示词
│   │   ├── Responses.cs          # 响应类型定义
│   │   ├── Types.cs              # 数据类型定义
│   │   └── Helper.cs             # 辅助方法
│   ├── Siemens/                  # TIA Portal API 封装层
│   │   ├── Portal.cs             # 高层 Portal API
│   │   ├── Openness.cs           # Openness API 包装
│   │   ├── Engineering.cs        # 工程版本管理
│   │   ├── State.cs              # 状态模型
│   │   ├── PortalException.cs    # Portal 异常类型
│   │   └── PortalErrorCode.cs    # 错误码枚举
│   ├── Program.cs                # 程序入口
│   ├── CliOptions.cs             # 命令行参数解析
│   └── TiaMcpServer.csproj       # 项目文件
├── tests/TiaMcpServer.Test/      # 单元测试
├── vm-setup/                     # 虚拟机部署脚本
├── LICENSE.txt                   # MIT 许可证
└── TiaMcpServer.sln              # 解决方案文件
```

## 错误处理

- Portal 层通过 `PortalException` 抛出结构化异常，附带 `PortalErrorCode` 和上下文元数据
- MCP 层将 Portal 错误映射为 MCP 标准错误码（`InvalidParams`、`InternalError` 等）
- 批量操作支持进度通知和部分失败聚合
- 详细错误模型见 `docs/error-model.md`

## 已知限制与 MCP 能力边界

### 导入限制

- **`ImportBlock` 不支持带参数的 FC/FB 调用**：`<CallInfo>` 不能包含 `<Parameter>` 子元素，参数传递需用 `ImportExternalSource`
- **`ImportBlock` 对手写 XML 兼容性差**：建议使用 TIA Portal 导出的 XML 作为模板，手动编写极易因格式问题静默失败
- **LAD 块 s7dcl 导入**：需要配套 `.s7res` 文件含所有条目的 en-US 标签（TIA Portal Openness 已知限制）
- **ImportFromDocuments 不支持 OB**：任何 OB 类型的 s7dcl 导入均会失败
- **.scl 文件 UTF-8 BOM 必须**：无 BOM 会导致 `ImportExternalSource` 失败
- **OB 名称无法覆盖**：MCP 无法删除/覆盖已存在的 OB 块
- **变量表 Culture 限制**：`ImportTagTable` 的 XML 中 `Culture` 必须与项目已安装语言一致

### 运行时限制

- **在线模式 (Go online)** 下无法 `CompileSoftware`（返回 "No result returned"）和 `SaveProject`（返回 "The operation is not permitted in online mode"）
- **ExportBlock**：`blockPath` 必须使用完整路径格式 `Group/Subgroup/Name`
- **ExportTagTable**：`exportPath` 需指定完整文件路径，不能是已存在的目录
- **导出为文档** 和 **从文档导入** 需要 TIA Portal V20+
- **isConsistent=false 的块无法通过 `ExportBlocks` 导出**
- **空项目编译**：无任何块的项目执行 `CompileSoftware` 可能返回 "No result returned"

### 已知工具异常

| 工具 | 问题 | 影响 |
|------|------|------|
| `GetProject` | 调用时抛出内部异常 | 无法获取已打开项目列表，可用 `GetState` 替代 |
| `GetDevices` | 调用时抛出内部异常 | 无法获取设备列表，可用 `GetProjectTree` 替代 |
| `GetDeviceInfo` | 调用时抛出内部异常 | 无法获取设备详情，可用 `GetProjectTree` 替代 |
| `GetDeviceItemInfo` | 调用时抛出内部异常 | 无法获取设备子项详情 |
| `ImportBlock` | 手写 XML 格式不兼容时静默失败 | 建议使用 TIA 导出的 XML 作为模板 |

### MCP 无法完成的操作（需在 TIA Portal 中手动执行）

| 操作 | 替代方案 |
|------|---------|
| 删除块 / 删除变量表 | 无 MCP Delete 工具，需在 TIA Portal 中手动删除 |
| 编辑 FBD/LAD 网络 | 可导入但不可在线编辑，需在 TIA Portal 图形编辑器操作 |
| 覆盖已有 OB 块 | 无法删除/覆盖同名 OB，需创建新名 OB 后手动清理 |

## 常见问题速查

| 症状 | 根因 | 解决方案 |
|------|------|---------|
| "Project is null" | MCP 重启后未重连项目 | `Connect → OpenProject` |
| "Software not found" | `softwarePath` 不正确 | 用 `GetProjectTree` 查看设备名，硬件 PLC 用设备名（如 `PLC_1`） |
| `ImportExternalSource` 失败 | .scl 无 UTF-8 BOM 或文件名已存在 | 添加 BOM，使用新文件名 |
| `ImportBlock` 无报错但失败 | CallInfo 含 Parameter 子元素 | 改用 `ImportExternalSource` (.scl) |
| `ImportBlock` XML 导入失败 | 手写 XML 格式不兼容 | 使用 TIA Portal 导出的 XML 作为模板 |
| `ImportTagTable` Culture 错误 | XML 中 Culture 与项目不匹配 | 先 `ExportTagTable` 获取正确格式再修改 |
| `CompileSoftware` 无结果返回 | 项目处于 Go online 模式或空项目 | 先 Go offline，确保项目有块 |
| `SaveProject` 不允许在线 | 项目处于 Go online 模式 | 先在 TIA Portal 中 Go offline |
| `ExportBlocks` 返回 0 blocks | 块 isConsistent=false | 先 `CompileSoftware` 使块一致 |
| `ExportTagTable` 目录已存在 | `exportPath` 指向已存在目录 | 改为完整文件路径（如 `C:\out\tags.xml`） |
| 重启后块丢失 | 未调用 `SaveProject` | 每次编译后必须 `SaveProject` |
| `GetDevices` / `GetProject` 报错 | Siemens API 内部异常 | 使用 `GetProjectTree` 或 `GetState` 替代 |

## 具体部署

`vm-setup/` 目录提供环境配置脚本，MCP 服务端直接使用项目中的 TiaMcpServer.exe 与 TIA Portal Openness API 通信，无需额外编译部署：

```powershell
cd vm-setup
.\setup-vm.ps1              # 配置运行环境（管理员权限）
dotnet build ..\src\TiaMcpServer -c Release  # 编译
.\test-local-mcp.ps1        # 验证安装
```

详细说明见 `vm-setup/README.md`。

## 构建与测试

```powershell
# 构建
dotnet build

# 运行测试（需 TIA Portal V20 环境）
dotnet test
```

测试需要 TIA Portal V20 环境及相关许可证，详见 `tests/TiaMcpServer.Test/README.md`。

## 许可证

本项目基于 MIT 许可证开源，版权归 [J.Heilingbrunner](https://github.com/JHeilingbrunner) 所有。

```
MIT License

Copyright (c) 2025 J.Heilingbrunner
```

完整许可证文本见 [LICENSE.txt](LICENSE.txt)。

## 贡献

- 遵循项目代码风格：C# 四空格缩进、大括号换行、PascalCase/camelCase 命名
- 新 MCP 工具放置于 `ModelContextProtocol/`，Siemens API 封装放置于 `Siemens/`
- 测试执行策略：仅在用户明确确认后运行依赖 TIA Portal 环境的测试
- 更多指南见根目录 `AGENTS.md`