#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${SCRIPT_DIR}"

# ================= 配置区 =================
HAR_MODULE_NAME="svg_image"
HAR_MODULE_PATH="packages/svg_image"
OUTPUT_DIR="./build/build_outputs"
BUILD_DATE=$(date +%Y%m%d_%H%M%S)

# 动态解析构建模式：支持传入 debug 或 release，默认为 release
BUILD_MODE="${1:-release}"
# 转为小写以兼容大小写输入
BUILD_MODE=$(echo "$BUILD_MODE" | tr '[:upper:]' '[:lower:]')

if [ "$BUILD_MODE" != "debug" ] && [ "$BUILD_MODE" != "release" ]; then
    echo "❌ ERROR: 无效的构建模式 '$BUILD_MODE'！仅支持 'debug' 或 'release'"
    echo "💡 使用示例: $0 debug 或 $0 release"
    exit 1
fi
# =========================================

# 校验全局 hvigorw 是否可用
if ! command -v hvigorw &> /dev/null; then
    echo "❌ ERROR: 系统未安装全局 hvigorw！"
    echo "💡 解决办法：请运行 'npm install -g @ohos/hvigor-cli' 全局安装工具。"
    exit 1
fi

echo "🚀 [1/4] 清理旧的构建缓存与输出..."
rm -rf ${OUTPUT_DIR}
mkdir -p ${OUTPUT_DIR}

hvigorw clean

echo "🔨 [2/4] 开始构建 ${HAR_MODULE_NAME} HAR 包 [模式: ${BUILD_MODE}]..."
# 关键改动：添加 -p buildMode=${BUILD_MODE} 参数
hvigorw --mode module -p module=${HAR_MODULE_NAME}@default -p product=default -p buildMode=${BUILD_MODE} assembleHar

# HAR 产物源路径（Hvigor 会自动放到对应 mode 的输出目录下）
HAR_SOURCE_PATH="./${HAR_MODULE_PATH}/build/default/outputs/default/${HAR_MODULE_NAME}.har"

echo "📦 [3/4] 检查并导出构建产物..."
mkdir -p "${OUTPUT_DIR}"
if [ -f "$HAR_SOURCE_PATH" ]; then
    # 产物名称带上模式标识（如：svg_image_release_v_20260330_120000.har）
    TARGET_NAME="${HAR_MODULE_NAME}_${BUILD_MODE}_v_${BUILD_DATE}.har"
    cp "$HAR_SOURCE_PATH" "${OUTPUT_DIR}/${TARGET_NAME}"
    echo "✅ SUCCESS: HAR 包构建成功，已导出至: ${OUTPUT_DIR}/${TARGET_NAME}"
else
    echo "❌ ERROR: 找不到构建产物，请检查路径: ${HAR_SOURCE_PATH}"
    exit 1
fi

if [ "$BUILD_MODE" != "release" ]; then
  echo "🎉 [4/4] 脚本执行完成。"
  exit 0
fi

confirm() {
    echo -n "是否发布${HAR_MODULE_NAME} 到 OHPM 仓库？(y/n): "
    read -n 1 -r response
    echo
    if [[ $response =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}
if confirm; then

  echo "📤 [4/4] 检查自动上传逻辑..."

  if [ "$BUILD_MODE" == "release" ] && ! command -v ohpm &> /dev/null; then
      echo "❌ ERROR: 系统未安装 ohpm 命令行工具！"
      exit 1
  fi

  echo "📡 正在发布 ${HAR_MODULE_NAME} 到 OHPM 仓库..."
  # 执行 ohpm 发布命令
  ohpm publish "${OUTPUT_DIR}/${TARGET_NAME}"

  echo "🎉 发布成功！"

else
  echo "💡 已取消发布到 OHPM 仓库。"
fi