#!/bin/bash
#
# H200_100P_AM625 项目专用 Post-Image 脚本
# 功能：在 genimage.sh 生成镜像后，对指定镜像进行 EMS 签名打包
#
# 参数：
#   $1 = BINARIES_DIR (buildroot/output/images)
#   $2+ = 其他参数（与 genimage.sh 相同）
#

set -e

BINARIES_DIR="$1"
BOARD_DIR="$(dirname $0)"

# EMS 签名工具路径（相对于 buildroot-external-TI）
EMS_SIGN_TOOL="${BR2_EXTERNAL_LINUX_BSP_PATH}/utils/ems_sign_tools/ems_sign"

echo ""
echo "========================================"
echo "  H200 Post-Image Processing"
echo "========================================"
echo "Project: H200_100P_AM625"
echo "Binaries: ${BINARIES_DIR}"
echo "EMS_SIGN_TOOL: $EMS_SIGN_TOOL"
echo ""

# Check if EMS sign tool exists
if [ ! -f "$EMS_SIGN_TOOL" ]; then
    echo "[Error] EMS sign tool not found!"
    echo "Path: $EMS_SIGN_TOOL"
    exit 1
fi

# ==========================================
# 文件名定义（在BINARIES_DIR目录下）
# ==========================================
FILE_LOADER="tiboot3.bin"

# 从 Buildroot 配置中动态获取设备树文件名
# 优先从环境变量读取，如果没有则从 .config 文件读取
if [ -n "$BR2_H200_DTB_FILE" ]; then
    FILE_FDT="$BR2_H200_DTB_FILE"
else
    # 从 Buildroot .config 文件中读取配置
    BR2_CONFIG="${BR2_CONFIG:-${O:-output}/.config}"
    if [ -f "$BR2_CONFIG" ]; then
        FILE_FDT=$(grep '^BR2_H200_DTB_FILE=' "$BR2_CONFIG" | cut -d'"' -f2)
    fi

    # 如果仍然没有获取到，使用默认值
    if [ -z "$FILE_FDT" ]; then
        FILE_FDT="k3-am625-sk.dtb"
        echo "[Warning] BR2_H200_DTB_FILE not found in config, using default: $FILE_FDT"
    fi
fi

echo "[Info] Using Device Tree: $FILE_FDT"

FILE_TEEOS="tispl.bin"
FILE_UBOOT="u-boot.img"
FILE_KERNEL="Image.gz"

# ==========================================
# 输出文件名定义
# ==========================================
OUT_LOADER="loader-sign.bin"
OUT_FDT="fdt-sign.bin"
OUT_TEEOS="teeos-sign.bin"
OUT_UBOOT="uboot-sign.bin"
OUT_KERNEL="kernel-sign.bin"

# ==========================================
# 打包配置表 (格式: "源文件变量名 输出文件变量名 head_write_flag")
# head_write_flag: yes=需要使用-h参数, no=不使用-h参数
# ==========================================
PACK_TABLE="
FILE_LOADER    OUT_LOADER    no
FILE_FDT       OUT_FDT       yes
FILE_TEEOS     OUT_TEEOS     yes
FILE_UBOOT     OUT_UBOOT     yes
FILE_KERNEL    OUT_KERNEL    yes
"

# Create release output directory
RELEASE_DIR="${BINARIES_DIR}/release"
if [ ! -d "$RELEASE_DIR" ]; then
    echo "[Info] Creating release directory..."
    mkdir -p "$RELEASE_DIR"
fi

# ================= Execute Pack Commands =================
echo ""
echo "[Pack] Starting to pack files using EMS sign tool..."
echo "=========================================="

# 使用临时文件记录结果
PACKED_LIST="/tmp/packed_$$.txt"
SKIPPED_LIST="/tmp/skipped_$$.txt"
FAILED_LIST="/tmp/failed_$$.txt"
> "$PACKED_LIST"
> "$SKIPPED_LIST"
> "$FAILED_LIST"

echo "$PACK_TABLE" | while read -r src_var out_var head_flag; do
    # 跳过空行
    [ -z "$src_var" ] && continue

    # 通过变量名获取实际文件名
    eval src_file=\$$src_var
    eval out_file=\$$out_var

    src_path="$BINARIES_DIR/$src_file"
    dst_path="$RELEASE_DIR/$out_file"

    # 检查源文件是否存在
    if [ ! -f "$src_path" ]; then
        echo "⏭️  跳过: $src_file - 文件不存在"
        echo "$src_file" >> "$SKIPPED_LIST"
        continue
    fi

    # 根据head_flag决定是否使用-h参数
    if [ "$head_flag" = "yes" ]; then
        echo "📦 打包: $src_file -> $out_file (with -h flag)"
        "$EMS_SIGN_TOOL" -h "$src_path" "$dst_path"
    else
        echo "📦 打包: $src_file -> $out_file (without -h flag)"
        "$EMS_SIGN_TOOL" "$src_path" "$dst_path"
    fi

    if [ $? -eq 0 ]; then
        echo "✅ 打包成功: $out_file"
        echo "$out_file" >> "$PACKED_LIST"
    else
        echo "❌ 打包失败: $out_file"
        echo "$out_file" >> "$FAILED_LIST"
    fi
    echo ""
done

# 从临时文件读取结果
PACKED_FILES=$(cat "$PACKED_LIST" 2>/dev/null)
SKIPPED_FILES=$(cat "$SKIPPED_LIST" 2>/dev/null)
PACK_FAILED_FILES=$(cat "$FAILED_LIST" 2>/dev/null)

# 清理临时文件
rm -f "$PACKED_LIST" "$SKIPPED_LIST" "$FAILED_LIST"

echo "=========================================="
echo "✅ 打包任务完成！"
echo "=========================================="

# 显示打包汇总信息
echo ""
echo "📊 打包汇总:"
echo "----------------------------------------"

if [ -n "$PACKED_FILES" ]; then
    echo "✅ 成功打包的文件:"
    for file in $PACKED_FILES; do
        echo "   ✓ $file"
    done
else
    echo "⚠️  没有成功打包任何文件"
fi

echo ""
if [ -n "$SKIPPED_FILES" ] || [ -n "$PACK_FAILED_FILES" ]; then
    echo "⏭️  跳过/失败的文件:"
    for file in $SKIPPED_FILES; do
        echo "   - $file (文件不存在)"
    done
    for file in $PACK_FAILED_FILES; do
        echo "   - $file (打包失败)"
    done
fi

echo "----------------------------------------"
echo "[Info] 输出目录: $RELEASE_DIR"
if [ -n "$PACKED_FILES" ]; then
    echo "[Info] 生成的文件列表:"
    ls -lh "$RELEASE_DIR"
fi
echo "=========================================="
echo ""

