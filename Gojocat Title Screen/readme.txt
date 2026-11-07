Gojocat Title Screen Mod

You may edit this mod for PERSONAL use only. Do NOT distribute this mod without my permission and consent on anywhere. Do NOT repost this mod or the art used in this mod anywhere. This mod is only on NexusMods.

IN CASE OF CLASH:
If you have other mods which replace the loading screen, for example any UI Recolor mods, this mod may not work as it clashes with these mods and will be overwritten. 

Follow these steps to get this to work.
1. Go to the clashing mod and find the content.json file
2. Make a backup of the content.json then open it with Notepad
3. Press CTRL+F and search "TitleButtons" to find this section. It should look like this:
This is the code for the loading screen and should be the clashing code.
﻿ {
      "Action": "EditImage",
      "Target": "Minigames/TitleButtons",
      "FromFile": "assets/TitleButtons.png",
      "FromArea": {
        "X": 0,
        "Y": 307,
        "Width": 400,
        "Height": 137
4. Simply delete that section
5. Ctrl+S to save the file, and launch the game, now the mod should work properly.
6. If anything went wrong, use the backup you made of the content.json

Happy Gojocat!

- lunarmilktea

If you liked this mod you may donate to me here:
ko-fi.com/lunarmilkt
Every bit of money will help me in bringing more of my random ideas to life. Thank you!