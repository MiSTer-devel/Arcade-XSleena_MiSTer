# Xain'd Sleena (Bootleg) (beta):
![Xaind Sleena](/doc/Xaind-sleena-Flyer.jpg)


Xain'd Sleena (ザインドスリーナ) is a two genre Platformer and side-scrolling arcade video game produced by Technos in 1986. It was licensed for release outside of Japan by Taito. In the USA, the game was published by Memetron, and the game was renamed to Solar Warrior. The European home computer ports renamed the game to Soldier of Light.

## Gameplay
![Instructions](/doc/xain_sleena_preview.JPG)
The main character, Xain, is a galactic bounty-hunter who must defeat evil forces who oppress five different planets. The player can select any order to play the various planets, so, there is no 'official' sequence of play (For the U.S. version, this game was released as 'Solar Warrior'. This version goes through a set sequence instead of having to choose planets).

Each planet is played with right horizontal and vertical scrolling, shooting enemies and dodging natural hazards. Xain can crouch, double crouch (prone), jump and double jump. In some of the planets the player will need to kill a sub-boss to resume. Certain enemies carry a powerup which changes the default laser gun into a different weapon. The different weapons which are cycled through powerups include a laser-grenade gun, a 2-way gun, a spreadfire gun and a strong bullet gun with their own respective damage and directional firing capabilities.

At the end of the planet, the player goes into battle with a boss. Once defeated, the player plants a bomb into the boss' base and has ten seconds to escape in a starship.

The next half of the planet stage is an interlude stage during which the player must battle through waves of enemy ships while heading to the next planet. After three planets there is a battle through an asteroid field and against a giant mothership.

When all five planets are liberated, the player will play the longer final stage on a gigantic metallic fortress, facing the bosses previously met on each of the five planets. Fighting bosses in this stage is optional. Halfway through the stage the player plants a bomb on the fortress core and has 60 seconds to reach the exit hangar and jump into the starship.

sources: https://en.wikipedia.org/wiki/Xain%27d_Sleena

## Game inputs
### SNAC controller:
Enable it in OSD>SNAC>DB15 Devices
* Button A: Fire
* Button B: Jump
* Select: coin
* Start: start P1 or P2
* Button C: start P2 (mapped to player 1 controls for ease of continuing the game if you're only using one controller)
* Start + A: pause and Ko-fi supporters credits

### Keyboard:
* 1 Start P1
* 2 Start P2
* 5 Coin P1
* 6 Coin P2
* P Pause
* Ctrl Fir
* Alt Jump

### USB/Bluetooth game controllers:
* Configurable via MiSTer OSD menu.

## Relevant OSD options: 
* __Video Settings > Video Timing: 57.44Hz (Native), 60.0Hz (Standard)__: alternates between the default native video mode (intended for CRT displays) or a more convenient 60Hz mode (intended for HDMI and modern displays that don't play well with odd video timings)
* __OSD Pause__: Off, On
* __SNAC > DB15 Devices: Off, OnlyP1, OnlyP2, P1&P2__: if you connect a DB15 joystick/controller using a compatible SNAC adapter like the one created by Antonio Villena (https://www.antoniovillena.es/store/product/splitter-for-mister/). For me the best option by far to have a minimum of delay and better response.
* __HACKS > CPU Turbo: 1.0x, 2.0x__: This tweak allows you to double the speed of the primary and secondary CPU, which results in more fluid movement in general but has some side effects, although it allows you to play the game until the end. Turn it on or off as you like during the game.

## MiSTer.ini 
* __forced_scandoubler=0__: disable this setting, don't work with Xain'd Sleena Core.
* __composite_sync__: if you want to use a SVGA monitor use composite_sync=0. In another case use the setting that best fit your needs.
* __vga_scaler__: if you want play using a SVGA monitor use vga_scaler=1, in another case vga_scaler=0
* __video_mode__: if you want to use a SVGA monitor with vga_scaler=1 set a compatible resolution with your SVGA monitor here. Example: video_mode=1 (1024x768#60). In another case use the video mode that best suit your screen
## Manual installation
Rename the Arcade-XSleena_XXXXXXXX.rbf file to XSleena_XXXXXXXX.rbf and copy to the SD Card to the folder  /media/fat/_Arcade/cores and the .MRA files to /media/fat/_Arcade.

The required ROM files follow the MAME naming conventions (check inside MRA for this). Is the user responsability to be installed in the following folder:
/media/fat/_Arcade/mame/<mame rom>.zip

## Acknowledgments
* __Martin Donlon__ (__@Wickerwaka__) for helping with the SDRAM controller and PLL reconfig, based on its fabulous Irem-M72 core (https://github.com/MiSTer-devel/Arcade-IremM72_MiSTer).
* __@topapate__ for his JT12 core (https://github.com/jotego/jt12).
* To all Ko-fi contributors for supporting this project:__
LovePastrami__, __Zorro__, __Juan RA__, __Deu__, __@bdlou__, __Peter Bray__, __Nat__, __Funkycochise__, __David__, __Kevin Coleman__, __Denymetanol__, __Schermobianco__, __TontonKaloun__, __Wark91__, __Dan__, __Beaps__, __Todd Gill__, __John Stringer__, __Moi__, __Olivier Krumm__, __Raymond Bielun__, __peerlow__, __ManuelDopazoAtalaya__, __ALU_Card__.
* To all the people who with their comments have encouraged me to continue with this project.

