#!/bin/bash

# Иконки
ACTIVE_ICON="\n"
INACTIVE_ICON="\n"

# Получаем список рабочих столов
workspaces=$(niri msg workspaces | tail -n +2)

# Обрабатываем вывод
output=""
while IFS= read -r line; do
    # Извлекаем номер рабочего стола
    num=$(echo "$line" | awk '{print $NF}')
    
    # Проверяем, активный ли это рабочий стол
    if [[ "$line" == *"*"* ]]; then
        output+="$ACTIVE_ICON "
    elif [[ "$line" == *":"* ]]; then
        output+="\n "
    else
        output+="$INACTIVE_ICON "
    fi
done <<< "$workspaces"

# Удаляем последний пробел
output=$(echo "$output" | sed 's/ $//')

# Возвращаем JSON
echo "{\"text\":\"\n $output \"}"
