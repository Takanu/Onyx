#### low-key 2022 readme update
*Hey there, this plugin has been abandoned for a while as I stopped using Godot but the idea still lives on, i've instead adapted these ideas into a set of tools that utilize Blender which i'll be releasing soon.  While this certainly contradicts the things I said about not wanting to use 3D modelling programs for environment design, Blender didn't have the powerful Geometry Nodes feature in 2019 and i've since been able to make a really tight workflow that quickly gets content out of Blender ready for any game engine you wish to use.*

*This plugin might still be useful but I can't provide any support or assistance*


----


## What is Onyx?
Onyx is a Godot plugin that provides series of custom 3D level design tools that can be used to develop advanced level designs, with a focus on architectural design and man-made structures.  They leverage Godot's unique design strengths and CSG boolean tech to make building complex structures and layouts simple.

### What is this for?
Apart from various private game engine tools developed in-house, a lot of level design still revolves around either reusing blocky assets which restricts your ability to be artistic, or using a 3D modelling engine to carve bespoke shapes and structures which prevents you from iterating on game design quickly and effectively as the logic, function and shading of a level becomes separated.

With next-gen consoles focusing heavily on SSDs to stream level content in almost instantaneously and tools like Media Molecule's Dreams demonstrating the potential of being able to work on all aspects of game design holistically, Onyx is my attempt to develop a tool *that lets you develop 3D levels in a way that lets you build as an Environment Artist and Level Designer simultaneously*, leaving the 3D modelling app for important visual elements. 


### What's included?
The first tool included is a node called *OnyxShape* that acts as a replacement for CSG shapes.  It uses the same CSG tech but with many improvements:

- Integrates several parametric shapes into a single node, letting you quickly copy, paste, switch and adjust to fill out a scene organically.
- Precise 3D controls with grid snap support and various meta-key actions, letting you adjust shapes with less clicks.
- Auto-Updating Origins on most parametric shapes, ensuring the origin is always positioned relative to the shape, where it makes sense.
- Proportional unwraps on almost all shapes by default, with additional UV options available
- Hollow Mode lets you quickly create compound shapes that adjust as the shape does.
- Better Boolean Preview wireframes that get out of the way when you need them to.


The next tool to be finished soon is *OnyxBrush*, a powerful replacement for CSGPolygon that builds its shape based on a series of polygonal points you define, but will offer many of the same features as *OnyxShape* and more.


## Installation Instructions
- Create a folder called 'addons' in the main folder of your project.
- Drag 'onyx' into the addons folder.
- View all your currently available plugins by going to Project > Project Settings > Plugins.
- Activate Onyx by clicking on the Status dropdown and changing it to 'Active'.

Once done, all the extra nodes this plugin provides will be available for you to add in your scenes.



