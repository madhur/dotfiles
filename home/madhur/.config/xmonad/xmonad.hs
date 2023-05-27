import XMonad
import System.IO (hClose, hPutStr, hPutStrLn)
import Data.Char (isSpace, toUpper)

import XMonad.Layout.Named	(named)
import XMonad.Hooks.StatusBar
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.StatusBar.PP
import XMonad.Util.Loggers
import XMonad.Layout.Accordion
import XMonad.Layout.Tabbed
import XMonad.Layout.Decoration 
import XMonad.Layout.SubLayouts
import XMonad.Layout.ResizableTile
import XMonad.Layout.MultiToggle (mkToggle, single, EOT(EOT), (??))
import XMonad.Layout.MultiToggle.Instances
import XMonad.Layout.WindowNavigation
import XMonad.Layout.LimitWindows (limitWindows, increaseLimit, decreaseLimit)
import XMonad.Actions.Promote
import XMonad.Actions.RotSlaves (rotSlavesDown, rotAllDown)
import XMonad.Actions.WindowGo (runOrRaise)
import XMonad.Actions.WithAll (sinkAll, killAll)
import XMonad.Actions.CycleWS (Direction1D(..), moveTo, shiftTo, WSType(..), nextWS, prevWS, toggleWS, emptyWS)
import XMonad.Hooks.ManageDocks (avoidStruts, docksEventHook, manageDocks, ToggleStruts(..))
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.SetWMName
import XMonad.Layout.LayoutCombinators (JumpToLayout)
import XMonad.Util.EZConfig
import XMonad.Util.Ungrab
import XMonad.Layout.ThreeColumns
import qualified XMonad.Layout.Magnifier as Mag
import XMonad.Hooks.EwmhDesktops
import XMonad.Layout.Renamed
import XMonad.Layout.NoBorders
import XMonad.Prompt.ConfirmPrompt
import XMonad.Prompt
import XMonad.Prompt.Shell
import XMonad.Layout.ToggleLayouts as TL
import XMonad.Util.ClickableWorkspaces
import qualified Data.Map                            as M
import qualified XMonad.StackSet                     as W
import qualified XMonad.Layout.ToggleLayouts as T (toggleLayouts, ToggleLayout(Toggle))
import qualified XMonad.Layout.MultiToggle as MT (Toggle(..))
import System.Exit (exitSuccess)
import XMonad.Util.Run (runProcessWithInput, safeSpawn, spawnPipe)
import XMonad.Util.SpawnOnce
import XMonad.ManageHook
import XMonad.Util.Cursor
import XMonad.Util.NamedActions
import XMonad.Layout.Gaps
import XMonad.Layout.Spacing
import XMonad.Hooks.DynamicIcons
import XMonad.Layout.LayoutModifier
import XMonad.Hooks.InsertPosition
import XMonad.Layout.Simplest
import XMonad.Layout.Spiral
import XMonad.Layout.SimplestFloat
import XMonad.Layout.GridVariants (Grid(Grid))
import XMonad.Layout.CenteredMaster
import ResizedMagnifier

normalBorderColor' = "#333333"
focusedBorderColor' = "#4c7899"
borderWidth' = 1
myTerminal = "kitty"
-- Prompt
myPromptConfig = def
    { position          = Top
    , alwaysHighlight   = True
    , promptBorderWidth = 0
    , font              = "xft:monospace:size=12"
    }



--Makes setting the spacingRaw simpler to write. The spacingRaw module adds a configurable amount of space around windows.
mySpacing :: Integer -> l a -> XMonad.Layout.LayoutModifier.ModifiedLayout Spacing l a
mySpacing i = spacingRaw False (Border i i i i) True (Border i i i i) True

-- Below is a variation of the above except no borders are applied
-- if fewer than two windows. So a single window has no gaps.
mySpacing' :: Integer -> l a -> XMonad.Layout.LayoutModifier.ModifiedLayout Spacing l a
mySpacing' i = spacingRaw True (Border i i i i) True (Border i i i i) True



tall = renamed [Replace "Tall"]
       $ smartBorders
       $ windowNavigation
--       $ subTabbed
       $ addTabs shrinkText myTabTheme
       $ subLayout [] (Simplest)
--          $ limitWindows 12
--       $ mySpacing 8
--           $ ResizableTall 1 (3/100) (1/2) []
       $ Mag.magnifierczOff 1.3 
       $ Tall 1 (3/100) (1/2)

threecolmid = renamed [Replace "ThreeCol"]
              $ smartBorders
              $ windowNavigation
              $ addTabs shrinkText myTabTheme
              $ subLayout [] (Simplest)
--          $ limitWindows 12
--           $ mySpacing 8
--           $ ResizableTall 1 (3/100) (1/2) []          
              $ Mag.magnifierczOff 1.3 
              $ ThreeColMid 1 (3/100) (1/2)

fullgaps = renamed [Replace "FullGaps"]
           $ smartBorders
           $ gaps [(L,500), (R,500)] 
           Full

full = renamed [Replace "Full"]
           $ smartBorders           
           Full


-- floats   = renamed [Replace "floats"]
--            $ smartBorders
--            $ limitWindows 20 simplestFloat

grid     = renamed [Replace "grid"]
           $ smartBorders
           $ windowNavigation
           $ addTabs shrinkText myTabTheme
           $ subLayout [] (Simplest)
           $ limitWindows 12
           $ mkToggle (single MIRROR)
           $ Grid (16/10)


resizedMagnifier = renamed [Replace "resizedMagnifier"]
                   $ smartBorders
                   $ windowNavigation
                   $ Mirror Accordion

resizedMagnifier2 = renamed [Replace "resizedMagnifier"]
                   $ smartBorders
                   $ windowNavigation
                   $ Mirror ResizedMagnifier

tabsnew = renamed [Replace "Tabbed"]
--          $ smartBorders      
--          $ windowNavigation
--            $ spacingRaw False (Border 0 0 0 0) True (Border 8 8 8 8) True -- borderless
            $ tabbedAlways shrinkText myTabTheme


newLayout = mkToggle (NBFULL ?? NOBORDERS ?? EOT) $ (named "tall" tall ||| named "tabsnew" tabsnew ||| named "threecolmid" threecolmid ||| named "fullgaps" fullgaps ||| named "grid" grid |||  centerMaster threecolmid ||| named "Accordion" resizedMagnifier ||| named "ResizedMagnifier" resizedMagnifier2)

-- setting colors for tabs layout and tabs sublayout.
myTabTheme = def { fontName            = "xft:DejaVu Sans Mono:size=12:antialias=true"
                 , activeColor         = "#285577"
                 , inactiveColor       = "#5f676a"
                 , activeBorderColor   = "#285577"
                 , inactiveBorderColor = "#5f676a"
                 , activeTextColor     = "#ffffff"
                 , inactiveTextColor   = "#ffffff"
                 , decoHeight = 30
                 }

-- newLayout = mkToggle (NBFULL ?? NOBORDERS ?? EOT) $ (named "tall" tall ||| named "tabsnew" tabsnew ||| named "threecolmid" threecolmid ||| named "fullgaps" fullgaps )

-- myLayout =  mkToggle (NBFULL ?? NOBORDERS ?? EOT)  $  (gaps [(L,500), (R,500)] tiled   |||  gaps [(L,500), (R,500)]  Full |||  gaps [(L,500), (R,500)] threeCol |||    gaps [(L,500), (R,500)] tabs)
--   where
--     threeCol =  Mag.magnifierczOff 1.3 $ ThreeColMid nmaster delta ratio
--     tiled   = Mag.magnifierczOff 1.3 $ Tall nmaster delta ratio
--     nmaster = 1      -- Default number of windows in the master pane
--     ratio   = 1/2    -- Default proportion of screen occupied by master pane
--     delta   = 3/100  -- Percent of screen to increment by when resizing panes
-- tabs     = renamed [Replace "tabs"]
--   $ tabbed shrinkText myTabTheme

myStartupHook :: X ()
myStartupHook = do
  
  --spawn "killall conky"   -- kill current conky on each restart
  --spawn "killall trayer"  -- kill current trayer on each restart
  spawnOnce "trayer --edge top --align right --SetDockType true --SetPartialStrut true --expand true  --widthtype request  --transparent true --alpha 0 --height 30 --tint  0x000000"
  spawnOnce "sxhkd"
  spawnOnce "$HOME/.config/picom/launch.sh"
  spawnOnce "$HOME/.config/conky/launch.sh"
  spawnOnce "feh  --randomize --bg-fill $HOME/Pictures/wallpapers/"
  spawnOnce "killall dunst"
  spawnOnce "dunst"
  spawnOnce "flatpak run com.github.hluk.copyq"
  spawnOnce "xsettingsd"
  spawnOnce "nm-applet"
  spawnOnce "/opt/paloaltonetworks/globalprotect/PanGPUI"
  spawnOnce "guake"
  spawnOnce "indicator-sound-switcher"
  spawnOnce "/usr/libexec/xfce-polkit"
  -- spawnOnce "stalonetray"
  
  setDefaultCursor xC_left_ptr
  setWMName "LG3D"

windowCount :: X (Maybe String)
windowCount = gets $ Just . show . length . W.integrate' . W.stack . W.workspace . W.current . windowset


myXmobarPP :: PP
myXmobarPP = def
    { ppSep             = magenta " | "
    , ppTitle           = blue
    , ppTitleSanitize   = xmobarStrip
    , ppCurrent         = focused . wrap "" "" . xmobarBorder "Top" "#8be9fd" 2
    , ppHidden          = white . wrap "" ""
    , ppWsSep           = blue_dark " | "
    , ppLayout          = blue_dark
    -- , ppVisible =      blue . wrap " " ""
   -- , ppHiddenNoWindows = lowWhite . wrap " " ""
    , ppUrgent          = red . wrap (yellow "!") (yellow "!")
    , ppOrder           = \[ws, l, _, wins] -> [ws, l, wins]
    , ppExtras          = [logTitles formatFocused formatUnfocused]
    }
  where
    formatFocused   = wrap (  white    "[") (white    "]") . magenta . ppWindow
    formatUnfocused = wrap (  lowWhite "[") (lowWhite "]") . blue    . ppWindow
    -- | Windows should have *some* title, which should not not exceed a
    -- sane length.
    ppWindow :: String -> String
    ppWindow = xmobarRaw . (\w -> if null w then "untitled" else w) . shorten 30

    blue, lowWhite, magenta, red, white, yellow :: String -> String
    magenta  = xmobarColor "#81a1c1" ""
    blue     = xmobarColor "#81a1c1" "#2b2f40"
    blue_dark = xmobarColor "#81a1c1" ""
    white    = xmobarColor "#81a1c1" ""
    yellow   = xmobarColor "#f1fa8c" ""
    red      = xmobarColor "#ff5555" ""
    lowWhite = xmobarColor "#81a1c1" ""
    focused = xmobarColor  "#81a1c1" "#2b2f40"


toggleFloat :: Window -> X ()
toggleFloat w =
  windows
    ( \s ->
        if M.member w (W.floating s)
          then W.sink w s
          else (W.float w (W.RationalRect (1 / 3) (1 / 4) (1 / 2) (1 / 2)) s)
    )

subtitle' ::  String -> ((KeyMask, KeySym), NamedAction)
subtitle' x = ((0,0), NamedAction $ map toUpper
                      $ sep ++ "\n-- " ++ x ++ " --\n" ++ sep)
  where
    sep = replicate (6 + length x) '-'

showKeybindings :: [((KeyMask, KeySym), NamedAction)] -> NamedAction
showKeybindings x = addName "Show Keybindings" $ io $ do
  h <- spawnPipe $ "yad --text-info --fontname=\"SauceCodePro Nerd Font Mono 12\" --fore=#46d9ff back=#282c36 --center --geometry=1200x800 --title \"XMonad keybindings\""
  --hPutStr h (unlines $ showKm x) -- showKM adds ">>" before subtitles
  hPutStr h (unlines $ showKmSimple x) -- showKmSimple doesn't add ">>" to subtitles
  hClose h
  return ()


-- START_KEYS
myKeys :: XConfig l0 -> [((KeyMask, KeySym), NamedAction)]
myKeys c =
  let subKeys str ks = subtitle' str : mkNamedKeymap c ks in
    subKeys "Xmonad Essentials"
  [
   ("M-1", addName "Switch to workspace 1"    $ (windows $ W.greedyView $ myWorkspaces !! 0))
  , ("M-2", addName "Switch to workspace 2"    $ (windows $ W.greedyView $ myWorkspaces !! 1))
  , ("M-3", addName "Switch to workspace 3"    $ (windows $ W.greedyView $ myWorkspaces !! 2))
  , ("M-4", addName "Switch to workspace 4"    $ (windows $ W.greedyView $ myWorkspaces !! 3))
  , ("M-5", addName "Switch to workspace 5"    $ (windows $ W.greedyView $ myWorkspaces !! 4))
  , ("M-6", addName "Switch to workspace 6"    $ (windows $ W.greedyView $ myWorkspaces !! 5))
  , ("M-7", addName "Switch to workspace 7"    $ (windows $ W.greedyView $ myWorkspaces !! 6))
  , ("M-8", addName "Switch to workspace 8"    $ (windows $ W.greedyView $ myWorkspaces !! 7))
  , ("M-9", addName "Switch to workspace 9"    $ (windows $ W.greedyView $ myWorkspaces !! 8))
  , ("M-0", addName "Switch to workspace 9"    $ (windows $ W.greedyView $ myWorkspaces !! 9))

  
  , ("M-S-1", addName "Send to workspace 1"    $ (windows $ W.shift $ myWorkspaces !! 0))
  , ("M-S-2", addName "Send to workspace 2"    $ (windows $ W.shift $ myWorkspaces !! 1))
  , ("M-S-3", addName "Send to workspace 3"    $ (windows $ W.shift $ myWorkspaces !! 2))
  , ("M-S-4", addName "Send to workspace 4"    $ (windows $ W.shift $ myWorkspaces !! 3))
  , ("M-S-5", addName "Send to workspace 5"    $ (windows $ W.shift $ myWorkspaces !! 4))
  , ("M-S-6", addName "Send to workspace 6"    $ (windows $ W.shift $ myWorkspaces !! 5))
  , ("M-S-7", addName "Send to workspace 7"    $ (windows $ W.shift $ myWorkspaces !! 6))
  , ("M-S-8", addName "Send to workspace 8"    $ (windows $ W.shift $ myWorkspaces !! 7))
  , ("M-S-9", addName "Send to workspace 9"    $ (windows $ W.shift $ myWorkspaces !! 8))
  , ("M-S-0", addName "Send to workspace 9"    $ (windows $ W.shift $ myWorkspaces !! 9))
    -- KB_GROUP Xmonad
        --[ ("M-C-r", spawn "xmonad --recompile")       -- Recompiles xmonad
        --, ("M-S-r", spawn "xmonad --restart")         -- Restarts xmonad
  ,       ("M-S-q", addName "Quit XMonad"    $  io exitSuccess)                   -- Quits xmonad

    -- KB_GROUP Get Help
        , ("M-S-/",  addName "CheatSheat"  $ spawn "~/.config/xmonad/xmonad-keys.sh") -- Get list of keybindings
        , ("M-<Return>", addName "Launch terminal"   $ spawn (myTerminal))
    
    -- KB_GROUP Kill windows
        , ("M-S-c", addName "Kill focused window" $ kill)     -- Kill the currently focused client
    --    , ("M-S-a", killAll)   -- Kill all windows on current workspace

    -- KB_GROUP Workspaces
        , ("M-M1-<Left>", addName "Switch to previous workspace"   $ moveTo Prev(Not emptyWS))  -- Switch focus to previous workspace
        , ("M-M1-<Right>", addName "Switch to next workspace"  $ moveTo Next(Not emptyWS))  -- Switch focus to next workspace
         , ("M-<Left>", addName "Switch to left window"   $ sendMessage $ Go L)  
        , ("M-<Right>", addName "Switch to right window"   $ sendMessage $ Go R)  
        , ("M-<Up>", addName "Switch to right window"   $ sendMessage $ Go U) 
        , ("M-<Down>", addName "Switch to right window"   $ sendMessage $ Go D) 
        , ("M-S-<Left>", addName "Switch to left window"   $ sendMessage $ Swap L)  
        , ("M-S-<Right>", addName "Switch to right window"   $ sendMessage $ Swap R)  
        , ("M-S-<Up>", addName "Switch to right window"   $ sendMessage $ Swap U) 
        , ("M-S-<Down>", addName "Switch to right window"   $ sendMessage $ Swap D) 
        ,   ("M-<Space>", addName "Switch to next layout"   $ sendMessage NextLayout)
      --  ,   ("M-e", addName "Switch to tab layout"   $ JumpToLayout(tabs))
    -- KB_GROUP Floating windows
        , ("M-S-<Space>", addName "Float toggle" $ withFocused toggleFloat)
        , ("M-t", addName "Sink a floating window" $ withFocused $ windows . W.sink)  -- Push floating window back to tile
     --   , ("M-S-t", sinkAll)                       -- Push ALL floating windows to tile

    -- KB_GROUP Windows navigation
        , ("M-m", addName "Move focus to master window" $ windows W.focusMaster)  -- Move focus to the master window
        , ("M-j", addName "Move focus to next window"   $ windows W.focusDown)    -- Move focus to the next window
        , ("M-k", addName "Move focus to prev window"  $ windows W.focusUp)      -- Move focus to the prev window
        , ("M-S-m", addName "Swap focused window with master window" $ windows W.swapMaster) -- Swap the focused window and the master window
        , ("M-S-j", addName "Swap focused window with next window" $ windows W.swapDown)   -- Swap focused window with next window
        , ("M-S-k", addName "Swap focused window with prev window" $ windows W.swapUp)     -- Swap focused window with prev window
        , ("M-<Backspace>", addName "Move focused window to master" $ promote)      -- Moves focused window to master, others maintain order
        , ("M-S-<Tab>", addName "Rotate all windows except master" $ rotSlavesDown)    -- Rotate all windows except master and keep focus in place
        , ("M-C-<Tab>",  addName "Rotate all windows current stack" $ rotAllDown)       -- Rotate all the windows in the current stack

    -- KB_GROUP Layouts
        , ("M-<Tab>", addName "Toggle workspaces" $ toggleWS)           -- Switch to next layout
        -- , ("M-f", addName "Toggle noborders/full" $ sendMessage (MT.Toggle NBFULL) >> sendMessage ToggleStruts) -- Toggles noborder/full
         , ("M-f", addName "Toggle noborders/full" $ sendMessage (MT.Toggle NBFULL)) -- Toggles noborder/full
         --, ("M-f", addName "Toggle noborders/full" $ sendMessage $ JumpToLayout "full") -- Toggles noborder/full
        -- ("M-f", sendMessage (TL.Toggle "Full"))
        , ("M-`", addName "Toggle Magnifier"  $ sendMessage Mag.Toggle     )
         , ("M-g", addName "Toggle Gaps" $ sendMessage $ JumpToLayout "fullgaps")  -- Move focus to the master windo
         ,("M-<Escape>", addName "Toggle xmobar" $ sendMessage ToggleStruts)
         ,("M-e", addName "Jump to tiled" $ sendMessage $ JumpToLayout "tall")
         ,("M-w", addName "Jump to tabs" $ sendMessage $ JumpToLayout "tabsnew")
       --   ,("M-y", addName "Jump to tabs" $ sendMessage $ Toggle MIRROR)
   --     ,("M-S-q", confirmPrompt myPromptConfig "Confirm restart?" $ restart "xmonad" True)

    -- KB_GROUP Increase/decrease windows in the master pane or the stack
        , ("M-C-<Up>",  addName "Increase clients in master pane"   $ sendMessage (IncMasterN 1))      -- Increase # of clients master pane
        , ("M-C-<Down>",  addName "Decrease clients in master pane" $ sendMessage (IncMasterN (-1))) -- Decrease # of clients master pane
       -- , ("M-C-<Up>", addName "Increase max # of windows for layout" $ increaseLimit)                   -- Increase # of windows
       -- , ("M-C-<Down>",  addName "Decrease max # of windows for layout" $ decreaseLimit)                 -- Decrease # of windows

    -- KB_GROUP Window resizing
        , ("M-h", addName "Shrink window"  $ sendMessage Shrink)                   -- Shrink horiz window width
        , ("M-l", addName "Expand window"     $ sendMessage Expand)                   -- Expand horiz window width
        , ("M-M1-j", addName "Shrink window vertically" $ sendMessage MirrorShrink)          -- Shrink vert window width
        , ("M-M1-k", addName "Expand window vertically" $ sendMessage MirrorExpand)          -- Expand vert window width

    -- KB_GROUP Sublayouts
    -- This is used to push windows to tabbed sublayouts, or pull them out of it.
        , ("M-C-h", addName "pullGroup L"  $ sendMessage $ pullGroup L)
        , ("M-C-l", addName "pullGroup R"  $ sendMessage $ pullGroup R)
        , ("M-C-k", addName "pullGroup U"  $   sendMessage $ pullGroup U)
        , ("M-C-j", addName "pullGroup D"   $ sendMessage $ pullGroup D)
        , ("M-C-m", addName "MergeAll"  $ withFocused (sendMessage . MergeAll))
        -- , ("M-C-u", withFocused (sendMessage . UnMerge))
        , ("M-C-/", addName "UnMergeAll" $ withFocused (sendMessage . UnMergeAll))
        , ("M-C-.", addName "Switch focus next tab" $ onGroup W.focusUp')    -- Switch focus to next tab
        , ("M-C-,", addName "Switch focus prev tab" $ onGroup W.focusDown')  -- Switch focus to prev tab

        ]



-- Mouse bindings

myMouseBindings XConfig {XMonad.modMask = modm} = M.fromList

    -- mod-button1, Set the window to floating mode and move by dragging
    [ 
      ((modm, button1), (\w -> focus w >> mouseMoveWindow w))

    -- mod-button2, Raise the window to the top of the stack
       -- mod-button2, Raise the window to the top of the stack
    , ((modm, button2), (\w -> focus w >> windows W.swapMaster))
    , ((0, button2), \w -> kill)

    -- mod-button3, Set the window to floating mode and resize by dragging
    , ((modm, button3), (\w -> focus w >> mouseResizeWindow w))

    -- you may also bind events to the mouse scroll wheel (button4 and button5)
    ]


myManageHook :: ManageHook
myManageHook = composeAll
    [ 
      className =? "Guake" --> doCenterFloat,
      className =? "copyq" --> doCenterFloat,
      className =? "kruler" --> doCenterFloat,
      className =? "Yad" --> doCenterFloat,
      className =? "feh" --> doCenterFloat,
    --  resource =? "stalonetray" --> doIgnore,
     -- classNameH =? "trayer" --> doIgnore,

      className =? "PanGPUI" --> doRectFloat (W.RationalRect 0.85 0 0.9 0.25) ,
    
     className =? "Firefox" --> doShift (myWorkspaces !!8),
     className =? "firefox" --> doShift (myWorkspaces !!8),
     className =? "Navigator" --> doShift (myWorkspaces !!8),
     className =? "Chrome" --> doShift (myWorkspaces !!0),
     className =? "Slack" --> doShift (myWorkspaces !!9),
     className =? "Google-chrome" --> doShift (myWorkspaces !!0),
     className =? "Code" --> doShift (myWorkspaces !!2),
     className =? "install4j-com-kafkatool-ui-MainApp" --> doShift (myWorkspaces !!6),
     className =? "DBeaver" --> doShift (myWorkspaces !!3),
     className =? "jetbrains-idea-ce" --> doShift (myWorkspaces !!1),
     className =? "jetbrains-idea" --> doShift (myWorkspaces !!1),
      isDialog            --> doCenterFloat,
      isModal --> doCenterFloat
    ]

isModal :: Query Bool
isModal = isInProperty "_NET_WM_STATE" "_NET_WM_STATE_MODAL"

myWorkspaces       = ["  1: \xf268   ","  2: \xe738   ","  3: \xe70c   ","  4: \xf1c0   ","  5: \xf197   ","  6: \xfb13   ","  7: \xfb13   ","  8: \xfb13   ","  9: \xf269   ","  10: \xf198   "]
-- myWorkspaces       = ["1","2","3","4","5","6","7","8","9","0"]

myIcons :: Query [String]
myIcons = composeAll
  [ className =? "Google-Chrome" --> appIcon "\xf268"
  , className =? "firefox" --> appIcon "\xf269"
  , className =? "Navigator" --> appIcon "\xf269"
  , className =? "Code" --> appIcon "\xe70c"
  ]
myIconConfig = def{ iconConfigIcons = myIcons, iconConfigFmt = iconsFmtAppend concat }

main :: IO ()
main = xmonad $ addDescrKeys' ((mod4Mask, xK_F1), showKeybindings) myKeys
     . ewmhFullscreen
     . ewmh
     . withEasySB (statusBarProp "xmobar ~/.config/xmonad/xmobarrc" (clickablePP myXmobarPP)) toggleStrutsKey
     $ myConfig
  where
    toggleStrutsKey :: XConfig Layout -> (KeyMask, KeySym)
    toggleStrutsKey XConfig{ modMask = m } = (m, xK_Escape)

myConfig = def
    { modMask    = mod4Mask  -- Rebind Mod to the Super key
    --, layoutHook =  smartBorders $ myLayout  -- Use custom layouts
    ,layoutHook = newLayout
    , manageHook =  insertPosition End Newer <+>  myManageHook  -- Match on certain windows
    , terminal           = myTerminal
    ,focusedBorderColor = focusedBorderColor'
    , normalBorderColor = normalBorderColor'
     , borderWidth = borderWidth'
      ,workspaces          = myWorkspaces
    ,mouseBindings       = myMouseBindings
    , startupHook        = myStartupHook
    }

