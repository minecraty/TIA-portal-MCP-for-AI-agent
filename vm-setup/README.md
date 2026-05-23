# TIA Portal MCP - 本地部署指南

## 概述

本项目通过 MCP (Model Context Protocol) 将 AI 编码助手（Trae、Claude 等）与西门子 TIA Portal 连接，使 AI 能够直接操作和控制 TIA Portal。

**架构说明：** MCP 服务端（TiaMcpServer.exe）在虚拟机本地运行，通过 Siemens Openness API 直接与 TIA Portal V20 通信，无需额外编译部署或 SSH 中转。MCP 使用 stdio 传输协议，Agent 通过启动 exe 子进程即可完成所有交互。

## 环境要求

| 组件 | 要求 |
|------|------|
| Windows 10 / 11 | 操作系统 |
| TIA Portal V20 | 已安装并至少运行过一次 |
| .NET Framework 4.8 | 运行时 |
| .NET Framework 4.8 Developer Pack | 编译时需要 |
| Trae / Claude / VS Code | 最新版本 |

## 快速部署（3 步）

### 第 1 步：环境配置

以**管理员**身份打开 PowerShell，运行：

```powershell
cd C:\path\to\tiaportal-mcp-main\vm-setup
.\setup-vm.ps1
```

此脚本自动完成：
- 检测 .NET Framework 4.8
- 检测 Developer Pack（编译所需）
- 检测 TIA Portal V20 安装
- 设置 `TiaPortalLocation` 环境变量
- 将用户添加到 `Siemens TIA Openness` 组

### 第 2 步：编译 MCP 服务端

```powershell
cd C:\path\to\tiaportal-mcp-main
dotnet build src\TiaMcpServer\TiaMcpServer.csproj -c Release
```

编译输出：`src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe`

### 第 3 步：验证安装

```powershell
.\test-local-mcp.ps1
```

所有测试通过即表示部署成功。

## 配置 Trae

### 方法 1：自动生成配置

```powershell
.\generate-trae-config.ps1
```

脚本自动生成 `trae-mcp-config.json`，复制其内容到 Trae MCP 设置即可。

### 方法 2：手动配置

在 Trae MCP 设置中添加：

```json
{
    "mcpServers": {
        "tiaportal-mcp": {
            "command": "C:\\path\\to\\tiaportal-mcp-main\\src\\TiaMcpServer\\bin\\Release\\net48\\TiaMcpServer.exe",
            "args": ["--tia-major-version", "20"],
            "env": {}
        }
    }
}
```

TiaMcpServer.exe 直接通过 Siemens Openness API 与 TIA Portal 通信，无需网络配置。

## 可用脚本

| 脚本 | 功能 | 说明 |
|------|------|------|
| `setup-vm.ps1` | 配置运行环境 | 首次部署时以管理员身份运行 |
| `test-local-mcp.ps1` | 测试 MCP 服务器 | 验证安装是否成功 |
| `check-environment.ps1` | 检查环境 | 诊断环境问题 |
| `generate-trae-config.ps1` | 生成配置 | 自动生成 Trae MCP 配置 JSON |
| `verify-mcp.ps1` | 验证 MCP | 详细验证 MCP 功能 |
| `check-tia.ps1` | 检查 TIA Portal | 检查 TIA Portal 运行状态 |
| `check-openness.ps1` | 检查 Openness | 检查 Openness API 可用性 |
| `set-tia-env.ps1` | 设置环境变量 | 手动设置 TiaPortalLocation |

## 使用示例

配置完成后，在 Trae 中输入自然语言指令即可控制 TIA Portal：

```
连接到 TIA Portal
打开项目 C:\Projects\MyProject.ap20
获取项目结构
编译软件
导出程序块到 C:\Exports
```

## 常见问题

### Q1: 用户不在 Siemens TIA Openness 组

1. 确保已运行过 TIA Portal（这会创建用户组）
2. 以管理员身份运行 `setup-vm.ps1`
3. 注销并重新登录 Windows

### Q2: MCP 服务器未找到

```powershell
.\check-environment.ps1
```
确认已执行编译步骤：
```powershell
dotnet build src\TiaMcpServer\TiaMcpServer.csproj -c Release
```

### Q3: Trae 中 MCP 工具不显示

1. 检查 MCP 配置 JSON 格式是否正确
2. 确认 exe 路径指向项目中的 `src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe`
3. 重启 Trae

### Q4: 连接 TIA Portal 失败

1. 确保虚拟机有显示（TIA Portal 需要 UI）
2. 尝试手动启动 TIA Portal
3. 检查 TIA Portal 版本是否匹配（默认 V20）
4. 检查 `TiaPortalLocation` 环境变量是否正确

## TIA Portal 版本

默认使用 TIA Portal V20。如需其他版本：

```powershell
.\setup-vm.ps1 -TiaMajorVersion 19
.\test-local-mcp.ps1 -TiaMajorVersion 19
.\generate-trae-config.ps1 -TiaMajorVersion 19
```

## 技术说明

### MCP 通信

MCP 服务器使用 stdio 传输协议：
- 输入：JSON-RPC 请求（stdin）
- 输出：JSON-RPC 响应（stdout）
- 日志：调试信息（stderr）

### Openness API

MCP 服务器通过 Siemens Openness API 直接连接 TIA Portal，无需额外中间层：
- 附加到运行中的 TIA Portal 实例
- 或启动新的 TIA Portal 实例（无头模式支持）

## 项目结构

```
vm-setup/
├── setup-vm.ps1              # 环境配置脚本
├── test-local-mcp.ps1        # MCP 测试脚本
├── check-environment.ps1     # 环境检查
├── generate-trae-config.ps1  # Trae 配置生成
├── verify-mcp.ps1            # MCP 功能验证
├── check-tia.ps1             # TIA Portal 状态检查
├── check-openness.ps1        # Openness API 检查
├── set-tia-env.ps1           # 环境变量设置
└── README.md                 # 本文档
```