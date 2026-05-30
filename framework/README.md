# Godot Multiplayer Framework

基于 Godot 4 的多人联机游戏框架，采用 Host-Authoritative 架构，面向 4 人以内休闲联机游戏。

## 特性

- **Host-Authoritative 权威服务器架构** — 服务端执行物理，客户端同步状态
- **多网络后端** — ENet（LAN/直连）、Noray（NAT 穿透）、Steam（Steam 联机），运行时切换
- **场景管理** — 带过渡动画的场景切换、参数传递、场景历史栈、多线程加载
- **存档系统** — JSON 持久化、分区存储、多存档槽位、自动保存、类型校验
- **事件总线** — 跨模块零耦合通信、类型校验、订阅者安全隔离
- **调试快捷键** — Ctrl+Shift 修饰键防冲突、暂停/逐帧/加速/状态面板，Release 自动移除
- **动画状态机** — 本地输入驱动 + 远程同步状态驱动，自动切换

## 目录结构

```
├── framework/                     # 框架核心（不需要修改）
│   └── core/
│       ├── scene_manager.gd       # 场景管理器
│       ├── save_system.gd         # 存档系统
│       ├── event_bus.gd           # 事件总线
│       └── debug_shortcuts.gd     # 调试快捷键
│
├── scripts/                       # 框架网络模块（不需要修改）
│   ├── network/
│   │   ├── network_manager.gd     # 网络连接管理
│   │   ├── multiplayer_manager.gd # 玩家同步管理
│   │   ├── enet_network.gd        # ENet 适配器
│   │   ├── noray_network.gd       # Noray 适配器
│   │   ├── steam_network.gd       # Steam 适配器
│   │   ├── lan_discovery.gd       # LAN 发现
│   │   ├── room_code.gd           # 房间编码
│   │   ├── upnp.gd                # UPnP
│   │   └── dedicated_server.gd    # 专用服务器启动器
│   ├── player/
│   │   ├── authoritative_player.gd # 权威玩家基类
│   │   ├── player_input.gd        # 输入采集 + RPC
│   │   └── character_model.gd     # 动画状态机
│   ├── ui/
│   │   └── ui_manager.gd          # UI 管理
│   └── menus/
│       └── ...                    # 菜单场景
│
├── scenes/                        # 场景文件
├── asssets/                       # 美术资源
└── addons/                        # 第三方插件（netfox 等）
```

## 架构概览

```
┌─────────────────────────────────────────────────────────┐
│                      游戏代码层                          │
│   GamePlayer (继承 AuthoritativePlayer)                  │
│   GameWorld (监听 EventBus 信号)                         │
│   场景脚本 (实现 SceneManager 钩子)                       │
└───────────────┬──────────────────────┬──────────────────┘
                │ 继承                  │ 监听/调用
┌───────────────▼──────────────────────▼──────────────────┐
│                      框架核心层                          │
│                                                         │
│   NetworkManager ──┬── NetworkPeer (ENet/Noray/Steam)   │
│                    └── MultiplayerManager                │
│                                                         │
│   AuthoritativePlayer (可继承扩展)                       │
│     ├── PlayerInput (输入采集 + RPC)                     │
│     └── CharacterModel (动画状态机)                      │
│                                                         │
│   SceneManager (场景切换 + 过渡动画 + 参数传递)           │
│   SaveSystem (JSON 持久化 + 多槽位 + 自动保存)           │
│   EventBus (跨模块事件通信 + 类型校验)                   │
│   DebugShortcuts (调试工具 + Release 自动移除)           │
│                                                         │
│   全局单例: NetworkManager, SceneManager,                │
│            SaveSystem, EventBus, DebugShortcuts          │
└─────────────────────────────────────────────────────────┘
```

## 模块详细说明

### SceneManager — 场景管理器

带过渡动画的场景切换，支持参数传递、场景历史栈和多线程加载。

```gdscript
# 带过渡动画切换场景
SceneManager.change_scene("res://scenes/game.tscn", {"level": 2}, SceneManager.Transition.FADE)

# 无动画立即切换
SceneManager.change_scene_instant("res://scenes/game.tscn")

# 返回上一个场景
SceneManager.go_back()

# 重启当前场景
SceneManager.restart_scene()

# 查询状态
SceneManager.is_changing_scene()
SceneManager.get_current_scene_data()  # {"path": "...", "params": {...}}
SceneManager.has_history()
```

**过渡动画类型**：

| 类型 | 效果 |
|------|------|
| `Transition.NONE` | 无过渡 |
| `Transition.FADE` | 淡入淡出 |
| `Transition.SLIDE_LEFT` | 左滑切换 |
| `Transition.SLIDE_RIGHT` | 右滑切换 |

**场景钩子方法** — 在场景脚本中实现，SceneManager 会在对应时机自动调用：

```gdscript
func get_data() -> Dictionary:       # 离开场景时，传递数据给下一个场景
    return {"score": 100}

func receive_data(data):             # 进入场景时，接收上一个场景的数据
    level_id = data.get("level", 1)

func init_scene():                   # 场景添加到树后，过渡动画还在播放时
    spawn_enemies()

func start_scene():                  # 过渡动画结束后
    enable_player_input()
```

**信号**：

```gdscript
SceneManager.scene_change_started
SceneManager.scene_change_finished
SceneManager.load_progress_updated(progress: float)  # 0.0 ~ 1.0
```

---

### SaveSystem — 存档系统

基于 JSON 的分区持久化存储，支持多存档槽位和自动保存。

```gdscript
# 写入
SaveSystem.set_value("settings", "volume", 0.8)
SaveSystem.set_value("settings", "fullscreen", true)
SaveSystem.set_value("progress", "level_unlocked", 5)
SaveSystem.save()

# 读取（第三个参数是默认值）
var vol = SaveSystem.get_value("settings", "volume", 1.0)

# 查询
SaveSystem.has_section("settings")
SaveSystem.has_section_key("progress", "level_unlocked")
SaveSystem.get_section_keys("settings")

# 删除
SaveSystem.erase_section_key("settings", "volume")
SaveSystem.erase_section("stats")
SaveSystem.clear_all()

# 多存档槽位
SaveSystem.set_slot(1)                           # 切换到槽位 1
SaveSystem.get_slot()                            # 当前槽位
SaveSystem.get_available_slots(5)                # 查询所有槽位状态
SaveSystem.delete_slot(1)                        # 删除槽位

# 自动保存：每 60 秒检查，有脏数据时自动写入磁盘
SaveSystem.is_dirty()
```

**类型校验** — 只接受 JSON 可序列化的类型（bool、int、float、String、Array、Dictionary），传入其他类型会报错拒绝。

**信号**：

```gdscript
SaveSystem.save_completed(section: String)
SaveSystem.load_completed(section: String)
```

---

### EventBus — 事件总线

跨模块零耦合通信，支持类型校验和订阅者安全隔离。

```gdscript
# 注册事件（可指定数据类型校验）
EventBus.register("player_died", TYPE_DICTIONARY)
EventBus.register("score_changed", TYPE_INT)

# 订阅事件
EventBus.subscribe("player_died", _on_player_died)
EventBus.subscribe("score_changed", _on_score_changed)

# 发射事件（类型不匹配会报错）
EventBus.emit_event("player_died", {"cause": "fall"})
EventBus.emit_event("score_changed", 100)

# 取消订阅
EventBus.unsubscribe("player_died", _on_player_died)

# 清理
EventBus.clear_event("player_died")
EventBus.clear_all()

# 查询
EventBus.has_subscribers("player_died")
```

**安全机制**：
- emit 前复制订阅者列表，遍历中 unsubscribe 不会崩溃
- 自动检测并清理已释放对象的订阅
- 数据类型校验，发射时类型不匹配会报错

**使用示例** — 玩家死亡通知多个系统：

```gdscript
# player.gd
func die():
    EventBus.emit_event("player_died", {"cause": "fall"})

# hud.gd
func _ready():
    EventBus.subscribe("player_died", _on_player_died)

func _on_player_died(data):
    show_death_screen(data.cause)

# sound_manager.gd
func _ready():
    EventBus.subscribe("player_died", _on_player_died)

func _on_player_died(_data):
    play_sound("death")
```

---

### DebugShortcuts — 调试快捷键

开发期调试工具，默认需要 `Ctrl+Shift` 修饰键防止与游戏输入冲突，Release 构建自动移除。

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+Shift+R` | 重启当前场景 |
| `Ctrl+Shift+P` | 暂停/恢复游戏 |
| `Ctrl+Shift+.` | 逐帧推进（暂停时） |
| `Ctrl+Shift+Q` | 退出游戏 |
| `Ctrl+Shift+F3` | 显示/隐藏调试面板 |
| `Ctrl+Shift` 按住 | 2 倍速 |

**调试面板显示内容**：
- FPS
- 对象数 / 节点数
- 渲染缓冲区内存
- 多人联机状态（在线/离线、对等体数量）

**自定义配置**：

```gdscript
@export var require_modifier: bool = true   # 是否需要修饰键（可关闭）
@export var restart_key: Key = KEY_R
@export var pause_key: Key = KEY_P
@export var speed_up_factor: float = 2.0
```

---

### NetworkManager — 网络连接管理

网络连接的统一入口，协调网络后端、场景切换、状态管理。内部通过 SceneManager 切换场景。

```gdscript
# 开房
NetworkManager.host_game(configs)

# 加入
NetworkManager.join_game(configs)

# 断开
NetworkManager.disconnect_from_game()

# 查询
NetworkManager.game_state          # MENU / LOBBY / IN_GAME
NetworkManager.is_host()           # 是否是主机
```

**信号**：

```gdscript
NetworkManager.connection_successful
NetworkManager.connection_failed(reason: String)
NetworkManager.server_disconnected
```

---

### MultiplayerManager — 玩家同步管理

Host-Authoritative 模式下的玩家实体管理。

```gdscript
# 获取玩家实体
var player = MultiplayerManager.get_player(peer_id)
```

**同步数据** — 服务端以 20Hz 广播，包含位置、速度、地面状态、跑步状态：

```gdscript
{
    "p": Vector3,      # position
    "v": Vector3,      # velocity
    "f": bool,         # is_on_floor
    "r": bool,         # is_running
}
```

**中途加入** — 新客户端加入时，服务端会传递所有现有玩家的完整状态（position + velocity + is_on_floor + is_running），避免首帧状态不完整。

---

### AuthoritativePlayer — 权威玩家基类

服务端执行物理，客户端 lerp 同步位置。提供 `_on_physics_tick` 钩子供子类扩展。

```gdscript
# 继承扩展游戏逻辑
class_name GamePlayer
extends AuthoritativePlayer

@export var attack_damage: float = 10.0
var health: float = 100.0

func _on_physics_tick(delta):       # 覆写钩子
    if _wants_attack:
        _do_attack()

func _do_attack():
    pass
```

**可覆写的属性和方法**：

| 属性/方法 | 说明 |
|-----------|------|
| `move_speed` | 移动速度（@export） |
| `jump_velocity` | 跳跃速度（@export） |
| `gravity` | 重力（@export） |
| `remote_smooth_rate` | 客户端 lerp 速率（@export） |
| `_on_physics_tick(delta)` | 物理帧钩子，子类覆写 |
| `get_effective_velocity()` | 获取速度（服务端真实/客户端同步） |
| `get_effective_is_on_floor()` | 获取地面状态 |
| `get_effective_is_running()` | 获取跑步状态 |

---

### PlayerInput — 输入采集

采集本地输入并通过 RPC 发送到服务端。

**输入数据包格式**：

```gdscript
{
    "direction_x": float,    # 水平方向
    "direction_z": float,    # 垂直方向
    "jump": bool,            # 跳跃
    "run": bool,             # 跑步
}
```

**设计决策**：
- 方向输入用 `unreliable_ordered`（30Hz），丢了下一帧补
- 跳跃用 `reliable`，离散事件丢了就跳不起来

---

### CharacterModel — 动画状态机

根据本地/远程自动选择动画驱动方式。

**本地玩家**：输入驱动状态机（Idle → Walk → Run → Jump）
**远程玩家**：同步数据驱动（根据 velocity + is_on_floor + is_running 判断动画）

**远程动画判断逻辑**：

```
不在地面 → jump
is_running 且 速度 > 0.5 → run
速度 > 0.5 → walk
否则 → idle
```

---

## 网络后端

框架支持三种网络后端，统一接口运行时切换：

| 后端 | 适用场景 | 依赖 |
|------|---------|------|
| ENet | LAN / 直连 / 专用服务器 | 内置 |
| Noray | NAT 穿透（跨网络直连） | noray 插件 |
| Steam | Steam 平台联机 | steam-multiplayer-peer 插件 |

切换方式：在主菜单选择网络类型，框架自动实例化对应后端。

## 快速开始

### 1. 创建自定义玩家

```gdscript
# game/player/game_player.gd
class_name GamePlayer
extends AuthoritativePlayer

@export var attack_damage: float = 10.0
var health: float = 100.0

func _on_physics_tick(delta):
    if _wants_attack and is_on_floor():
        _do_attack()
```

### 2. 创建玩家场景

基于 `authoritative_player.tscn`，将脚本替换为 `game_player.gd`。

### 3. 配置 MultiplayerManager

在 `game.tscn` 中，将 MultiplayerManager 的 `_authoritative_player_scene` 指向你的玩家场景。

### 4. 使用 EventBus 通信

```gdscript
# 注册和订阅
EventBus.register("game_over")
EventBus.subscribe("game_over", _on_game_over)

# 发射
EventBus.emit_event("game_over", {"winner": "player_1"})
```

### 5. 使用 SaveSystem 持久化

```gdscript
# 保存游戏设置
SaveSystem.set_value("settings", "music_volume", 0.5)
SaveSystem.save()

# 读取
var vol = SaveSystem.get_value("settings", "music_volume", 1.0)

# 多存档
SaveSystem.set_slot(2)
```

### 6. 使用 SceneManager 切换场景

```gdscript
# 带参数和过渡动画切换
SceneManager.change_scene("res://scenes/game.tscn", {"level": 3}, SceneManager.Transition.FADE)

# 在目标场景中接收参数
func receive_data(data):
    current_level = data.get("level", 1)

func start_scene():
    enable_input()

# 返回上一个场景
SceneManager.go_back()
```

## 断线处理策略

采用"断线即清理，重进当新人"策略（参考星露谷物语）：

1. 客机断线 → 服务端立即 `queue_free()` 实体 + 广播 despawn
2. 客机重新加入 → 当作新玩家，重新 spawn
3. 无重连 token、无宽限期、无状态保留

## 依赖

- **Godot 4.6+**
- **netfox** — 网络时间同步（当前未深度使用，预留）
- **noray** — NAT 穿透（Noray 后端时需要）
- **steam-multiplayer-peer** — Steam 联机（Steam 后端时需要）

## License

MIT
