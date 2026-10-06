result=$(eww get result)
echo -n "$result" | xclip -selection clipboard

notify-send "$result copied to clipboard"

eww close calculator