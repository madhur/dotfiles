local os = os

return {
    editor = os.getenv("EDITOR") or "vim",
    terminal = "kitty",
    modkey = "Mod4",
    altkey = "Mod1",
    ctrlkey = "Control",
    shiftkey = "Shift",
    M = {modkey},
    M1 = {altkey},
    M_S = {modkey, shiftkey},
    M_C = {modkey, ctrlkey},
    M_S_C = {modkey, shiftkey, ctrlkey}
}
