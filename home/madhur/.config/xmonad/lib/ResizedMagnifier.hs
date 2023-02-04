{-# LANGUAGE FlexibleInstances, MultiParamTypeClasses #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Layout.ResizedMagnifier
-- Description :  Put non-focused windows in ribbons at the top and bottom of the screen.
-- Copyright   :  (c) glasser@mit.edu
-- License     :  BSD
--
-- Maintainer  :  glasser@mit.edu
-- Stability   :  stable
-- Portability :  unportable
--
-- LayoutClass that puts non-focused windows in ribbons at the top and bottom
-- of the screen.
-----------------------------------------------------------------------------

module ResizedMagnifier (
    -- * Usage
    -- $usage
    ResizedMagnifier(ResizedMagnifier)) where

import XMonad
import qualified XMonad.StackSet as W
import Data.Ratio

-- $usage
-- You can use this module with the following in your @~\/.xmonad\/xmonad.hs@:
--
-- > import XMonad.Layout.Accordion
--
-- Then edit your @layoutHook@ by adding the Accordion layout:
--
-- > myLayout = Accordion ||| Full ||| etc..
-- > main = xmonad def { layoutHook = myLayout }
--
-- For more detailed instructions on editing the layoutHook see:
--
-- "XMonad.Doc.Extending#Editing_the_layout_hook"

data ResizedMagnifier a = ResizedMagnifier deriving ( Read, Show )

instance LayoutClass ResizedMagnifier Window where
    pureLayout _ sc ws = zip ups tops ++ [(W.focus ws, mainPane)] ++ zip dns bottoms
     where
       ups    = reverse $ W.up ws
       dns    = W.down ws
       (top,  allButTop) = splitVerticallyBy (3%8 :: Ratio Int) sc
       (center,  bottom) = splitVerticallyBy (2%5 :: Ratio Int) allButTop
       (allButBottom, _) = splitVerticallyBy (5%8 :: Ratio Int) sc
       mainPane | ups /= [] && dns /= [] = center
                | ups /= []              = allButTop
                | dns /= []              = allButBottom
                | otherwise              = sc
       tops    = if ups /= [] then splitVertically (length ups) top    else []
       bottoms = if dns /= [] then splitVertically (length dns) bottom else []

