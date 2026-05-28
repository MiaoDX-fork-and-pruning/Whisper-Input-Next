#!/bin/bash

# Whisper-Input-Next 启动脚本 v2.0.0
# 用于启动语音转录工具

SESSION_NAME="whisper-input"
APP_DIR="$(pwd)"
PID_FILE="$APP_DIR/.whisper-input.pid"

stop_existing() {
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "🔄 关闭 tmux 会话: $SESSION_NAME"
    tmux send-keys -t "$SESSION_NAME" C-c 2>/dev/null || true
    sleep 0.5
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
  fi

  if [ -f "$PID_FILE" ]; then
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo "🔄 关闭主进程: $pid"
      kill "$pid" 2>/dev/null || true
      sleep 0.5
      kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi

  # 清理从当前项目目录直接启动的残留 main.py。
  for pid in $(pgrep -f 'python(3|)? .*main\.py|python(3|)? main\.py' || true); do
    cwd="$(readlink -f "/proc/$pid/cwd" 2>/dev/null || true)"
    if [ "$cwd" = "$APP_DIR" ]; then
      echo "🔄 清理残留进程: $pid"
      kill "$pid" 2>/dev/null || true
      sleep 0.2
      kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
    fi
  done
}

if [ "${1:-}" = "stop" ] || [ "${1:-}" = "off" ]; then
  stop_existing
  echo "✅ Whisper-Input-Next 已停止"
  exit 0
fi

echo "🚀 启动 Whisper-Input-Next 语音转录工具..."

# 创建日志目录(如果不存在)
if [ ! -d "logs" ]; then
  mkdir -p logs
fi

# 生成带时间戳的日志文件名
LOG_FILE="logs/Whisper-Input-Next-$(date +%Y%m%d-%H%M%S).log"
echo "📝 日志将保存到: $LOG_FILE"

# 检查.env文件是否存在
if [ ! -f ".env" ]; then
  echo "❌ 未找到 .env 配置文件"
  echo "请复制 env.example 到 .env 并配置您的API密钥"
  exit 1
fi

# 检查是否已有会话或残留进程
stop_existing

# 创建虚拟环境(如果不存在)
if [ ! -d ".venv" ]; then
  echo "🐍 创建虚拟环境..."
  python -m venv .venv
  echo "✅ 虚拟环境创建完成"
fi

# 检查依赖是否已安装
if [ ! -f ".venv/pyvenv.cfg" ] || [ ! -f "venv/lib/python*/site-packages/openai" ]; then
  echo "📦 安装项目依赖..."
  source .venv/bin/activate
  pip install -r requirements.txt
  echo "✅ 依赖安装完成"
fi

# 创建一个新的tmux会话
tmux new-session -d -s "$SESSION_NAME"

# 确保在正确的目录
tmux send-keys -t "$SESSION_NAME" "cd $(pwd)" C-m

# 激活虚拟环境
tmux send-keys -t "$SESSION_NAME" "source .venv/bin/activate" C-m

# 启动应用程序并同时将输出保存到日志文件
echo "🎙️  启动语音转录服务..."
tmux send-keys -t "$SESSION_NAME" \
  "python main.py > >(tee $LOG_FILE) 2>&1 & echo \$! > $PID_FILE; wait \$(cat $PID_FILE)" C-m

# 连接到会话
echo ""
echo "✅ Whisper-Input-Next 已启动！"
echo "📋 快捷键说明："
echo "   Ctrl+F: OpenAI GPT-4 转录 (高质量)"
echo "   Ctrl+I: 本地 Whisper 转录 (省钱)"
echo ""
echo "🔧 会话管理："
echo "   按 Ctrl+B 然后 D 可以分离会话"
echo "   使用 'tmux attach -t $SESSION_NAME' 重新连接"
echo "   使用 './stop.sh' 停止服务"
echo ""
echo "📝 日志文件: $LOG_FILE"
echo ""

tmux attach -t "$SESSION_NAME"
