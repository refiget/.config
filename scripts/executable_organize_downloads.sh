#!/usr/bin/env bash

DOWNLOADS="$HOME/Downloads"

# 路径定义
IMG="$DOWNLOADS/Images"
DOC="$DOWNLOADS/Documents"
VID="$DOWNLOADS/Videos"
ARC="$DOWNLOADS/Archives"
AUD="$DOWNLOADS/Audio"
COD="$DOWNLOADS/Code"
OTH="$DOWNLOADS/Others"
LOG_DIR="$DOWNLOADS/Logs"
LOG="$LOG_DIR/organize_downloads.log"

mkdir -p "$IMG" "$DOC" "$VID" "$ARC" "$AUD" "$COD" "$OTH" "$LOG_DIR"
touch "$LOG"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"
}

move_file() {
  local src="$1"
  local dest="$2"
  local echo_msg="$3"
  local log_msg="$4"

  if mv "$src" "$dest/"; then
    echo "$echo_msg → $(basename "$src")"
    log "$log_msg: $(basename "$src")"
  else
    echo "⚠️ 移动失败 → $(basename "$src")" >&2
    log "ERROR: failed to move $(basename "$src") to $dest"
  fi
}

echo "📂 正在整理 $DOWNLOADS ..."
log "Run start"

shopt -s nullglob
for file in "$DOWNLOADS"/*; do
  # 跳过目录，只整理文件
  if [ -d "$file" ]; then 
    continue
  fi

  # 获取文件扩展名（全部转换成小写）
  ext=$(echo "${file##*.}" | tr '[:upper:]' '[:lower:]')

  case "$ext" in
    jpg|jpeg|png|gif|bmp|svg|webp|heic)
      move_file "$file" "$IMG" "🖼 移动图片" "Moved image"
      ;;
    pdf|txt|md|doc|docx|ppt|pptx|xls|xlsx|csv)
      move_file "$file" "$DOC" "📄 移动文档" "Moved document"
      ;;
    mp4|mov|avi|mkv|flv|wmv)
      move_file "$file" "$VID" "🎬 移动视频" "Moved video"
      ;;
    zip|rar|7z|gz|tar)
      move_file "$file" "$ARC" "📦 移动压缩包" "Moved archive"
      ;;
    mp3|wav|aac|flac|ogg)
      move_file "$file" "$AUD" "🎵 移动音频" "Moved audio"
      ;;
    py|js|ts|cpp|c|java|html|css|json|sh)
      move_file "$file" "$COD" "💻 移动代码文件" "Moved code file"
      ;;
    *)
      move_file "$file" "$OTH" "📦 其他文件" "Moved other file"
      ;;
  esac
done

echo "✨ 整理完成！"
log "Run complete"
